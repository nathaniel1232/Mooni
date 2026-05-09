import Foundation

enum SleepScoringManager {
    static func update(
        entry: inout SleepEntry,
        goalHours: Double,
        consistencyDays: Int,
        checkIn: MorningCheckIn?
    ) {
        let summary = summarize(
            entry: entry,
            goalHours: goalHours,
            consistencyDays: consistencyDays,
            checkIn: checkIn
        )
        entry.totalSleep = summary.totalSleep
        entry.stages = summary.stages
        entry.score = summary.sleepScore
        entry.readinessScore = summary.readinessScore
        entry.energyLevel = summary.energyLevel
        entry.insight = summary.insight
        entry.recoveryMessage = summary.recoveryMessage
        entry.source = summary.source
        entry.didCompleteMorningCheckIn = checkIn != nil
        entry.energyEarned = SleepScoreCalculator.energyReward(for: entry, score: entry.score)
    }

    static func summarize(
        entry: SleepEntry,
        goalHours: Double,
        consistencyDays: Int,
        checkIn: MorningCheckIn?
    ) -> DailySleepSummary {
        let source = entry.resolvedSource
        let existingStages = entry.stages
        let totalSleep = max(0, entry.totalSleep ?? existingStages?.totalSleep ?? entry.duration)
        let timeInBed = entry.timeInBed ?? fallbackTimeInBed(for: entry, totalSleep: totalSleep)
        let stages: SleepStagesEstimate

        if let existingStages, existingStages.isEstimated == false {
            stages = existingStages
        } else {
            stages = estimateStages(
                totalSleep: totalSleep,
                timeInBed: timeInBed,
                date: entry.wakeTime,
                quality: entry.quality,
                checkIn: checkIn
            )
        }

        let sleepScore = scoreSleep(
            totalSleep: totalSleep,
            stages: stages,
            consistencyDays: consistencyDays,
            checkIn: checkIn
        )
        let readiness = scoreReadiness(
            sleepScore: sleepScore,
            totalSleep: totalSleep,
            checkIn: checkIn
        )
        let energyLevel = energyLevel(for: readiness)
        let insight = makeInsight(
            totalSleep: totalSleep,
            sleepScore: sleepScore,
            readinessScore: readiness,
            stages: stages,
            checkIn: checkIn
        )
        let recovery = makeRecoveryMessage(
            readinessScore: readiness,
            energyLevel: energyLevel,
            checkIn: checkIn
        )

        return DailySleepSummary(
            date: entry.wakeTime,
            sleepStart: entry.bedtime,
            wakeTime: entry.wakeTime,
            totalSleep: totalSleep,
            stages: stages,
            sleepScore: sleepScore,
            readinessScore: readiness,
            energyLevel: energyLevel,
            insight: insight,
            recoveryMessage: recovery,
            source: source
        )
    }

    private static func fallbackTimeInBed(for entry: SleepEntry, totalSleep: TimeInterval) -> TimeInterval? {
        switch entry.resolvedSource {
        case .appActivityEstimate, .userAdjusted:
            return max(entry.duration, totalSleep)
        case .healthKit:
            return nil
        }
    }

    static func estimateStages(
        totalSleep: TimeInterval,
        timeInBed: TimeInterval?,
        date: Date,
        quality: SleepEntry.Quality,
        checkIn: MorningCheckIn?
    ) -> SleepStagesEstimate {
        guard totalSleep > 0 else {
            return SleepStagesEstimate(deepSleep: 0, remSleep: 0, lightSleep: 0, awakeTime: 0, isEstimated: true)
        }

        var deepPct = 0.18 + seededFraction(date: date, salt: 13) * 0.06
        var remPct = 0.20 + seededFraction(date: date, salt: 29) * 0.05
        var awakePct = 0.02 + seededFraction(date: date, salt: 41) * 0.06

        if checkIn?.feeling == .great { deepPct += 0.02 }
        if checkIn?.dreams == .yes { remPct += 0.025 }
        if checkIn?.dreams == .notSure { remPct += 0.005 }

        switch checkIn?.wakeUps {
        case .fewTimes:
            awakePct += 0.02
        case .aLot:
            awakePct += 0.04
        default:
            break
        }

        if quality == .poor || checkIn?.feeling == .exhausted {
            deepPct -= 0.025
        }
        if checkIn?.feeling == .tired {
            deepPct -= 0.01
        }

        deepPct = clamp(deepPct, min: 0.16, max: 0.27)
        remPct = clamp(remPct, min: 0.18, max: 0.29)
        awakePct = clamp(awakePct, min: 0.02, max: 0.08)

        let deep = totalSleep * deepPct
        let rem = totalSleep * remPct
        let light = max(0, totalSleep - deep - rem)
        let awake = timeInBed.map { max(0, $0 * awakePct) } ?? 0

        return SleepStagesEstimate(
            deepSleep: deep,
            remSleep: rem,
            lightSleep: light,
            awakeTime: awake,
            isEstimated: true
        )
    }

