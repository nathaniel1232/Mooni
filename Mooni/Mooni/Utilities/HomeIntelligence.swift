import Foundation
import SwiftUI

/// Generates the morning "briefing" copy for the Home screen.
///
/// The goal is variability + emotional intelligence: the user opens
/// SleepOwl each morning and sees a fresh aura, fresh predictions, and
/// occasionally a rare-event surprise — but the values are deterministic
/// per day, so refreshing the screen doesn't shuffle them.
enum HomeIntelligence {

    // MARK: - Aura

    enum DailyAura: String, CaseIterable {
        case glowing, energized, focused, calm, recovering, unstable, chaotic

        var label: String {
            switch self {
            case .glowing:    return "Glowing"
            case .energized:  return "Energized"
            case .focused:    return "Focused"
            case .calm:       return "Calm"
            case .recovering: return "Recovering"
            case .unstable:   return "Unstable"
            case .chaotic:    return "Chaotic"
            }
        }

        var icon: String {
            switch self {
            case .glowing:    return "sparkles"
            case .energized:  return "bolt.fill"
            case .focused:    return "scope"
            case .calm:       return "leaf.fill"
            case .recovering: return "heart.fill"
            case .unstable:   return "waveform.path"
            case .chaotic:    return "tornado"
            }
        }

        var color: Color {
            switch self {
            case .glowing:    return MooniColor.warning
            case .energized:  return MooniColor.success
            case .focused:    return MooniColor.accentSoft
            case .calm:       return MooniColor.accent
            case .recovering: return MooniColor.danger
            case .unstable:   return MooniColor.warning
            case .chaotic:    return MooniColor.danger
            }
        }

        var caption: String {
            switch self {
            case .glowing:    return "Today is a glow-up kind of day."
            case .energized:  return "Your body is ready to move."
            case .focused:    return "Sharp brain hours ahead."
            case .calm:       return "Steady, even tempo today."
            case .recovering: return "Take it gentle. Today is repair."
            case .unstable:   return "A few rough patches expected."
            case .chaotic:    return "Your rhythm is all over the place."
            }
        }
    }

    // MARK: - Cards

    enum MorningCardKind: String, CaseIterable, Identifiable {
        case energy, recovery, mood, consistency, focus
        var id: String { rawValue }

        var title: String {
            switch self {
            case .energy:      return "Today's energy"
            case .recovery:    return "Recovery"
            case .mood:        return "SleepOwl's mood"
            case .consistency: return "Consistency"
            case .focus:       return "Focus"
            }
        }

        var icon: String {
            switch self {
            case .energy:      return "bolt.fill"
            case .recovery:    return "heart.fill"
            case .mood:        return "face.smiling.fill"
            case .consistency: return "calendar"
            case .focus:       return "scope"
            }
        }

        var color: Color {
            switch self {
            case .energy:      return MooniColor.warning
            case .recovery:    return MooniColor.danger
            case .mood:        return MooniColor.accent
            case .consistency: return MooniColor.success
            case .focus:       return MooniColor.accentSoft
            }
        }
    }

    struct MorningCard: Identifiable {
        let kind: MorningCardKind
        var id: String { kind.id }
        let headline: String
        let detail: String
    }

    // MARK: - Achievement / streak chip

    struct Achievement {
        let icon: String
        let title: String
    }

    // MARK: - Rare events

    struct RareEvent {
        let icon: String
        let title: String
        let body: String
        let tint: Color
    }

    // MARK: - Briefing

    struct Briefing {
        let aura: DailyAura
        let auraDeck: [DailyAura]
        let heroLine: String         // big top-area copy
        let heroSubline: String      // smaller text
        let speech: String           // short Luna speech bubble
        let cards: [MorningCard]
        let achievement: Achievement?
        let rareEvent: RareEvent?
        let whyLine: String          // "why you feel this way"
    }

    // MARK: - Public entry points

