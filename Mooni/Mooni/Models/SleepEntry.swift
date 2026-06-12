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

    var id: UUID
    var bedtime: Date
    var wakeTime: Date
    var quality: Quality
    var mood: Mood
    var notes: String
    var routineCompleted: Bool
    var score: Int
    var energyEarned: Int
    /// True when bedtime/wake were inferred from app activity (no HealthKit /
    /// no manual log). Surfaced in UI as "Estimated".
    var isEstimated: Bool
    var totalSleep: TimeInterval?
    var timeInBed: TimeInterval?
    var stages: SleepStagesEstimate?
    var readinessScore: Int?
    var energyLevel: String?
    var insight: String?
    var recoveryMessage: String?
    var source: SleepDataSource?
    var didCompleteMorningCheckIn: Bool
    /// True when this entry was fabricated purely from the user's target
    /// schedule because a night elapsed with zero real signals. These never
    /// trigger the morning check-in and must not be presented as a tracked
    /// night — they only exist so the night stays editable.
    var isScheduleBackfill: Bool
    /// Sleep-brain confidence (0–1) for auto-detected nights. nil for manual,
    /// HealthKit, and legacy entries.
    var confidence: Double?

    init(
        id: UUID = UUID(),
        bedtime: Date,
        wakeTime: Date,
        quality: Quality,
        mood: Mood,
        notes: String = "",
        routineCompleted: Bool = false,
        score: Int = 0,
        energyEarned: Int = 0,
        isEstimated: Bool = false,
        totalSleep: TimeInterval? = nil,
        timeInBed: TimeInterval? = nil,
        stages: SleepStagesEstimate? = nil,
        readinessScore: Int? = nil,
        energyLevel: String? = nil,
        insight: String? = nil,
        recoveryMessage: String? = nil,
        source: SleepDataSource? = nil,
        didCompleteMorningCheckIn: Bool = false,
        isScheduleBackfill: Bool = false,
        confidence: Double? = nil
    ) {
        self.id = id
        self.bedtime = bedtime
        self.wakeTime = wakeTime
        self.quality = quality
        self.mood = mood
        self.notes = notes
        self.routineCompleted = routineCompleted
        self.score = score
        self.energyEarned = energyEarned
        self.isEstimated = isEstimated
        self.totalSleep = totalSleep
        self.timeInBed = timeInBed
        self.stages = stages
        self.readinessScore = readinessScore
        self.energyLevel = energyLevel
        self.insight = insight
        self.recoveryMessage = recoveryMessage
        self.source = source
        self.didCompleteMorningCheckIn = didCompleteMorningCheckIn
        self.isScheduleBackfill = isScheduleBackfill
        self.confidence = confidence
    }

    var duration: TimeInterval {
        max(0, wakeTime.timeIntervalSince(bedtime))
    }

    var totalSleepDuration: TimeInterval {
        max(0, totalSleep ?? stages?.totalSleep ?? duration)
    }

    var hours: Double { totalSleepDuration / 3600 }

    var formattedDuration: String {
        let total = Int(totalSleepDuration)
        let h = total / 3600
        let m = (total % 3600) / 60
        return "\(h)h \(String(format: "%02d", m))m"
    }

    var dayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: wakeTime)
    }

    var resolvedSource: SleepDataSource {
        if let source { return source }
        return isEstimated ? .appActivityEstimate : .userAdjusted
    }

    enum CodingKeys: String, CodingKey {
        case id, bedtime, wakeTime, quality, mood, notes, routineCompleted
        case score, energyEarned, isEstimated, totalSleep, timeInBed, stages
        case readinessScore, energyLevel, insight, recoveryMessage, source
        case didCompleteMorningCheckIn, isScheduleBackfill, confidence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        bedtime = try container.decode(Date.self, forKey: .bedtime)
        wakeTime = try container.decode(Date.self, forKey: .wakeTime)
        quality = try container.decodeIfPresent(Quality.self, forKey: .quality) ?? .good
        mood = try container.decodeIfPresent(Mood.self, forKey: .mood) ?? .okay
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        routineCompleted = try container.decodeIfPresent(Bool.self, forKey: .routineCompleted) ?? false
        score = try container.decodeIfPresent(Int.self, forKey: .score) ?? 0
        energyEarned = try container.decodeIfPresent(Int.self, forKey: .energyEarned) ?? 0
        isEstimated = try container.decodeIfPresent(Bool.self, forKey: .isEstimated) ?? false
        totalSleep = try container.decodeIfPresent(TimeInterval.self, forKey: .totalSleep)
        timeInBed = try container.decodeIfPresent(TimeInterval.self, forKey: .timeInBed)
        stages = try container.decodeIfPresent(SleepStagesEstimate.self, forKey: .stages)
        readinessScore = try container.decodeIfPresent(Int.self, forKey: .readinessScore)
        energyLevel = try container.decodeIfPresent(String.self, forKey: .energyLevel)
        insight = try container.decodeIfPresent(String.self, forKey: .insight)
        recoveryMessage = try container.decodeIfPresent(String.self, forKey: .recoveryMessage)
        source = try container.decodeIfPresent(SleepDataSource.self, forKey: .source)
        didCompleteMorningCheckIn = try container.decodeIfPresent(Bool.self, forKey: .didCompleteMorningCheckIn) ?? false
        isScheduleBackfill = try container.decodeIfPresent(Bool.self, forKey: .isScheduleBackfill) ?? false
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence)
    }
}
