import Foundation

/// Sleep scoring engine.
///
/// The score is a 0–100 number meant to *feel* like the consumer sleep apps
/// people already trust (Oura, Whoop, Apple Watch, Sleep Cycle). It is built
/// from five clinical components used in adult sleep research:
///
///   1. Duration              — Total Sleep Time vs. the user's goal.
///                              AASM/NSF guidance: 7–9h is optimal for adults.
///   2. Efficiency            — TST / Time-in-bed. ≥85% is the standard
///                              benchmark of healthy sleep efficiency.
///   3. Restfulness           — WASO (wake-after-sleep-onset) and self-
///                              reported awakenings. Clinical target: <30 min.
///   4. Stage balance         — Deep 13–23% of TST, REM 20–25% of TST
///                              (Walker, Carskadon).
///   5. Timing & consistency  — Adherence to the user's target bedtime, plus
///                              a consistency streak bonus.
///
/// A *hard floor* prevents nonsense scores when the user logs a sub-hour
/// "nap" (e.g. testing the app for two minutes): under 1 hour the score is
/// capped to 0–5, and tighter ceilings apply up to 6 hours.
enum SleepScoringManager {
    static func update(
        entry: inout SleepEntry,
        goalHours: Double,
        targetBedtime: Date? = nil,
        consistencyDays: Int,
        checkIn: MorningCheckIn?,
        age: Int? = nil
    ) {
        let summary = summarize(
            entry: entry,
            goalHours: goalHours,
            targetBedtime: targetBedtime,
            consistencyDays: consistencyDays,
            checkIn: checkIn,
            age: age
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
        targetBedtime: Date? = nil,
        consistencyDays: Int,
        checkIn: MorningCheckIn?,
        age: Int? = nil
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
                bedtime: entry.bedtime,
                wakeTime: entry.wakeTime,
                quality: entry.quality,
                checkIn: checkIn,
                age: age
            )
        }

