import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Binding var showPaywall: Bool
    @State private var showWindDown = false
    @State private var showStartSleep = false

    var body: some View {
        ZStack {
            MooniGradient.night.ignoresSafeArea()
            StarsBackground(count: 60)

            ScrollView {
                VStack(spacing: 22) {
                    header
                        .padding(.top, 8)

                    petHero

                    moodCard

                    statsRow

                    bedtimeCard

                    if let banner = rewardBanner {
                        banner
                    }

                    Spacer(minLength: 16)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showWindDown) {
            WindDownSheet()
        }
        .sheet(isPresented: $showStartSleep) {
            StartSleepSheet()
        }
    }

    // MARK: - Sections
    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(MooniFont.caption(14))
                    .foregroundColor(MooniColor.textSecondary)
                Text(appState.pet.name)
                    .font(MooniFont.display(30))
                    .foregroundColor(MooniColor.textPrimary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text("Level \(appState.pet.level)")
                    .font(MooniFont.title(15))
                    .foregroundColor(MooniColor.accent)
                Text("\(appState.pet.dreamEnergy) / \(appState.pet.energyForNextLevel) ✦")
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textSecondary)
                if !subscriptionManager.isPro {
                    Button {
                        showPaywall = true
                    } label: {
                        Label("Pro", systemImage: "sparkles")
                            .font(MooniFont.caption(11))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                LinearGradient(colors: [MooniColor.accentSoft, MooniColor.accent],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var petHero: some View {
        VStack(spacing: 12) {
            DreamSpiritView(pet: appState.pet, size: 180)
                .padding(.vertical, 8)

            Text("\(appState.pet.name) \(appState.pet.mood.message)")
                .font(MooniFont.body(15))
                .foregroundColor(MooniColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
    }

    private var moodCard: some View {
        MooniCard {
            HStack(spacing: 16) {
                if let score = appState.pet.lastSleepScore {
                    SleepScoreRing(score: score, size: 96, lineWidth: 10)
                } else {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 10)
                            .frame(width: 96, height: 96)
                        Image(systemName: "moon.zzz")
                            .font(.system(size: 28))
                            .foregroundColor(MooniColor.accent)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Last night")
                        .font(MooniFont.caption(13))
                        .foregroundColor(MooniColor.textSecondary)

                    if let entry = appState.lastEntry {
                        Text(entry.formattedDuration)
                            .font(MooniFont.title(22))
                            .foregroundColor(MooniColor.textPrimary)
                        Text("\(entry.bedtime.hourMinuteString) → \(entry.wakeTime.hourMinuteString)")
                            .font(MooniFont.caption(13))
                            .foregroundColor(MooniColor.textMuted)
                    } else {
                        Text("No sleep logged")
                            .font(MooniFont.title(18))
                            .foregroundColor(MooniColor.textPrimary)
                        Text("Log a night to begin")
                            .font(MooniFont.caption(13))
                            .foregroundColor(MooniColor.textMuted)
                    }
                }
                Spacer()
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statTile(
                icon: "flame.fill",
                value: "\(appState.bedtimeConsistencyDays)",
                label: "Consistent days",
                color: MooniColor.warning
            )
            statTile(
                icon: "sparkles",
                value: "\(appState.pet.dreamEnergy)",
                label: "Dream energy",
                color: MooniColor.accent
            )
            statTile(
                icon: "checkmark.circle.fill",
                value: "\(appState.routine.completedToday.count)/\(max(appState.routine.habits.count, 1))",
                label: "Routine",
                color: MooniColor.success
            )
        }
    }

    private func statTile(icon: String, value: String, label: String, color: Color) -> some View {
        MooniCard(padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon).foregroundColor(color)
                Text(value)
                    .font(MooniFont.title(20))
                    .foregroundColor(MooniColor.textPrimary)
                Text(label)
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.textSecondary)
            }
        }
    }

    private var bedtimeCard: some View {
        MooniCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "moon.stars.fill")
                        .foregroundColor(MooniColor.accent)
                    Text("Tonight")
                        .font(MooniFont.title(18))
                        .foregroundColor(MooniColor.textPrimary)
                    Spacer()
                }

                HStack(spacing: 24) {
                    timeBlock(title: "Best bedtime", time: appState.recommendedBedtime)
                    Divider().background(Color.white.opacity(0.1)).frame(height: 38)
                    timeBlock(title: "Wake target", time: appState.recommendedWakeTime)
                }

                if !appState.routine.habits.isEmpty {
                    routineSummary
                }

                VStack(spacing: 10) {
                    PrimaryButton(title: "Start wind-down", icon: "leaf.fill") {
                        showWindDown = true
                    }
                    SecondaryButton(title: "Going to bed now", icon: "bed.double.fill") {
                        showStartSleep = true
                    }
                }
            }
        }
    }

    private func timeBlock(title: String, time: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(MooniFont.caption(11))
                .foregroundColor(MooniColor.textSecondary)
            Text(time.hourMinuteString)
                .font(MooniFont.display(28))
                .foregroundColor(MooniColor.textPrimary)
        }
    }

    private var routineSummary: some View {
        let completed = appState.routine.completedToday.count
        let total = appState.routine.habits.count
        return HStack {
            Image(systemName: "checklist")
                .foregroundColor(MooniColor.accentSoft)
            Text("Wind-down: \(completed) of \(total) done")
                .font(MooniFont.caption(13))
                .foregroundColor(MooniColor.textSecondary)
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var rewardBanner: AnyView? {
        guard let earned = appState.lastEarnedEnergy else { return nil }
        let levelUp = appState.lastLevelUp
        return AnyView(
            MooniCard {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 22))
                        .foregroundColor(MooniColor.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("+\(earned) dream energy")
                            .font(MooniFont.title(16))
                            .foregroundColor(MooniColor.textPrimary)
                        if let lvl = levelUp {
                            Text("Level up! \(appState.pet.name) reached level \(lvl)")
                                .font(MooniFont.caption(12))
                                .foregroundColor(MooniColor.success)
                        } else {
                            Text("\(appState.pet.name) is enjoying it")
                                .font(MooniFont.caption(12))
                                .foregroundColor(MooniColor.textSecondary)
                        }
                    }
                    Spacer()
                    Button {
                        withAnimation { appState.clearRewardBanner() }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(MooniColor.textMuted)
                    }
                }
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        )
    }

    private var greeting: String {
        switch TimeOfDay.current {
        case .morning: return "Good morning"
        case .day:     return "Good afternoon"
        case .evening: return "Good evening"
        case .night:   return "Good night"
        }
    }
}

