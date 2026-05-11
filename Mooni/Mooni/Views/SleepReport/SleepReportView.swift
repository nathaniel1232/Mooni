import SwiftUI

/// The Sleep Report tab.
/// Free users see last night, basic score, 7-day trend, simple explanation.
/// Premium users additionally see sleep debt, consistency, best window, habit lift,
/// and recovery prediction.
struct SleepReportView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Binding var showPaywall: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                MooniGradient.night.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        if let entry = appState.lastEntry {
                            lastNightCard(entry)
                            trendCard
                            explanationCard(entry)

                            if subscriptionManager.isPro {
                                premiumInsights
                            } else {
                                premiumTeaser
                            }
                        } else {
                            emptyState
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Sleep Report")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Free sections

    private func lastNightCard(_ entry: SleepEntry) -> some View {
        let stages = stages(for: entry)
        let readiness = entry.readinessScore ?? entry.score
        let energy = entry.energyLevel ?? SleepScoringManager.energyLevel(for: readiness)
        let stageTotal = max(stages.totalSleep + stages.awakeTime, 1)
        let durationProgress = min(1, entry.totalSleepDuration / max(appState.goalHours * 3600, 1))

        return VStack(spacing: 14) {
            MooniCard {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("Last night")
                            .font(MooniFont.title(15))
                            .foregroundColor(MooniColor.textSecondary)
                        Spacer()
                        Text(entry.wakeTime.shortDateString)
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.textMuted)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text(entry.formattedDuration)
                            .font(MooniFont.display(44))
                            .foregroundColor(MooniColor.textPrimary)

                        HStack(spacing: 6) {
                            Image(systemName: "moon.stars.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(MooniColor.accentSoft)
                            Text("\(entry.bedtime.hourMinuteString) → \(entry.wakeTime.hourMinuteString)")
                                .font(MooniFont.body(14))
                                .foregroundColor(MooniColor.textSecondary)
                        }

                        HStack(spacing: 10) {
                            ScoreChip(score: entry.score, title: "Sleep", color: scoreColor(entry.score))
                            ScoreChip(score: readiness, title: "Ready", color: scoreColor(readiness))
                            Spacer(minLength: 0)
                        }

                        EnergyMeter(label: energy, score: readiness)
                    }
                }
            }

            MooniCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Sleep stages")
                        .font(MooniFont.title(15))
                        .foregroundColor(MooniColor.textPrimary)
                    StagesBar(stages: stages)
                    StageLegend()
                    StageProgressGrid(stages: stages, totalSleep: stageTotal)
                }
            }

            MooniCard {
                VStack(spacing: 10) {
                    MeterRow(
                        title: "Goal progress",
                        value: entry.formattedDuration,
                        progress: durationProgress,
                        color: MooniColor.accent
                    )
                    MeterRow(
                        title: "Recovery charge",
                        value: "\(readiness)%",
                        progress: Double(readiness) / 100,
                        color: scoreColor(readiness)
                    )
                }
            }
        }
    }

    private func stages(for entry: SleepEntry) -> SleepStagesEstimate {
        if let stages = entry.stages {
            return stages
        }
        let total = max(entry.totalSleepDuration, appState.goalHours * 3600, 8 * 3600)
        return SleepScoringManager.estimateStages(
            totalSleep: total,
            timeInBed: entry.timeInBed ?? entry.duration,
            bedtime: entry.bedtime,
            wakeTime: entry.wakeTime,
            quality: entry.quality,
            checkIn: appState.checkIn(for: entry),
            age: appState.profile.age
        )
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 85...: return MooniColor.success
        case 70..<85: return MooniColor.accent
        case 50..<70: return MooniColor.warning
        default: return MooniColor.danger
        }
    }

    private var trendCard: some View {
        let recent = appState.recentEntries
        return MooniCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Last 7 nights")
                        .font(MooniFont.title(15))
                        .foregroundColor(MooniColor.textPrimary)
                    Spacer()
                    let avg = recent.isEmpty ? 0 : recent.map(\.hours).reduce(0, +) / Double(recent.count)
                    Text(String(format: "avg %.1fh", avg))
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                }
                trendBars(entries: recent)
            }
        }
    }

    private func trendBars(entries: [SleepEntry]) -> some View {
        let max = max(entries.map(\.hours).max() ?? 8, 9)
        return HStack(alignment: .bottom, spacing: 8) {
            ForEach(entries.reversed()) { e in
                VStack(spacing: 4) {
                    SleepStackBar(stages: stages(for: e), maxHeight: CGFloat(e.hours / max) * 120)
                    Text(e.wakeTime.weekdayShort)
                        .font(MooniFont.caption(10))
                        .foregroundColor(MooniColor.textMuted)
                }
                .frame(maxWidth: .infinity)
            }
            if entries.count < 7 {
                ForEach(0..<(7 - entries.count), id: \.self) { _ in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 18)
                        Text("0h")
                            .font(MooniFont.caption(10))
                            .foregroundColor(MooniColor.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: 140)
    }

    private func explanationCard(_ entry: SleepEntry) -> some View {
        let petName = appState.pet.name
        let isLate: Bool = {
            let cal = Calendar.current
            let bedHM = cal.dateComponents([.hour, .minute], from: entry.bedtime)
            let targetHM = cal.dateComponents([.hour, .minute], from: appState.targetBedtime)
            let aMin = (bedHM.hour ?? 0) * 60 + (bedHM.minute ?? 0)
            let bMin = (targetHM.hour ?? 0) * 60 + (targetHM.minute ?? 0)
            let diff = min(abs(aMin - bMin), 1440 - abs(aMin - bMin))
            return diff > 30 && aMin > bMin
        }()
        let summary: String = {
            if let insight = entry.insight {
                return insight
            }
            if entry.score >= 80 {
                return "\(petName) feels great. Keep this rhythm going."
            } else if entry.score >= 65 {
                return "\(petName) feels okay\(isLate ? ", but bedtime was later than your goal." : ".")"
            } else {
                return "\(petName) is recovering. Aim to be in bed earlier tonight."
            }
        }()
        return MooniCard {
            HStack(spacing: 14) {
                Image(systemName: "text.bubble.fill")
                    .foregroundColor(MooniColor.accentSoft)
                    .frame(width: 32, height: 32)
                    .background(MooniColor.accentSoft.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(summary)
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                Spacer()
            }
        }
    }

    // MARK: - Premium sections

    private var premiumInsights: some View {
        VStack(spacing: 14) {
            sleepDebtCard
            consistencyCard
            bestWindowCard
            habitLiftCard
            recoveryCard
        }
    }

    private var sleepDebtCard: some View {
        let debt = SleepInsights.sleepDebt(entries: appState.entries, goalHours: appState.goalHours)
        return premiumCard(icon: "moon.zzz.fill", color: MooniColor.danger,
                           title: "Sleep debt",
                           value: SleepInsights.formatDebt(debt),
                           detail: "\(appState.pet.name)'s energy is lower because of accumulated sleep debt this week.")
    }

    private var consistencyCard: some View {
        let variance = SleepInsights.wakeTimeVariance(entries: appState.entries)
        let h = variance / 60
        let m = variance % 60
        let formatted = h > 0 ? "\(h)h \(m)m" : "\(m)m"
        return premiumCard(icon: "calendar.badge.clock", color: MooniColor.warning,
                           title: "Wake-time variance",
                           value: formatted,
                           detail: "Your wake time varied by \(formatted) this week. Lower is calmer for your body clock.")
    }

    private var bestWindowCard: some View {
        let win = SleepInsights.bestSleepWindow(entries: appState.entries)
        let value: String = {
            guard let w = win else {
                let start = Calendar.current.date(byAdding: .minute, value: -30, to: appState.targetBedtime) ?? appState.targetBedtime
                let end = Calendar.current.date(byAdding: .minute, value: 30, to: appState.targetBedtime) ?? appState.targetBedtime
                return "\(start.hourMinuteString)–\(end.hourMinuteString)"
            }
            return "\(w.start.hourMinuteString)–\(w.end.hourMinuteString)"
        }()
        let detail: String = win == nil
            ? "Starting with your target window until SleepOwl has more nights."
            : "Your best nights happen when you fall asleep in this window."
        return premiumCard(icon: "target", color: MooniColor.accent,
                           title: "Best sleep window",
                           value: value,
                           detail: detail)
    }

    private var habitLiftCard: some View {
        let lift = SleepInsights.windDownLift(entries: appState.entries)
        let value = lift > 0 ? "+\(lift) min" : "0 min"
        let detail = lift > 0
            ? "You sleep \(lift) minutes longer on nights when you complete wind-down."
            : "SleepOwl will update this once routine nights stack up."
        return premiumCard(icon: "checklist", color: MooniColor.success,
                           title: "Wind-down lift",
                           value: value,
                           detail: detail)
    }

    private var recoveryCard: some View {
        let predicted = SleepInsights.recoveryPrediction(
            entries: appState.entries,
            goalHours: appState.goalHours,
            plannedHours: appState.goalHours
        )
        return premiumCard(icon: "heart.fill", color: MooniColor.accentSoft,
                           title: "Recovery prediction",
                           value: "\(predicted)%",
                           detail: "If you sleep your goal tonight, \(appState.pet.name) should recover to \(predicted)% energy tomorrow.")
    }

    private func premiumCard(icon: String, color: Color, title: String,
                             value: String, detail: String) -> some View {
        MooniCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .frame(width: 28, height: 28)
                        .background(color.opacity(0.16))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    Text(title)
                        .font(MooniFont.title(14))
                        .foregroundColor(MooniColor.textPrimary)
                    Spacer()
                    Text(value)
                        .font(MooniFont.title(16))
                        .foregroundColor(color)
                }
                Text(detail)
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textSecondary)
            }
        }
    }

    private var premiumTeaser: some View {
        Button { showPaywall = true } label: {
            MooniCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Pro insights", systemImage: "sparkles")
                            .font(MooniFont.title(15))
                            .foregroundColor(MooniColor.accent)
                        Spacer()
                        Image(systemName: "lock.fill")
                            .foregroundColor(MooniColor.textMuted)
                    }
                    Text("Unlock sleep debt, consistency analysis, your best sleep window, habit correlations, and recovery prediction.")
                        .font(MooniFont.caption(13))
                        .foregroundColor(MooniColor.textSecondary)
                        .multilineTextAlignment(.leading)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        MooniCard {
            VStack(spacing: 10) {
                Image(systemName: "moon.zzz")
                    .font(.system(size: 36))
                    .foregroundColor(MooniColor.accentSoft)
                Text("No sleep yet")
                    .font(MooniFont.title(17))
                    .foregroundColor(MooniColor.textPrimary)
                Text("Once you've slept a night, your report will show up here.")
                    .font(MooniFont.caption(13))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 16)
        }
    }
}