    static func scoreSleep(
        totalSleep: TimeInterval,
        stages: SleepStagesEstimate,
        consistencyDays: Int,
        checkIn: MorningCheckIn?
    ) -> Int {
        let hours = totalSleep / 3600
        var score = 70

        switch hours {
        case 7.5...9.0:
            score += 20
        case 6.5..<7.5:
            score += 10
        case 5.5..<6.5:
            break
        case ..<5.5:
            score -= 15
        default:
            if hours > 10 { score -= 5 }
        }

        switch checkIn?.feeling {
        case .great:
            score += 10
        case .okay:
            score += 3
        case .tired:
            score -= 7
        case .exhausted:
            score -= 15
        case nil:
            break
        }

        switch checkIn?.wakeUps {
        case .some(.none):
            score += 5
        case .once:
            break
        case .fewTimes:
            score -= 8
        case .aLot:
            score -= 15
        case nil:
            break
        }

        switch checkIn?.getOutOfBedDifficulty {
        case .easy:
            score += 5
        case .normal:
            break
        case .hard:
            score -= 6
        case .veryHard:
            score -= 12
        case nil:
            break
        }

        if consistencyDays >= 7 {
            score += 4
        } else if consistencyDays >= 3 {
            score += 2
        }

        let deepRatio = totalSleep > 0 ? stages.deepSleep / totalSleep : 0
        let awakeRatio = totalSleep > 0 ? stages.awakeTime / totalSleep : 0
        if deepRatio < 0.18 { score -= 3 }
        if awakeRatio > 0.07 { score -= 3 }

        return clamp(score, min: 0, max: 100)
    }

    static func scoreReadiness(
        sleepScore: Int,
        totalSleep: TimeInterval,
        checkIn: MorningCheckIn?
    ) -> Int {
        let hours = totalSleep / 3600
        var readiness = sleepScore

        switch checkIn?.feeling {
        case .great:
            readiness += 8
        case .okay:
            readiness += 2
        case .tired:
            readiness -= 8
        case .exhausted:
            readiness -= 18
        case nil:
            break
        }

        if checkIn?.wakeUps == .fewTimes || checkIn?.wakeUps == .aLot {
            readiness -= 10
        }
        if hours < 6 {
            readiness -= 10
        }
        if hours >= 7.5 && hours <= 9 {
            readiness += 5
        }

        return clamp(readiness, min: 0, max: 100)
    }

    static func energyLevel(for readinessScore: Int) -> String {
        switch readinessScore {
        case 90...100: return "Peak Mode"
        case 75..<90: return "Charged"
        case 60..<75: return "Steady"
        case 40..<60: return "Low Battery"
        default: return "Recovery Day"
        }
    }

    static func makeInsight(
        totalSleep: TimeInterval,
        sleepScore: Int,
        readinessScore: Int,
        stages: SleepStagesEstimate,
        checkIn: MorningCheckIn?
    ) -> String {
        let hours = totalSleep / 3600

        if hours < 5.5 {
            return "Short sleep detected. Keep today lighter if you can."
        }
        if checkIn?.wakeUps == .fewTimes || checkIn?.wakeUps == .aLot {
            return "You slept enough, but your wake-ups may have lowered recovery."
        }
        if checkIn?.dreams == .yes {
            return "You reported dreams, so your REM line may run higher than usual."
        }
        if readinessScore >= 90 || sleepScore >= 90 {
            return "Good recovery night - your SleepOwl pet is fully charged."
        }
        if checkIn?.feeling == .tired || checkIn?.feeling == .exhausted {
            return "Your body might need a slower start today."
        }
        if hours >= 7.5 && hours <= 9 {
            return "Your sleep duration looks solid. Today is good for focused work."
        }
        if stages.isEstimated {
            return "Based on your check-in, SleepOwl filled in tonight's sleep chart."
        }
        return "Looks like a steady night. Keep the rhythm gentle today."
    }

    static func makeRecoveryMessage(
        readinessScore: Int,
        energyLevel: String,
        checkIn: MorningCheckIn?
    ) -> String {
        if readinessScore >= 90 {
            return "looks fully charged this morning."
        }
        if readinessScore >= 75 {
            return "has a bright little charge today."
        }
        if readinessScore >= 60 {
            return "feels steady and ready for a normal day."
        }
        if checkIn?.wakeUps == .aLot {
            return "may need a gentler start after a choppy night."
        }
        return energyLevel == "Recovery Day"
            ? "is in recovery mode, so take the morning softly."
            : "is saving energy after last night."
    }

    private static func seededFraction(date: Date, salt: Int) -> Double {
        let key = date.dayKey
        let sum = key.unicodeScalars.reduce(salt) { $0 + Int($1.value) }
        return Double(abs((sum * 1103515245 + 12345) % 1000)) / 1000
    }

    private static func clamp(_ value: Double, min minValue: Double, max maxValue: Double) -> Double {
        min(max(value, minValue), maxValue)
    }

    private static func clamp(_ value: Int, min minValue: Int, max maxValue: Int) -> Int {
        min(max(value, minValue), maxValue)
    }
}