// MARK: - Wind-down sheet (entry into routine)
private struct WindDownSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                MooniGradient.night.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        DreamSpiritView(pet: appState.pet, size: 120)
                            .padding(.top, 8)

                        Text("Tonight's wind-down")
                            .font(MooniFont.display(24))
                            .foregroundColor(MooniColor.textPrimary)

                        if appState.routine.habits.isEmpty {
                            MooniCard {
                                Text("Add a few habits in the Routine tab to begin your wind-down.")
                                    .font(MooniFont.body(15))
                                    .foregroundColor(MooniColor.textSecondary)
                            }
                        } else {
                            ForEach(scheduledItems(), id: \.habit.id) { item in
                                HabitRow(habit: item.habit, time: item.time)
                            }
                        }

                        PrimaryButton(title: "I'm going to sleep", icon: "moon.fill") {
                            dismiss()
                        }
                        .padding(.top, 12)
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
        }
    }

    private func scheduledItems() -> [(habit: RoutineHabit, time: Date)] {
        let bed = appState.targetBedtime
        return appState.routine.habits
            .sorted { $0.minutesBeforeBed > $1.minutesBeforeBed }
            .map { habit in
                let t = Calendar.current.date(byAdding: .minute, value: -habit.minutesBeforeBed, to: bed) ?? bed
                return (habit, t)
            }
    }
}

private struct HabitRow: View {
    @EnvironmentObject var appState: AppState
    let habit: RoutineHabit
    let time: Date

    var body: some View {
        let done = appState.routine.completedToday.contains(habit.id)
        Button {
            withAnimation { appState.toggleHabitCompletion(habit) }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: habit.icon)
                    .foregroundColor(done ? MooniColor.success : MooniColor.accent)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.title)
                        .font(MooniFont.title(15))
                        .foregroundColor(MooniColor.textPrimary)
                        .strikethrough(done)
                    Text(time.hourMinuteString)
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                }
                Spacer()
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(done ? MooniColor.success : MooniColor.textMuted)
                    .font(.system(size: 22))
            }
            .padding(14)
            .background(Color.white.opacity(done ? 0.1 : 0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Start sleep sheet
private struct StartSleepSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var bedtime: Date = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                MooniGradient.night.ignoresSafeArea()
                VStack(spacing: 24) {
                    DreamSpiritView(pet: appState.pet, size: 140)

                    Text("Sleep well, \(appState.pet.name) is settling in.")
                        .font(MooniFont.body(15))
                        .foregroundColor(MooniColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

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

                    PrimaryButton(title: "Confirm", icon: "moon.stars.fill") {
                        // Mark routine touched so the morning prompt shows tomorrow.
                        dismiss()
                    }
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
}

#Preview {
    HomeView().environmentObject(AppState.preview)
}