    /// Produce a full morning briefing for the most recent sleep entry.
    static func briefing(
        for entry: SleepEntry,
        all: [SleepEntry],
        targetBedtime: Date,
        targetWakeTime: Date,
        goalHours: Double,
        petName: String
    ) -> Briefing {
        let seed = daySeed(entry.dayKey)
        let aura = aura(for: entry, all: all, targetBedtime: targetBedtime, seed: seed)
        let cards = cards(for: entry,
                          all: all,
                          aura: aura,
                          targetBedtime: targetBedtime,
                          targetWakeTime: targetWakeTime,
                          goalHours: goalHours,
                          seed: seed)
        let hero = heroCopy(for: aura, entry: entry, petName: petName, seed: seed)
        let speech = speechCopy(for: aura, entry: entry, petName: petName, seed: seed)
        let achievement = achievement(for: entry, all: all, targetBedtime: targetBedtime, seed: seed)
        let rare = rareEvent(for: entry, all: all, petName: petName, seed: seed)
        let why = whyLine(for: entry, all: all, targetBedtime: targetBedtime, seed: seed)

        // Build a ranked list of auras so the badge can show the top
        // pick + a couple of close-second moods.
        let deck = auraDeck(primary: aura, seed: seed)

        return Briefing(
            aura: aura,
            auraDeck: deck,
            heroLine: hero.title,
            heroSubline: hero.subtitle,
            speech: speech,
            cards: cards,
            achievement: achievement,
            rareEvent: rare,
            whyLine: why
        )
    }

    /// Lightweight evening "anticipation" line shown when there's no
    /// recent morning entry yet but it's nighttime.
    static func eveningAnticipation(
        bedtimeConsistencyDays: Int,
        targetBedtime: Date,
        petName: String
    ) -> String {
        let pool: [String]
        if bedtimeConsistencyDays >= 3 {
            pool = [
                "\(petName) is excited — you're \(bedtimeConsistencyDays + 1) nights into a streak.",
                "One more cozy night to extend your \(bedtimeConsistencyDays)-night rhythm.",
                "Tonight could lock in your best streak yet."
            ]
        } else {
            pool = [
                "\(petName) is getting sleepy — start wind-down by \(thirtyBefore(targetBedtime).hourMinuteString).",
                "A bedtime before \(targetBedtime.hourMinuteString) gives you a real edge tomorrow.",
                "Sleeping before midnight tends to lift your morning energy."
            ]
        }
        let seed = daySeed(Date().dayKey)
        return pick(pool, seed: seed, salt: 71) ?? ""
    }

    // MARK: - Aura logic

    private static func aura(
        for entry: SleepEntry,
        all: [SleepEntry],
        targetBedtime: Date,
        seed: UInt64
    ) -> DailyAura {
        let score = entry.score

        // Variance of bedtimes in the last 7 nights → "chaotic" signal.
        let recent = Array(all.sorted(by: { $0.wakeTime > $1.wakeTime }).prefix(7))
        let bedMinutes = recent.map { minuteOfDay($0.bedtime) }
        let variance = stddev(bedMinutes)

        if variance > 90 && score < 70 { return .chaotic }
        if score >= 88 { return .glowing }
        if score >= 78 { return pick([.energized, .glowing], seed: seed, salt: 7) ?? .calm }
        if score >= 68 {
            return pick([.focused, .calm, .energized], seed: seed, salt: 13) ?? .calm
        }
        if score >= 55 {
            return pick([.calm, .focused, .recovering], seed: seed, salt: 17) ?? .calm
        }
        if score >= 40 { return pick([.recovering, .unstable], seed: seed, salt: 23) ?? .calm }
        return .unstable
    }

    private static func auraDeck(primary: DailyAura, seed: UInt64) -> [DailyAura] {
        // A trio of auras: primary plus two adjacent / complementary ones,
        // shuffled deterministically so the badge can show "you're mostly X,
        // with a hint of Y and Z."
        let neighbors: [DailyAura: [DailyAura]] = [
            .glowing:    [.energized, .focused],
            .energized:  [.glowing, .focused],
            .focused:    [.calm, .energized],
            .calm:       [.focused, .recovering],
            .recovering: [.calm, .unstable],
            .unstable:   [.recovering, .chaotic],
            .chaotic:    [.unstable, .recovering]
        ]
        var deck: [DailyAura] = [primary] + (neighbors[primary] ?? [])
        // Randomise ordering of the two side-auras.
        if deck.count == 3 && (seed & 1) == 1 {
            deck.swapAt(1, 2)
        }
        return deck
    }

