import Foundation

/// Snapshot of what to render on a Sleepowl Reveal card. Constructed once from
/// AppState; immutable after — the card view, the renderer, and the share
/// flow all read from the same struct so the image and the on-screen preview
/// can never drift.
struct RevealStats {
    /// Pet's mood AT THE START of the comparison window (synthesized from the
    /// oldest entry's score). Used to render the "before" owl tone.
    let beforeMood: Pet.Mood
    let beforeScore: Int

    /// Current pet — full identity (name, color, stage) used to render the
    /// "after" owl in the user's actual customization.
    let pet: Pet
    let afterMood: Pet.Mood
    let afterScore: Int

    /// Streak length and level snapshotted at render time.
    let streakDays: Int
    let level: Int

    /// Number of nights tracked in the comparison window.
    let nightsTracked: Int

    /// Human-readable range like "May 21 – May 27".
    let windowLabel: String

    /// Encouraging tagline picked based on the score delta. Capped to ~36 chars.
    let tagline: String

    /// Positive when the user improved; informs subtitle copy and arrow direction.
    var scoreDelta: Int { afterScore - beforeScore }

    // MARK: - Eligibility

    /// Reveal is only worth showing when the user has enough data AND something
    /// to brag about. We require at least `minNights` entries in the window.
    static let minNights = 3

    /// Build a stats object from raw AppState pieces. Returns nil if there's
    /// not enough data — callers should show a "locked / keep tracking" state
    /// in that case instead of a half-baked reveal.
    ///
    /// `windowDays` defaults to 7 (one week recap), which is the cadence the
    /// teaser card uses on Home.
    static func build(
        entries: [SleepEntry],
        pet: Pet,
        streakDays: Int,
        windowDays: Int = 7,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> RevealStats? {
        guard let windowStart = calendar.date(byAdding: .day, value: -windowDays, to: now) else { return nil }

        let inWindow = entries
            .filter { $0.wakeTime >= windowStart && $0.wakeTime <= now }
            .sorted { $0.wakeTime < $1.wakeTime }

        guard inWindow.count >= minNights,
              let first = inWindow.first,
              let last  = inWindow.last
        else { return nil }

        let beforeScore = first.score
        let afterScore  = last.score
        let delta = afterScore - beforeScore

        return RevealStats(
            beforeMood: Pet.Mood.from(score: beforeScore),
            beforeScore: beforeScore,
            pet: pet,
            afterMood: Pet.Mood.from(score: afterScore),
            afterScore: afterScore,
            streakDays: streakDays,
            level: pet.level,
            nightsTracked: inWindow.count,
            windowLabel: Self.formatWindow(start: first.wakeTime, end: last.wakeTime, calendar: calendar),
            tagline: Self.tagline(forDelta: delta, streak: streakDays)
        )
    }

    /// Synthesize a friendly preview when there's no real data yet — for the
    /// onboarding-tease screen / debug previews. NOT shown to real users.
    static var demo: RevealStats {
        var pet = Pet()
        pet.name = "Sleepowl"
        pet.level = 5
        pet.mood = .energized
        return RevealStats(
            beforeMood: .restless,
            beforeScore: 58,
            pet: pet,
            afterMood: .energized,
            afterScore: 87,
            streakDays: 7,
            level: 5,
            nightsTracked: 7,
            windowLabel: "Your first week",
            tagline: "+29 points in 7 nights"
        )
    }

    // MARK: - Copy

    private static func formatWindow(start: Date, end: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .current
        formatter.dateFormat = "MMM d"
        if calendar.isDate(start, inSameDayAs: end) {
            return formatter.string(from: end)
        }
        let startStr = formatter.string(from: start)
        let endStr = formatter.string(from: end)
        return "\(startStr) – \(endStr)"
    }

    private static func tagline(forDelta delta: Int, streak: Int) -> String {
        if delta >= 20 { return "+\(delta) points — huge week" }
        if delta >= 10 { return "+\(delta) points this week" }
        if delta >= 1  { return "+\(delta) points — building" }
        if delta == 0  { return "Steady week" }
        if streak >= 7 { return "\(streak)-day streak strong" }
        return "Resetting tonight"
    }
}
