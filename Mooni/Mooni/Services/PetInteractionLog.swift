import Foundation
import Combine

/// Tracks the user's playful interactions with the owl (taps, pets, hearts).
///
/// Two pieces of state live here:
///   • `lastInteraction` — drives the "I missed you" speech bubble when the
///     user returns after more than 24 hours away.
///   • `interactionsToday` — light gating so a tap-spammer doesn't burn through
///     every line in the reaction pool in one second. Resets at midnight.
///
/// Stored in plain UserDefaults; no sync, no Supabase write. This is a comfort
/// feature, not a metric.
@MainActor
final class PetInteractionLog: ObservableObject {

    static let shared = PetInteractionLog()

    private enum Key {
        static let lastInteraction = "mooni.pet.lastInteractionAt"
        static let dayBucket = "mooni.pet.interactionsBucketDay"
        static let dayCount = "mooni.pet.interactionsBucketCount"
    }

    @Published private(set) var lastInteraction: Date?
    @Published private(set) var interactionsToday: Int = 0

    private init() {
        self.lastInteraction = UserDefaults.standard.object(forKey: Key.lastInteraction) as? Date
        self.interactionsToday = Self.currentBucketCount()
    }

    /// Call when the user taps the owl. Updates both timestamps so the next
    /// tap-reaction picker can use `interactionsToday` to vary the message.
    func registerTap(now: Date = Date()) {
        lastInteraction = now
        UserDefaults.standard.set(now, forKey: Key.lastInteraction)

        let todayKey = Self.dayKey(for: now)
        let storedKey = UserDefaults.standard.string(forKey: Key.dayBucket)
        if storedKey == todayKey {
            interactionsToday += 1
        } else {
            interactionsToday = 1
            UserDefaults.standard.set(todayKey, forKey: Key.dayBucket)
        }
        UserDefaults.standard.set(interactionsToday, forKey: Key.dayCount)
    }

    /// True when the owl should greet the user with "I missed you" — i.e. no
    /// interaction has been recorded in the last 24 hours.
    func owlMissedYou(now: Date = Date()) -> Bool {
        guard let last = lastInteraction else { return false }
        return now.timeIntervalSince(last) >= 24 * 3600
    }

    // MARK: - Helpers

    private static func dayKey(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.calendar = Calendar.current
        return f.string(from: date)
    }

    private static func currentBucketCount() -> Int {
        let storedKey = UserDefaults.standard.string(forKey: Key.dayBucket)
        let today = dayKey(for: Date())
        guard storedKey == today else { return 0 }
        return UserDefaults.standard.integer(forKey: Key.dayCount)
    }
}
