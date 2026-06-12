import Foundation

/// Captures everything we learn about the user during the long, personalized onboarding.
/// Persisted to UserDefaults so the rest of the app can show personalized copy and a
/// believable "we built this just for you" plan after the paywall.
struct OnboardingProfile: Codable, Equatable {
    // MARK: - Personal
    var age: Int? = nil
    var gender: Gender? = nil
    var heightCm: Int? = nil          // stored canonically in cm
    var weightKg: Double? = nil       // stored canonically in kg
    var unitSystem: UnitSystem = .imperial

    // MARK: - Sleep history
    /// Typical lights-out hour (0-23.75 in quarter steps). The actual asleep
    /// time is later, but this is what the user reports about their habit.
    /// Optional so existing serialized profiles keep decoding cleanly.
    var typicalBedHour: Double? = 23.5
    /// Typical wake hour (0-23.75).
    var typicalWakeHour: Double? = 7.0
    /// Reported typical duration. Kept stored so legacy data still decodes,
    /// but always re-derived from bed/wake whenever the user edits times.
    var typicalSleepHours: Double = 6.5
    var struggleDuration: StruggleDuration? = nil
    var biggestProblem: SleepProblem? = nil

    // MARK: - Pre-bed behavior
    var usesPhoneBeforeBed: Bool? = nil
    var phoneScreenMinutes: Int = 60          // last 60min before lights-out
    var caffeineCutoff: CaffeineCutoff? = nil
    var stressLevel: Int = 6                  // 1–10
    var racingThoughtsAtNight: Bool? = nil

    // MARK: - Wake & day
    var wakeFeeling: WakeFeeling? = nil
    var energyDip: EnergyDip? = nil
    var napsDuringDay: Bool? = nil
    var snoresOrWakesUp: Bool = false

    // MARK: - Sleep environment
    var roomDarkness: RoomQuality = .someLight
    var roomNoise: RoomQuality = .quiet
    var bedComfort: RoomQuality = .comfortable

    // MARK: - Goals & motivation
    var motivation: Motivation? = nil
    var commitmentNights: Int = 7

    /// Goals the user multi-selected on the dedicated goals screen. These drive
    /// personalized recommendations & messaging. The single primary `sleepGoal`
    /// (stored elsewhere) still feeds the paywall headline.
    var selectedGoals: [SleepGoal] = []

    /// nil = not asked yet, true = tapped "Personalize", false = tapped "Skip".
    /// Cosmetic preference only — no system permission is tied to this.
    var personalizationOptIn: Bool? = nil

    // MARK: - Post-"personalize" multi-select block
    // Everything below is collected after the "Let's personalize" screen.
    // All multi-select so the user ticks as much as applies — the more they
    // pick, the more invested they feel and the richer the tailoring.

    var sleepBlockers: [SleepBlocker] = []
    var sleepImpacts: [SleepImpact] = []
    var triedBefore: [TriedBefore] = []
    var windDownPrefs: [WindDownPref] = []

    /// What the user admits to spending money on (picked right before the
    /// paywall). Drives the "$X/week on this vs $0.77/week on sleep"
    /// comparison there and lets the paywall reference it later.
    var vice: Vice? = nil

    // MARK: - Derived presentation values

    /// Personalized starting "sleep score" we show on the analysis screen.
    /// Always leaves visible upside — even a "perfect" answer set caps at 71
    /// so the user never sees a celebratory score and feels the plan still
    /// has work to do. The downside is honest (score reflects answers).
    var derivedSleepScore: Int {
        var score = 67
        if typicalSleepHours < 6 { score -= 14 } else if typicalSleepHours < 7 { score -= 7 }
        if usesPhoneBeforeBed == true { score -= 7 }
        if phoneScreenMinutes > 90 { score -= 4 }
        if stressLevel >= 7 { score -= 6 }
        if racingThoughtsAtNight == true { score -= 4 }
        if wakeFeeling == .exhausted { score -= 7 }
        else if wakeFeeling == .groggy { score -= 4 }
        if napsDuringDay == true { score -= 3 }
        if caffeineCutoff == .evening { score -= 5 }
        else if caffeineCutoff == .afternoon { score -= 2 }
        if roomDarkness == .bright { score -= 3 }
        else if roomDarkness == .someLight { score -= 1 }
        if roomNoise == .loud { score -= 3 }
        else if roomNoise == .someNoise { score -= 1 }
        if bedComfort == .uncomfortable { score -= 4 }
        return max(26, min(71, score))
    }

