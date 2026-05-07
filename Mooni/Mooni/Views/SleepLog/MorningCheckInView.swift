import SwiftUI

/// Morning prompt that asks the user how they woke up, then tunes the
/// duration-based sleep estimate into friendlier scores.
struct MorningCheckInView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var step: Step = .greeting
    @State private var feeling: MorningFeeling = .okay
    @State private var wakeUps: WakeUpFrequency = .none
    @State private var dreams: DreamRecall = .notSure
    @State private var bedDifficulty: BedDifficulty = .normal
    @State private var caffeine: CaffeineChoice = .notSure
    @State private var savedEntry: SleepEntry?

    enum Step {
        case greeting, feeling, wakeUps, dreams, bedDifficulty, caffeine, summary
    }

    private enum CaffeineChoice: String, CaseIterable, Identifiable {
        case no, yes, notSure

        var id: String { rawValue }

        var label: String {
            switch self {
            case .no: return "No"
            case .yes: return "Yes"
            case .notSure: return "Not sure"
            }
        }

        var value: Bool? {
            switch self {
            case .no: return false
            case .yes: return true
            case .notSure: return nil
            }
        }
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
        case .greeting:      greetingView
        case .feeling:       feelingView
        case .wakeUps:       wakeUpsView
        case .dreams:        dreamsView
        case .bedDifficulty: bedDifficultyView
        case .caffeine:      caffeineView
        case .summary:       summaryView
        }
    }

    private var greetingView: some View {
        VStack(spacing: 18) {
            DreamSpiritView(pet: appState.pet, size: 150)
            Text("Good morning")
                .font(MooniFont.display(32))
                .foregroundColor(MooniColor.textPrimary)
            Text("A few quick taps will tune last night's Mooni score.")
                .font(MooniFont.body(17))
                .foregroundColor(MooniColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
    }

    private var feelingView: some View {
        questionView(title: "How do you feel this morning?") {
            ForEach(MorningFeeling.allCases) { option in
                pickerRow(label: option.label, selected: feeling == option) {
                    feeling = option
                }
            }
        }
    }

    private var wakeUpsView: some View {
        questionView(title: "Did you wake up during the night?") {
            ForEach(WakeUpFrequency.allCases) { option in
                pickerRow(label: option.label, selected: wakeUps == option) {
                    wakeUps = option
                }
            }
        }
    }

    private var dreamsView: some View {
        questionView(title: "Do you remember dreaming?") {
            ForEach(DreamRecall.allCases) { option in
                pickerRow(label: option.label, selected: dreams == option) {
                    dreams = option
                }
            }
        }
    }

    private var bedDifficultyView: some View {
        questionView(title: "How hard was it to get out of bed?") {
            ForEach(BedDifficulty.allCases) { option in
                pickerRow(label: option.label, selected: bedDifficulty == option) {
                    bedDifficulty = option
                }
            }
        }
    }

    private var caffeineView: some View {
        questionView(title: "Any caffeine late yesterday?") {
            ForEach(CaffeineChoice.allCases) { option in
                pickerRow(label: option.label, selected: caffeine == option) {
                    caffeine = option
                }
            }
        }
    }

    private func questionView<Content: View>(
        title: String,
        @ViewBuilder options: () -> Content
    ) -> some View {
        VStack(spacing: 16) {
            Text(title)
                .font(MooniFont.display(24))
                .foregroundColor(MooniColor.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
            VStack(spacing: 10) {
                options()
            }
        }
    }

    private var summaryView: some View {
        VStack(spacing: 16) {
            DreamSpiritView(pet: appState.pet, size: 150)
            if let entry = savedEntry ?? appState.entryNeedingMorningCheckIn {
                VStack(spacing: 6) {
                    Text(entry.energyLevel ?? SleepScoringManager.energyLevel(for: entry.readinessScore ?? entry.score))
                        .font(MooniFont.display(24))
                        .foregroundColor(MooniColor.textPrimary)
                    Text("\(appState.pet.name) \(entry.recoveryMessage ?? appState.pet.mood.message)")
                        .font(MooniFont.body(15))
                        .foregroundColor(MooniColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                MooniCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 14) {
                            SleepScoreRing(score: entry.score, size: 84, lineWidth: 9)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Readiness \(entry.readinessScore ?? entry.score)")
                                    .font(MooniFont.title(17))
                                    .foregroundColor(MooniColor.success)
                                Text(entry.formattedDuration)
                                    .font(MooniFont.caption(13))
                                    .foregroundColor(MooniColor.textSecondary)
                            }
                            Spacer()
                        }
                        if let insight = entry.insight {
                            Text(insight)
                                .font(MooniFont.caption(12))
                                .foregroundColor(MooniColor.textSecondary)
                        }
                    }
                }
            } else {
                Text("Mooni is still gathering last night's sleep.")
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
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
                PrimaryButton(title: step == .greeting ? "Begin" : (step == .caffeine ? "See result" : "Next")) {
                    if step == .caffeine {
                        saveCheckIn()
                    } else {
                        withAnimation { step = nextStep(of: step) }
                    }
                }
            }
        }
    }

    private func saveCheckIn() {
        let date = appState.entryNeedingMorningCheckIn?.wakeTime ?? Date()
        let checkIn = MorningCheckIn(
            date: date,
            feeling: feeling,
            wakeUps: wakeUps,
            dreams: dreams,
            getOutOfBedDifficulty: bedDifficulty,
            lateCaffeine: caffeine.value
        )
        savedEntry = appState.completeMorningCheckIn(checkIn)
        withAnimation { step = .summary }
    }

    private func nextStep(of s: Step) -> Step {
        switch s {
        case .greeting:      return .feeling
        case .feeling:       return .wakeUps
        case .wakeUps:       return .dreams
        case .dreams:        return .bedDifficulty
        case .bedDifficulty: return .caffeine
        case .caffeine:      return .summary
        case .summary:       return .summary
        }
    }

    private func previousStep(of s: Step) -> Step {
        switch s {
        case .greeting:      return .greeting
        case .feeling:       return .greeting
        case .wakeUps:       return .feeling
        case .dreams:        return .wakeUps
        case .bedDifficulty: return .dreams
        case .caffeine:      return .bedDifficulty
        case .summary:       return .caffeine
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
