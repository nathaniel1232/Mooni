import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Binding var showPaywall: Bool

    @StateObject private var healthKit = HealthKitManager.shared
    @State private var showWindDown = false
    @State private var showStartSleep = false
    @State private var showWhy = false
    @State private var showRecoveryPlan = false

    private enum HomeMode {
        case firstNight
        case evening
        case morning(SleepEntry)
        case recovery(SleepEntry)
    }

    var body: some View {
        ZStack {
            MooniGradient.night.ignoresSafeArea()
            StarsBackground(count: 38)

            ScrollView {
                VStack(spacing: 22) {
                    header
                        .padding(.top, 8)

                    if let event = morningBriefing?.rareEvent {
                        RareEventBanner(event: event)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    heroSection

                    mainCard

                    if let achievement = morningBriefing?.achievement {
                        AchievementChip(achievement: achievement)
                    }

                    stateSupportCards

                    if appState.entries.count >= 7 {
                        weeklyRecapCard
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 96)
            }
        }
        .sheet(isPresented: $showWindDown, onDismiss: {
            // Sheet dismissed without sleeping — release the tint/dim.
            if !appState.isSleeping {
                WindDownDimController.shared.end()
            }
        }) {
            WindDownSheet()
                .onAppear { WindDownDimController.shared.begin() }
        }
        .sheet(isPresented: $showStartSleep) {
            StartSleepSheet()
        }
        .sheet(isPresented: $showWhy) {
            if let entry = appState.lastEntry {
                MorningWhySheet(entry: entry, showPaywall: $showPaywall)
            }
        }
        .sheet(isPresented: $showRecoveryPlan) {
            RecoveryPlanSheet(showPaywall: $showPaywall)
        }
    }

    // MARK: - Main state

    private var mode: HomeMode {
        guard let entry = appState.lastEntry else { return .firstNight }

        let now = Date()
        let isRecentMorningResult = Calendar.current.isDateInToday(entry.wakeTime)
            && Calendar.current.component(.hour, from: now) < 17

        if isRecentMorningResult {
            return entry.score < 60 ? .recovery(entry) : .morning(entry)
        }

        if TimeOfDay.current == .evening || TimeOfDay.current == .night {
            return .evening
        }

        return entry.score < 60 ? .recovery(entry) : .morning(entry)
    }

    /// Generated daily briefing — only available in morning/recovery
    /// modes. All hero copy, cards, achievements, and rare events
    /// flow from this so the home screen feels different every morning.
    private var morningBriefing: HomeIntelligence.Briefing? {
        switch mode {
        case .morning(let entry), .recovery(let entry):
            return HomeIntelligence.briefing(
                for: entry,
                all: appState.entries,
                targetBedtime: appState.targetBedtime,
                targetWakeTime: appState.targetWakeTime,
                goalHours: appState.goalHours,
                petName: appState.pet.name
            )
        default:
            return nil
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text(greeting)
                    .font(MooniFont.caption(14))
                    .foregroundColor(MooniColor.accentSoft)
                Text(title)
                    .font(MooniFont.display(30))
                    .foregroundColor(MooniColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            Button {
                showPaywall = true
            } label: {
                Image(systemName: subscriptionManager.isPro ? "sparkles" : "lock.open.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(MooniColor.background)
                    .frame(width: 38, height: 38)
                    .background(MooniColor.accentSoft)
                    .clipShape(Circle())
            }
            .accessibilityLabel(subscriptionManager.isPro ? "Premium active" : "Open premium")
        }
    }

    private var heroSection: some View {
        VStack(spacing: 12) {
            if let briefing = morningBriefing {
                DailyAuraBadge(aura: briefing.aura, deck: briefing.auraDeck)
            }
            InteractiveLunaHero(
                pet: appState.pet,
                mood: heroMood,
                size: 218
            )
            LunaSpeechBubble(text: lunaSpeech)
                .padding(.horizontal, 12)
        }
    }

    @ViewBuilder
    private var mainCard: some View {
        switch mode {
        case .firstNight:
            firstNightCard
        case .evening:
            eveningCard
        case .morning(let entry):
            morningResultCard(entry)
        case .recovery(let entry):
            recoveryCard(entry)
        }
    }

    private var firstNightCard: some View {
        MooniCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tonight's mission")
                        .font(MooniFont.title(20))
                        .foregroundColor(MooniColor.textPrimary)
                    Text("Help \(appState.pet.name) get cozy before \(appState.targetBedtime.hourMinuteString).")
                        .font(MooniFont.body(14))
                        .foregroundColor(MooniColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    MooniInfoRow(icon: "moon.zzz.fill", title: "Wind-down starts", value: windDownTime.hourMinuteString, color: MooniColor.success)
                    MooniInfoRow(icon: "bed.double.fill", title: "Bedtime target", value: appState.targetBedtime.hourMinuteString)
                    MooniInfoRow(icon: "sunrise.fill", title: "Wake target", value: appState.targetWakeTime.hourMinuteString, color: MooniColor.warning)
                }

                VStack(spacing: 10) {
                    PrimaryButton(title: "Start wind-down", icon: "moon.zzz.fill") {
                        showWindDown = true
                    }

                    if !isHealthConnected {
                        SecondaryButton(title: "Connect Apple Health", icon: "heart.text.square.fill") {
                            connectAppleHealth()
                        }
                    }
                }

                Text("Complete tonight's quest to earn +20 dream stars.")
                    .font(MooniFont.caption(13))
                    .foregroundColor(MooniColor.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var eveningCard: some View {
        MooniCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Tonight's mission")
                            .font(MooniFont.title(20))
                            .foregroundColor(MooniColor.textPrimary)
                        Text("Help \(appState.pet.name) get cozy before sleep.")
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.textSecondary)
                    }
                    Spacer()
                    Text("\(questDone)/3 done")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.accentSoft)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(MooniColor.accent.opacity(0.14))
                        .clipShape(Capsule())
                }

                VStack(spacing: 10) {
                    MooniInfoRow(icon: "checkmark.circle.fill", title: "Quest progress", value: "\(questDone)/3", color: MooniColor.success)
                    MooniInfoRow(icon: "moon.zzz.fill", title: "Wind-down time", value: windDownTime.hourMinuteString, color: MooniColor.success)
                    MooniInfoRow(icon: "moon.fill", title: "Sleep target", value: appState.targetBedtime.hourMinuteString)
                    MooniInfoRow(icon: "sparkles", title: "Reward", value: "+20 dream stars", color: MooniColor.warning)
                }

                MooniProgressBar(value: Double(questDone) / 3.0, height: 9)

                VStack(spacing: 10) {
                    PrimaryButton(title: "Start wind-down", icon: "moon.zzz.fill") {
                        showWindDown = true
                    }
                    SecondaryButton(title: "Going to bed now", icon: "bed.double.fill") {
                        showStartSleep = true
                    }
                }
            }
        }
    }

    private func morningResultCard(_ entry: SleepEntry) -> some View {
        VStack(spacing: 16) {
            if let briefing = morningBriefing {
                MooniCard(padding: 18, cornerRadius: 24) {
                    HStack(alignment: .center, spacing: 16) {
                        SleepScoreRing(score: entry.score, size: 84, lineWidth: 9)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                miniStat(icon: "moon.zzz.fill",
                                         value: entry.formattedDuration,
                                         label: "Slept")
                                miniStat(icon: "bed.double.fill",
                                         value: entry.bedtime.hourMinuteString,
                                         label: "Bed")
                                miniStat(icon: "sunrise.fill",
                                         value: entry.wakeTime.hourMinuteString,
                                         label: "Up")
                            }
                        }
                    }
                }

                MorningCardCarousel(cards: briefing.cards)

                PrimaryButton(title: "See why", icon: "text.magnifyingglass") {
                    showWhy = true
                }
            }
        }
    }

    private func miniStat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(MooniColor.accentSoft)
            Text(value)
                .font(MooniFont.title(14))
                .foregroundColor(MooniColor.textPrimary)
            Text(label)
                .font(MooniFont.caption(10))
                .foregroundColor(MooniColor.textMuted)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func recoveryCard(_ entry: SleepEntry) -> some View {
        VStack(spacing: 16) {
            // Same dopamine layout, but with a recovery footer button.
            morningResultCard(entry)

            MooniCard(padding: 16, cornerRadius: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(MooniColor.danger)
                        Text("Tonight: gentle recovery")
                            .font(MooniFont.title(15))
                            .foregroundColor(MooniColor.textPrimary)
                    }
                    Text("Earlier wind-down at \(recoveryWindDownTime.hourMinuteString) and a 2-minute breathing reset.")
                        .font(MooniFont.body(13))
                        .foregroundColor(MooniColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    SecondaryButton(title: "Open recovery plan", icon: "heart.fill") {
                        showRecoveryPlan = true
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var stateSupportCards: some View {
        switch mode {
        case .firstNight:
            tomorrowPreviewCard
            growthFooter
        case .evening:
            tomorrowSmallCard
            growthFooter
        case .morning, .recovery:
            insightPreview
            growthFooter
        }
    }

    private var tomorrowPreviewCard: some View {
        MooniCard(padding: 18, cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tomorrow morning")
                        .font(MooniFont.title(18))
                        .foregroundColor(MooniColor.textPrimary)
                    Text("\(appState.pet.name) will wake up based on your sleep.")
                        .font(MooniFont.body(14))
                        .foregroundColor(MooniColor.textSecondary)
                }

                HStack(spacing: 8) {
                    outcomeChip(title: "Short sleep", mood: "Tired", color: MooniColor.danger)
                    outcomeChip(title: "On target", mood: "Calm", color: MooniColor.success)
                    outcomeChip(title: "Great rhythm", mood: "Glowing", color: MooniColor.accent)
                }
            }
        }
    }

    private var tomorrowSmallCard: some View {
        MooniCard(padding: 16, cornerRadius: 24) {
            HStack(spacing: 12) {
                Image(systemName: "sunrise.fill")
                    .foregroundColor(MooniColor.warning)
                    .frame(width: 34, height: 34)
                    .background(MooniColor.warning.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                Text("Tomorrow \(appState.pet.name) wakes up with you based on tonight's sleep.")
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
        }
    }

    private func outcomeChip(title: String, mood: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(MooniFont.caption(10))
                .foregroundColor(MooniColor.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(mood)
                .font(MooniFont.title(12))
                .foregroundColor(color)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.11))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var insightPreview: some View {
        if let briefing = morningBriefing {
            MooniCard(padding: 16, cornerRadius: 24) {
                HStack(spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(MooniColor.warning)
                        .frame(width: 34, height: 34)
                        .background(MooniColor.warning.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Why you feel this way")
                            .font(MooniFont.caption(11))
                            .foregroundColor(MooniColor.warning)
                            .textCase(.uppercase)
                            .tracking(0.5)
                        Text(briefing.whyLine)
                            .font(MooniFont.body(14))
                            .foregroundColor(MooniColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }
            }
        } else {
            EmptyView()
        }
    }

    private var growthFooter: some View {
        MooniCard(padding: 16, cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Next: \(appState.pet.name) becomes \(nextStageName)")
                        .font(MooniFont.title(18))
                        .foregroundColor(MooniColor.textPrimary)
                    Text(growthCopy)
                        .font(MooniFont.body(13))
                        .foregroundColor(MooniColor.textSecondary)
                }

                MooniProgressBar(value: appState.growthProgress, height: 9)

                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .foregroundColor(MooniColor.warning)
                    Text("Next unlock: Starry Blanket")
                        .font(MooniFont.caption(13))
                        .foregroundColor(MooniColor.warning)
                    Spacer()
                    Text("\(appState.dreamStars) stars")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textMuted)
                }
            }
        }
    }

    private var weeklyRecapCard: some View {
        MooniCard(padding: 18, cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Weekly recap", systemImage: "calendar.badge.clock")
                        .font(MooniFont.title(16))
                        .foregroundColor(MooniColor.textPrimary)
                    Spacer()
                    Text("\(appState.recentEntries.count)/7 nights")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.accentSoft)
                }

                Text("\(appState.pet.name) is learning your rhythm. Your next goal is one calmer bedtime window this week.")
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

    // MARK: - Copy

    private var title: String {
        if let briefing = morningBriefing {
            return briefing.heroLine
        }
        switch mode {
        case .firstNight:
            return "Tonight is \(appState.pet.name)'s first night"
        case .evening:
            return "\(appState.pet.name) is getting sleepy"
        case .morning, .recovery:
            return "\(appState.pet.name) woke up"
        }
    }

    private var subtitle: String {
        if let briefing = morningBriefing {
            return briefing.heroSubline
        }
        switch mode {
        case .firstNight:
            return "Help \(appState.pet.name) settle in and wake up together tomorrow."
        case .evening:
            return HomeIntelligence.eveningAnticipation(
                bedtimeConsistencyDays: appState.bedtimeConsistencyDays,
                targetBedtime: appState.targetBedtime,
                petName: appState.pet.name
            )
        case .morning, .recovery:
            return ""
        }
    }

    private var heroMood: Pet.Mood {
        switch mode {
        case .firstNight: return .cozy
        case .evening: return .sleepy
        case .morning(let entry): return Pet.Mood.from(score: entry.score)
        case .recovery: return .recovering
        }
    }

    private var heroCaption: String {
        switch mode {
        case .firstNight:
            return "\(appState.pet.name) is settling into the room and waiting for your first calm night together."
        case .evening:
            return "A tiny wind-down now makes bedtime feel softer later."
        case .morning(let entry):
            return entry.score >= 70 ? "That helped me feel rested." : "Rough night. Small steps still count."
        case .recovery:
            return "I just need a gentle night."
        }
    }

    private var lunaSpeech: String {
        if let briefing = morningBriefing {
            return briefing.speech
        }
        switch mode {
        case .firstNight:
            return "Is tonight our first calm night?"
        case .evening:
            return "Can we get cozy soon?"
        case .morning, .recovery:
            return "Let's reset tonight."
        }
    }

    private var growthCopy: String {
        guard let next = appState.nextEvolutionStage else {
            return "\(appState.pet.name) is fully grown"
        }

        let nights = appState.nightsUntilNextEvolution
        if nights == 0 {
            return "\(appState.pet.name) is ready to grow into \(next.label)"
        }
        return "\(nights) calm night\(nights == 1 ? "" : "s") until \(appState.pet.name) becomes \(next.label)"
    }

    private var nextStageName: String {
        appState.nextEvolutionStage?.label ?? "Dream form"
    }

    private var greeting: String {
        switch TimeOfDay.current {
        case .morning: return "Good morning"
        case .day: return "Good afternoon"
        case .evening: return "Good evening"
        case .night: return "Good evening"
        }
    }

    // MARK: - Helpers

    private var windDownTime: Date {
        Calendar.current.date(byAdding: .minute, value: -30, to: appState.targetBedtime) ?? appState.targetBedtime
    }

    private var recoveryWindDownTime: Date {
        Calendar.current.date(byAdding: .minute, value: -45, to: appState.targetBedtime) ?? windDownTime
    }

    private var questDone: Int {
        min(appState.routine.completedToday.intersection(Set(questHabitIDs)).count, 3)
    }

    private var questHabitIDs: [String] {
        ["breathing", "journal", "no_phone"]
    }

    private var isHealthConnected: Bool {
        if case .authorized = healthKit.authState {
            return true
        }
        return false
    }

    private func connectAppleHealth() {
        Task {
            _ = await healthKit.requestAuthorization()
            await appState.importHealthKitSleep()
        }
    }

    private func moodWord(for score: Int) -> String {
        switch score {
        case 85...: return "cozy"
        case 70..<85: return "calm"
        case 60..<70: return "sleepy"
        default: return "tired"
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...: return MooniColor.success
        case 60..<80: return MooniColor.warning
        default: return MooniColor.danger
        }
    }

    private func bedtimeConsistencyLabel(for entry: SleepEntry) -> String {
        consistencyLabel(actual: entry.bedtime, target: appState.targetBedtime)
    }

    private func wakeConsistencyLabel(for entry: SleepEntry) -> String {
        consistencyLabel(actual: entry.wakeTime, target: appState.targetWakeTime)
    }

    private func consistencyLabel(actual: Date, target: Date) -> String {
        let diff = minuteDifference(actual, target)
        if diff <= 30 { return "On rhythm" }
        if diff < 60 { return "\(diff)m off" }
        return "\(diff / 60)h \(diff % 60)m off"
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

    private func insightText(for entry: SleepEntry) -> String {
        if appState.bedtimeConsistencyDays > 0 {
            return "You slept better when bedtime stayed within 30 minutes."
        }
        if entry.score < 60 {
            return "A shorter recovery quest tonight can help \(appState.pet.name) bounce back without pressure."
        }
        return "Keeping bedtime close to \(appState.targetBedtime.hourMinuteString) helps \(appState.pet.name) wake up cozier."
    }
}

private struct WindDownSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var systemTask: WindDownSystemTask?

    private var questHabits: [RoutineHabit] {
        ["breathing", "journal", "no_phone"].compactMap { id in
            RoutineHabit.library.first { $0.id == id }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MooniGradient.night.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        LunaMoodHero(
                            pet: appState.pet,
                            mood: .sleepy,
                            size: 150,
                            caption: "Screen is dimmed. \(appState.pet.name) is settling in with you."
                        )
                        .padding(.top, 8)

                        if let task = systemTask {
                            WindDownSystemTaskCard(task: task)
                        }

                        MooniCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Tonight's Quest")
                                    .font(MooniFont.title(18))
                                    .foregroundColor(MooniColor.textPrimary)

                                ForEach(Array(questHabits.enumerated()), id: \.element.id) { index, habit in
                                    HabitRow(habit: habit, index: index)
                                }
                            }
                        }

                        PrimaryButton(title: "I'm ready for sleep", icon: "moon.fill") {
                            appState.enterSleepMode()
                            dismiss()
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Wind-down")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(MooniColor.accent)
                }
            }
            .onAppear {
                if systemTask == nil, let task = WindDownSystemTaskStore.shared.taskForTonight {
                    systemTask = task
                    WindDownSystemTaskStore.shared.markShown(task)
                }
            }
        }
    }
}

