import Foundation
import AuthenticationServices
import CryptoKit
import Supabase
import UIKit

/// Native Sign in with Apple → Supabase OIDC exchange.
///
/// Flow:
///   1. Generate a cryptographic nonce, send the SHA256 hash to Apple.
///   2. Apple returns an identity token bound to that hash.
///   3. We hand the token + the raw (un-hashed) nonce to Supabase, which
///      verifies the token's signature against Apple's JWKs.
///   4. Supabase issues its own session — from here on we use Supa.client.
///
/// **Required setup**
///   - Xcode → target → Signing & Capabilities → +Capability → "Sign in with Apple".
///   - Apple Developer portal → Identifiers → enable Sign in with Apple on the App ID.
///   - Supabase dashboard → Authentication → Providers → Apple:
///       • Services ID (e.g. `com.sabaiduka.mooni.signin`)
///       • Team ID
///       • Key ID + the `.p8` private key from Apple Developer
///       • Add `https://YOUR-PROJECT.supabase.co/auth/v1/callback` to the
///         Apple Developer "Return URLs" list
@MainActor
final class AppleSignInService: NSObject {

    static let shared = AppleSignInService()
    private override init() {}

    private var continuation: CheckedContinuation<ASAuthorization, Error>?
    private var currentNonce: String?

    /// Triggers the system Apple sign-in sheet, then exchanges the resulting
    /// identity token for a Supabase session. Throws on cancellation, network
    /// failure, or invalid token.
    func signInAndSyncWithSupabase() async throws {
        let nonce = Self.randomNonceString()
        currentNonce = nonce

        let authorization = try await runAppleSignIn(nonce: Self.sha256(nonce))

        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let idTokenData = credential.identityToken,
            let idTokenString = String(data: idTokenData, encoding: .utf8)
        else {
            throw NSError(
                domain: "AppleSignIn",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Apple didn't return a valid identity token. Please try again."]
            )
        }

        try await Supa.client.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idTokenString,
                nonce: nonce
            )
        )
    }

    /// Wraps the delegate-based ASAuthorizationController in async/await.
    private func runAppleSignIn(nonce hashedNonce: String) async throws -> ASAuthorization {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ASAuthorization, Error>) in
            self.continuation = continuation
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = hashedNonce

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    // MARK: - Nonce helpers

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with \(errorCode)")
                }
                return random
            }
            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleSignInService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            self.continuation?.resume(returning: authorization)
            self.continuation = nil
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            self.continuation?.resume(throwing: error)
            self.continuation = nil
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AppleSignInService: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(
        for controller: ASAuthorizationController
    ) -> ASPresentationAnchor {
        // Hop to the main actor synchronously to grab the active window.
        // ASAuthorizationController calls this on the main thread already
        // but the protocol is declared nonisolated, so we use an explicit
        // sync hop to keep the compiler happy.
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?
                .windows
                .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
        }
    }
}
