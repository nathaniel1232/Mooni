import Foundation

/// Premium-tier analytics derived from a user's sleep history.
/// All functions are pure — pass entries + targets, get insights back.
enum SleepInsights {

    // MARK: - Sleep debt
    /// Cumulative deficit (in hours) versus the goal across the last `days` nights.
    static func sleepDebt(entries: [SleepEntry], goalHours: Double, days: Int = 7) -> Double {
        let recent = recentEntries(entries, days: days)
        let deficit = recent.reduce(0.0) { acc, e in
            acc + max(0, goalHours - e.hours)
        }
        return deficit
    }

    static func formatDebt(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        if h == 0 { return "\(m)m" }
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    // MARK: - Wake-time consistency
    /// Range (in minutes) between earliest and latest wake-time over the last `days`.
    static func wakeTimeVariance(entries: [SleepEntry], days: Int = 7) -> Int {
        let recent = recentEntries(entries, days: days)
        guard recent.count >= 2 else { return 0 }
        let cal = Calendar.current
        let mins = recent.map { e -> Int in
            let c = cal.dateComponents([.hour, .minute], from: e.wakeTime)
            return (c.hour ?? 0) * 60 + (c.minute ?? 0)
        }
        guard let mn = mins.min(), let mx = mins.max() else { return 0 }
        return mx - mn
    }

    // MARK: - Best sleep window
    /// Returns the bedtime range (start, end) that the user's best-scoring nights fall into.
    static func bestSleepWindow(entries: [SleepEntry]) -> (start: Date, end: Date)? {
        let top = entries.sorted(by: { $0.score > $1.score }).prefix(5)
        guard top.count >= 3 else { return nil }
        let cal = Calendar.current
        let times = top.map { e -> Int in
            let c = cal.dateComponents([.hour, .minute], from: e.bedtime)
            return (c.hour ?? 0) * 60 + (c.minute ?? 0)
        }
        guard let mn = times.min(), let mx = times.max() else { return nil }
        let start = Date.todayAt(hour: mn / 60, minute: mn % 60)
        let end = Date.todayAt(hour: mx / 60, minute: mx % 60)
        return (start, end)
    }

    // MARK: - Recovery prediction
    /// Predict tomorrow's pet energy if the user gets `plannedHours` of sleep tonight.
    static func recoveryPrediction(entries: [SleepEntry], goalHours: Double, plannedHours: Double) -> Int {
        let debt = sleepDebt(entries: entries, goalHours: goalHours, days: 7)
        let surplus = max(0, plannedHours - goalHours)
        let baseline = 70
        let bonus = Int((surplus * 8.0).rounded())
        let penalty = Int((debt * 1.5).rounded())
        return max(20, min(100, baseline + bonus - penalty))
    }

    // MARK: - Habit correlation
    /// Average extra minutes of sleep on nights where the wind-down routine was completed.
    static func windDownLift(entries: [SleepEntry]) -> Int {
        let withRoutine = entries.filter { $0.routineCompleted }
        let without = entries.filter { !$0.routineCompleted }
        guard !withRoutine.isEmpty, !without.isEmpty else { return 0 }
        let avgWith = withRoutine.map(\.hours).reduce(0, +) / Double(withRoutine.count)
        let avgWithout = without.map(\.hours).reduce(0, +) / Double(without.count)
        return Int(((avgWith - avgWithout) * 60).rounded())
    }

    // MARK: - Helpers
    private static func recentEntries(_ entries: [SleepEntry], days: Int) -> [SleepEntry] {
        let sorted = entries.sorted { $0.wakeTime > $1.wakeTime }
        return Array(sorted.prefix(days))
    }
}
