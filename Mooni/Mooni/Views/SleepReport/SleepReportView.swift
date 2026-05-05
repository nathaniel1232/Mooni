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
        MooniCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Last night")
                        .font(MooniFont.title(15))
                        .foregroundColor(MooniColor.textSecondary)
                    Spacer()
                    Text(entry.wakeTime.shortDateString)
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textMuted)
                }
                HStack(spacing: 18) {
                    SleepScoreRing(score: entry.score, size: 88, lineWidth: 9)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.formattedDuration)
                            .font(MooniFont.display(28))
                            .foregroundColor(MooniColor.textPrimary)
                        Text("\(entry.bedtime.hourMinuteString) → \(entry.wakeTime.hourMinuteString)")
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.textSecondary)
                        Text("Score \(entry.score) · \(entry.quality.label)")
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.textMuted)
                    }
                    Spacer()
                }
            }
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
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [MooniColor.accentSoft, MooniColor.accent],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(height: CGFloat(e.hours / max) * 120)
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
                            .frame(height: 24)
                        Text("—")
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
            guard let w = win else { return "—" }
            return "\(w.start.hourMinuteString)–\(w.end.hourMinuteString)"
        }()
        let detail: String = win == nil
            ? "Log a few more nights to find your best sleep window."
            : "Your best nights happen when you fall asleep in this window."
        return premiumCard(icon: "target", color: MooniColor.accent,
                           title: "Best sleep window",
                           value: value,
                           detail: detail)
    }

    private var habitLiftCard: some View {
        let lift = SleepInsights.windDownLift(entries: appState.entries)
        let value = lift > 0 ? "+\(lift) min" : "—"
        let detail = lift > 0
            ? "You sleep \(lift) minutes longer on nights when you complete wind-down."
            : "Complete a few wind-downs to see how much they help."
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