private struct ScoreChip: View {
    let score: Int
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 4)
                    .frame(width: 36, height: 36)
                Circle()
                    .trim(from: 0, to: Double(min(max(score, 0), 100)) / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 36, height: 36)
                Text("\(score)")
                    .font(MooniFont.title(13))
                    .foregroundColor(MooniColor.textPrimary)
            }
            Text(title)
                .font(MooniFont.caption(12))
                .foregroundColor(MooniColor.textSecondary)
                .textCase(.uppercase)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.05))
        .clipShape(Capsule())
    }
}

private struct EnergyMeter: View {
    let label: String
    let score: Int

    private var progress: Double { Double(min(max(score, 0), 100)) / 100 }
    private var color: Color {
        switch score {
        case 85...: return MooniColor.success
        case 70..<85: return MooniColor.accent
        case 50..<70: return MooniColor.warning
        default: return MooniColor.danger
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(color)
                Text(label)
                    .font(MooniFont.title(13))
                    .foregroundColor(MooniColor.textPrimary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.09))
                    Capsule()
                        .fill(LinearGradient(colors: [color.opacity(0.65), color],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(progress))
                }
            }
            .frame(height: 8)
        }
    }
}

private struct StagesBar: View {
    let stages: SleepStagesEstimate

    private var segments: [(name: String, duration: TimeInterval, color: Color)] {
        [
            ("Deep",  stages.deepSleep,  MooniColor.success),
            ("Light", stages.lightSleep, MooniColor.accentSoft),
            ("REM",   stages.remSleep,   MooniColor.accent),
            ("Awake", stages.awakeTime,  MooniColor.warning)
        ].filter { $0.duration > 0 }
    }

