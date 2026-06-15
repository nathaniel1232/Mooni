import Foundation

/// The overnight physiology read-out for a single night — every value the
/// Night Analytics page renders. Pure data (no SwiftUI): the view maps the
/// `Tone` of each verdict onto a colour.
///
/// These are modelled from the night's timing and stage balance using
/// well-established sleep-science relationships. They are presented to the user
/// as confident, plain statements — never hedged — but the engine that fills
/// this struct keeps every number bounded and grounded.
struct NightPhysiology {

    /// How a window or signal landed — drives copy + colour in the view.
    enum Tone { case positive, neutral, caution }

    enum WindowVerdict {
        case caught, partial, missed
        var label: String {
            switch self {
            case .caught:  return "Caught it"
            case .partial: return "Partly caught"
            case .missed:  return "Missed it"
            }
        }
        var tone: Tone {
            switch self {
            case .caught:  return .positive
            case .partial: return .neutral
            case .missed:  return .caution
            }
        }
    }

    enum Grade {
        case strong, fair, low
        var label: String {
            switch self {
            case .strong: return "Strong"
            case .fair:   return "Fair"
            case .low:    return "Low"
            }
        }
        var tone: Tone {
            switch self {
            case .strong: return .positive
            case .fair:   return .neutral
            case .low:    return .caution
            }
        }
    }

    enum WakeEase {
        case easy, normal, hard
        var label: String {
            switch self {
            case .easy:   return "Easy rise"
            case .normal: return "Normal rise"
            case .hard:   return "Hard rise"
            }
        }
        var tone: Tone {
            switch self {
            case .easy:   return .positive
            case .normal: return .neutral
            case .hard:   return .caution
            }
        }
    }

    // Timeline anchors (the night runs inBed → wake).
    var inBed: Date
    var sleepOnset: Date
    var wakeTime: Date
    var totalSleep: TimeInterval

    // Stage shares (0…1 of total sleep) and minutes — mirrored from the entry's
    // stage estimate so the view has one source of truth.
    var deepShare: Double
    var deepMinutes: Int
    var remShare: Double
    var remMinutes: Int

    // Cycles
    var completeCycles: Int
    var cycleLength: TimeInterval

    // REM / dreaming
    var remOnset: Date

    // Growth hormone (first slow-wave episode)
    var ghStart: Date
    var ghEnd: Date
    var ghQuality: Int            // 0…100
    var ghVerdict: WindowVerdict

    // Core body temperature
    var tempMin: Date
    var minutesWokeAfterTempMin: Int   // signed: + means on the rising limb
    var wakeEase: WakeEase

    // Cortisol awakening response
    var cortisolPeak: Date
    var cortisolRiseStart: Date
    var cortisolQuality: Int     // 0…100
    var cortisolGrade: Grade

    // Melatonin
    var melatoninOnset: Date
    var melatoninPeak: Date
    var melatoninSuppressed: Bool

    // Recovery readouts
    var muscleRestfulness: Int   // 0…100
    var adenosineCleared: Int    // 0…100

    // Confident one-liners tied to the user's logged inputs (only the ones
    // that actually apply for this night).
    var inputNotes: [String]

    /// Clock string helper used throughout the view.
    func clockString(_ date: Date) -> String { date.hourMinuteString }
}