    // MARK: - Hero copy

    private static func heroCopy(
        for aura: DailyAura,
        entry: SleepEntry,
        petName: String,
        seed: UInt64
    ) -> (title: String, subtitle: String) {
        let titles: [String]
        let subs: [String]

        switch aura {
        case .glowing:
            titles = [
                "You actually recovered well last night.",
                "\(petName) is glowing today.",
                "That was a peak-rest kind of night."
            ]
            subs = [
                "Today should feel light and clear.",
                "Energy and mood are both lined up for you.",
                "Your rhythm is paying off — coast on it."
            ]
        case .energized:
            titles = [
                "Strong recovery — you're charged up.",
                "\(petName) feels energized today.",
                "That sleep gave your body real fuel."
            ]
            subs = [
                "Push the harder things into the morning.",
                "Workouts and focus blocks will hit harder today.",
                "You'll feel the lift before noon."
            ]
        case .focused:
            titles = [
                "Sharp brain morning ahead.",
                "Quietly good sleep — focus is loaded.",
                "\(petName) is calm and clear today."
            ]
            subs = [
                "Best 2-hour window for deep work is right now.",
                "Mental tasks before lunch will land.",
                "Clarity peaks early — protect it."
            ]
        case .calm:
            titles = [
                "Steady night, steady day.",
                "\(petName) is content today.",
                "Nothing dramatic — just a calm rhythm."
            ]
            subs = [
                "Even, consistent energy through the afternoon.",
                "Save big swings for tomorrow.",
                "A good day to do small wins back to back."
            ]
        case .recovering:
            titles = [
                "Your body needed that sleep.",
                "Recovery mode — be a bit gentler today.",
                "\(petName) is still resting up."
            ]
            subs = [
                "Mental fatigue may hit earlier than usual.",
                "Skip caffeine after 2 PM if you can.",
                "Plan tonight's bedtime 30 min earlier."
            ]
        case .unstable:
            titles = [
                "A patchy night — you'll feel it in waves.",
                "\(petName) is groggy this morning.",
                "Recovery looks shallow today."
            ]
            subs = [
                "Expect an energy dip mid-afternoon.",
                "A short walk after lunch will help a lot.",
                "Rebuild tonight with an earlier wind-down."
            ]
        case .chaotic:
            titles = [
                "Your rhythm is all over the place.",
                "\(petName) is confused — bedtimes keep shifting.",
                "Chaotic week — let's anchor tonight."
            ]
            subs = [
                "One consistent bedtime resets a lot of this.",
                "Pick a wake time and protect it for 3 days.",
                "Even a 15-minute consistency win helps."
            ]
        }

        return (
            pick(titles, seed: seed, salt: 31) ?? "",
            pick(subs,   seed: seed, salt: 37) ?? ""
        )
    }

    private static func speechCopy(
        for aura: DailyAura,
        entry: SleepEntry,
        petName: String,
        seed: UInt64
    ) -> String {
        let pool: [String]
        switch aura {
        case .glowing:    pool = ["I feel amazing.", "Best night in a while.", "I could do anything today."]
        case .energized:  pool = ["I'm awake awake.", "Let's go.", "Charged up."]
        case .focused:    pool = ["Brain feels crisp.", "Quiet and ready.", "I can think today."]
        case .calm:       pool = ["I'm cozy.", "All good in here.", "Steady and warm."]
        case .recovering: pool = ["Soft day, please.", "I'm recovering.", "Be gentle with me."]
        case .unstable:   pool = ["Bit fuzzy.", "Coffee, then talk.", "Slow start today."]
        case .chaotic:    pool = ["What day is it?", "Where am I?", "Let's reset tonight."]
        }
        return pick(pool, seed: seed, salt: 43) ?? "" ?? ""
    }

    // MARK: - Morning cards

