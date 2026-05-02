import SwiftUI

struct RoutineBuilderView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []

    private let maxHabits = 4

    var body: some View {
        NavigationStack {
            ZStack {
                MooniGradient.night.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        header
                        ForEach(RoutineHabit.library) { habit in
                            row(for: habit)
                        }
                        PrimaryButton(title: "Save routine", icon: "checkmark") {
                            let chosen = RoutineHabit.library.filter { selected.contains($0.id) }
                            appState.setHabits(chosen)
                            dismiss()
                        }
                        .padding(.top, 12)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Build routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(MooniColor.accent)
                }
            }
            .onAppear {
                selected = Set(appState.routine.habits.map { $0.id })
            }
        }
    }

    private var header: some View {
        MooniCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("Choose 2–4 habits")
                    .font(MooniFont.title(17))
                    .foregroundColor(MooniColor.textPrimary)
                Text("Small, calming things to do before bed.")
                    .font(MooniFont.caption(13))
                    .foregroundColor(MooniColor.textSecondary)
            }
        }
    }

    private func row(for habit: RoutineHabit) -> some View {
        let isSelected = selected.contains(habit.id)
        let canAdd = selected.count < maxHabits || isSelected
        return Button {
            if isSelected {
                selected.remove(habit.id)
            } else if canAdd {
                selected.insert(habit.id)
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: habit.icon)
                    .foregroundColor(isSelected ? MooniColor.background : MooniColor.accent)
                    .frame(width: 30, height: 30)
                    .background(isSelected ? MooniColor.accent : Color.white.opacity(0.08))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.title)
                        .font(MooniFont.title(15))
                        .foregroundColor(MooniColor.textPrimary)
                    Text("\(habit.minutesBeforeBed) min before bed")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? MooniColor.success : MooniColor.textMuted)
            }
            .padding(14)
            .background(isSelected ? Color.white.opacity(0.10) : Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? MooniColor.accent.opacity(0.6) : Color.clear, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(canAdd ? 1.0 : 0.55)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RoutineBuilderView().environmentObject(AppState.preview)
}
