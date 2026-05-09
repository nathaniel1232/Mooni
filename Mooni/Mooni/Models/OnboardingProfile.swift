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

    // MARK: - Derived presentation values

    /// Personalized starting "sleep score" we show on the analysis screen.
    /// This is intentionally generous-looking (40–65) so the user has obvious upside.
    var derivedSleepScore: Int {
        var score = 70
        if typicalSleepHours < 6 { score -= 12 } else if typicalSleepHours < 7 { score -= 6 }
        if usesPhoneBeforeBed == true { score -= 6 }
        if phoneScreenMinutes > 90 { score -= 4 }
        if stressLevel >= 7 { score -= 5 }
        if racingThoughtsAtNight == true { score -= 4 }
        if wakeFeeling == .exhausted { score -= 6 }
        else if wakeFeeling == .groggy { score -= 3 }
        if napsDuringDay == true { score -= 2 }
        if caffeineCutoff == .evening { score -= 4 }
        if roomDarkness == .bright { score -= 2 }
        if roomNoise == .loud { score -= 2 }
        return max(28, min(78, score))
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
    var topIssues: [String] {
        var out: [String] = []
        if usesPhoneBeforeBed == true && phoneScreenMinutes >= 30 {
            out.append("Late-night screens flatten your melatonin")
        }
        if stressLevel >= 6 || racingThoughtsAtNight == true {
            out.append("Mind racing keeps you out of deep sleep")
        }
        if typicalSleepHours < 7 {
            out.append("You're \(String(format: "%.1f", 7.5 - typicalSleepHours)) hrs short most nights")
        }
        if caffeineCutoff == .evening || caffeineCutoff == .afternoon {
            out.append("Caffeine half-life is steeling your sleep")
        }
        if wakeFeeling == .exhausted || wakeFeeling == .groggy {
            out.append("You wake up in the wrong sleep stage")
        }
        if out.isEmpty {
            out = [
                "Your bedtime drifts later on stressful days",
                "Your wake-up time isn't aligned with your rhythm",
                "Small habits are blocking your deep sleep"
            ]
        }
        return Array(out.prefix(3))
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
