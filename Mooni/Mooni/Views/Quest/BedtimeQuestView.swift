import SwiftUI

/// The Bedtime Quest tab — daily routine + (premium) programs and guided content.
/// Free users see a single nightly quest with up to 4 habits.
/// Premium users unlock multiple routine presets, guided content, and programs.
struct BedtimeQuestView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Binding var showPaywall: Bool

    @State private var showBuilder = false

    var body: some View {
        NavigationStack {
            ZStack {
                MooniGradient.night.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        questCard
                        rewardCard
                        if subscriptionManager.isPro {
                            windDownLibrary
                            programsSection
                        } else {
                            programsTeaser
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Bedtime Quest")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showBuilder = true } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(MooniColor.accent)
                    }
                }
            }
            .sheet(isPresented: $showBuilder) {
                RoutineBuilderView()
            }
        }
    }

    // MARK: - Quest card
    private var questCard: some View {
        MooniCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tonight's quest")
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.accentSoft)
                            .textCase(.uppercase)
                        Text("Help \(appState.pet.name) get cozy")
                            .font(MooniFont.title(18))
                            .foregroundColor(MooniColor.textPrimary)
                    }
                    Spacer()
                    Text("Bed at \(appState.targetBedtime.hourMinuteString)")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                }

                if appState.routine.habits.isEmpty {
                    Text("Pick 2–4 habits to build your nightly quest.")
                        .font(MooniFont.body(14))
                        .foregroundColor(MooniColor.textSecondary)
                    PrimaryButton(title: "Build my quest", icon: "plus") {
                        showBuilder = true
                    }
                } else {
                    ForEach(scheduledItems(), id: \.habit.id) { item in
                        scheduleRow(habit: item.habit, time: item.time)
                    }
                }
            }
        }
    }

    private var rewardCard: some View {
        let total = appState.routine.habits.count
        let done = appState.routine.completedToday.count
        let stars = done * 5
        return MooniCard {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20))
                    .foregroundColor(MooniColor.warning)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(done) of \(total) done")
                        .font(MooniFont.title(15))
                        .foregroundColor(MooniColor.textPrimary)
                    Text("Reward so far: +\(stars) dream stars")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                }
                Spacer()
                Text("\(appState.dreamStars) ✦")
                    .font(MooniFont.title(15))
                    .foregroundColor(MooniColor.accent)
            }
        }
    }

    // MARK: - Premium: wind-down library
    private var windDownLibrary: some View {
        MooniCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Guided wind-downs", systemImage: "wind")
                        .font(MooniFont.title(15))
                        .foregroundColor(MooniColor.textPrimary)
                    Spacer()
                    Text("Pro")
                        .font(MooniFont.caption(11))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(MooniColor.accent)
                        .clipShape(Capsule())
                }
                ForEach(WindDownContent.library) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .foregroundColor(MooniColor.accentSoft)
                            .frame(width: 28)
                        Text(item.title)
                            .font(MooniFont.body(14))
                            .foregroundColor(MooniColor.textPrimary)
                        Spacer()
                        Text("\(item.minutes) min")
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.textMuted)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    // MARK: - Premium: programs
    private var programsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Programs")
                .font(MooniFont.title(17))
                .foregroundColor(MooniColor.textPrimary)
                .padding(.horizontal, 4)
                .padding(.top, 4)
            VStack(spacing: 10) {
                ForEach(SleepProgram.catalog) { p in
                    programRow(p)
                }
            }
        }
    }

    private func programRow(_ p: SleepProgram) -> some View {
        MooniCard(padding: 14) {
            HStack(spacing: 14) {
                Image(systemName: p.icon)
                    .font(.system(size: 20))
                    .foregroundColor(MooniColor.accent)
                    .frame(width: 40, height: 40)
                    .background(MooniColor.accent.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.title)
                        .font(MooniFont.title(15))
                        .foregroundColor(MooniColor.textPrimary)
                    Text(p.subtitle)
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                }
                Spacer()
                Text("\(p.days)d")
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.accentSoft)
            }
        }
    }

    // MARK: - Free teaser for programs
    private var programsTeaser: some View {
        Button { showPaywall = true } label: {
            MooniCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Programs & guided wind-downs", systemImage: "sparkles")
                            .font(MooniFont.title(15))
                            .foregroundColor(MooniColor.accent)
                        Spacer()
                        Image(systemName: "lock.fill")
                            .foregroundColor(MooniColor.textMuted)
                    }
                    Text("7-Day Reset, Earlier Bedtime, Revenge Bedtime Plan, Jet Lag Recovery, sleep stories, breathing, body scans, and more.")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers
    private func scheduledItems() -> [(habit: RoutineHabit, time: Date)] {
        let bed = appState.targetBedtime
        return appState.routine.habits
            .sorted { $0.minutesBeforeBed > $1.minutesBeforeBed }
            .map { habit in
                let t = Calendar.current.date(byAdding: .minute, value: -habit.minutesBeforeBed, to: bed) ?? bed
                return (habit, t)
            }
    }

    private func scheduleRow(habit: RoutineHabit, time: Date) -> some View {
        let done = appState.routine.completedToday.contains(habit.id)
        return Button {
            withAnimation {
                appState.toggleHabitCompletion(habit)
                if !done { appState.addDreamStars(5) }
            }
        } label: {
            HStack(spacing: 12) {
                Text(time.hourMinuteString)
                    .font(MooniFont.mono(13))
                    .foregroundColor(MooniColor.textSecondary)
                    .frame(width: 50, alignment: .leading)
                Image(systemName: habit.icon)
                    .foregroundColor(done ? MooniColor.success : MooniColor.accent)
                    .frame(width: 22)
                Text(habit.title)
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textPrimary)
                    .strikethrough(done)
                Spacer()
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(done ? MooniColor.success : MooniColor.textMuted)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(done ? Color.white.opacity(0.10) : Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    BedtimeQuestView(showPaywall: .constant(false))
        .environmentObject(AppState.preview)
        .environmentObject(SubscriptionManager.shared)
}
