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
                StarsBackground(count: 32)
                ScrollView {
                    VStack(spacing: 16) {
                        if let entry = appState.lastEntry {
                            let ctx = SleepStoryContext(appState: appState, entry: entry)
                            MorningHookCard(
                                context: ctx,
                                streakCurrent: StreakManager.shared.current,
                                streakLongest: StreakManager.shared.longest
                            )
                            lastNightCard(entry)
                            SleepBreakdownView(context: ctx, style: .fullReport)
                            DayPlanView(
                                forecast: SleepForecast.make(appState: appState, entry: entry),
                                style: .full
                            )
                            SleepStatsStrip(context: ctx)
                            trendCard

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
        let readiness = entry.readinessScore ?? entry.score
        let energy = entry.energyLevel ?? SleepScoringManager.energyLevel(for: readiness)
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
                VStack(spacing: 10) {
                    MeterRow(
                        title: "Goal progress",
                        value: entry.formattedDuration,
                        progress: durationProgress
                    )
                    MeterRow(
                        title: "Recovery charge",
                        value: "\(readiness)%",
                        progress: Double(readiness) / 100
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(MooniColor.accent)
                Text(label)
                    .font(MooniFont.title(13))
                    .foregroundColor(MooniColor.textPrimary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.09))
                    Capsule()
                        .fill(MooniColor.accent)
                        .frame(width: geo.size.width * CGFloat(progress))
                }
            }
            .frame(height: 8)
        }
    }
}

private struct SleepStackBar: View {
    let stages: SleepStagesEstimate
    let maxHeight: CGFloat

    private var segments: [(duration: TimeInterval, color: Color)] {
        [
            (stages.deepSleep, StagePalette.deep),
            (stages.lightSleep, StagePalette.light),
            (stages.remSleep, StagePalette.rem),
            (stages.awakeTime, StagePalette.awake)
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

private struct MeterRow: View {
    let title: String
    let value: String
    let progress: Double

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
                        .fill(MooniColor.accent)
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

#Preview {
    SleepReportView(showPaywall: .constant(false))
        .environmentObject(AppState.preview)
        .environmentObject(SubscriptionManager.shared)
}
