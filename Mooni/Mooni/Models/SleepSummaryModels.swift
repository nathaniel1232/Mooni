import Foundation

struct SleepStagesEstimate: Codable, Hashable {
    var deepSleep: TimeInterval
    var remSleep: TimeInterval
    var lightSleep: TimeInterval
    var awakeTime: TimeInterval
    var isEstimated: Bool

    var totalSleep: TimeInterval {
        deepSleep + remSleep + lightSleep
    }
}

struct MorningCheckIn: Codable, Hashable {
    var date: Date
    var feeling: MorningFeeling
    var wakeUps: WakeUpFrequency
    var dreams: DreamRecall
    var getOutOfBedDifficulty: BedDifficulty
    var lateCaffeine: Bool?
    /// Self-reported minutes to fall asleep last night.
    var minutesToFallAsleep: Int?
    /// Minutes between SleepOwl's wake-tap and the user actually opening
    /// the morning check-in. Used to refine wake-time accuracy.
    var minutesFromWakeToAppOpen: Int?
    /// If the user corrected the auto-detected bedtime in the check-in.
    var correctedBedtime: Date?
    /// If the user corrected the auto-detected wake time in the check-in.
    var correctedWakeTime: Date?
    /// How accurate the user judged the auto-detected sleep window to be.
    var accuracyRating: SleepAccuracyRating?

    // MARK: - Expanded intake (Plan 1)
    // Every field below is Optional so a legacy MorningCheckIn (encoded before
    // these existed) still decodes — the synthesized decoder maps a missing key
    // to nil. nil means "not asked / skipped", never "zero".

    /// Minutes between putting the phone down and actually drifting off.
    /// Sharpens the real sleep-onset clock beyond `minutesToFallAsleep`.
    var minutesPhoneDownToSleep: Int?
    /// Minutes from waking to actually getting out of bed.
    var minutesWakeToOutOfBed: Int?
    /// How many caffeinated drinks the user had yesterday.
    var caffeineCount: Int?
    /// Clock time of the last caffeinated drink (only when caffeineCount ≥ 1).
    var lastCaffeineTime: Date?
    /// Clock time of the last meal / snack yesterday.
    var lastMealTime: Date?
    /// Whether that last meal was late & heavy.
    var lateHeavyMeal: Bool?
    /// Alcoholic drinks yesterday (0, 1, 2, 3 = "3+").
    var alcoholDrinks: Int?
    /// When the user moved/exercised most yesterday.
    var exerciseTime: ExerciseTiming?
    /// Total nap minutes yesterday.
    var napMinutes: Int?
    /// Self-reported stress level yesterday.
    var stressLevel: StressLevel?
    /// Whether the user was on their phone in bed before sleep.
    var screenInBed: Bool?
    /// How the bedroom felt temperature-wise.
    var roomFeel: RoomTemp?
    /// Optional self-report that bedtime ran late.
    var bedtimeWasLate: Bool?

    init(
        date: Date,
        feeling: MorningFeeling,
        wakeUps: WakeUpFrequency,
        dreams: DreamRecall,
        getOutOfBedDifficulty: BedDifficulty,
        lateCaffeine: Bool? = nil,
        minutesToFallAsleep: Int? = nil,
        minutesFromWakeToAppOpen: Int? = nil,
        correctedBedtime: Date? = nil,
        correctedWakeTime: Date? = nil,
        accuracyRating: SleepAccuracyRating? = nil,
        minutesPhoneDownToSleep: Int? = nil,
        minutesWakeToOutOfBed: Int? = nil,
        caffeineCount: Int? = nil,
        lastCaffeineTime: Date? = nil,
        lastMealTime: Date? = nil,
        lateHeavyMeal: Bool? = nil,
        alcoholDrinks: Int? = nil,
        exerciseTime: ExerciseTiming? = nil,
        napMinutes: Int? = nil,
        stressLevel: StressLevel? = nil,
        screenInBed: Bool? = nil,
        roomFeel: RoomTemp? = nil,
        bedtimeWasLate: Bool? = nil
    ) {
        self.date = date
        self.feeling = feeling
        self.wakeUps = wakeUps
        self.dreams = dreams
        self.getOutOfBedDifficulty = getOutOfBedDifficulty
        self.lateCaffeine = lateCaffeine
        self.minutesToFallAsleep = minutesToFallAsleep
        self.minutesFromWakeToAppOpen = minutesFromWakeToAppOpen
        self.correctedBedtime = correctedBedtime
        self.correctedWakeTime = correctedWakeTime
        self.accuracyRating = accuracyRating
        self.minutesPhoneDownToSleep = minutesPhoneDownToSleep
        self.minutesWakeToOutOfBed = minutesWakeToOutOfBed
        self.caffeineCount = caffeineCount
        self.lastCaffeineTime = lastCaffeineTime
        self.lastMealTime = lastMealTime
        self.lateHeavyMeal = lateHeavyMeal
        self.alcoholDrinks = alcoholDrinks
        self.exerciseTime = exerciseTime
        self.napMinutes = napMinutes
        self.stressLevel = stressLevel
        self.screenInBed = screenInBed
        self.roomFeel = roomFeel
        self.bedtimeWasLate = bedtimeWasLate
    }
}

