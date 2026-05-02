import Foundation

struct SleepEntry: Identifiable, Codable, Hashable {
    enum Quality: String, Codable, CaseIterable, Identifiable {
        case great, good, okay, poor
        var id: String { rawValue }

        var label: String {
            switch self {
            case .great: return "Great"
            case .good:  return "Good"
            case .okay:  return "Okay"
            case .poor:  return "Poor"
            }
        }

        var emoji: String {
            switch self {
            case .great: return "🌟"
            case .good:  return "🙂"
            case .okay:  return "😐"
            case .poor:  return "😴"
            }
        }

        var points: Int {
            switch self {
            case .great: return 20
            case .good:  return 16
            case .okay:  return 11
            case .poor:  return 6
            }
        }
    }

    enum Mood: String, Codable, CaseIterable, Identifiable {
        case tired, okay, energized
        var id: String { rawValue }

        var label: String {
            switch self {
            case .tired:     return "Tired"
            case .okay:      return "Okay"
            case .energized: return "Energized"
            }
        }

        var emoji: String {
            switch self {
            case .tired:     return "😪"
            case .okay:      return "🙂"
            case .energized: return "✨"
            }
        }
    }

    var id: UUID = UUID()
    var bedtime: Date
    var wakeTime: Date
    var quality: Quality
    var mood: Mood
    var notes: String = ""
    var routineCompleted: Bool = false
    var score: Int = 0
    var energyEarned: Int = 0

    var duration: TimeInterval {
        max(0, wakeTime.timeIntervalSince(bedtime))
    }

    var hours: Double { duration / 3600 }

    var formattedDuration: String {
        let total = Int(duration)
        let h = total / 3600
        let m = (total % 3600) / 60
        return "\(h)h \(String(format: "%02d", m))m"
    }

    var dayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: wakeTime)
    }
}