private struct HabitRow: View {
    @EnvironmentObject var appState: AppState
    let habit: RoutineHabit
    let index: Int

    private var isDone: Bool {
        appState.routine.completedToday.contains(habit.id)
    }

    var body: some View {
        Button {
            let wasDone = isDone
            withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) {
                appState.toggleHabitCompletion(habit)
            }
            if !wasDone {
                appState.awardDreamStarsForQuestStep(habit, amount: index == 2 ? 10 : 5)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } else {
                UISelectionFeedbackGenerator().selectionChanged()
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "\(index + 1).circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(isDone ? MooniColor.success : MooniColor.accent)

                VStack(alignment: .leading, spacing: 3) {
                    Text(habit.title)
                        .font(MooniFont.title(15))
                        .foregroundColor(MooniColor.textPrimary)
                    Text(isDone ? lunaMicrocopy(index: index) : stepHint(index: index))
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(14)
            .background(Color.white.opacity(isDone ? 0.11 : 0.055))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func stepHint(index: Int) -> String {
        switch index {
        case 0: return "A few slow breaths soften bedtime."
        case 1: return "Clear one thought before sleep."
        default: return "Phone away — last step before bed."
        }
    }

    private func lunaMicrocopy(index: Int) -> String {
        switch index {
        case 0: return "Almost ready for sleep."
        case 1: return "That helped me feel calmer."
        default: return "I feel cozy now."
        }
    }
}

private struct StartSleepSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var bedtime: Date = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                MooniGradient.night.ignoresSafeArea()
                VStack(spacing: 24) {
                    LunaMoodHero(
                        pet: appState.pet,
                        mood: .sleepy,
                        size: 150,
                        caption: "Sleep well. \(appState.pet.name) is settling in with you."
                    )

                    MooniCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tonight's bedtime")
                                .font(MooniFont.caption(13))
                                .foregroundColor(MooniColor.textSecondary)
                            DatePicker("", selection: $bedtime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .colorScheme(.dark)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 4)

                    PrimaryButton(title: "Good night", icon: "moon.stars.fill") {
                        ActivitySleepEstimator.shared.recordSleepStart(at: normalizedBedtime)
                        appState.enterSleepMode()
                        dismiss()
                    }

                    #if DEBUG
                    SecondaryButton(title: "DEV: Simulate morning now", icon: "forward.end.fill") {
                        appState.simulateCompletedNightEndingNow()
                        dismiss()
                    }
                    #endif

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Going to bed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(MooniColor.accent)
                }
            }
        }
    }

    private var normalizedBedtime: Date {
        let now = Date()
        let calendar = Calendar.current
        let picked = calendar.dateComponents([.hour, .minute], from: bedtime)
        var today = calendar.dateComponents([.year, .month, .day], from: now)
        today.hour = picked.hour
        today.minute = picked.minute

        guard let selectedToday = calendar.date(from: today) else { return now }
        if selectedToday > now.addingTimeInterval(30 * 60) {
            return calendar.date(byAdding: .day, value: -1, to: selectedToday) ?? now
        }
        return min(selectedToday, now)
    }
}

