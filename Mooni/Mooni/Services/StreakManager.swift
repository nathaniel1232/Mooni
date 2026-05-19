import Foundation
import SwiftUI
import Combine

/// Nightly sleep-logging streak.
///
/// A day "counts" when the user logs a real sleep entry of at least 4h.
/// Missing a day breaks the streak — but the user gets one *freeze* per
/// pet level (capped) which is consumed automatically to bridge a single
/// missed day. When all freezes are spent, the streak drops to zero and
/// a one-time "lost" flag is set so the UI can surface a message.
@MainActor
final class StreakManager: ObservableObject {
    static let shared = StreakManager()

    private enum Key {
        static let current = "mooni.streak.current"
        static let longest = "mooni.streak.longest"
        static let lastDay = "mooni.streak.lastDay"          // yyyy-MM-dd
        static let freezes = "mooni.streak.freezes"          // remaining
        static let freezesGrantedForLevel = "mooni.streak.freezeLevel"
        static let lostFlagShown = "mooni.streak.lostShown"  // bool — surface once
        static let lostCarryStreak = "mooni.streak.lostCarry" // streak that was just lost
    }

    @Published var current: Int
    @Published var longest: Int
    @Published var freezesRemaining: Int
    /// Length of the streak that was just lost, if any. Cleared after the
    /// "you lost your streak" sheet has been acknowledged.
    @Published var lostStreakLength: Int

    private init() {
        let d = UserDefaults.standard
        self.current = d.integer(forKey: Key.current)
        self.longest = d.integer(forKey: Key.longest)
        self.freezesRemaining = d.integer(forKey: Key.freezes)
        self.lostStreakLength = d.integer(forKey: Key.lostCarryStreak)
    }

    var lastLoggedDay: String? {
        UserDefaults.standard.string(forKey: Key.lastDay)
    }

    /// Call once at app open so streaks can decay even without a new log.
    /// Evaluates the gap between `lastDay` and today and consumes freezes
    /// or breaks the streak as needed. Safe to call repeatedly per day.
    func evaluateOnLaunch() {
        guard let last = lastLoggedDay,
              let lastDate = Self.date(from: last) else { return }
        let today = Calendar.current.startOfDay(for: Date())
        let lastStart = Calendar.current.startOfDay(for: lastDate)
        let days = Calendar.current.dateComponents([.day], from: lastStart, to: today).day ?? 0

        // 0 or 1 day gap is fine — yesterday's log is still "current".
        guard days >= 2 else { return }

        // For each fully-missed day (gap days - 1 nights), try to spend a freeze.
        var missed = days - 1
        var freezes = freezesRemaining
        while missed > 0 && freezes > 0 {
            freezes -= 1
            missed -= 1
        }
        freezesRemaining = freezes
        UserDefaults.standard.set(freezes, forKey: Key.freezes)

        if missed > 0 {
            // Streak broken — remember the length so the UI can show it once.
            if current > 0 {
                lostStreakLength = current
                UserDefaults.standard.set(current, forKey: Key.lostCarryStreak)
                UserDefaults.standard.set(false, forKey: Key.lostFlagShown)
            }
            current = 0
            UserDefaults.standard.set(0, forKey: Key.current)
        }
    }

    /// Call whenever a sleep entry is logged. Advances the streak if the
    /// entry's wake-day is newer than the last counted day.
    func registerSleepLogged(on wakeDate: Date, durationHours: Double) {
        // Naps don't count.
        guard durationHours >= 4 else { return }
        let key = Self.dayKey(wakeDate)
        if let last = lastLoggedDay, last == key {
            return // already counted today
        }

        // Check continuity: was the prior day logged? If yes, increment.
        // If no, the launch-time evaluator already handled freeze/loss —
        // treat this log as a fresh start (= 1).
        if let last = lastLoggedDay,
           let lastDate = Self.date(from: last),
           let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: wakeDate),
           Calendar.current.isDate(lastDate, inSameDayAs: yesterday) {
            current += 1
        } else {
            current = max(current, 1)
            if current == 0 { current = 1 }
        }

        longest = max(longest, current)
        UserDefaults.standard.set(current, forKey: Key.current)
        UserDefaults.standard.set(longest, forKey: Key.longest)
        UserDefaults.standard.set(key, forKey: Key.lastDay)
    }

    /// Grants freezes proportional to pet level. Capped at 5 so streaks stay
    /// meaningful — at level 1 you get 1 freeze, level 3 → 3, max 5.
    /// Called whenever the pet levels up.
    func reconcileFreezes(forLevel level: Int) {
        let target = min(5, max(1, level))
        let granted = UserDefaults.standard.integer(forKey: Key.freezesGrantedForLevel)
        if level > granted {
            // Top up freezes to target on level-ups.
            freezesRemaining = max(freezesRemaining, target)
            UserDefaults.standard.set(freezesRemaining, forKey: Key.freezes)
            UserDefaults.standard.set(level, forKey: Key.freezesGrantedForLevel)
        }
    }

    func acknowledgeLostStreak() {
        lostStreakLength = 0
        UserDefaults.standard.set(0, forKey: Key.lostCarryStreak)
        UserDefaults.standard.set(true, forKey: Key.lostFlagShown)
    }

    var hasUnseenLoss: Bool {
        lostStreakLength > 0 && !UserDefaults.standard.bool(forKey: Key.lostFlagShown)
    }

    func resetAll() {
        let d = UserDefaults.standard
        for k in [Key.current, Key.longest, Key.lastDay, Key.freezes,
                  Key.freezesGrantedForLevel, Key.lostFlagShown, Key.lostCarryStreak] {
            d.removeObject(forKey: k)
        }
        current = 0
        longest = 0
        freezesRemaining = 0
        lostStreakLength = 0
    }

    private static func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
    private static func date(from key: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: key)
    }
}

/// Visual streak flame chip — used on Home and Me.
struct StreakFlameChip: View {
    let current: Int
    let freezes: Int

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Image(systemName: "flame.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(current > 0 ? MooniColor.warning : MooniColor.textMuted)
            }
            Text("\(current)")
                .font(MooniFont.display(24))
                .foregroundColor(MooniColor.textPrimary)
                .lineLimit(1)
            if freezes > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "snowflake")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(MooniColor.accentSoft)
                    Text("\(freezes)")
                        .font(MooniFont.caption(13))
                        .foregroundColor(MooniColor.textSecondary)
                }
                .padding(.leading, 3)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(
                current > 0 ? MooniColor.warning.opacity(0.35) : Color.white.opacity(0.1),
                lineWidth: 1
            )
        )
    }
}
