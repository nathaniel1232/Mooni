import Foundation
import AuthenticationServices
import CryptoKit
import Supabase
import UIKit
import RevenueCat

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
        let nonce = try Self.randomNonceString()
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

        // Tie RevenueCat to the now-signed-in Supabase user. Routed through
        // SubscriptionManager.identify() so there's a single source of truth
        // for the logIn + refresh sequence. Without this, RevenueCat keeps a
        // device-bound anonymous ID, so an anonymous onboarding purchase would
        // be orphaned instead of following the user — and a reinstall would
        // lose the entitlement until the user signed in again. With it, an
        // anonymous purchase is aliased onto the Supabase user and re-attaches
        // automatically on a new install.
        if let uid = Supa.currentUserID {
            await SubscriptionManager.shared.identify(uid.uuidString)
        }
    }

    /// Call from sign-out paths so the next anonymous user (or a different
    /// signed-in user) doesn't inherit the previous user's entitlement.
    func signOut() async {
        try? await Supa.client.auth.signOut()
        _ = try? await Purchases.shared.logOut()
        await SubscriptionManager.shared.refreshCustomerInfo()
    }

    /// Backs the "Delete account & data" flow. Deletes the user's server-side
    /// data *before* signing out, because the row-level-security policies on
    /// `profiles` are scoped to `auth.uid()` — once the session is gone the
    /// client can no longer prove ownership and the delete would be rejected.
    ///
    /// Order matters and is deliberate:
    ///   1. Delete the server-side profile row while the session is still live.
    ///   2. Sign out of Supabase + unlink RevenueCat (local-side teardown).
    ///
    /// We rethrow a server-delete failure so the caller can surface it (and
    /// keep the session, letting the user retry) instead of silently signing
    /// out and orphaning the row. We still sign out on success.
    ///
    /// NOTE (backend): this removes only rows the *client* can delete under
    /// existing RLS — currently just `public.profiles`. The Supabase
    /// `auth.users` record itself can only be removed by a privileged
    /// (service-role) call, e.g. an Edge Function or admin job; the client
    /// anon key cannot delete an auth user. See crossFileNeeds.
    func deleteAccount() async throws {
        // 1. Server-side data wipe (throws on failure so we don't sign out
        //    and strand an undeletable row behind an expired session).
        try await ProfileSync.shared.deleteProfile()

        // 2. Local/session teardown — same path as a normal sign-out.
        await signOut()
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

    private static func randomNonceString(length: Int = 32) throws -> String {
        guard length > 0 else {
            throw NSError(domain: "AppleSignIn", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Nonce length must be positive."])
        }
        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let errorCode = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            guard errorCode == errSecSuccess else {
                throw NSError(domain: "AppleSignIn", code: Int(errorCode),
                              userInfo: [NSLocalizedDescriptionKey: "Could not generate secure random bytes. Please try again."])
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