private struct MorningWhySheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let entry: SleepEntry
    @Binding var showPaywall: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                MooniGradient.night.ignoresSafeArea()

                VStack(spacing: 18) {
                    LunaMoodHero(
                        pet: appState.pet,
                        mood: Pet.Mood.from(score: entry.score),
                        size: 150,
                        caption: "Here is the simple version."
                    )

                    MooniCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(explanation)
                                .font(MooniFont.body(16))
                                .foregroundColor(MooniColor.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)

                            MooniInfoRow(icon: "bed.double.fill", title: "Bedtime", value: bedtimeDetail)
                            MooniInfoRow(icon: "sunrise.fill", title: "Wake time", value: wakeDetail, color: MooniColor.warning)
                            MooniInfoRow(icon: "moon.zzz.fill", title: "Wind-down", value: entry.routineCompleted ? "Completed" : "Try tonight", color: MooniColor.success)
                        }
                    }

                    if !appState.entries.isEmpty {
                        MooniPremiumLockCard(
                            icon: "sparkles",
                            title: "Deeper sleep insight",
                            subtitle: "Unlock sleep debt, best sleep window, and recovery prediction.",
                            actionTitle: "See your full pattern"
                        ) {
                            showPaywall = true
                            dismiss()
                        }
                    }

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Why")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(MooniColor.accent)
                }
            }
        }
    }

    private var explanation: String {
        let name = appState.pet.name
        if entry.score >= 80 {
            return "\(name) woke up cozy because your sleep duration and timing were close to your goal."
        }
        if entry.score >= 60 {
            return "\(name) had an okay night. A steadier bedtime tonight should make tomorrow feel softer."
        }
        return "Rough night. A small recovery quest tonight is enough to help \(name) start bouncing back."
    }

    private var bedtimeDetail: String {
        "\(entry.bedtime.hourMinuteString) target \(appState.targetBedtime.hourMinuteString)"
    }

    private var wakeDetail: String {
        "\(entry.wakeTime.hourMinuteString) target \(appState.targetWakeTime.hourMinuteString)"
    }
}