    private static func cards(
        for entry: SleepEntry,
        all: [SleepEntry],
        aura: DailyAura,
        targetBedtime: Date,
        targetWakeTime: Date,
        goalHours: Double,
        seed: UInt64
    ) -> [MorningCard] {
        let score = entry.score
        let hours = entry.totalSleepDuration / 3600

        // Energy
        let peakHour = energyPeakHour(wakeTime: entry.wakeTime, score: score)
        let energy = MorningCard(
            kind: .energy,
            headline: pick([
                "Peak around \(formatHour(peakHour))",
                "Most energy near \(formatHour(peakHour))",
                "Push hard at \(formatHour(peakHour))"
            ], seed: seed, salt: 51) ?? "",
            detail: score >= 70
                ? "You'll likely feel sharpest in a 90-minute window around then."
                : "After that, expect a noticeable dip — plan a break."
        )

        // Recovery
        let recovery = MorningCard(
            kind: .recovery,
            headline: score >= 75
                ? "Your body recovered well."
                : score >= 55 ? "Half-recovered." : "Still recovering.",
            detail: pick(recoveryDetails(score: score, hours: hours), seed: seed, salt: 53) ?? ""
        )

        // Mood (SleepOwl)
        let mood = MorningCard(
            kind: .mood,
            headline: aura.label,
            detail: aura.caption
        )

        // Consistency
        let consistencyMin = bedtimeConsistencyMinutes(entry: entry, all: all)
        let consistency = MorningCard(
            kind: .consistency,
            headline: consistencyMin <= 25
                ? "On rhythm tonight"
                : "\(consistencyMin) min off your usual",
            detail: consistencyMin <= 25
                ? "Your bedtime is right where your body expects it."
                : "Drifting bedtimes flatten your deep sleep."
        )

        // Focus
        let focusDip = focusDipHour(wakeTime: entry.wakeTime, score: score)
        let focus = MorningCard(
            kind: .focus,
            headline: score >= 70
                ? "Strong morning focus"
                : "Focus may dip near \(formatHour(focusDip))",
            detail: pick(focusDetails(score: score), seed: seed, salt: 57) ?? ""
        )

        return [energy, recovery, mood, consistency, focus]
    }

    private static func recoveryDetails(score: Int, hours: Double) -> [String] {
        if score >= 75 {
            return [
                "Deep sleep was generous — your nervous system reset.",
                String(format: "You banked %.1fh of restorative sleep.", hours),
                "Workouts and intense thinking will hit harder today."
            ]
        }
        if score >= 55 {
            return [
                "Some recovery, but not full — go easier this afternoon.",
                "You'll feel mostly okay, with one slow patch.",
                "An earlier bedtime tonight will compound."
            ]
        }
        return [
            "Body looks under-recovered. Treat today gently.",
            "Skip late caffeine and aim 30 min earlier tonight.",
            "Recovery is the only goal today."
        ]
    }

    private static func focusDetails(score: Int) -> [String] {
        if score >= 70 {
            return [
                "Save deep work for the next 2 hours.",
                "Brain is loaded — protect it from notifications.",
                "Hard tasks before lunch will land easier."
            ]
        }
        return [
            "A short walk after lunch resets attention.",
            "Break work into 25-minute chunks today.",
            "Hydrate before reaching for caffeine."
        ]
    }

    // MARK: - Achievements / streaks