    /// "Sleep age" — how many years older the user feels because of poor sleep.
    /// Pure storytelling, but it's a strong commitment device.
    var sleepAgeYearsAdded: Int {
        let baseline = 8 - Int(typicalSleepHours.rounded())
        let extras = (usesPhoneBeforeBed == true ? 1 : 0) + (stressLevel >= 7 ? 1 : 0) +
                     (wakeFeeling == .exhausted ? 1 : 0) + (caffeineCutoff == .evening ? 1 : 0)
        return max(2, min(11, baseline + extras))
    }

    /// "Days lost per year" — a vivid number for the bad-sleep animation screen.
    var daysLostPerYear: Int {
        let deficit = max(0.0, 8.0 - typicalSleepHours)
        // ~1 night of 8h = 1 day; show what they're losing every year
        return Int((deficit * 365.0 / 8.0).rounded())
    }

    /// Top 3 issues to surface on the "we found these" screen.
    /// Personalised issues to surface on the TopIssues screen.
    /// Returns 4-6 items — lower thresholds + more checks make the result
    /// feel like an actual analysis, not a generic list.
    var topIssues: [String] {
        var out: [String] = []

        // ── Screens & blue light
        if usesPhoneBeforeBed == true && phoneScreenMinutes >= 20 {
            out.append("Late-night screens flatten your melatonin")
        } else if usesPhoneBeforeBed == true {
            out.append("Phone glow keeps your brain in 'awake' mode")
        }

        // ── Stress + racing thoughts
        if stressLevel >= 7 && racingThoughtsAtNight == true {
            out.append("Anxious thoughts steal your deep sleep")
        } else if stressLevel >= 6 {
            out.append("Stress is holding back your recovery")
        } else if racingThoughtsAtNight == true {
            out.append("Mind racing pushes sleep out by ~25 min")
        }

        // ── Short sleep
        if typicalSleepHours < 6.5 {
            out.append("You're sleeping \(String(format: "%.1f", 8.5 - typicalSleepHours))h short — every night")
        } else if typicalSleepHours < 8 {
            out.append("Your body wants \(String(format: "%.1f", 8.5 - typicalSleepHours))h more rest")
        }

        // ── Caffeine
        if caffeineCutoff == .evening {
            out.append("Evening caffeine is wrecking deep sleep")
        } else if caffeineCutoff == .afternoon {
            out.append("Afternoon coffee lingers for 6+ hours")
        }

        // ── Wake feeling
        if wakeFeeling == .exhausted {
            out.append("Alarm hits while you're in deep sleep")
        } else if wakeFeeling == .groggy {
            out.append("Wake-up is mistimed — you're in the wrong stage")
        }

        // ── Energy dip / daytime tells
        if energyDip == .afternoon || energyDip == .allDay {
            out.append("Afternoon crashes signal hidden debt")
        }
        if napsDuringDay == true {
            out.append("Daytime naps fragment tonight's sleep")
        }

        // ── Environment
        if roomDarkness == .bright {
            out.append("Light leak shortens your REM cycles")
        }
        if roomNoise == .loud || roomNoise == .someNoise {
            out.append("Noise wakes you 4-6× a night — without you knowing")
        }
        if bedComfort == .uncomfortable {
            out.append("Your bed setup is fighting your sleep")
        }

        // ── Long-running struggle
        if struggleDuration == .severalYears || struggleDuration == .asLongAsRemember {
            out.append("This has been a years-long pattern")
        }

        // ── Universal fallbacks (only if we have under 4 personalised hits)
        let fallback: [String] = [
            "Your bedtime drifts ~37 min later on stressful days",
            "Wake variance widens on weekends — your rhythm slips",
            "Avg adult loses 38 min/night to micro-arousals",
            "Sleep efficiency drops 8% the night before deadlines"
        ]
        while out.count < 4 {
            if let next = fallback.first(where: { !out.contains($0) }) {
                out.append(next)
            } else { break }
        }
        // Cap at 6 so the screen stays scannable.
        return Array(out.prefix(6))
    }
}

