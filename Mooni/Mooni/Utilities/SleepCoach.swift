import Foundation
import SwiftUI

/// The "fix" half of "SleepOwl fixed my sleep."
///
/// Where `SleepInsights` measures and `HomeIntelligence` narrates, `SleepCoach`
/// *prescribes*: it reads the user's real history and returns the single
/// highest-leverage thing to do **tonight** — one concrete action, the reason
/// (from real data), and the honest payoff. No tracking-speak, no laundry list:
/// one move that makes tomorrow better than today.
///
/// Pure + deterministic per night, so the Home card never reshuffles on redraw.
enum SleepCoach {

    struct TonightFix: Equatable {
        enum Kind: String {
            case firstNight, clearDebt, anchorWake, earlierBedtime, windDown, holdTheWin, anchorBedtime
        }
        let kind: Kind
        /// Punchy action headline — the thing to actually do.
        let title: String
        /// One line, grounded in the user's real numbers.
        let why: String
        /// Honest expected outcome of doing it.
        let payoff: String
        let icon: String
        let tint: Color
        /// CTA label for the action button.
        let actionLabel: String
        /// Bedtime the action aims at (for wind-down / reminders). nil when N/A.
        let targetBedtime: Date?
    }

    /// The one fix for tonight, chosen from the strongest available signal.
    static func tonightFix(
        entries: [SleepEntry],
        goalHours: Double,
        targetBedtime: Date,
        targetWakeTime: Date,
        petName: String
    ) -> TonightFix {
        // Real (non-backfill) nights only — never coach off fabricated
        // schedule placeholders (see SleepEntry.isScheduleBackfill).
        let real = entries
            .filter { !$0.isScheduleBackfill }
            .sorted { $0.wakeTime > $1.wakeTime }

        // ── No real history yet → first-night fix ──────────────────────────
        guard let last = real.first else {
            return TonightFix(
                kind: .firstNight,
                title: "Lights out by \(targetBedtime.hourMinuteString)",
                why: "Tonight sets your baseline — SleepOwl reads the whole night on its own.",
                payoff: "Your very first score lands by morning.",
                icon: "moon.stars.fill",
                tint: MooniColor.accent,
                actionLabel: "Start wind-down",
                targetBedtime: targetBedtime
            )
        }

        let debt = SleepInsights.sleepDebt(entries: real, goalHours: goalHours, days: 7)
        let wakeVar = SleepInsights.wakeTimeVariance(entries: real, days: 7)
        let lift = SleepInsights.windDownLift(entries: real)
        let targetBedMin = minuteOfDay(targetBedtime)
        let lastBedMin = minuteOfDay(last.bedtime)
        let bedDrift = circularDiff(lastBedMin, targetBedMin)       // distance from target
        let lastLate = signedLateness(lastBedMin, targetBedMin)     // + = later than target

        // Priority 1 — heavy sleep debt: bank hours with an earlier night.
        if debt >= 3 {
            let extra = max(15, min(60, Int((debt / 7.0 * 60).rounded())))
            return TonightFix(
                kind: .clearDebt,
                title: "Bank an extra \(extra) min tonight",
                why: "You're carrying \(SleepInsights.formatDebt(debt)) of sleep debt this week.",
                payoff: "Clearing debt is the fastest lift to tomorrow's energy.",
                icon: "bolt.heart.fill",
                tint: MooniColor.warning,
                actionLabel: "Start wind-down early",
                targetBedtime: targetBedtime
            )
        }

        // Priority 2 — wildly inconsistent wake times: anchor the wake time.
        if wakeVar >= 90 {
            return TonightFix(
                kind: .anchorWake,
                title: "Same wake-up tomorrow: \(targetWakeTime.hourMinuteString)",
                why: "Your wake time swung \(formatMinutes(wakeVar)) this week — that's what flattens your mornings.",
                payoff: "A fixed wake time is the #1 lever in sleep science.",
                icon: "alarm.fill",
                tint: MooniColor.accent,
                actionLabel: "Set tonight up",
                targetBedtime: targetBedtime
            )
        }

        // Priority 3 — bedtime drifting late: pull it back to target.
        if lastLate >= 40 {
            return TonightFix(
                kind: .earlierBedtime,
                title: "Lights out by \(targetBedtime.hourMinuteString)",
                why: "Last night you turned in \(formatMinutes(lastLate)) past your target.",
                payoff: "Hit your window tonight and you should see real points back.",
                icon: "moon.fill",
                tint: MooniColor.accent,
                actionLabel: "Start wind-down",
                targetBedtime: targetBedtime
            )
        }

        // Priority 4 — wind-down demonstrably helps and last night skipped it.
        if lift >= 10 && !last.routineCompleted {
            return TonightFix(
                kind: .windDown,
                title: "Run your wind-down tonight",
                why: "On nights you wind down, you sleep about \(lift) min longer.",
                payoff: "It's your most reliable personal lever — use it.",
                icon: "wind",
                tint: MooniColor.success,
                actionLabel: "Start wind-down",
                targetBedtime: targetBedtime
            )
        }

        // Priority 5 — on rhythm and a strong last night: hold the win.
        if bedDrift <= 25 && last.score >= 78 {
            return TonightFix(
                kind: .holdTheWin,
                title: "Repeat last night — lights out ~\(last.bedtime.hourMinuteString)",
                why: "You scored \(last.score). Your rhythm is dialed in.",
                payoff: "Two strong nights back to back is where it compounds.",
                icon: "checkmark.seal.fill",
                tint: MooniColor.success,
                actionLabel: "Lock it in",
                targetBedtime: last.bedtime
            )
        }

        // Default — anchor at the prescribed bedtime.
        return TonightFix(
            kind: .anchorBedtime,
            title: "Aim for \(targetBedtime.hourMinuteString) tonight",
            why: "Keeping bedtime within 30 min of target keeps your deep sleep steady.",
            payoff: "Small, consistent wins stack up fast.",
            icon: "target",
            tint: MooniColor.accent,
            actionLabel: "Start wind-down",
            targetBedtime: targetBedtime
        )
    }

    // MARK: - Helpers

    private static func minuteOfDay(_ d: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    /// Shortest distance between two minute-of-day values (handles midnight wrap).
    private static func circularDiff(_ a: Int, _ b: Int) -> Int {
        let raw = abs(a - b)
        return min(raw, 1440 - raw)
    }

    /// Signed minutes `bed` is later than `target` (handles the midnight wrap so
    /// 12:10 AM vs an 11:30 PM target reads as +40, not −1400).
    private static func signedLateness(_ bed: Int, _ target: Int) -> Int {
        var diff = bed - target
        if diff > 720 { diff -= 1440 }
        if diff < -720 { diff += 1440 }
        return diff
    }

    private static func formatMinutes(_ m: Int) -> String {
        m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m) min"
    }
}
