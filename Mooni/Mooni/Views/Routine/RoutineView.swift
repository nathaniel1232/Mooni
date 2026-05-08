import SwiftUI

struct RoutineView: View {
    @EnvironmentObject var appState: AppState
    @State private var showBuilder = false

    var body: some View {
        NavigationStack {
            ZStack {
                MooniGradient.night.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        scheduleCard
                        progressCard
                        habitsCard
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Routine")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showBuilder = true
                    } label: {
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

    private var scheduleCard: some View {
        MooniCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "moon.stars.fill").foregroundColor(MooniColor.accent)
                    Text("Tonight's wind-down")
                        .font(MooniFont.title(17))
                        .foregroundColor(MooniColor.textPrimary)
                    Spacer()
                    Text("Bed at \(appState.targetBedtime.hourMinuteString)")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                }

                if appState.routine.habits.isEmpty {
                    Text("Pick 2–4 habits to build a calming bedtime routine.")
                        .font(MooniFont.body(14))
                        .foregroundColor(MooniColor.textSecondary)
                    PrimaryButton(title: "Build my routine", icon: "plus") {
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

    private var progressCard: some View {
        MooniCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Today")
                        .font(MooniFont.title(15))
                        .foregroundColor(MooniColor.textPrimary)
                    Spacer()
                    Text("\(appState.routine.completedToday.count) / \(appState.routine.habits.count)")
                        .font(MooniFont.caption(13))
                        .foregroundColor(MooniColor.textSecondary)
                }
                progressBar(value: appState.routine.completion)
                Text("Each completed step supports your sleep rhythm.")
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textMuted)
            }
        }
    }

    private var habitsCard: some View {
        MooniCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Your habits")
                        .font(MooniFont.title(15))
                        .foregroundColor(MooniColor.textPrimary)
                    Spacer()
                    Button("Edit") { showBuilder = true }
                        .foregroundColor(MooniColor.accent)
                        .font(MooniFont.caption(13))
                }

                if appState.routine.habits.isEmpty {
                    Text("No habits yet — tap edit to add some.")
                        .font(MooniFont.caption(13))
                        .foregroundColor(MooniColor.textMuted)
                } else {
                    ForEach(appState.routine.habits) { habit in
                        HStack {
                            Image(systemName: habit.icon).foregroundColor(MooniColor.accent).frame(width: 22)
                            Text(habit.title)
                                .font(MooniFont.body(15))
                                .foregroundColor(MooniColor.textPrimary)
                            Spacer()
                            Text("-\(habit.minutesBeforeBed)m")
                                .font(MooniFont.caption(12))
                                .foregroundColor(MooniColor.textSecondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private func scheduleRow(habit: RoutineHabit, time: Date) -> some View {
        let done = appState.routine.completedToday.contains(habit.id)
        return Button {
            withAnimation { appState.toggleHabitCompletion(habit) }
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

    private func scheduledItems() -> [(habit: RoutineHabit, time: Date)] {
        let bed = appState.targetBedtime
        return appState.routine.habits
            .sorted { $0.minutesBeforeBed > $1.minutesBeforeBed }
            .map { habit in
                let t = Calendar.current.date(byAdding: .minute, value: -habit.minutesBeforeBed, to: bed) ?? bed
                return (habit, t)
            }
    }

    private func progressBar(value: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(colors: [MooniColor.accentSoft, MooniColor.accent], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * CGFloat(value))
                    .animation(.easeOut, value: value)
            }
        }
        .frame(height: 8)
    }
}

#Preview {
    RoutineView().environmentObject(AppState.preview)
}