private struct RecoveryPlanSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Binding var showPaywall: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                MooniGradient.night.ignoresSafeArea()

                VStack(spacing: 18) {
                    LunaMoodHero(
                        pet: appState.pet,
                        mood: .recovering,
                        size: 150,
                        caption: "Tonight is a fresh start."
                    )

                    MooniCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Gentle recovery")
                                .font(MooniFont.title(18))
                                .foregroundColor(MooniColor.textPrimary)

                            MooniInfoRow(icon: "iphone.slash", title: "Phone away", value: "10 min earlier")
                            MooniInfoRow(icon: "wind", title: "Breathing", value: "2 minutes", color: MooniColor.success)
                            MooniInfoRow(icon: "moon.fill", title: "Bedtime", value: appState.targetBedtime.hourMinuteString)
                        }
                    }

                    MooniPremiumLockCard(
                        icon: "heart.text.square.fill",
                        title: "Personal recovery plan",
                        subtitle: "Premium adapts recovery nights to sleep debt, schedule, and wake-up patterns."
                    ) {
                        showPaywall = true
                    }

                    PrimaryButton(title: "Start wind-down", icon: "moon.zzz.fill") {
                        dismiss()
                    }

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Recovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(MooniColor.accent)
                }
            }
        }
    }
}

#Preview {
    HomeView(showPaywall: .constant(false))
        .environmentObject(AppState.preview)
        .environmentObject(SubscriptionManager.shared)
}
