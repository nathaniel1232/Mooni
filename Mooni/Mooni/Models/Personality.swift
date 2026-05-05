import Foundation

/// Personality traits a pet develops based on the user's sleep behavior.
/// These are derived (not stored) — call `derive(from:)` with current sleep data.
enum Personality: String, Codable, CaseIterable, Identifiable {
    case consistent
    case nightOwl
    case earlyBird
    case recovering
    case explorer
    case balanced

    var id: String { rawValue }

    var label: String {
        switch self {
        case .consistent: return "Consistent"
        case .nightOwl:   return "Night Owl"
        case .earlyBird:  return "Early Bird"
        case .recovering: return "Recovering"
        case .explorer:   return "Explorer"
        case .balanced:   return "Balanced"
        }
    }

    var description: String {
        switch self {
        case .consistent: return "Calm, reliable, cozy. Loves a steady rhythm."
        case .nightOwl:   return "Curious, moon-loving, playful in the late hours."
        case .earlyBird:  return "Bright, energetic, greets every sunrise."
        case .recovering: return "Gentle and resilient — bouncing back."
        case .explorer:   return "Adventurous, restless, always trying new schedules."
        case .balanced:   return "Easygoing — adapts to whatever the night brings."
        }
    }

    var icon: String {
        switch self {
        case .consistent: return "metronome.fill"
        case .nightOwl:   return "moon.stars.fill"
        case .earlyBird:  return "sun.max.fill"
        case .recovering: return "heart.fill"
        case .explorer:   return "binoculars.fill"
        case .balanced:   return "scale.3d"
        }
    }

    /// Derive the dominant personality trait from recent sleep history.
    static func derive(entries: [SleepEntry], targetBedtime: Date,
                       consistencyDays: Int, debt: Double) -> Personality {
        guard !entries.isEmpty else { return .balanced }

        let cal = Calendar.current
        let bedHours = entries.prefix(14).map { e -> Int in
            cal.component(.hour, from: e.bedtime)
        }
        let avgBedHour = Double(bedHours.reduce(0, +)) / Double(max(bedHours.count, 1))

        if consistencyDays >= 5 { return .consistent }
        if debt >= 5 { return .recovering }
        if avgBedHour >= 24 || avgBedHour < 4 { return .nightOwl }
        if avgBedHour <= 21 && avgBedHour > 17 { return .earlyBird }

        // Variance check — high wake variance → explorer
        let wakeVar = SleepInsights.wakeTimeVariance(entries: entries, days: 7)
        if wakeVar >= 90 { return .explorer }

        return .balanced
    }
}