        let sleepScore = scoreSleep(
            totalSleep: totalSleep,
            timeInBed: timeInBed,
            stages: stages,
            bedtime: entry.bedtime,
            targetBedtime: targetBedtime,
            goalHours: goalHours,
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

    /// Estimates sleep stages from the data we *do* have when no HealthKit
    /// stage breakdown is available. Built from published adult averages:
    ///   • Deep (N3):   ~18% of TST, declining ~2% per decade after 30
    ///                  (Ohayon et al., Sleep 2004; Carskadon & Dement 2005).
    ///   • REM:         ~22% of TST in adults; weighted toward late sleep
    ///                  cycles, so short early-cut sleeps lose REM faster
    ///                  than they lose deep (Walker, Why We Sleep).
    ///   • Wake/WASO:   ~3–8% of TIB in healthy adults, rising with age and
    ///                  with self-reported awakenings.
    /// Subjective check-in answers (feeling, dreams, wake-ups) shift the
    /// estimate within research-supported bounds rather than fabricating
    /// stage data.
    static func estimateStages(
        totalSleep: TimeInterval,
        timeInBed: TimeInterval?,
        bedtime: Date,
        wakeTime: Date,
        quality: SleepEntry.Quality,
        checkIn: MorningCheckIn?,
        age: Int? = nil
    ) -> SleepStagesEstimate {
        guard totalSleep > 0 else {
            return SleepStagesEstimate(deepSleep: 0, remSleep: 0, lightSleep: 0, awakeTime: 0, isEstimated: true)
        }

        // Age-adjusted baseline: deep N3 sleep declines roughly 2 percentage
        // points per decade after 30 (Ohayon meta-analysis). REM is more
        // stable; WASO rises slightly with age.
        let ageYears = Double(age ?? 30)
        let ageOver30 = max(0, ageYears - 30)
        let deepBaseline = max(0.10, 0.20 - (ageOver30 / 10) * 0.02)
        let remBaseline  = 0.22
        let awakeBaseline = min(0.10, 0.03 + (ageOver30 / 10) * 0.006)

        // Tiny per-day jitter (±1pp) — keeps a hint of natural variation
        // without inventing precision we don't have.
        var deepPct  = deepBaseline + (seededFraction(date: wakeTime, salt: 13) - 0.5) * 0.02
        var remPct   = remBaseline  + (seededFraction(date: wakeTime, salt: 29) - 0.5) * 0.02
        var awakePct = awakeBaseline + seededFraction(date: wakeTime, salt: 41) * 0.03

        // REM is concentrated in the final third of the night. If the user
        // cut sleep short relative to typical 7–9h adult sleep, knock down
        // REM proportionally; deep is concentrated early and barely moves.
        let hours = totalSleep / 3600
        if hours < 6 {
            let remPenalty = (6 - hours) / 6 * 0.06  // up to 6pp at very short sleep
            remPct = max(0.08, remPct - remPenalty)
        }
        // Late bedtime (after 1 AM) is associated with REM compression on the
        // first cycles — REM appears, but slightly reduced.
        let bedHour = Calendar.current.component(.hour, from: bedtime)
        if bedHour >= 1 && bedHour < 5 {
            remPct = max(0.10, remPct - 0.015)
        }

        // Subjective signal — bounded so the estimate stays plausible.
        if checkIn?.feeling == .great    { deepPct += 0.015 }
        if checkIn?.feeling == .tired    { deepPct -= 0.01 }
        if checkIn?.feeling == .exhausted { deepPct -= 0.02 }
        if quality == .poor              { deepPct -= 0.015 }
        if checkIn?.dreams == .yes       { remPct += 0.02 }
        if checkIn?.dreams == .notSure   { remPct += 0.005 }

        switch checkIn?.wakeUps {
        case .fewTimes: awakePct += 0.02
        case .aLot:     awakePct += 0.04
        default:        break
        }

        // Very short "sleeps" don't have time to cycle — pull deep/REM toward
        // zero so a 2-minute nap doesn't claim 30 seconds of REM.
        if hours < 3 {
            let scale = max(0, hours / 3.0)
            deepPct *= scale
            remPct  *= scale
        }

        // Clinical bounds (Ohayon norms): adults rarely sit outside these.
        deepPct  = clamp(deepPct,  min: 0.0,  max: 0.27)
        remPct   = clamp(remPct,   min: 0.0,  max: 0.29)
        awakePct = clamp(awakePct, min: 0.02, max: 0.12)

        let deep  = totalSleep * deepPct
        let rem   = totalSleep * remPct
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

    // MARK: - Sleep score (clinical components)

    /// Compute a 0–100 sleep score from the components below.
    /// Component weights (out of 100):
    ///   • Duration:         40
    ///   • Efficiency:       15
    ///   • Restfulness:      15
    ///   • Stage balance:    15
    ///   • Timing/consistency: 15
    static func scoreSleep(
        totalSleep: TimeInterval,
        timeInBed: TimeInterval?,
        stages: SleepStagesEstimate,
        bedtime: Date,
        targetBedtime: Date?,
        goalHours: Double,
        consistencyDays: Int,
        checkIn: MorningCheckIn?
    ) -> Int {
        let hours = totalSleep / 3600

        // Hard floor: clinically a "sleep" under 1 hour is a nap, not a night.
        // Don't ever score it like rested sleep — this is what the user hit
        // when they tested with a 2-minute window and got 63.
        if hours < 1.0 {
            return clamp(Int((hours * 6).rounded()), min: 0, max: 6)
        }

        let durationPts = durationPoints(actualHours: hours, goalHours: goalHours)
        let efficiencyPts = efficiencyPoints(totalSleep: totalSleep, timeInBed: timeInBed)
        let restfulnessPts = restfulnessPoints(
            stages: stages,
            totalSleep: totalSleep,
            checkIn: checkIn
        )
        let stagePts = stageBalancePoints(stages: stages, totalSleep: totalSleep)
        let timingPts = timingPoints(
            bedtime: bedtime,
            target: targetBedtime,
            consistencyDays: consistencyDays
        )

        var score = Double(durationPts + efficiencyPts + restfulnessPts + stagePts + timingPts)

        // Subjective check-in nudge (small — the objective signals already
        // reflect most of this). Stays bounded so a happy mood can't rescue
        // a 3-hour night.
        switch checkIn?.feeling {
        case .great:     score += 3
        case .okay:      score += 0
        case .tired:     score -= 4
        case .exhausted: score -= 8
        case nil:        break
        }
        switch checkIn?.getOutOfBedDifficulty {
        case .easy:      score += 2
        case .normal:    break
        case .hard:      score -= 3
        case .veryHard:  score -= 6
        case nil:        break
        }

        // Duration ceilings — short sleep should look short.
        // CDC: <7h = insufficient; <6h = associated with notable risk.
        if hours < 3 { score = min(score, 28) }
        else if hours < 4 { score = min(score, 42) }
        else if hours < 5 { score = min(score, 55) }
        else if hours < 6 { score = min(score, 68) }

        // Excessively long sleep also isn't "great" — mild cap.
        if hours > 11 { score = min(score, 78) }

        return clamp(Int(score.rounded()), min: 0, max: 100)
    }

    /// Duration vs. user's personal goal. 40 pts max.
    /// Generous around the optimal 7–9h adult band: full credit within ±45 min
    /// of goal *and* any night that lands inside 7–9h still gets near-full credit
    /// even if the personal goal is higher.
    private static func durationPoints(actualHours: Double, goalHours: Double) -> Int {
        let safeGoal = max(4.0, min(10.0, goalHours))
        let deviation = abs(actualHours - safeGoal)
        let inOptimalBand = actualHours >= 7.0 && actualHours <= 9.0

        // Optimal-band floor: 7–9h is healthy adult sleep (AASM/NSF) — never
        // score it as worse than 36/40, regardless of personal goal.
        if inOptimalBand && deviation >= 0.75 {
            return 36
        }

        switch deviation {
        case ..<0.75: return 40    // within ±45 min of goal = full credit
        case ..<1.25: return 34
        case ..<1.75: return 28
        case ..<2.25: return 22
        case ..<2.75: return 16
        case ..<3.25: return 10
        case ..<4.0:  return 6
        default:      return 0
        }
    }

    /// Sleep efficiency = TST / TIB. 15 pts max.
    /// Clinical benchmark: ≥85% healthy, ≥90% excellent.
    private static func efficiencyPoints(totalSleep: TimeInterval, timeInBed: TimeInterval?) -> Int {
        guard let tib = timeInBed, tib > 0 else {
            // No TIB known (HealthKit sometimes returns this). Stay slightly
            // generous — assuming healthy efficiency by default keeps the
            // score from being unfairly dragged down on user-logged nights.
            return 14
        }
        let efficiency = min(1.0, totalSleep / tib)
        switch efficiency {
        case 0.92...:    return 15
        case 0.85..<0.92: return 13
        case 0.78..<0.85: return 10
        case 0.70..<0.78: return 7
        case 0.60..<0.70: return 4
        default:          return 1
        }
    }

    /// Awakenings + WASO. 15 pts max.
    /// Clinical target WASO <30 min; >60 min is fragmented sleep.
    private static func restfulnessPoints(
        stages: SleepStagesEstimate,
        totalSleep: TimeInterval,
        checkIn: MorningCheckIn?
    ) -> Int {
        var pts = 15
        let wasoMinutes = stages.awakeTime / 60
        switch wasoMinutes {
        case ..<15:    break
        case 15..<30:  pts -= 2
        case 30..<60:  pts -= 5
        case 60..<90:  pts -= 8
        default:       pts -= 11
        }

        switch checkIn?.wakeUps {
        case .some(.none): break
        case .once:        pts -= 1
        case .fewTimes:    pts -= 4
        case .aLot:        pts -= 7
        case nil:          break
        }

        return clamp(pts, min: 0, max: 15)
    }

    /// Deep + REM proportions. 15 pts max (8 deep + 7 REM).
    /// Healthy adult ranges (Carskadon, Walker): Deep 13–23%, REM 20–25%.
    private static func stageBalancePoints(stages: SleepStagesEstimate, totalSleep: TimeInterval) -> Int {
        guard totalSleep > 0 else { return 0 }
        let deepRatio = stages.deepSleep / totalSleep
        let remRatio = stages.remSleep / totalSleep

        let deepScore: Int
        switch deepRatio {
        case 0.13...0.23:                    deepScore = 8
        case 0.10..<0.13, 0.23..<0.27:       deepScore = 5
        case 0.07..<0.10, 0.27..<0.32:       deepScore = 3
        default:                             deepScore = 1
        }

        let remScore: Int
        switch remRatio {
        case 0.20...0.25:                    remScore = 7
        case 0.16..<0.20, 0.25..<0.30:       remScore = 4
        case 0.12..<0.16, 0.30..<0.35:       remScore = 2
        default:                             remScore = 0
        }

        return deepScore + remScore
    }

    /// Bedtime adherence + consistency streak bonus. 15 pts max.
    private static func timingPoints(bedtime: Date, target: Date?, consistencyDays: Int) -> Int {
        var pts: Int
        if let target {
            let diffMin = minutesBetweenTimeOfDay(bedtime, target)
            switch diffMin {
            case ..<15:    pts = 10
            case 15..<30:  pts = 8
            case 30..<60:  pts = 5
            case 60..<90:  pts = 3
            default:       pts = 1
            }
        } else {
            // No target known — give middle credit so missing setting doesn't punish.
            pts = 7
        }

        if consistencyDays >= 7 { pts += 5 }
        else if consistencyDays >= 3 { pts += 3 }
        else if consistencyDays >= 1 { pts += 1 }

        return clamp(pts, min: 0, max: 15)
    }

    private static func minutesBetweenTimeOfDay(_ a: Date, _ b: Date) -> Int {
        let cal = Calendar.current
        let ca = cal.dateComponents([.hour, .minute], from: a)
        let cb = cal.dateComponents([.hour, .minute], from: b)
        let aMin = (ca.hour ?? 0) * 60 + (ca.minute ?? 0)
        let bMin = (cb.hour ?? 0) * 60 + (cb.minute ?? 0)
        let raw = abs(aMin - bMin)
        return min(raw, 1440 - raw)
    }

    static func scoreReadiness(
        sleepScore: Int,
        totalSleep: TimeInterval,
        checkIn: MorningCheckIn?
    ) -> Int {
        let hours = totalSleep / 3600
        var readiness = Double(sleepScore)

        switch checkIn?.feeling {
        case .great:     readiness += 8
        case .okay:      readiness += 2
        case .tired:     readiness -= 8
        case .exhausted: readiness -= 18
        case nil:        break
        }

        if checkIn?.wakeUps == .fewTimes || checkIn?.wakeUps == .aLot {
            readiness -= 8
        }
        if hours < 6 { readiness -= 8 }
        if hours >= 7.5 && hours <= 9 { readiness += 4 }

        // Same hard ceilings as sleep score — readiness can never be high
        // when the body simply didn't sleep enough.
        if hours < 3 { readiness = min(readiness, 25) }
        else if hours < 4 { readiness = min(readiness, 38) }
        else if hours < 5 { readiness = min(readiness, 52) }
        else if hours < 6 { readiness = min(readiness, 65) }

        return clamp(Int(readiness.rounded()), min: 0, max: 100)
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

    /// Insight is the single line we show on the home card. Order matters:
    /// catastrophic / actionable findings beat generic copy. When stages are
    /// estimated rather than measured, the closing sentence flags that.
    static func makeInsight(
        totalSleep: TimeInterval,
        sleepScore: Int,
        readinessScore: Int,
        stages: SleepStagesEstimate,
        checkIn: MorningCheckIn?
    ) -> String {
        let hours = totalSleep / 3600
        let deepPct = totalSleep > 0 ? stages.deepSleep / totalSleep : 0
        let remPct  = totalSleep > 0 ? stages.remSleep  / totalSleep : 0
        let estimatedNote = stages.isEstimated
            ? " Stage breakdown estimated from your schedule and check-in."
            : ""

        if hours < 1 {
            return "That's not really a full night yet — log again after a real sleep."
        }
        if hours < 4 {
            let shortBy = String(format: "%.1f", 7.5 - hours)
            return "Very short night — \(shortBy) h below the adult 7–9 h range. Today will feel heavy; keep things easy.\(estimatedNote)"
        }
        if hours < 5.5 {
            return "Short night (under 6 h). The CDC links chronic <6 h sleep with higher cardiovascular risk — try a 30-min earlier bedtime tonight.\(estimatedNote)"
        }
        // High signal: low deep N3
        if deepPct > 0 && deepPct < 0.10 {
            return "Deep sleep ran short (~\(Int(deepPct * 100))% of total). Aim for an earlier, cooler room tonight — deep N3 is biggest in the first 2 cycles.\(estimatedNote)"
        }
        // High signal: low REM (early wake or alcohol/late bedtime)
        if remPct > 0 && remPct < 0.15 {
            return "REM looked light (~\(Int(remPct * 100))%). REM concentrates in the last third — pushing wake 20–30 min later usually adds a full REM cycle.\(estimatedNote)"
        }
        if checkIn?.wakeUps == .aLot {
            return "You reported many wake-ups — fragmented sleep blunts deep N3 even when total hours look fine.\(estimatedNote)"
        }
        if checkIn?.wakeUps == .fewTimes {
            return "A couple of wake-ups nicked recovery, but the foundation is solid.\(estimatedNote)"
        }
        if readinessScore >= 90 || sleepScore >= 90 {
            return "Strong recovery — duration, efficiency and stage balance all hit healthy ranges."
        }
        if checkIn?.feeling == .tired || checkIn?.feeling == .exhausted {
            return "Hours look OK but your check-in flagged fatigue — your body might need a slower start today."
        }
        if hours >= 7.5 && hours <= 9 {
            return "Duration sits in the optimal 7–9 h band. Deep \(Int(deepPct*100))% · REM \(Int(remPct*100))% — solid mix.\(estimatedNote)"
        }
        if hours > 9.5 {
            return "Longer than usual — occasionally fine, but chronic >9 h can leave you groggy. See how today feels."
        }
        return "Steady night. Keep the rhythm gentle today.\(estimatedNote)"
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
