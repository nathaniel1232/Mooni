import SwiftUI

/// Sleep explains last night in plain language. It is intentionally quieter than
/// a dashboard: one summary, one trend, one useful explanation.
struct SleepReportView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Binding var showPaywall: Bool

    @StateObject private var healthKit = HealthKitManager.shared
    @State private var showManualLog = false

    var body: some View {
        NavigationStack {
            ZStack {
                MooniGradient.night.ignoresSafeArea()
                StarsBackground(count: 28)

                ScrollView {
                    VStack(spacing: 16) {
                        if let entry = appState.lastEntry {
                            lastNightCard(entry)
                            trendCard
                            if appState.entries.count >= 7 {
                                weeklyRecapCard
                            }
                            explanationCard(entry)
                            premiumSection
                        } else {
                            emptyActivation
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 96)
                }
            }
            .navigationTitle("Sleep")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showManualLog) {
                LogSleepSheet()
            }
        }
    }

    // MARK: - Free sections

    private func lastNightCard(_ entry: SleepEntry) -> some View {
        MooniCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Last night")
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.accentSoft)
                            .textCase(.uppercase)
                        Text("Luna's sleep result")
                            .font(MooniFont.title(20))
                            .foregroundColor(MooniColor.textPrimary)
                    }
                    Spacer()
                    Text(entry.wakeTime.shortDateString)
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textMuted)
                }

                HStack(spacing: 18) {
                    SleepScoreRing(score: entry.score, size: 92, lineWidth: 9)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(entry.formattedDuration)
                            .font(MooniFont.display(30))
                            .foregroundColor(MooniColor.textPrimary)
                        Text(scoreLabel(entry.score))
                            .font(MooniFont.body(14))
                            .foregroundColor(MooniColor.textSecondary)
                    }

                    Spacer()
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    MooniStatPill(icon: "moon.zzz.fill", value: entry.formattedDuration, label: "Duration")
                    MooniStatPill(icon: "bed.double.fill", value: entry.bedtime.hourMinuteString, label: "Bedtime")
                    MooniStatPill(icon: "sunrise.fill", value: entry.wakeTime.hourMinuteString, label: "Wake time", color: MooniColor.warning)
                    MooniStatPill(icon: "gauge.with.dots.needle.67percent", value: "\(entry.score)", label: "Basic score", color: scoreColor(entry.score))
                }
            }
        }
    }

    private var trendCard: some View {
        let recent = appState.recentEntries
        let average = recent.isEmpty ? 0 : recent.map(\.hours).reduce(0, +) / Double(recent.count)

        return MooniCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("7-day rhythm")
                            .font(MooniFont.title(18))
                            .foregroundColor(MooniColor.textPrimary)
                        Text(recent.isEmpty ? "Your first week will fill in softly." : String(format: "Average %.1fh", average))
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.textSecondary)
                    }
                    Spacer()
                }

                trendBars(entries: recent)
            }
        }
    }

    private func trendBars(entries: [SleepEntry]) -> some View {
        let maxHours = max(entries.map(\.hours).max() ?? appState.goalHours, appState.goalHours, 8)

        return HStack(alignment: .bottom, spacing: 8) {
            ForEach(entries.reversed()) { entry in
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [MooniColor.accentSoft, scoreColor(entry.score)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: max(24, CGFloat(entry.hours / maxHours) * 116))

                    Text(entry.wakeTime.weekdayShort)
                        .font(MooniFont.caption(10))
                        .foregroundColor(MooniColor.textMuted)
                }
                .frame(maxWidth: .infinity)
            }

            if entries.count < 7 {
                ForEach(0..<(7 - entries.count), id: \.self) { _ in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 24)
                        Text(" ")
                            .font(MooniFont.caption(10))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: 138)
    }

    private func explanationCard(_ entry: SleepEntry) -> some View {
        MooniCard {
            HStack(spacing: 14) {
                Image(systemName: "text.bubble.fill")
                    .foregroundColor(MooniColor.accentSoft)
                    .frame(width: 40, height: 40)
                    .background(MooniColor.accentSoft.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Why Luna feels this way")
                        .font(MooniFont.title(16))
                        .foregroundColor(MooniColor.textPrimary)
                    Text(explanation(for: entry))
                        .font(MooniFont.body(14))
                        .foregroundColor(MooniColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
        }
    }

    // MARK: - Premium

    @ViewBuilder
    private var premiumSection: some View {
        if subscriptionManager.isPro {
            premiumInsights
        } else {
            lockedInsights
        }
    }

    private var premiumInsights: some View {
        VStack(spacing: 12) {
            advancedCard(
                icon: "moon.zzz.fill",
                title: "Sleep debt",
                value: SleepInsights.formatDebt(appState.currentSleepDebt),
                detail: appState.currentSleepDebt == 0
                    ? "You are not carrying measurable sleep debt this week."
                    : "This is the gap between your goal and recent sleep."
            )

            advancedCard(
                icon: "face.dashed.fill",
                title: "Why you woke tired",
                value: tiredReasonValue,
                detail: tiredReasonDetail
            )

            advancedCard(
                icon: "target",
                title: "Best sleep window",
                value: bestWindowValue,
                detail: "Your strongest nights tend to start in this window."
            )

            advancedCard(
                icon: "calendar.badge.clock",
                title: "Consistency analysis",
                value: "\(appState.bedtimeConsistencyDays) nights",
                detail: "Nights within 30 minutes of your target build Luna's sleep rhythm."
            )

            advancedCard(
                icon: "heart.fill",
                title: "Recovery prediction",
                value: "\(recoveryPrediction)%",
                detail: "Estimated recovery if you sleep your goal tonight."
            )

            advancedCard(
                icon: "chart.line.uptrend.xyaxis",
                title: "Long-term trends",
                value: monthlyAverageText,
                detail: "Your broader rhythm appears here as more nights are tracked."
            )
        }
    }

    private var lockedInsights: some View {
        VStack(spacing: 12) {
            Text("Deeper insights")
                .font(MooniFont.title(18))
                .foregroundColor(MooniColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.top, 4)

            ForEach(lockedInsightCards) { card in
                MooniPremiumLockCard(
                    icon: card.icon,
                    title: card.title,
                    subtitle: card.subtitle,
                    actionTitle: card.actionTitle
                ) {
                    showPaywall = true
                }
            }
        }
    }

    private func advancedCard(icon: String, title: String, value: String, detail: String) -> some View {
        MooniCard(padding: 16, cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .foregroundColor(MooniColor.accent)
                        .frame(width: 32, height: 32)
                        .background(MooniColor.accent.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Text(title)
                        .font(MooniFont.title(15))
                        .foregroundColor(MooniColor.textPrimary)
                    Spacer()
                    Text(value)
                        .font(MooniFont.title(15))
                        .foregroundColor(MooniColor.accentSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                Text(detail)
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Empty

    private var emptyActivation: some View {
        VStack(spacing: 18) {
            LunaMoodHero(
                pet: appState.pet,
                mood: .cozy,
                size: 190,
                caption: "After Luna wakes up, this page will explain your sleep in plain English."
            )

            MooniCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Tonight starts the pattern")
                        .font(MooniFont.title(20))
                        .foregroundColor(MooniColor.textPrimary)
                    Text("After Luna wakes up, this page will explain your sleep in plain English.")
                        .font(MooniFont.body(14))
                        .foregroundColor(MooniColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("What Luna will learn")
                        .font(MooniFont.title(16))
                        .foregroundColor(MooniColor.textPrimary)

                    VStack(spacing: 10) {
                        MooniInfoRow(icon: "bed.double.fill", title: "When you went to bed", value: "Tonight")
                        MooniInfoRow(icon: "moon.zzz.fill", title: "How long you slept", value: "After wake")
                        MooniInfoRow(icon: "target", title: "Close to target", value: appState.targetBedtime.hourMinuteString)
                        MooniInfoRow(icon: "flame.fill", title: "Rhythm forming", value: "Day 1", color: MooniColor.warning)
                    }

                    if isHealthConnected {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(MooniColor.success)
                            Text("Connected to Apple Health")
                                .font(MooniFont.caption(13))
                                .foregroundColor(MooniColor.success)
                            Spacer()
                        }
                        .padding(.vertical, 6)
                    } else {
                        PrimaryButton(title: "Connect Apple Health", icon: "heart.text.square.fill") {
                            connectAppleHealth()
                        }
                    }

                    SecondaryButton(title: "Add sleep manually", icon: "plus") {
                        showManualLog = true
                    }
                }
            }

            tomorrowPreviewCard

            lockedInsights
        }
    }

    private var tomorrowPreviewCard: some View {
        MooniCard(padding: 18, cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Tomorrow you'll see")
                    .font(MooniFont.title(18))
                    .foregroundColor(MooniColor.textPrimary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    MooniStatPill(icon: "heart.fill", value: "Mood", label: "Luna")
                    MooniStatPill(icon: "gauge.with.dots.needle.67percent", value: "Score", label: "Sleep")
                    MooniStatPill(icon: "text.bubble.fill", value: "Reason", label: "Plain English", color: MooniColor.accent)
                    MooniStatPill(icon: "moon.zzz.fill", value: "Tip", label: "Recovery", color: MooniColor.success)
                }
            }
        }
    }

    private var weeklyRecapCard: some View {
        MooniCard(padding: 18, cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("7-night recap", systemImage: "calendar.badge.clock")
                        .font(MooniFont.title(16))
                        .foregroundColor(MooniColor.textPrimary)
                    Spacer()
                    Text("Preview")
                        .font(MooniFont.caption(11))
                        .foregroundColor(MooniColor.background)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(MooniColor.accentSoft)
                        .clipShape(Capsule())
                }

                Text("Luna has enough nights to spot a weekly pattern. Your next goal is one calmer bedtime window.")
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !subscriptionManager.isPro {
                    Button {
                        showPaywall = true
                    } label: {
                        Text("Unlock full weekly recap")
                            .font(MooniFont.caption(13))
                            .foregroundColor(MooniColor.accentSoft)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Derived copy

    private func scoreLabel(_ score: Int) -> String {
        switch score {
        case 85...: return "Luna woke up cozy."
        case 70..<85: return "Luna woke up calm."
        case 60..<70: return "Luna is a little sleepy."
        default: return "Rough night. Let's recover gently."
        }
    }

    private var isHealthConnected: Bool {
        if case .authorized = healthKit.authState { return true }
        return false
    }

    private func connectAppleHealth() {
        Task {
            _ = await healthKit.requestAuthorization()
            await appState.importHealthKitSleep()
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...: return MooniColor.success
        case 60..<80: return MooniColor.warning
        default: return MooniColor.danger
        }
    }

    private func explanation(for entry: SleepEntry) -> String {
        let bedtimeDiff = minuteDifference(entry.bedtime, appState.targetBedtime)
        let wakeDiff = minuteDifference(entry.wakeTime, appState.targetWakeTime)

        if entry.score >= 80 {
            return "Your sleep was close to your goal and your timing stayed steady. That helps Luna keep her rhythm."
        }
        if bedtimeDiff > 30 {
            return "Bedtime was \(formattedMinutes(bedtimeDiff)) away from your target. A gentler wind-down tonight can help."
        }
        if wakeDiff > 45 {
            return "Wake time moved more than usual. Keeping mornings steady helps Luna feel calmer."
        }
        return "Duration was the main thing holding this night back. Tonight, aim for a simple recovery night."
    }

    private var tiredReasonValue: String {
        guard let entry = appState.lastEntry else { return "More data" }
        if entry.hours < appState.goalHours { return "Short sleep" }
        if minuteDifference(entry.bedtime, appState.targetBedtime) > 30 { return "Late bedtime" }
        return "Light rhythm"
    }

    private var tiredReasonDetail: String {
        guard let entry = appState.lastEntry else {
            return "Track a few nights to identify what affects tired mornings."
        }
        if entry.hours < appState.goalHours {
            return "The night was shorter than your goal, which can make Luna wake up slower."
        }
        if minuteDifference(entry.bedtime, appState.targetBedtime) > 30 {
            return "Your bedtime shifted away from target, which can affect morning energy."
        }
        return "No single issue stands out yet. More nights will sharpen this explanation."
    }

    private var bestWindowValue: String {
        guard let window = SleepInsights.bestSleepWindow(entries: appState.entries) else {
            return "Learning"
        }
        return "\(window.start.hourMinuteString)-\(window.end.hourMinuteString)"
    }

    private var recoveryPrediction: Int {
        SleepInsights.recoveryPrediction(
            entries: appState.entries,
            goalHours: appState.goalHours,
            plannedHours: appState.goalHours
        )
    }

    private var monthlyAverageText: String {
        guard let average = monthlyAverage() else { return "Learning" }
        return String(format: "%.1fh", average)
    }

    private func monthlyAverage() -> Double? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recent = appState.entries.filter { $0.wakeTime >= cutoff }
        guard !recent.isEmpty else { return nil }
        return recent.map(\.hours).reduce(0, +) / Double(recent.count)
    }

    private func minuteDifference(_ a: Date, _ b: Date) -> Int {
        let cal = Calendar.current
        let aComps = cal.dateComponents([.hour, .minute], from: a)
        let bComps = cal.dateComponents([.hour, .minute], from: b)
        let aMinutes = (aComps.hour ?? 0) * 60 + (aComps.minute ?? 0)
        let bMinutes = (bComps.hour ?? 0) * 60 + (bComps.minute ?? 0)
        let diff = abs(aMinutes - bMinutes)
        return min(diff, 1440 - diff)
    }

    private func formattedMinutes(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) minutes" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours) hour\(hours == 1 ? "" : "s")" : "\(hours)h \(remainder)m"
    }

    private var lockedInsightCards: [LockedInsightCard] {
        [
            .init(
                icon: "moon.zzz.fill",
                title: "Sleep debt",
                subtitle: "See how much recovery Luna may need this week.",
                actionTitle: "Unlock recovery depth"
            ),
            .init(
                icon: "face.dashed.fill",
                title: "Why you woke up tired",
                subtitle: "Connect timing, duration, and routine patterns.",
                actionTitle: "Find the pattern"
            ),
            .init(
                icon: "target",
                title: "Best sleep window",
                subtitle: "Discover when your strongest nights usually begin.",
                actionTitle: "Reveal your window"
            ),
            .init(
                icon: "calendar.badge.clock",
                title: "Consistency analysis",
                subtitle: "Understand what protects Luna's rhythm.",
                actionTitle: "Analyze rhythm"
            ),
            .init(
                icon: "heart.fill",
                title: "Recovery prediction",
                subtitle: "Preview how tonight could help after a rough night.",
                actionTitle: "Plan recovery"
            ),
            .init(
                icon: "chart.line.uptrend.xyaxis",
                title: "Long-term trends",
                subtitle: "Watch sleep improve across weeks and seasons.",
                actionTitle: "See the bigger picture"
            )
        ]
    }
}

private struct LockedInsightCard: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let actionTitle: String
}

private extension Date {
    var weekdayShort: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: self)
    }

    var shortDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: self)
    }
}

#Preview {
    SleepReportView(showPaywall: .constant(false))
        .environmentObject(AppState.preview)
        .environmentObject(SubscriptionManager.shared)
}