    private var total: TimeInterval {
        max(segments.reduce(0) { $0 + $1.duration }, 1)
    }

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 2
            let count = max(segments.count, 1)
            let available = max(geo.size.width - spacing * CGFloat(count - 1), 1)

            HStack(spacing: spacing) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    let frac = CGFloat(segment.duration / total)
                    let width = max(20, available * frac)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(LinearGradient(
                            colors: [segment.color.opacity(0.78), segment.color],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .frame(width: width, height: 44)
                        .overlay(
                            Text(segment.name)
                                .font(MooniFont.caption(10))
                                .foregroundColor(MooniColor.background.opacity(0.88))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .padding(.horizontal, 6)
                                .opacity(frac > 0.12 ? 1 : 0)
                        )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 44)
    }
}

private struct StageLegend: View {
    private let items: [(String, Color)] = [
        ("Deep", MooniColor.success),
        ("Light", MooniColor.accentSoft),
        ("REM", MooniColor.accent),
        ("Awake", MooniColor.warning)
    ]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(items, id: \.0) { title, color in
                HStack(spacing: 5) {
                    Circle()
                        .fill(color)
                        .frame(width: 7, height: 7)
                    Text(title)
                        .font(MooniFont.caption(10))
                        .foregroundColor(MooniColor.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct SleepStackBar: View {
    let stages: SleepStagesEstimate
    let maxHeight: CGFloat

    private var segments: [(duration: TimeInterval, color: Color)] {
        [
            (stages.deepSleep, MooniColor.success),
            (stages.lightSleep, MooniColor.accentSoft),
            (stages.remSleep, MooniColor.accent),
            (stages.awakeTime, MooniColor.warning)
        ].filter { $0.duration > 0 }
    }

    private var total: TimeInterval {
        max(segments.reduce(0) { $0 + $1.duration }, 1)
    }

    var body: some View {
        VStack(spacing: 2) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(segment.color)
                    .frame(height: max(5, maxHeight * CGFloat(segment.duration / total)))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: max(24, maxHeight), alignment: .bottom)
    }
}

private struct StageProgressGrid: View {
    let stages: SleepStagesEstimate
    let totalSleep: TimeInterval

    private var stageItems: [(title: String, duration: TimeInterval, color: Color)] {
        [
            ("REM", stages.remSleep, MooniColor.accent),
            ("Deep", stages.deepSleep, MooniColor.success),
            ("Light", stages.lightSleep, MooniColor.accentSoft),
            ("Awake", stages.awakeTime, MooniColor.warning)
        ]
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(stageItems, id: \.title) { item in
                StageProgressTile(
                    title: item.title,
                    duration: item.duration,
                    progress: item.duration / max(totalSleep, 1),
                    color: item.color
                )
            }
        }
    }
}

private struct StageProgressTile: View {
    let title: String
    let duration: TimeInterval
    let progress: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                MiniProgressCircle(progress: progress, color: color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(MooniFont.title(13))
                        .foregroundColor(MooniColor.textPrimary)
                    Text(duration.stageDurationString)
                        .font(MooniFont.caption(11))
                        .foregroundColor(MooniColor.textSecondary)
                }
                Spacer(minLength: 0)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(min(max(progress, 0), 1)))
                }
            }
            .frame(height: 6)
        }
        .padding(12)
        .background(Color.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct MiniProgressCircle: View {
    let progress: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 5)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 34, height: 34)
    }
}

private struct MeterRow: View {
    let title: String
    let value: String
    let progress: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textSecondary)
                Spacer()
                Text(value)
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textPrimary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(LinearGradient(colors: [color.opacity(0.65), color],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(min(max(progress, 0), 1)))
                }
            }
            .frame(height: 9)
        }
    }
}

// MARK: - Date helpers used here
private extension Date {
    var weekdayShort: String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: self)
    }
    var shortDateString: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: self)
    }
}

private extension TimeInterval {
    var stageDurationString: String {
        let totalMinutes = max(0, Int((self / 60).rounded()))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 { return "\(minutes)m" }
        return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
    }
}

#Preview {
    SleepReportView(showPaywall: .constant(false))
        .environmentObject(AppState.preview)
        .environmentObject(SubscriptionManager.shared)
}