    private static func achievement(
        for entry: SleepEntry,
        all: [SleepEntry],
        targetBedtime: Date,
        seed: UInt64
    ) -> Achievement? {
        let sorted = all.sorted(by: { $0.wakeTime > $1.wakeTime })

        // Earliest bedtime in N days
        let earlier = countWhereLater(entry: entry, in: sorted)
        if earlier >= 5 {
            return Achievement(icon: "moon.stars.fill",
                               title: "Earliest bedtime in \(earlier) days")
        }

        // On-rhythm consistency streak
        let streak = bedtimeStreak(in: sorted, target: targetBedtime)
        if streak >= 3 {
            return Achievement(icon: "flame.fill",
                               title: "\(streak)-night rhythm streak")
        }

        // Recovery percentile vs last 7
        let last7 = Array(sorted.prefix(7))
        if last7.count >= 4 {
            let better = last7.filter { $0.score < entry.score }.count
            let pct = Int(Double(better) / Double(last7.count) * 100)
            if pct >= 70 {
                return Achievement(icon: "chart.line.uptrend.xyaxis",
                                   title: "Recovered better than \(pct)% of your week")
            }
        }

        // Best-day-of-week in M weeks
        if let weeks = bestDayOfWeekStreak(entry: entry, in: sorted), weeks >= 2 {
            let weekday = Calendar.current.component(.weekday, from: entry.wakeTime)
            let weekdayName = DateFormatter().weekdaySymbols[weekday - 1]
            return Achievement(icon: "rosette",
                               title: "Best \(weekdayName) in \(weeks) weeks")
        }

        // Generic "first night" / fallback when none of the above
        if sorted.count <= 2 {
            return Achievement(icon: "sparkles",
                               title: "First nights logged — keep going")
        }
        return nil
    }

    private static func countWhereLater(entry: SleepEntry, in sorted: [SleepEntry]) -> Int {
        let entryMinute = minuteOfDay(entry.bedtime)
        var count = 0
        for e in sorted where e.id != entry.id {
            if minuteOfDay(e.bedtime) > entryMinute + 5 {
                count += 1
            } else {
                break
            }
            if count >= 30 { break }
        }
        return count
    }

    private static func bedtimeStreak(in sorted: [SleepEntry], target: Date) -> Int {
        let targetMin = minuteOfDay(target)
        var streak = 0
        for e in sorted {
            let diff = circularMinuteDifference(minuteOfDay(e.bedtime), targetMin)
            if diff <= 30 { streak += 1 } else { break }
        }
        return streak
    }

