import Foundation
import Supabase

/// Single shared Supabase entry point.
///
/// **Setup checklist**
///
/// 1. Create a project at https://supabase.com.
/// 2. Settings → API → copy the **Project URL** and the **anon public** key.
/// 3. In Xcode, add an `xcconfig` (e.g. `Mooni/Config/Supabase.xcconfig`) with:
///    ```
///    SUPABASE_URL = https:/$()/your-project-ref.supabase.co
///    SUPABASE_ANON_KEY = your-anon-public-key
///    ```
///    The `$()` escape stops Xcode from interpreting `//` as a comment.
/// 4. Add matching `SUPABASE_URL` (string) and `SUPABASE_ANON_KEY` (string)
///    keys to `Info.plist` so the values get baked into the app at build
///    time. NEVER commit the real key file — use a `.gitignore` line.
/// 5. Hook this client up to your sleep sync, friends list, etc.
///
/// **Why a singleton**: `SupabaseClient` from the SDK is itself a heavy
/// long-lived object that holds an authenticated session, retries, and a
/// realtime socket. There's no benefit to constructing more than one.
enum Supa {

    /// Single global client. Crashes early at launch if config is missing,
    /// which is what you want — better than silently failing every query.
    static let client: SupabaseClient = {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let url = URL(string: urlString),
            let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            !key.isEmpty
        else {
            fatalError("""
                Missing SUPABASE_URL / SUPABASE_ANON_KEY in Info.plist.
                Add them via an xcconfig file. See SupabaseClient.swift for setup.
                """)
        }
        return SupabaseClient(supabaseURL: url, supabaseKey: key)
    }()

    /// Convenience: is there a logged-in user right now?
    static var isSignedIn: Bool {
        client.auth.currentSession != nil
    }

    /// Returns the current user id, or nil if signed out.
    static var currentUserID: UUID? {
        client.auth.currentUser?.id
    }
}
