import Foundation

/// The user's primary sleep goal — picked in onboarding, used throughout the app
/// to personalize messaging, paywall framing, and program recommendations.
enum SleepGoal: String, Codable, CaseIterable, Identifiable {
    case fallAsleepEarlier
    case wakeUpLessTired
    case fixSchedule
    case stopRevengeBedtime
    case improveRecovery
    case reduceStress

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fallAsleepEarlier:  return "Fall asleep earlier"
        case .wakeUpLessTired:    return "Wake up less tired"
        case .fixSchedule:        return "Fix my sleep schedule"
        case .stopRevengeBedtime: return "Stop revenge bedtime procrastination"
        case .improveRecovery:    return "Improve recovery"
        case .reduceStress:       return "Reduce stress at night"
        }
    }

    var icon: String {
        switch self {
        case .fallAsleepEarlier:  return "moon.fill"
        case .wakeUpLessTired:    return "sun.max.fill"
        case .fixSchedule:        return "calendar"
        case .stopRevengeBedtime: return "iphone.slash"
        case .improveRecovery:    return "heart.fill"
        case .reduceStress:       return "wind"
        }
    }

    /// Sentence used in the personalized paywall headline & messages.
    var promise: String {
        switch self {
        case .fallAsleepEarlier:  return "We'll help you fall asleep earlier."
        case .wakeUpLessTired:    return "We'll help you wake up less tired."
        case .fixSchedule:        return "We'll help you fix your sleep schedule."
        case .stopRevengeBedtime: return "We'll help you reclaim your evenings."
        case .improveRecovery:    return "We'll help you recover faster."
        case .reduceStress:       return "We'll help you wind down with less stress."
        }
    }
}
