import SwiftUI

/// Morning prompt that asks the user how they slept.
struct MorningCheckInView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var step: Step = .greeting
    @State private var bedtime: Date = Date.todayAt(hour: 23, minute: 0).addingTimeInterval(-86400)
    @State private var wakeTime: Date = Date()
    @State private var quality: SleepEntry.Quality = .good
    @State private var mood: SleepEntry.Mood = .okay
    @State private var phoneAway: Bool? = nil
    @State private var savedEntry: SleepEntry?

    enum Step {
        case greeting, phone, times, quality, mood, summary
    }

    var body: some View {
        ZStack {
            MooniGradient.dawn.ignoresSafeArea()
            VStack(spacing: 24) {
                topBar

                Spacer()
                content
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                    .id(step)
                Spacer()

                footer
            }
            .padding(24)
        }
        .interactiveDismissDisabled(step != .summary)
    }

    // MARK: - Steps content
    @ViewBuilder
    private var content: some View {
        switch step {
        case .greeting: greetingView
        case .phone:    phoneView
        case .times:    timesView
        case .quality:  qualityView
        case .mood:     moodView
        case .summary:  summaryView
        }
    }

    private var phoneView: some View {
        VStack(spacing: 16) {
            Text("Did you put your phone away last night?")
                .font(MooniFont.display(24))
                .foregroundColor(MooniColor.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
            Text("If yes, Luna gets a head start on tonight's quest.")
                .font(MooniFont.caption(13))
                .foregroundColor(MooniColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            VStack(spacing: 10) {
                pickerRow(label: "📵  Yes, phone was away", selected: phoneAway == true) {
                    phoneAway = true
                }
                pickerRow(label: "📱  No, I had it nearby", selected: phoneAway == false) {
                    phoneAway = false
                }
            }
        }
    }

    private var greetingView: some View {
        VStack(spacing: 18) {
            DreamSpiritView(pet: appState.pet, size: 150)
            Text("Good morning")
                .font(MooniFont.display(32))
                .foregroundColor(MooniColor.textPrimary)
            Text("How did you sleep?")
                .font(MooniFont.body(17))
                .foregroundColor(MooniColor.textSecondary)
        }
    }

    private var timesView: some View {
        VStack(spacing: 16) {
            Text("When did you sleep?")
                .font(MooniFont.display(24))
                .foregroundColor(MooniColor.textPrimary)
            MooniCard {
                VStack(spacing: 14) {
                    timeRow(title: "Bedtime", icon: "moon.fill",    selection: $bedtime)
                    Divider().background(Color.white.opacity(0.1))
                    timeRow(title: "Woke up", icon: "sun.max.fill", selection: $wakeTime)
                }
            }
        }
    }

    private var qualityView: some View {
        VStack(spacing: 16) {
            Text("How was the sleep?")
                .font(MooniFont.display(24))
                .foregroundColor(MooniColor.textPrimary)
            VStack(spacing: 10) {
                ForEach(SleepEntry.Quality.allCases) { q in
                    pickerRow(label: "\(q.emoji)  \(q.label)", selected: quality == q) {
                        quality = q
                    }
                }
            }
        }
    }

    private var moodView: some View {
        VStack(spacing: 16) {
            Text("How do you feel?")
                .font(MooniFont.display(24))
                .foregroundColor(MooniColor.textPrimary)
            VStack(spacing: 10) {
                ForEach(SleepEntry.Mood.allCases) { m in
                    pickerRow(label: "\(m.emoji)  \(m.label)", selected: mood == m) {
                        mood = m
                    }
                }
            }
        }
    }

    private var summaryView: some View {
        VStack(spacing: 16) {
            DreamSpiritView(pet: appState.pet, size: 150)
            if let entry = savedEntry {
                VStack(spacing: 6) {
                    Text("You slept \(entry.formattedDuration)")
                        .font(MooniFont.display(24))
                        .foregroundColor(MooniColor.textPrimary)
                    Text("\(appState.pet.name) \(appState.pet.mood.message)")
                        .font(MooniFont.body(15))
                        .foregroundColor(MooniColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                MooniCard {
                    HStack(spacing: 14) {
                        SleepScoreRing(score: entry.score, size: 84, lineWidth: 9)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("+\(entry.energyEarned) growth")
                                .font(MooniFont.title(17))
                                .foregroundColor(MooniColor.success)
                            if appState.lastLevelUp != nil {
                                Text("\(appState.pet.name) grew brighter after this night.")
                                    .font(MooniFont.caption(13))
                                    .foregroundColor(MooniColor.accent)
                            } else {
                                Text("\(entry.bedtime.hourMinuteString) → \(entry.wakeTime.hourMinuteString)")
                                    .font(MooniFont.caption(13))
                                    .foregroundColor(MooniColor.textSecondary)
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Helpers
    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                appState.dismissMorningCheckIn()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if step == .summary {
                PrimaryButton(title: "Done", icon: "checkmark") {
                    dismiss()
                }
            } else {
                if step != .greeting {
                    SecondaryButton(title: "Back") {
                        withAnimation { step = previousStep(of: step) }
                    }
                    .frame(maxWidth: 110)
                }
                PrimaryButton(title: step == .greeting ? "Begin" : (step == .mood ? "See result" : "Next")) {
                    if step == .mood {
                        if phoneAway == true {
                            if let habit = RoutineHabit.library.first(where: { $0.id == "no_phone" }),
                               !appState.routine.completedToday.contains(habit.id) {
                                appState.toggleHabitCompletion(habit)
                                appState.awardDreamStarsForQuestStep(habit, amount: 10)
                            }
                        }
                        let entry = appState.logSleep(
                            bedtime: bedtime,
                            wakeTime: wakeTime,
                            quality: quality,
                            mood: mood,
                            notes: "",
                            routineCompleted: appState.routine.isFullyCompleted
                        )
                        savedEntry = entry
                        withAnimation { step = .summary }
                    } else {
                        withAnimation { step = nextStep(of: step) }
                    }
                }
                .disabled(step == .phone && phoneAway == nil)
                .opacity(step == .phone && phoneAway == nil ? 0.55 : 1)
            }
        }
    }

    private func nextStep(of s: Step) -> Step {
        switch s {
        case .greeting: return .phone
        case .phone:    return .times
        case .times:    return .quality
        case .quality:  return .mood
        case .mood:     return .summary
        case .summary:  return .summary
        }
    }

    private func previousStep(of s: Step) -> Step {
        switch s {
        case .greeting: return .greeting
        case .phone:    return .greeting
        case .times:    return .phone
        case .quality:  return .times
        case .mood:     return .quality
        case .summary:  return .mood
        }
    }

    private func timeRow(title: String, icon: String, selection: Binding<Date>) -> some View {
        HStack {
            Image(systemName: icon).foregroundColor(MooniColor.accent).frame(width: 24)
            Text(title)
                .font(MooniFont.title(15))
                .foregroundColor(MooniColor.textPrimary)
            Spacer()
            DatePicker("", selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden().colorScheme(.dark)
        }
    }

    private func pickerRow(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(MooniFont.title(16))
                    .foregroundColor(MooniColor.textPrimary)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(MooniColor.accent)
                }
            }
            .padding(16)
            .background(selected ? Color.white.opacity(0.18) : Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? MooniColor.accent : Color.clear, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MorningCheckInView().environmentObject(AppState.preview)
}
