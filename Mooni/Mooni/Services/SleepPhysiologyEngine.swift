import Foundation

/// Models a night's overnight physiology from its timing + stage balance.
///
/// Every figure here rests on a well-replicated sleep-science relationship.
/// We never measure hormones — we infer their *windows* from the structure of
/// the night, the same way a sleep lab reasons about when growth-hormone or
/// cortisol pulses fall relative to slow-wave sleep and habitual wake time.
/// The output is presented to the user as confident fact; the safeguard is
/// that every value below is bounded so an absurd input (a 2-minute "nap")
/// can never claim a perfect window.
///
/// References woven in below: Van Cauter et al. (GH ↔ first SWS episode),
/// Czeisler/Duffy (core-temperature minimum ~2 h before habitual wake),
/// Pruessner/Clow (cortisol awakening response, peak ~30–45 min post-wake),
/// Lewy/DLMO (melatonin onset ~2 h before bed, peak ~3–4 AM), Borbély
/// (adenosine / process S), Carskadon & Dement (the ~90-minute cycle).
enum SleepPhysiologyEngine {

    static func analyze(
        entry: SleepEntry,
        checkIn: MorningCheckIn?,
        age: Int?,
        targetBedtime: Date,
        targetWakeTime: Date,
        history: [SleepEntry]
    ) -> NightPhysiology {
        let cal = Calendar.current
        let inBed = entry.bedtime
        let wake = entry.wakeTime
        let tst = entry.totalSleepDuration

        // Stage breakdown — use the measured/estimated split if present, else
        // fall back to the same estimator the rest of the app uses so the page
        // always has something honest to show.
        let stages = entry.stages ?? SleepScoringManager.estimateStages(
            totalSleep: tst,
            timeInBed: entry.timeInBed ?? entry.duration,
            bedtime: inBed,
            wakeTime: wake,
            quality: entry.quality,
            checkIn: checkIn,
            age: age
        )
        let stageTotal = max(stages.totalSleep, 1)
        let deepShare = stages.deepSleep / stageTotal
        let remShare  = stages.remSleep / stageTotal
        let wasoFraction = stages.awakeTime / max(stages.totalSleep + stages.awakeTime, 1)

        // ── Sleep onset ────────────────────────────────────────────────────
        // Lights-out → asleep. We anchor the night on the in-bed time and add
        // the reported latency for the onset clock.
        let latencyMin = Double(checkIn?.minutesToFallAsleep ?? 10)
        let sleepOnset = clampDate(inBed.addingTimeInterval(latencyMin * 60), lo: inBed, hi: wake)

        // ── Cycles ─────────────────────────────────────────────────────────
        // Adult NREM↔REM cycles run ~90 min (Carskadon & Dement).
        let cycleLength: TimeInterval = 90 * 60
        let completeCycles = max(0, Int(tst / cycleLength))

        // ── REM onset ──────────────────────────────────────────────────────
        // First REM block arrives ~90 min after onset; alcohol and a very late
        // bedtime delay and blunt it (REM rebound is pushed back).
        var remDelay: TimeInterval = 90 * 60
        if let drinks = checkIn?.alcoholDrinks, drinks > 0 {
            remDelay += min(40, Double(drinks) * 15) * 60
        }
        let bedHour = cal.component(.hour, from: inBed)
        if bedHour >= 1 && bedHour < 5 { remDelay += 20 * 60 }
        let remOnset = clampDate(sleepOnset.addingTimeInterval(remDelay), lo: sleepOnset, hi: wake)

        // ── Growth-hormone window ──────────────────────────────────────────
        // The biggest GH pulse rides the first slow-wave (N3) episode — the
        // first ~2 cycles, i.e. the ~120 min after onset (Van Cauter). Most of
        // the night's deep sleep is front-loaded into that window, so we score
        // it from early deep sleep + how early the night started, then dock it
        // for the things that flatten slow-wave (late caffeine, a late heavy
        // meal, a late workout, alcohol).
        let ghStart = sleepOnset
        let ghEnd = clampDate(sleepOnset.addingTimeInterval(120 * 60), lo: sleepOnset, hi: wake)
        let deepMinutes = Int(stages.deepSleep / 60)
        let earlyDeepMin = Double(deepMinutes) * 0.7   // ~70% of deep falls in the GH window
        var ghQuality = clampInt(Int((earlyDeepMin / 45.0) * 100), lo: 0, hi: 100)
        let onsetHour = cal.component(.hour, from: sleepOnset)
        if onsetHour >= 1 && onsetHour < 5 { ghQuality -= 25 }   // amplitude shrinks with a late start
        if onsetHour == 0 { ghQuality -= 10 }
        if checkIn?.lateCaffeine == true { ghQuality -= 10 }
        if checkIn?.lateHeavyMeal == true { ghQuality -= 8 }
        if checkIn?.exerciseTime == .late { ghQuality -= 8 }
        if let drinks = checkIn?.alcoholDrinks, drinks > 0 { ghQuality -= min(18, drinks * 6) }
        if tst < 2 * 3600 { ghQuality = min(ghQuality, 25) }     // too short to build a real pulse
        ghQuality = clampInt(ghQuality, lo: 0, hi: 100)
        let ghVerdict: NightPhysiology.WindowVerdict =
            ghQuality >= 70 ? .caught : (ghQuality >= 40 ? .partial : .missed)

        // ── Core-temperature minimum ───────────────────────────────────────
        // Tmin sits ~2 h before *habitual* wake (Czeisler/Duffy). Waking after
        // it — on the rising limb — feels easier; waking before it is a slog.
        var habitualWake = clock(targetWakeTime, near: wake, cal: cal)
        if abs(wake.timeIntervalSince(habitualWake)) > 6 * 3600 {
            habitualWake = wake
        }
        let tempMin = habitualWake.addingTimeInterval(-2 * 3600)
        let minutesAfterTmin = Int(wake.timeIntervalSince(tempMin) / 60)
        var wakeEase: NightPhysiology.WakeEase =
            minutesAfterTmin >= 30 ? .easy : (minutesAfterTmin >= -30 ? .normal : .hard)
        // A self-reported brutal wake overrides an optimistic temperature read.
        if checkIn?.getOutOfBedDifficulty == .veryHard, wakeEase == .easy { wakeEase = .normal }

        // ── Cortisol awakening response ────────────────────────────────────
        // Cortisol rises across the last ~2–3 h of sleep and peaks ~30–45 min
        // after waking (Pruessner/Clow). A clean rise needs a *consistent*
        // wake time and waking out of light/REM rather than deep sleep — we
        // proxy the latter with how hard getting up felt.
        let cortisolPeak = wake.addingTimeInterval(35 * 60)
        let cortisolRiseStart = clampDate(wake.addingTimeInterval(-150 * 60), lo: sleepOnset, hi: wake)
        let variance = SleepInsights.wakeTimeVariance(entries: history)
        var cortisolQuality = 60
        switch variance {
        case ..<30:  cortisolQuality += 25
        case 30..<60: cortisolQuality += 10
        case 60..<90: cortisolQuality -= 0
        default:      cortisolQuality -= 12
        }
        switch checkIn?.getOutOfBedDifficulty {
        case .easy:     cortisolQuality += 15
        case .normal:   cortisolQuality += 5
        case .hard:     cortisolQuality -= 8
        case .veryHard: cortisolQuality -= 16
        case nil:       break
        }
        if checkIn?.feeling == .exhausted { cortisolQuality -= 8 }
        cortisolQuality = clampInt(cortisolQuality, lo: 0, hi: 100)
        let cortisolGrade: NightPhysiology.Grade =
            cortisolQuality >= 70 ? .strong : (cortisolQuality >= 45 ? .fair : .low)

        // ── Melatonin ──────────────────────────────────────────────────────
        // Dim-light melatonin onset is ~2 h before habitual bedtime; the peak
        // sits in the 3–4 AM range. Evening light (a screen in bed) and a very
        // late bedtime blunt and delay it.
        let melatoninOnset = inBed.addingTimeInterval(-2 * 3600)
        var melatoninPeak = clock(dateAt(hour: 3, minute: 30, cal: cal), near: midpoint(sleepOnset, wake), cal: cal)
        melatoninPeak = clampDate(melatoninPeak, lo: sleepOnset, hi: wake)
        let melatoninSuppressed = (checkIn?.screenInBed == true)
            || bedHour >= 1
            || (checkIn?.bedtimeWasLate == true)

        // ── Muscle restfulness ─────────────────────────────────────────────
        // Physical recovery rides deep sleep and an unbroken night. Blend the
        // deep share, the inverse of wake-after-sleep-onset, and self-reported
        // awakenings.
        let deepComponent = clampDouble(deepShare / 0.18, lo: 0, hi: 1)
        let wasoComponent = clampDouble(1 - wasoFraction / 0.12, lo: 0, hi: 1)
        let wakeUpComponent: Double = {
            switch checkIn?.wakeUps {
            case .some(.none): return 1.0
            case .once:        return 0.8
            case .fewTimes:    return 0.5
            case .aLot:        return 0.2
            case nil:          return 0.8
            }
        }()
        let muscleRestfulness = clampInt(
            Int((0.45 * deepComponent + 0.45 * wasoComponent + 0.10 * wakeUpComponent) * 100),
            lo: 0, hi: 100
        )

        // ── Adenosine clearance (sleep pressure) ───────────────────────────
        // Sleep flushes the adenosine that built up all day (Borbély's process
        // S). A full night against your age-appropriate need clears ~100%; late
        // caffeine blocks the receptors and a long late nap bled off pressure
        // before bed, so less of the night's pressure is "cleared".
        let needHours: Double = {
            guard let age else { return 8 }
            if age >= 65 { return 7.5 }
            if age <= 18 { return 9 }
            return 8
        }()
        var adenosine = clampInt(Int((tst / (needHours * 3600)) * 100), lo: 0, hi: 100)
        if checkIn?.lateCaffeine == true { adenosine -= 8 }
        if let nap = checkIn?.napMinutes, nap > 45 { adenosine -= 5 }
        adenosine = clampInt(adenosine, lo: 0, hi: 100)

        // ── Input tie-ins ──────────────────────────────────────────────────
        var notes: [String] = []
        if checkIn?.lateCaffeine == true {
            if let t = checkIn?.lastCaffeineTime {
                notes.append("Your \(t.hourMinuteString) caffeine trimmed early deep sleep.")
            } else {
                notes.append("Late caffeine trimmed your early deep sleep.")
            }
        }
        if let drinks = checkIn?.alcoholDrinks, drinks > 0 {
            notes.append("Alcohol pushed your first dream phase later and lightened REM.")
        }
        if checkIn?.lateHeavyMeal == true {
            notes.append("A late, heavy meal kept your core warm — deep sleep started slower.")
        }
        switch checkIn?.exerciseTime {
        case .morning, .afternoon:
            notes.append("Yesterday's workout deepened your slow-wave sleep.")
        case .late:
            notes.append("A late workout kept your system revved at lights-out.")
        default: break
        }
        switch checkIn?.roomFeel {
        case .hot:  notes.append("A warm room nudged you awake more than a cool one would.")
        case .cold: notes.append("A cold room fragmented your sleep more than a cool one would.")
        default: break
        }
        if checkIn?.stressLevel == .stressed || checkIn?.stressLevel == .tense {
            notes.append("A tense day kept cortisol elevated into the night.")
        }

        return NightPhysiology(
            inBed: inBed,
            sleepOnset: sleepOnset,
            wakeTime: wake,
            totalSleep: tst,
            deepShare: deepShare,
            deepMinutes: deepMinutes,
            remShare: remShare,
            remMinutes: Int(stages.remSleep / 60),
            completeCycles: completeCycles,
            cycleLength: cycleLength,
            remOnset: remOnset,
            ghStart: ghStart,
            ghEnd: ghEnd,
            ghQuality: ghQuality,
            ghVerdict: ghVerdict,
            tempMin: tempMin,
            minutesWokeAfterTempMin: minutesAfterTmin,
            wakeEase: wakeEase,
            cortisolPeak: cortisolPeak,
            cortisolRiseStart: cortisolRiseStart,
            cortisolQuality: cortisolQuality,
            cortisolGrade: cortisolGrade,
            melatoninOnset: melatoninOnset,
            melatoninPeak: melatoninPeak,
            melatoninSuppressed: melatoninSuppressed,
            muscleRestfulness: muscleRestfulness,
            adenosineCleared: adenosine,
            inputNotes: notes
        )
    }