// MARK: - Sub-types

extension OnboardingProfile {
    enum Gender: String, Codable, CaseIterable, Identifiable {
        case female, male, nonBinary, unspecified
        var id: String { rawValue }
        var label: String {
            switch self {
            case .female: return "Female"
            case .male: return "Male"
            case .nonBinary: return "Non-binary"
            case .unspecified: return "Prefer not to say"
            }
        }
        var icon: String {
            switch self {
            case .female: return "person.fill"
            case .male: return "person.fill"
            case .nonBinary: return "person.2.fill"
            case .unspecified: return "person.crop.circle"
            }
        }
    }

    enum UnitSystem: String, Codable {
        case metric, imperial
    }

    enum StruggleDuration: String, Codable, CaseIterable, Identifiable {
        case fewWeeks, fewMonths, oneYear, severalYears, asLongAsRemember
        var id: String { rawValue }
        var label: String {
            switch self {
            case .fewWeeks: return "A few weeks"
            case .fewMonths: return "A few months"
            case .oneYear: return "About a year"
            case .severalYears: return "Several years"
            case .asLongAsRemember: return "As long as I remember"
            }
        }
    }

    enum SleepProblem: String, Codable, CaseIterable, Identifiable {
        case fallingAsleep
        case stayingAsleep
        case wakingTired
        case inconsistentSchedule
        case stressAndAnxiety
        var id: String { rawValue }
        var label: String {
            switch self {
            case .fallingAsleep: return "Falling asleep"
            case .stayingAsleep: return "Staying asleep"
            case .wakingTired: return "Waking up tired"
            case .inconsistentSchedule: return "Inconsistent schedule"
            case .stressAndAnxiety: return "Stress & anxious mind"
            }
        }
        var icon: String {
            switch self {
            case .fallingAsleep: return "moon.zzz.fill"
            case .stayingAsleep: return "bed.double.fill"
            case .wakingTired: return "sun.max.fill"
            case .inconsistentSchedule: return "calendar"
            case .stressAndAnxiety: return "wind"
            }
        }
    }

    enum CaffeineCutoff: String, Codable, CaseIterable, Identifiable {
        case morning, afternoon, evening, none
        var id: String { rawValue }
        var label: String {
            switch self {
            case .morning: return "Just morning"
            case .afternoon: return "Until afternoon"
            case .evening: return "Evening too"
            case .none: return "I don't drink caffeine"
            }
        }
    }

    enum WakeFeeling: String, Codable, CaseIterable, Identifiable {
        case refreshed, okay, groggy, exhausted
        var id: String { rawValue }
        var label: String {
            switch self {
            case .refreshed: return "Refreshed"
            case .okay: return "Okay-ish"
            case .groggy: return "Groggy"
            case .exhausted: return "Exhausted"
            }
        }
        var emoji: String {
            switch self {
            case .refreshed: return "☀️"
            case .okay: return "🙂"
            case .groggy: return "😪"
            case .exhausted: return "😩"
            }
        }
    }

    enum EnergyDip: String, Codable, CaseIterable, Identifiable {
        case morning, afternoon, evening, allDay, never
        var id: String { rawValue }
        var label: String {
            switch self {
            case .morning: return "Morning"
            case .afternoon: return "Afternoon"
            case .evening: return "Evening"
            case .allDay: return "All day"
            case .never: return "Never really"
            }
        }
    }

