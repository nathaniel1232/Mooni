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
    /// Minutes between Mooni's wake-tap and the user actually opening
    /// the morning check-in. Used to refine wake-time accuracy.
    var minutesFromWakeToAppOpen: Int?
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
