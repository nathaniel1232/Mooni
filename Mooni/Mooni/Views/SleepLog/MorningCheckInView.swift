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
    @State private var fallAsleepBucket: FallAsleepBucket = .tenToTwenty
    @State private var openDelayBucket: OpenDelayBucket = .underFive
    @State private var savedEntry: SleepEntry?

    enum Step {
        case greeting, fallAsleep, openDelay, feeling, wakeUps, dreams, bedDifficulty, caffeine, summary
    }

    private enum OpenDelayBucket: String, CaseIterable, Identifiable {
        case rightAway, underFive, fiveToFifteen, fifteenToThirty, overThirty

        var id: String { rawValue }

        var label: String {
            switch self {
            case .rightAway:       return "Right away"
            case .underFive:       return "Under 5 min"
            case .fiveToFifteen:   return "5–15 min"
            case .fifteenToThirty: return "15–30 min"
            case .overThirty:      return "Over 30 min"
            }
        }

        var minutes: Int {
            switch self {
            case .rightAway:       return 0
            case .underFive:       return 3
            case .fiveToFifteen:   return 10
            case .fifteenToThirty: return 22
            case .overThirty:      return 40
            }
        }
    }

    private enum FallAsleepBucket: String, CaseIterable, Identifiable {
        case underFive, fiveToTen, tenToTwenty, twentyToForty, overForty, dontKnow

        var id: String { rawValue }

        var label: String {
            switch self {
            case .underFive:     return "Under 5 min"
            case .fiveToTen:     return "5–10 min"
            case .tenToTwenty:   return "10–20 min"
            case .twentyToForty: return "20–40 min"
            case .overForty:     return "Over 40 min"
            case .dontKnow:      return "Not sure"
            }
        }

        /// Approximate centre-of-bucket value used to refine the score.
        var minutes: Int? {
            switch self {
            case .underFive:     return 3
            case .fiveToTen:     return 8
            case .tenToTwenty:   return 15
            case .twentyToForty: return 30
            case .overForty:     return 50
            case .dontKnow:      return nil
            }
        }
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
            StarsBackground(count: 40)
                .opacity(0.45)
                .allowsHitTesting(false)
            VStack(spacing: 18) {
                topBar
                progressIndicator
                    .padding(.horizontal, 8)

                ScrollView(showsIndicators: false) {
                    content
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                        .id(step)
                        .padding(.top, 12)
                }
                .scrollDismissesKeyboard(.interactively)

                footer
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 24)
        }
        .interactiveDismissDisabled(step != .summary)
    }

    /// Compact step dots so the user feels how short the check-in is.
    /// Greeting and summary book-end the question steps so we don't draw
    /// dots for them — only the 7 questions matter for "how many left."
    private var progressIndicator: some View {
        let questionSteps: [Step] = [
            .fallAsleep, .openDelay, .feeling, .wakeUps,
            .dreams, .bedDifficulty, .caffeine
        ]
        let currentIdx = questionSteps.firstIndex(of: step) ?? -1

        return HStack(spacing: 6) {
            ForEach(Array(questionSteps.enumerated()), id: \.offset) { idx, _ in
                Capsule()
                    .fill(idx <= currentIdx ? MooniColor.warning : Color.white.opacity(0.18))
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)
                    .animation(.spring(response: 0.4), value: currentIdx)
            }
        }
        .opacity(step == .greeting || step == .summary ? 0.0 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: step)
    }

    // MARK: - Steps content
    @ViewBuilder
    private var content: some View {
        switch step {
        case .greeting:      greetingView
        case .fallAsleep:    fallAsleepView
        case .openDelay:     openDelayView
        case .feeling:       feelingView
        case .wakeUps:       wakeUpsView
        case .dreams:        dreamsView
        case .bedDifficulty: bedDifficultyView
        case .caffeine:      caffeineView
        case .summary:       summaryView
        }
    }

    private var greetingView: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [MooniColor.warning.opacity(0.34), .clear],
                            center: .center,
                            startRadius: 6,
                            endRadius: 130
                        )
                    )
                    .frame(width: 240, height: 240)
                DreamSpiritView(pet: appState.pet, size: 150)
            }

            VStack(spacing: 8) {
                Text("Good morning")
                    .font(MooniFont.display(34))
                    .foregroundColor(MooniColor.textPrimary)
                Text("\(appState.pet.name) saw you wake up.")
                    .font(MooniFont.title(17))
                    .foregroundColor(MooniColor.accentSoft)
            }

            if let context = wakeContextLine {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(MooniColor.warning)
                    Text(context)
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.07))
                .clipShape(Capsule())
            }

            Text("A few quick taps tune last night's SleepOwl score.")
                .font(MooniFont.body(15))
                .foregroundColor(MooniColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    private var fallAsleepView: some View {
        questionView(title: "How long did it take you to fall asleep?") {
            ForEach(FallAsleepBucket.allCases) { option in
                pickerRow(label: option.label, icon: fallAsleepIcon(option), selected: fallAsleepBucket == option) {
                    fallAsleepBucket = option
                }
            }
        }
    }

    private func fallAsleepIcon(_ b: FallAsleepBucket) -> String {
        switch b {
        case .underFive:     return "bolt.fill"
        case .fiveToTen:     return "moon.stars.fill"
        case .tenToTwenty:   return "moon.fill"
        case .twentyToForty: return "hourglass"
        case .overForty:     return "clock.badge.exclamationmark"
        case .dontKnow:      return "questionmark.circle"
        }
    }

    private var openDelayView: some View {
        questionView(title: "How long after waking did you open SleepOwl?") {
            ForEach(OpenDelayBucket.allCases) { option in
                pickerRow(label: option.label, icon: openDelayIcon(option), selected: openDelayBucket == option) {
                    openDelayBucket = option
                }
            }
        }
    }

    private func openDelayIcon(_ b: OpenDelayBucket) -> String {
        switch b {
        case .rightAway:       return "bolt.fill"
        case .underFive:       return "sun.max.fill"
        case .fiveToFifteen:   return "alarm.fill"
        case .fifteenToThirty: return "hourglass"
        case .overThirty:      return "clock.badge.exclamationmark"
        }
    }

    /// Friendly one-liner shown under the greeting that pulls from the
    /// timestamps SleepOwl captured automatically (wake tap + first
    /// app-open) so the user sees the system is paying attention.
    private var wakeContextLine: String? {
        guard let wake = appState.wakeTappedAt,
              let opened = appState.appOpenedAfterWakeAt else { return nil }
        let delay = max(0, Int(opened.timeIntervalSince(wake) / 60))
        let wakeStr = wake.hourMinuteString
        if delay <= 0 {
            return "Wake logged at \(wakeStr)."
        }
        return "Woke at \(wakeStr) · opened SleepOwl \(delay) min later."
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
                Text("SleepOwl is still gathering last night's sleep.")
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
                .frame(maxWidth: 280)
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
                .frame(maxWidth: 280)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func saveCheckIn() {
        let date = appState.entryNeedingMorningCheckIn?.wakeTime ?? Date()

        // Prefer the auto-captured delay (wake-tap → first app-open) when
        // we have both anchors; otherwise fall back to the user's
        // self-reported bucket.
        var delay: Int? = openDelayBucket.minutes
        if let wake = appState.wakeTappedAt,
           let opened = appState.appOpenedAfterWakeAt,
           opened > wake {
            delay = max(0, Int(opened.timeIntervalSince(wake) / 60))
        }

        let checkIn = MorningCheckIn(
            date: date,
            feeling: feeling,
            wakeUps: wakeUps,
            dreams: dreams,
            getOutOfBedDifficulty: bedDifficulty,
            lateCaffeine: caffeine.value,
            minutesToFallAsleep: fallAsleepBucket.minutes,
            minutesFromWakeToAppOpen: delay
        )
        savedEntry = appState.completeMorningCheckIn(checkIn)
        withAnimation { step = .summary }
    }

    /// True when wake → first-app-open delay was auto-captured by the
    /// notification probes. In that case we don't need to ask the user
    /// to estimate it — saves a screen.
    private var openDelayAutoCaptured: Bool {
        guard let wake = appState.wakeTappedAt,
              let opened = appState.appOpenedAfterWakeAt else { return false }
        return opened > wake
    }

    private func nextStep(of s: Step) -> Step {
        switch s {
        case .greeting:      return openDelayAutoCaptured ? .fallAsleep : .fallAsleep
        case .fallAsleep:    return openDelayAutoCaptured ? .feeling : .openDelay
        case .openDelay:     return .feeling
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
        case .fallAsleep:    return .greeting
        case .openDelay:     return .fallAsleep
        case .feeling:       return openDelayAutoCaptured ? .fallAsleep : .openDelay
        case .wakeUps:       return .feeling
        case .dreams:        return .wakeUps
        case .bedDifficulty: return .dreams
        case .caffeine:      return .bedDifficulty
        case .summary:       return .caffeine
        }
    }

    private func pickerRow(label: String, icon: String? = nil, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 12) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(selected ? MooniColor.warning : MooniColor.textMuted)
                        .frame(width: 32, height: 32)
                        .background((selected ? MooniColor.warning : Color.white).opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                Text(label)
                    .font(MooniFont.title(15))
                    .foregroundColor(MooniColor.textPrimary)
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selected ? MooniColor.warning : MooniColor.textMuted)
                    .font(.system(size: 18))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(selected ? Color.white.opacity(0.18) : Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? MooniColor.warning : Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MorningCheckInView().environmentObject(AppState.preview)
}