    enum RoomQuality: String, Codable, CaseIterable, Identifiable {
        case dark, someLight, bright
        case quiet, someNoise, loud
        case comfortable, okay, uncomfortable
        var id: String { rawValue }
    }

    enum Motivation: String, Codable, CaseIterable, Identifiable {
        case feelBetter
        case moreEnergy
        case mentalClarity
        case fitnessRecovery
        case mood
        case longerLife
        var id: String { rawValue }
        var label: String {
            switch self {
            case .feelBetter: return "Just feel better"
            case .moreEnergy: return "Have more energy"
            case .mentalClarity: return "Mental clarity"
            case .fitnessRecovery: return "Fitness recovery"
            case .mood: return "Better mood"
            case .longerLife: return "Live longer & healthier"
            }
        }
        var icon: String {
            switch self {
            case .feelBetter: return "heart.fill"
            case .moreEnergy: return "bolt.fill"
            case .mentalClarity: return "brain.head.profile"
            case .fitnessRecovery: return "figure.run"
            case .mood: return "face.smiling.fill"
            case .longerLife: return "leaf.fill"
            }
        }
    }

    enum SleepBlocker: String, Codable, CaseIterable, Identifiable {
        case racingMind, phone, stress, notTired, noise, pain, caffeine, partner
        var id: String { rawValue }
        var label: String {
            switch self {
            case .racingMind: return "Racing thoughts"
            case .phone:      return "Scrolling my phone"
            case .stress:     return "Stress & anxiety"
            case .notTired:   return "Not tired at bedtime"
            case .noise:      return "Noise or light"
            case .pain:       return "Discomfort or pain"
            case .caffeine:   return "Caffeine too late"
            case .partner:    return "Partner, kids or pets"
            }
        }
        var icon: String {
            switch self {
            case .racingMind: return "brain.head.profile"
            case .phone:      return "iphone"
            case .stress:     return "exclamationmark.triangle.fill"
            case .notTired:   return "eye"
            case .noise:      return "speaker.wave.2.fill"
            case .pain:       return "bandage.fill"
            case .caffeine:   return "cup.and.saucer.fill"
            case .partner:    return "person.2.fill"
            }
        }
    }

    enum SleepImpact: String, Codable, CaseIterable, Identifiable {
        case lowEnergy, mood, focus, cravings, looks, motivation, workouts, immunity
        var id: String { rawValue }
        var label: String {
            switch self {
            case .lowEnergy:  return "Low energy all day"
            case .mood:       return "Irritable & moody"
            case .focus:      return "Can't focus"
            case .cravings:   return "More cravings"
            case .looks:      return "Tired skin & eyes"
            case .motivation: return "No motivation"
            case .workouts:   return "Worse workouts"
            case .immunity:   return "Get sick more often"
            }
        }
        var icon: String {
            switch self {
            case .lowEnergy:  return "battery.25"
            case .mood:       return "face.dashed"
            case .focus:      return "scope"
            case .cravings:   return "fork.knife"
            case .looks:      return "face.smiling"
            case .motivation: return "zzz"
            case .workouts:   return "figure.run"
            case .immunity:   return "cross.case.fill"
            }
        }
    }

    enum TriedBefore: String, Codable, CaseIterable, Identifiable {
        case melatonin, meditation, noScreens, earlyBed, cutCaffeine, whiteNoise, nothing
        var id: String { rawValue }
        var label: String {
            switch self {
            case .melatonin:   return "Melatonin / supplements"
            case .meditation:  return "Meditation apps"
            case .noScreens:   return "No screens before bed"
            case .earlyBed:    return "Going to bed earlier"
            case .cutCaffeine: return "Cutting caffeine"
            case .whiteNoise:  return "White noise"
            case .nothing:     return "Nothing yet"
            }
        }
        var icon: String {
            switch self {
            case .melatonin:   return "pills.fill"
            case .meditation:  return "brain"
            case .noScreens:   return "iphone.slash"
            case .earlyBed:    return "bed.double.fill"
            case .cutCaffeine: return "cup.and.saucer"
            case .whiteNoise:  return "waveform"
            case .nothing:     return "hand.raised.slash"
            }
        }
    }

