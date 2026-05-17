import Foundation
import SwiftUI

/// A personalised, time-stamped forecast for *today*, derived from last
/// night's sleep (duration, REM, deep, readiness) plus the user's sleep
/// debt and target schedule. Everything is grounded in well-established
/// circadian science — sleep inertia, the post-lunch dip, the late-day
/// physical-performance peak, caffeine half-life — scaled by how the user
/// actually slept.
struct SleepForecast {

    struct Moment: Identifiable {
        enum Kind { case inertia, focus, dip, workout, caffeine, windDown, bedtime }
        let id = UUID()
        let kind: Kind
        let icon: String
        let title: String
        /// Pre-formatted clock time (or range) — the thing the eye lands on.
        let time: String
        /// One short "why".
        let detail: String
        let tint: ForecastTint
    }

    /// Semantic colour buckets — resolved to real colours in the view layer
    /// so the model stays UI-free.
    enum ForecastTint { case neutral, good, caution }

    let moments: [Moment]
    /// Energy curve sample points across the day, 0…1, for the chart.
    let energy: [Double]
    /// Tonight's headline target.
    let bedtimeText: String
    let sleepNeedText: String
    let tonightReason: String

    // MARK: - Build

    static func make(
        entry: SleepEntry,
        goalHours: Double,
        targetBedtime: Date,
        targetWakeTime: Date,
        debtHours: Double
    ) -> SleepForecast {
        let cal = Calendar.current
        let wake = entry.wakeTime
        let hours = entry.totalSleepDuration / 3600
        let readiness = entry.readinessScore ?? entry.score
        let remPct: Double = {
            guard let s = entry.stages, s.totalSleep > 0 else { return 0.22 }
            return s.remSleep / s.totalSleep
        }()

        func at(_ minutesAfterWake: Int) -> Date {
            wake.addingTimeInterval(TimeInterval(minutesAfterWake * 60))
        }
        func clock(_ d: Date) -> String { d.hourMinuteString }
        func range(_ a: Date, _ b: Date) -> String { "\(a.hourMinuteString)–\(b.hourMinuteString)" }

        let rough = readiness < 60 || hours < 6.5
        let debtHeavy = debtHours >= 3

        // 1 — Sleep inertia (grogginess) clears.
        let inertiaMin = rough ? 90 : 45
        let inertia = Moment(
            kind: .inertia, icon: "sunrise.fill",
            title: "Grogginess clears",
            time: "by \(clock(at(inertiaMin)))",
            detail: rough
                ? "Short night — go slow, water + daylight first, hold big decisions."
                : "Light and water now make the morning sharp.",
            tint: rough ? .caution : .neutral)

        // 2 — Peak focus window (morning cognitive peak).
        let focusEndMin = rough ? 210 : 300
        let focus = Moment(
            kind: .focus, icon: "brain.head.profile",
            title: "Sharpest focus",
            time: range(at(120), at(focusEndMin)),
            detail: "Best window for your hardest, most demanding work.",
            tint: .good)

        // 3 — Afternoon energy dip (post-lunch circadian trough).
        let dipCenter = at(7 * 60)
        let dipStrong = debtHeavy || hours < 6.5 || remPct < 0.16
        let dip = Moment(
            kind: .dip, icon: "battery.25",
            title: "Energy dip",
            time: "around \(clock(dipCenter))",
            detail: dipStrong
                ? "Will hit harder today (short/low-REM sleep). A 10–20 min walk or nap before \(clock(at(8 * 60))) resets it."
                : "Mild — a short walk or daylight clears it fast.",
            tint: dipStrong ? .caution : .neutral)

        // 4 — Physical performance peak (core-temp peak, late day).
        let wOffset = rough ? 8 * 60 : 9 * 60
        let workout = Moment(
            kind: .workout, icon: "figure.run",
            title: rough ? "Best (lighter) workout" : "Best workout window",
            time: range(at(wOffset), at(wOffset + 150)),
            detail: rough
                ? "Strength/coordination is down on low sleep — keep it easy today."
                : "Strength, power and reaction time peak in this window.",
            tint: .good)

        // 5 — Caffeine cutoff (≈8 h before target bed; ~6 h half-life).
        let caffeineCut = targetBedtime.addingTimeInterval(-8 * 3600)
        let caffeine = Moment(
            kind: .caffeine, icon: "cup.and.saucer.fill",
            title: "Last caffeine",
            time: "by \(clock(caffeineCut))",
            detail: "After this it's still active at bedtime and steals deep sleep.",
            tint: .caution)

        // 6 — Wind-down start.
        let windStart = targetBedtime.addingTimeInterval(-45 * 60)
        let windDown = Moment(
            kind: .windDown, icon: "moon.stars.fill",
            title: "Start winding down",
            time: clock(windStart),
            detail: "Screens down, lights low — this is what makes sleep come fast.",
            tint: .neutral)

        // 7 — Tonight's bedtime target (hit goal + pay back some debt).
        let payback = min(max(debtHours, 0) * 0.5, 1.0)
        let need = min(goalHours + payback, 9.5)
        let onsetBuffer: TimeInterval = 15 * 60
        var bed = targetWakeTime.addingTimeInterval(-(need * 3600) - onsetBuffer)
        // Pin bedtime to the evening before the target wake.
        if bed > targetWakeTime { bed = bed.addingTimeInterval(-86_400) }
        let needM = Int((need * 60).rounded())
        let bedtime = Moment(
            kind: .bedtime, icon: "bed.double.fill",
            title: "Be asleep by",
            time: clock(bed),
            detail: "≈ \(needM / 60)h \(String(format: "%02d", needM % 60))m of sleep — "
                + (debtHeavy ? "clears debt and resets energy." : "keeps you fully recharged."),
            tint: .good)

        let moments = [inertia, focus, dip, workout, caffeine, windDown, bedtime]

        // Energy curve across the day (0…1) — shaped by the night.
        let base = max(0.30, min(1.0, Double(readiness) / 100.0))
        let dipFloor = dipStrong ? 0.32 : 0.46
        let energy: [Double] = [
            0.34,                 // on waking (inertia)
            min(1.0, base + 0.05),// late-morning peak
            base,                 // late morning hold
            dipFloor,             // post-lunch trough
            base * 0.92,          // afternoon recovery (workout-friendly)
            base * 0.7,           // early evening
            0.28                  // pre-sleep
        ]

        let needText = "\(needM / 60)h \(String(format: "%02d", needM % 60))m"
        let reason = debtHeavy
            ? "You're carrying \(SleepInsights.formatDebt(debtHours)) of debt — tonight pays some back."
            : "Hitting this keeps your rhythm steady and tomorrow sharp."

        return SleepForecast(
            moments: moments,
            energy: energy,
            bedtimeText: clock(bed),
            sleepNeedText: needText,
            tonightReason: reason
        )
    }
}