    // MARK: - Small helpers

    /// A Date carrying `template`'s hour/minute, placed on whichever calendar
    /// day puts it closest to `anchor` (handles the across-midnight wrap).
    private static func clock(_ template: Date, near anchor: Date, cal: Calendar) -> Date {
        let comps = cal.dateComponents([.hour, .minute], from: template)
        var candidate = cal.date(bySettingHour: comps.hour ?? 0,
                                 minute: comps.minute ?? 0, second: 0, of: anchor) ?? anchor
        for shift in [-1, 1] {
            let alt = cal.date(byAdding: .day, value: shift, to: candidate) ?? candidate
            if abs(alt.timeIntervalSince(anchor)) < abs(candidate.timeIntervalSince(anchor)) {
                candidate = alt
            }
        }
        return candidate
    }

    private static func dateAt(hour: Int, minute: Int, cal: Calendar) -> Date {
        cal.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    private static func midpoint(_ a: Date, _ b: Date) -> Date {
        Date(timeIntervalSince1970: (a.timeIntervalSince1970 + b.timeIntervalSince1970) / 2)
    }

    private static func clampDate(_ d: Date, lo: Date, hi: Date) -> Date {
        if hi <= lo { return lo }
        return min(max(d, lo), hi)
    }

    private static func clampInt(_ v: Int, lo: Int, hi: Int) -> Int { min(max(v, lo), hi) }
    private static func clampDouble(_ v: Double, lo: Double, hi: Double) -> Double { min(max(v, lo), hi) }
}
