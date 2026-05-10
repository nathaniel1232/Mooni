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

    private static let supabaseURL = URL(string: "https://renvohmlflagosguffjn.supabase.co")!
    private static let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJlbnZvaG1sZmxhZ29zZ3VmZmpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgzOTAwMTAsImV4cCI6MjA5Mzk2NjAxMH0.yCff7HBTYXsiEH0lpf6yEDJUAVfaGxCytvoPWSlw-Rs"

    static let client: SupabaseClient = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey)

    /// Convenience: is there a logged-in user right now?
    static var isSignedIn: Bool {
        client.auth.currentSession != nil
    }

    /// Returns the current user id, or nil if signed out.
    static var currentUserID: UUID? {
        client.auth.currentUser?.id
    }
}