    private static func bestDayOfWeekStreak(entry: SleepEntry, in sorted: [SleepEntry]) -> Int? {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: entry.wakeTime)
        // Find prior entries on the same weekday and confirm `entry` beats them.
        let prior = sorted.filter {
            $0.id != entry.id && cal.component(.weekday, from: $0.wakeTime) == weekday
        }
        guard !prior.isEmpty else { return nil }
        let weeksBack = prior.filter { $0.score < entry.score }.count
        return weeksBack > 0 ? weeksBack : nil
    }

    // MARK: - Rare event

    private static func rareEvent(
        for entry: SleepEntry,
        all: [SleepEntry],
        petName: String,
        seed: UInt64
    ) -> RareEvent? {
        let score = entry.score

        if score >= 92 {
            return RareEvent(
                icon: "sparkles",
                title: "Perfect Recovery",
                body: "Your sleep landed in a near-perfect window. Rare night.",
                tint: MooniColor.warning
            )
        }
        if let prev = all.sorted(by: { $0.wakeTime > $1.wakeTime })
            .first(where: { $0.id != entry.id }),
           score - prev.score >= 25 {
            return RareEvent(
                icon: "arrow.up.right.circle.fill",
                title: "Big bounce-back",
                body: "Score jumped \(score - prev.score) points overnight.",
                tint: MooniColor.success
            )
        }

        // Sprinkle a "<pet> feels amazing" rare card on ~1 in 12 days
        // when score is good — adds variability without lying. Use the user's
        // own pet name when they've set one; fall back only when truly unknown.
        if score >= 80 && (seed % 12) == 0 {
            let trimmedName = petName.trimmingCharacters(in: .whitespacesAndNewlines)
            let displayName = trimmedName.isEmpty ? petNameFallback : trimmedName
            return RareEvent(
                icon: "moon.stars.fill",
                title: "\(displayName) feels amazing",
                body: "Catch the vibe — today is a charged-up kind of day.",
                tint: MooniColor.accentSoft
            )
        }
        return nil
    }

    private static var petNameFallback: String { "SleepOwl" }

    // MARK: - Why line

    private static func whyLine(
        for entry: SleepEntry,
        all: [SleepEntry],
        targetBedtime: Date,
        seed: UInt64
    ) -> String {
        let pool: [String] = whyPool(entry: entry, all: all, targetBedtime: targetBedtime)
        return pick(pool, seed: seed, salt: 67) ?? ""
    }

    private static func whyPool(
        entry: SleepEntry,
        all: [SleepEntry],
        targetBedtime: Date
    ) -> [String] {
        var out: [String] = []
        let hours = entry.totalSleepDuration / 3600

        if hours >= 8 {
            out.append("You slept longer because you went to bed earlier than usual.")
        }
        if hours < 6 {
            out.append("Short night — you fell short of your goal by \(String(format: "%.1f", max(0, 8 - hours)))h.")
        }
        if let prev = all.sorted(by: { $0.wakeTime > $1.wakeTime })
            .first(where: { $0.id != entry.id }) {
            let diff = abs(minuteOfDay(entry.bedtime) - minuteOfDay(prev.bedtime))
            if diff > 60 {
                out.append("Your bedtime shifted \(diff) minutes from yesterday.")
            } else if diff <= 15 {
                out.append("Bedtime stayed remarkably steady night-to-night.")
            }
        }

        let targetDiff = circularMinuteDifference(minuteOfDay(entry.bedtime), minuteOfDay(targetBedtime))
        if targetDiff <= 20 {
            out.append("You hit your target bedtime — that consistency compounds.")
        } else if targetDiff > 60 {
            out.append("You went to bed \(targetDiff) min off your target — your body noticed.")
        }

        if entry.score >= 80 {
            out.append("You usually feel more rested when sleep is this consistent.")
        }
        if entry.routineCompleted {
            out.append("Wind-down completed — those add up.")
        } else {
            out.append("A wind-down tonight could lift tomorrow's score noticeably.")
        }
        if out.isEmpty {
            out = ["A solid baseline night — small upgrades from here will show fast."]
        }
        return out
    }

    // MARK: - Numerical helpers

    private static func energyPeakHour(wakeTime: Date, score: Int) -> Int {
        let wakeHour = Calendar.current.component(.hour, from: wakeTime)
        // Strong night → peak ~5h after wake. Weak night → ~3h.
        let offset = score >= 70 ? 5 : 3
        return (wakeHour + offset) % 24
    }

    private static func focusDipHour(wakeTime: Date, score: Int) -> Int {
        let wakeHour = Calendar.current.component(.hour, from: wakeTime)
        // Weak night → afternoon dip earlier (~7h after wake), strong → ~9h.
        let offset = score >= 70 ? 9 : 7
        return (wakeHour + offset) % 24
    }

    private static func formatHour(_ hour: Int) -> String {
        let h = ((hour % 12) == 0) ? 12 : hour % 12
        return "\(h) \(hour < 12 ? "AM" : "PM")"
    }

    private static func bedtimeConsistencyMinutes(entry: SleepEntry, all: [SleepEntry]) -> Int {
        let recent = Array(all.sorted(by: { $0.wakeTime > $1.wakeTime })
            .filter { $0.id != entry.id }
            .prefix(7))
        guard !recent.isEmpty else { return 0 }
        let avg = recent.map { Double(minuteOfDay($0.bedtime)) }.reduce(0, +) / Double(recent.count)
        return Int(abs(Double(minuteOfDay(entry.bedtime)) - avg))
    }

    private static func minuteOfDay(_ d: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    private static func circularMinuteDifference(_ a: Int, _ b: Int) -> Int {
        let raw = abs(a - b)
        return min(raw, 1440 - raw)
    }

    private static func stddev(_ values: [Int]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = Double(values.reduce(0, +)) / Double(values.count)
        let variance = values.map { pow(Double($0) - mean, 2) }.reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }

    private static func thirtyBefore(_ d: Date) -> Date {
        Calendar.current.date(byAdding: .minute, value: -30, to: d) ?? d
    }

    // MARK: - Determinism helpers

    private static func daySeed(_ s: String) -> UInt64 {
        var hash: UInt64 = 5381
        for c in s.unicodeScalars { hash = hash &* 33 &+ UInt64(c.value) }
        return hash
    }

    private static func pick<T>(_ array: [T], seed: UInt64, salt: UInt64) -> T? {
        guard !array.isEmpty else { return nil }
        let idx = Int((seed &+ salt) % UInt64(array.count))
        return array[idx]
    }
}
