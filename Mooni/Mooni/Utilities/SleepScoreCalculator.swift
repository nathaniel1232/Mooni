import Foundation

struct SleepScoreBreakdown {
    var duration: Int      // out of 40
    var consistency: Int   // out of 30
    var quality: Int       // out of 20
    var routine: Int       // out of 10

    var total: Int { duration + consistency + quality + routine }

    var label: String {
        switch total {
        case 85...:   return "Great"
        case 70..<85: return "Good"
        case 50..<70: return "Okay"
        default:      return "Low"
        }
    }
}

enum SleepScoreCalculator {
    /// Compute a sleep score given the user's targets and the entry.
    static func score(
        for entry: SleepEntry,
        goalHours: Double,
        targetBedtime: Date,
        targetWakeTime: Date
    ) -> SleepScoreBreakdown {
        SleepScoreBreakdown(
            duration: durationPoints(hours: entry.hours, goal: goalHours),
            consistency: consistencyPoints(
                bedtime: entry.bedtime,
                target: targetBedtime,
                wake: entry.wakeTime,
                wakeTarget: targetWakeTime
            ),
            quality: entry.quality.points,
            routine: entry.routineCompleted ? 10 : 0
        )
    }

    private static func durationPoints(hours: Double, goal: Double) -> Int {
        guard goal > 0 else { return 0 }
        let diff = abs(hours - goal)
        switch diff {
        case ..<0.25: return 40
        case ..<0.75: return 36
        case ..<1.25: return 30
        case ..<2.0:  return 22
        case ..<3.0:  return 14
        default:      return 6
        }
    }

    private static func consistencyPoints(
        bedtime: Date,
        target: Date,
        wake: Date,
        wakeTarget: Date
    ) -> Int {
        let bedDiff = minutesBetweenTimeOfDay(bedtime, target)
        let wakeDiff = minutesBetweenTimeOfDay(wake, wakeTarget)
        let avg = (bedDiff + wakeDiff) / 2
        switch avg {
        case ..<10:  return 30
        case ..<20:  return 26
        case ..<35:  return 22
        case ..<60:  return 16
        case ..<90:  return 10
        default:     return 4
        }
    }

    /// Compares only hour/minute of two dates (mod 24h) and returns absolute minutes difference.
    private static func minutesBetweenTimeOfDay(_ a: Date, _ b: Date) -> Int {
        let cal = Calendar.current
        let ca = cal.dateComponents([.hour, .minute], from: a)
        let cb = cal.dateComponents([.hour, .minute], from: b)
        let aMin = (ca.hour ?? 0) * 60 + (ca.minute ?? 0)
        let bMin = (cb.hour ?? 0) * 60 + (cb.minute ?? 0)
        let raw = abs(aMin - bMin)
        return min(raw, 1440 - raw)
    }

    /// Calculate dream energy reward for a sleep entry.
    static func energyReward(for entry: SleepEntry, score: Int) -> Int {
        var energy = 10 // base for logging
        if entry.hours >= 7 { energy += 15 }
        if score >= 80 { energy += 10 }
        if entry.routineCompleted { energy += 10 }
        return energy
    }
}