enum SleepAccuracyRating: String, Codable, CaseIterable, Identifiable {
    case spotOn
    case mostlyRight
    case wayOff

    var id: String { rawValue }

    var label: String {
        switch self {
        case .spotOn:      return "Spot on"
        case .mostlyRight: return "Mostly right"
        case .wayOff:      return "Way off"
        }
    }

    var emoji: String {
        switch self {
        case .spotOn:      return "🎯"
        case .mostlyRight: return "👍"
        case .wayOff:      return "🤔"
        }
    }
}

enum MorningFeeling: String, Codable, CaseIterable, Identifiable {
    case great
    case okay
    case tired
    case exhausted

    var id: String { rawValue }

    var label: String {
        switch self {
        case .great: return "Great"
        case .okay: return "Okay"
        case .tired: return "Tired"
        case .exhausted: return "Exhausted"
        }
    }
}

enum WakeUpFrequency: String, Codable, CaseIterable, Identifiable {
    case none
    case once
    case fewTimes
    case aLot

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "No"
        case .once: return "Once"
        case .fewTimes: return "A few times"
        case .aLot: return "A lot"
        }
    }
}

enum DreamRecall: String, Codable, CaseIterable, Identifiable {
    case yes
    case notSure
    case no

    var id: String { rawValue }

    var label: String {
        switch self {
        case .yes: return "Yes"
        case .notSure: return "Not sure"
        case .no: return "No"
        }
    }
}

enum BedDifficulty: String, Codable, CaseIterable, Identifiable {
    case easy
    case normal
    case hard
    case veryHard

    var id: String { rawValue }

    var label: String {
        switch self {
        case .easy: return "Easy"
        case .normal: return "Normal"
        case .hard: return "Hard"
        case .veryHard: return "Very hard"
        }
    }
}

enum ExerciseTiming: String, Codable, CaseIterable, Identifiable {
    case none
    case morning
    case afternoon
    case evening
    case late

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none:      return "Didn't"
        case .morning:   return "Morning"
        case .afternoon: return "Afternoon"
        case .evening:   return "Evening"
        case .late:      return "Late night"
        }
    }

    var emoji: String {
        switch self {
        case .none:      return "🛋️"
        case .morning:   return "🌅"
        case .afternoon: return "☀️"
        case .evening:   return "🌆"
        case .late:      return "🌙"
        }
    }
}

enum StressLevel: String, Codable, CaseIterable, Identifiable {
    case calm
    case normal
    case tense
    case stressed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .calm:     return "Calm"
        case .normal:   return "Normal"
        case .tense:    return "Tense"
        case .stressed: return "Stressed"
        }
    }

    var emoji: String {
        switch self {
        case .calm:     return "😌"
        case .normal:   return "🙂"
        case .tense:    return "😬"
        case .stressed: return "😰"
        }
    }
}

enum RoomTemp: String, Codable, CaseIterable, Identifiable {
    case cold
    case cool
    case justRight
    case warm
    case hot

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cold:      return "Cold"
        case .cool:      return "Cool"
        case .justRight: return "Just right"
        case .warm:      return "Warm"
        case .hot:       return "Hot"
        }
    }

    var emoji: String {
        switch self {
        case .cold:      return "🥶"
        case .cool:      return "❄️"
        case .justRight: return "😌"
        case .warm:      return "🌡️"
        case .hot:       return "🥵"
        }
    }
}

enum SleepDataSource: String, Codable, Hashable {
    case healthKit
    case appActivityEstimate
    case userAdjusted

    var label: String {
        switch self {
        case .healthKit: return "HealthKit"
        case .appActivityEstimate: return "App activity"
        case .userAdjusted: return "User adjusted"
        }
    }
}

struct DailySleepSummary: Codable, Hashable {
    var date: Date
    var sleepStart: Date
    var wakeTime: Date
    var totalSleep: TimeInterval
    var stages: SleepStagesEstimate
    var sleepScore: Int
    var readinessScore: Int
    var energyLevel: String
    var insight: String
    var recoveryMessage: String
    var source: SleepDataSource
}
