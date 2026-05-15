import Foundation
import Supabase

/// Persists the user's `OnboardingProfile` to Supabase whenever it changes.
///
/// **Required Supabase table** (run once in the SQL editor):
/// ```sql
/// create table if not exists public.profiles (
///   user_id      uuid primary key references auth.users(id) on delete cascade,
///   payload      jsonb not null,
///   updated_at   timestamptz not null default now()
/// );
///
/// alter table public.profiles enable row level security;
///
/// create policy "Users read own profile"
///   on public.profiles for select
///   using (auth.uid() = user_id);
///
/// create policy "Users upsert own profile"
///   on public.profiles for insert
///   with check (auth.uid() = user_id);
///
/// create policy "Users update own profile"
///   on public.profiles for update
///   using (auth.uid() = user_id);
/// ```
///
/// We store the whole profile as a single `jsonb` blob rather than mapping
/// 30+ columns — fast to ship, easy to evolve, and we rarely query individual
/// fields server-side. If/when analytics needs structured columns we can add
/// generated columns over the JSON.
actor ProfileSync {
    static let shared = ProfileSync()
    private init() {}

    /// Debounce so the chain of `didSet` calls fired during onboarding
    /// completion only results in one network round-trip.
    private var pendingTask: Task<Void, Never>?

    func upsertProfile(_ profile: OnboardingProfile) {
        pendingTask?.cancel()
        pendingTask = Task { [profile] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            if Task.isCancelled { return }
            await Self.performUpsert(profile)
        }
    }

    private static func performUpsert(_ profile: OnboardingProfile) async {
        guard let userID = Supa.currentUserID else {
            // Not signed in yet — Sign in with Apple will fire its own sync
            // after the session lands; nothing to persist server-side.
            return
        }
        do {
            let row = ProfileRow(
                user_id: userID,
                payload: profile,
                updated_at: ISO8601DateFormatter().string(from: Date())
            )
            try await Supa.client
                .from("profiles")
                .upsert(row, onConflict: "user_id")
                .execute()
        } catch {
            // Silent: profile is still safe in UserDefaults. We'll retry on
            // the next mutation. A network toast here would be more noise
            // than signal during onboarding.
        }
    }
}

private struct ProfileRow: Encodable {
    let user_id: UUID
    let payload: OnboardingProfile
    let updated_at: String
}