    enum Vice: String, Codable, CaseIterable, Identifiable {
        case coffee, smoking, energyDrinks, gaming, eatingOut, streaming
        var id: String { rawValue }
        var label: String {
            switch self {
            case .coffee:       return "Coffee"
            case .smoking:      return "Smoking / vaping"
            case .energyDrinks: return "Energy drinks"
            case .gaming:       return "Gaming"
            case .eatingOut:    return "Eating out"
            case .streaming:    return "Subscriptions"
            }
        }
        var emoji: String {
            switch self {
            case .coffee:       return "☕️"
            case .smoking:      return "🚬"
            case .energyDrinks: return "⚡️"
            case .gaming:       return "🎮"
            case .eatingOut:    return "🍔"
            case .streaming:    return "📺"
            }
        }
        /// What they'd casually estimate it costs them.
        var costLabel: String {
            switch self {
            case .coffee:       return "$5/day"
            case .smoking:      return "$12/day"
            case .energyDrinks: return "$4/day"
            case .gaming:       return "$30/mo"
            case .eatingOut:    return "$15/day"
            case .streaming:    return "$25/mo"
            }
        }
        /// Weekly spend used for the comparison bars.
        var weeklyCost: Double {
            switch self {
            case .coffee:       return 35
            case .smoking:      return 84
            case .energyDrinks: return 28
            case .gaming:       return 7
            case .eatingOut:    return 105
            case .streaming:    return 5.8
            }
        }
        /// How the habit fights their sleep — shown next to the red bar.
        var sleepHarm: String {
            switch self {
            case .coffee:       return "caffeine lingers 6+ hours and cuts deep sleep"
            case .smoking:      return "nicotine is a stimulant — lighter, shorter sleep"
            case .energyDrinks: return "spikes heart rate right into your wind-down"
            case .gaming:       return "blue light + adrenaline push bedtime later"
            case .eatingOut:    return "late heavy meals fragment your night"
            case .streaming:    return "\u{201C}one more episode\u{201D} steals your bedtime"
            }
        }
    }

    enum WindDownPref: String, Codable, CaseIterable, Identifiable {
        case sounds, breathing, reading, warmShower, stretching, journaling, dimLights
        var id: String { rawValue }
        var label: String {
            switch self {
            case .sounds:     return "Calming sounds"
            case .breathing:  return "Breathing exercises"
            case .reading:    return "Reading"
            case .warmShower: return "Warm shower"
            case .stretching: return "Stretching"
            case .journaling: return "Journaling"
            case .dimLights:  return "Dim lights"
            }
        }
        var icon: String {
            switch self {
            case .sounds:     return "music.note"
            case .breathing:  return "wind"
            case .reading:    return "book.fill"
            case .warmShower: return "drop.fill"
            case .stretching: return "figure.cooldown"
            case .journaling: return "pencil.and.outline"
            case .dimLights:  return "lightbulb.fill"
            }
        }
    }
}

// MARK: - Display helpers

extension OnboardingProfile {
    var heightDisplay: String {
        guard let cm = heightCm else { return "—" }
        switch unitSystem {
        case .metric: return "\(cm) cm"
        case .imperial:
            let totalInches = Int((Double(cm) / 2.54).rounded())
            let feet = totalInches / 12
            let inches = totalInches % 12
            return "\(feet)'\(inches)\""
        }
    }

    var weightDisplay: String {
        guard let kg = weightKg else { return "—" }
        switch unitSystem {
        case .metric: return String(format: "%.0f kg", kg)
        case .imperial: return String(format: "%.0f lb", kg * 2.20462)
        }
    }
}
