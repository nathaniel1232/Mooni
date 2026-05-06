import SwiftUI

/// Quest is the nightly care ritual. Free users always get one useful bedtime
/// quest; Premium adds guided wind-down content and structured programs.
struct BedtimeQuestView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Binding var showPaywall: Bool

    @State private var showReadySheet = false
    @State private var showSampleWindDown = false
    @State private var showQuestFlow = false

    private var questHabits: [RoutineHabit] {
        ["no_phone", "breathing", "journal"].compactMap { id in
            RoutineHabit.library.first { $0.id == id }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MooniGradient.night.ignoresSafeArea()
                StarsBackground(count: 32)

                ScrollView {
                    VStack(spacing: 18) {
                        header
                        questCard
                        rewardCard
                        guidedWindDowns
                        programsSection
                    }
                    .padding(20)
                    .padding(.bottom, 96)
                }
            }
            .navigationTitle("Quest")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showReadySheet) {
                ReadyForSleepSheet()
            }
            .sheet(isPresented: $showSampleWindDown) {
                SampleWindDownSheet()
            }
            .sheet(isPresented: $showQuestFlow) {
                QuestFlowView()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tonight's Quest")
                .font(MooniFont.display(30))
                .foregroundColor(MooniColor.textPrimary)
            Text("Help Luna get cozy before \(appState.targetBedtime.hourMinuteString).")
                .font(MooniFont.body(15))
                .foregroundColor(MooniColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var questCard: some View {
        MooniCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    DreamSpiritView(pet: questPet, size: 78)
                        .frame(width: 86, height: 86)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(primaryQuestCopy)
                            .font(MooniFont.title(18))
                            .foregroundColor(MooniColor.textPrimary)
                        Text("\(completedCount)/3 steps done")
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.textSecondary)
                    }

                    Spacer()
                }

                ForEach(Array(questHabits.enumerated()), id: \.element.id) { index, habit in
                    QuestStepRow(
                        index: index,
                        habit: habit,
                        isDone: isCompleted(habit),
                        action: { showQuestFlow = true }
                    )
                }

                PrimaryButton(title: primaryButtonTitle, icon: primaryButtonIcon) {
                    if completedCount == 3 {
                        showReadySheet = true
                    } else {
                        showQuestFlow = true
                    }
                }
            }
        }
    }

    private var rewardCard: some View {
        MooniCard(padding: 16, cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Reward", systemImage: "sparkles")
                        .font(MooniFont.title(16))
                        .foregroundColor(MooniColor.textPrimary)
                    Spacer()
                    Text("+\(earnedStars)/+20")
                        .font(MooniFont.title(15))
                        .foregroundColor(MooniColor.warning)
                }

                MooniProgressBar(value: Double(completedCount) / 3.0, height: 9, colors: [MooniColor.warning, MooniColor.accent])

                HStack(spacing: 10) {
                    MooniStatPill(icon: "checkmark.circle.fill", value: "\(completedCount)/3", label: "Done", color: MooniColor.success)
                    MooniStatPill(icon: "sparkles", value: "+\(earnedStars)", label: "Dream stars", color: MooniColor.warning)
                }

                Text(completedCount == 3 ? "Tonight's rhythm is protected." : "Complete tonight's quest to earn dream stars and support Luna's rhythm.")
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var guidedWindDowns: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Guided wind-downs")

            ForEach(Array(WindDownContent.library.enumerated()), id: \.element.id) { index, item in
                let isFreeSample = index == 0
                Button {
                    if subscriptionManager.isPro || isFreeSample {
                        showSampleWindDown = true
                    } else {
                        showPaywall = true
                    }
                } label: {
                    guidedRow(item: item, isLocked: !subscriptionManager.isPro && !isFreeSample, isSample: isFreeSample)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func guidedRow(item: WindDownContent, isLocked: Bool, isSample: Bool) -> some View {
        MooniCard(padding: 15, cornerRadius: 24) {
            HStack(spacing: 14) {
                Image(systemName: item.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isLocked ? MooniColor.textMuted : MooniColor.accentSoft)
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(item.title)
                            .font(MooniFont.title(15))
                            .foregroundColor(isLocked ? MooniColor.textMuted : MooniColor.textPrimary)
                        if isSample {
                            Text("Free sample")
                                .font(MooniFont.caption(10))
                                .foregroundColor(MooniColor.background)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(MooniColor.success)
                                .clipShape(Capsule())
                        }
                    }
                    Text("\(item.minutes) min")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                }

                Spacer()

                Image(systemName: isLocked ? "lock.fill" : "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isLocked ? MooniColor.textMuted : MooniColor.accent)
            }
        }
    }

    private var programsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Programs")

            ForEach(SleepProgram.catalog) { program in
                Button {
                    if subscriptionManager.isPro {
                        showReadySheet = true
                    } else {
                        showPaywall = true
                    }
                } label: {
                    programRow(program)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func programRow(_ program: SleepProgram) -> some View {
        MooniCard(padding: 15, cornerRadius: 24) {
            HStack(spacing: 14) {
                Image(systemName: program.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(MooniColor.accentSoft)
                    .frame(width: 42, height: 42)
                    .background(MooniColor.accent.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(program.title)
                        .font(MooniFont.title(15))
                        .foregroundColor(MooniColor.textPrimary)
                    Text(subscriptionManager.isPro ? program.subtitle : "Preview day 1 • \(program.days) days")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: subscriptionManager.isPro ? "chevron.right" : "lock.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(subscriptionManager.isPro ? MooniColor.accent : MooniColor.textMuted)
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(MooniFont.title(18))
            .foregroundColor(MooniColor.textPrimary)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Quest actions

    private var completedCount: Int {
        questHabits.filter(isCompleted).count
    }

    private var earnedStars: Int {
        questHabits.enumerated().reduce(0) { partial, pair in
            let reward = pair.offset == 2 ? 10 : 5
            return partial + (isCompleted(pair.element) ? reward : 0)
        }
    }

    private var primaryButtonTitle: String {
        switch completedCount {
        case 0: return "Start quest"
        case 1: return "Continue quest"
        case 2: return "Finish quest"
        default: return "Ready for sleep"
        }
    }

    private var primaryButtonIcon: String {
        completedCount == 3 ? "moon.fill" : "checkmark.circle.fill"
    }

    private var primaryQuestCopy: String {
        switch completedCount {
        case 0: return "Help Luna settle down"
        case 1: return "Luna is getting calmer"
        case 2: return "Almost ready for sleep"
        default: return "Luna feels cozy now"
        }
    }

    private var questPet: Pet {
        var p = appState.pet
        p.mood = completedCount == 3 ? .cozy : .sleepy
        return p
    }

    private func isCompleted(_ habit: RoutineHabit) -> Bool {
        appState.routine.completedToday.contains(habit.id)
    }

    private func advanceQuest() {
        guard let next = questHabits.enumerated().first(where: { !isCompleted($0.element) }) else {
            showReadySheet = true
            return
        }
        complete(next.element, index: next.offset)
    }

    private func complete(_ habit: RoutineHabit, index: Int) {
        guard !isCompleted(habit) else { return }
        withAnimation {
            appState.toggleHabitCompletion(habit)
        }
        appState.awardDreamStarsForQuestStep(habit, amount: index == 2 ? 10 : 5)
    }
}

private struct QuestStepRow: View {
    let index: Int
    let habit: RoutineHabit
    let isDone: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "\(index + 1).circle")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundColor(isDone ? MooniColor.success : MooniColor.accent)

                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.title)
                        .font(MooniFont.title(16))
                        .foregroundColor(MooniColor.textPrimary)
                    Text(isDone ? lunaMicrocopy : hint)
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(15)
            .background(Color.white.opacity(isDone ? 0.12 : 0.055))
            .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDone)
    }

    private var hint: String {
        switch index {
        case 0: return "Make the room quieter for Luna."
        case 1: return "Breathe slowly for a softer bedtime."
        default: return "Let one thought rest before sleep."
        }
    }

    private var lunaMicrocopy: String {
        switch index {
        case 0: return "That helped me feel calmer."
        case 1: return "Almost ready for sleep."
        default: return "I feel cozy now."
        }
    }
}

private struct QuestFlowView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var stepIndex: Int = 0
    @State private var showedMicrocopy = false
    @State private var journalText = ""
    @State private var breathingExpanded = false

    private var questHabits: [RoutineHabit] {
        ["no_phone", "breathing", "journal"].compactMap { id in
            RoutineHabit.library.first { $0.id == id }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MooniGradient.night.ignoresSafeArea()
                StarsBackground(count: 24)

                VStack(spacing: 22) {
                    progressHeader

                    if stepIndex >= questHabits.count {
                        completionView
                    } else {
                        stepView(index: stepIndex, habit: questHabits[stepIndex])
                    }

                    Spacer(minLength: 0)
                }
                .padding(22)
            }
            .navigationTitle("Tonight's Quest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(MooniColor.accent)
                }
            }
            .onAppear {
                stepIndex = firstIncompleteIndex
            }
        }
    }

    private var progressHeader: some View {
        let done = questHabits.filter { appState.routine.completedToday.contains($0.id) }.count
        return MooniCard(padding: 16, cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("\(min(done, 3))/3 steps done")
                        .font(MooniFont.title(16))
                        .foregroundColor(MooniColor.textPrimary)
                    Spacer()
                    Text("+\(earnedStars)/+20 stars")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.warning)
                }
                MooniProgressBar(value: Double(min(done, 3)) / 3.0, height: 8)
            }
        }
    }

    private func stepView(index: Int, habit: RoutineHabit) -> some View {
        VStack(spacing: 20) {
            LunaMoodHero(
                pet: appState.pet,
                mood: index == 0 ? .sleepy : .cozy,
                size: 160,
                caption: nil
            )

            LunaSpeechBubble(text: showedMicrocopy ? microcopy(for: index) : speech(for: index))

            MooniCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text(title(for: index))
                        .font(MooniFont.display(26))
                        .foregroundColor(MooniColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle(for: index))
                        .font(MooniFont.body(15))
                        .foregroundColor(MooniColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if index == 1 {
                        breathingCircle
                    }

                    if index == 2 {
                        journalField
                    }

                    PrimaryButton(title: ctaTitle(for: index), icon: ctaIcon(for: index)) {
                        handleStepTap(habit: habit, index: index)
                    }

                    if index == 2 && !showedMicrocopy {
                        Button {
                            handleStepTap(habit: habit, index: index)
                        } label: {
                            Text("Skip tonight")
                                .font(MooniFont.caption(13))
                                .foregroundColor(MooniColor.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .onAppear {
            showedMicrocopy = appState.routine.completedToday.contains(habit.id)
            if index == 1 {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    breathingExpanded = true
                }
            }
        }
    }

    private var breathingCircle: some View {
        ZStack {
            Circle()
                .fill(MooniColor.accent.opacity(0.12))
                .frame(width: breathingExpanded ? 168 : 104, height: breathingExpanded ? 168 : 104)
            Circle()
                .stroke(MooniColor.accentSoft.opacity(0.8), lineWidth: 2)
                .frame(width: breathingExpanded ? 184 : 116, height: breathingExpanded ? 184 : 116)
            Text(breathingExpanded ? "Exhale" : "Inhale")
                .font(MooniFont.title(18))
                .foregroundColor(MooniColor.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 196)
        .padding(.vertical, 4)
    }

    private var journalField: some View {
        TextField(
            "",
            text: $journalText,
            prompt: Text("What's one thought you want to let rest tonight?")
                .foregroundColor(MooniColor.textMuted),
            axis: .vertical
        )
        .font(MooniFont.body(15))
        .foregroundColor(MooniColor.textPrimary)
        .lineLimit(3...5)
        .padding(14)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var completionView: some View {
        VStack(spacing: 20) {
            LunaMoodHero(
                pet: appState.pet,
                mood: .cozy,
                size: 184,
                caption: nil
            )

            LunaSpeechBubble(text: "I feel cozy now.")

            MooniCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Luna is cozy now")
                        .font(MooniFont.display(28))
                        .foregroundColor(MooniColor.textPrimary)
                    Text("You earned +20 dream stars. Sleep by \(appState.targetBedtime.hourMinuteString) to keep your rhythm.")
                        .font(MooniFont.body(15))
                        .foregroundColor(MooniColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    MooniInfoRow(icon: "sparkles", title: "Dream stars", value: "+20", color: MooniColor.warning)
                    MooniInfoRow(icon: "flame.fill", title: "Rhythm support", value: "Protected", color: MooniColor.success)
                    MooniInfoRow(icon: "arrow.up.right.circle.fill", title: "Growth support", value: "Tonight counts")
                    PrimaryButton(title: "Ready for sleep", icon: "moon.fill") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var firstIncompleteIndex: Int {
        questHabits.firstIndex { !appState.routine.completedToday.contains($0.id) } ?? questHabits.count
    }

    private var earnedStars: Int {
        questHabits.enumerated().reduce(0) { partial, pair in
            let reward = pair.offset == 2 ? 10 : 5
            return partial + (appState.routine.completedToday.contains(pair.element.id) ? reward : 0)
        }
    }

    private func handleStepTap(habit: RoutineHabit, index: Int) {
        if showedMicrocopy {
            withAnimation {
                showedMicrocopy = false
                stepIndex = min(index + 1, questHabits.count)
            }
            return
        }

        if !appState.routine.completedToday.contains(habit.id) {
            withAnimation {
                appState.toggleHabitCompletion(habit)
            }
            appState.awardDreamStarsForQuestStep(habit, amount: index == 2 ? 10 : 5)
        }

        withAnimation {
            if index == 2 {
                stepIndex = questHabits.count
            } else {
                showedMicrocopy = true
            }
        }
    }

    private func title(for index: Int) -> String {
        switch index {
        case 0: return "Put phone away"
        case 1: return "Breathe with Luna"
        default: return "Quick journal"
        }
    }

    private func subtitle(for index: Int) -> String {
        switch index {
        case 0: return "Make the room quieter for Luna."
        case 1: return "Breathe slowly for a softer bedtime."
        default: return "What's one thought you want to let rest tonight?"
        }
    }

    private func speech(for index: Int) -> String {
        switch index {
        case 0: return "A quiet room helps me settle."
        case 1: return "Let's slow down together."
        default: return "One tiny thought can rest here."
        }
    }

    private func microcopy(for index: Int) -> String {
        switch index {
        case 0: return "That feels calmer."
        case 1: return "Almost cozy."
        default: return "I feel cozy now."
        }
    }

    private func ctaTitle(for index: Int) -> String {
        if showedMicrocopy { return "Next" }
        switch index {
        case 0: return "I put it away"
        case 1: return "Done"
        default: return "Finish quest"
        }
    }

    private func ctaIcon(for index: Int) -> String {
        if showedMicrocopy { return "arrow.right" }
        switch index {
        case 0: return "iphone.slash"
        case 1: return "checkmark"
        default: return "sparkles"
        }
    }
}

private struct ReadyForSleepSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            MooniGradient.night.ignoresSafeArea()

            VStack(spacing: 22) {
                LunaMoodHero(
                    pet: appState.pet,
                    mood: .cozy,
                    size: 170,
                    caption: "Luna feels cozy now."
                )

                MooniCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ready for sleep")
                            .font(MooniFont.title(20))
                            .foregroundColor(MooniColor.textPrimary)
                        Text("Put the phone away and let tonight be simple. Luna will wake up with you tomorrow.")
                            .font(MooniFont.body(14))
                            .foregroundColor(MooniColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                PrimaryButton(title: "Good night", icon: "moon.fill") {
                    dismiss()
                }

                Spacer()
            }
            .padding(22)
        }
    }
}

private struct SampleWindDownSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            MooniGradient.night.ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "wind")
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundColor(MooniColor.accentSoft)
                    .frame(width: 92, height: 92)
                    .background(MooniColor.accent.opacity(0.16))
                    .clipShape(Circle())

                VStack(spacing: 8) {
                    Text("4-7-8 Breathing")
                        .font(MooniFont.display(28))
                        .foregroundColor(MooniColor.textPrimary)
                    Text("Inhale 4. Hold 7. Exhale 8. Repeat gently until bedtime feels quieter.")
                        .font(MooniFont.body(15))
                        .foregroundColor(MooniColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                PrimaryButton(title: "Done", icon: "checkmark") {
                    dismiss()
                }

                Spacer()
            }
            .padding(24)
        }
    }
}

#Preview {
    BedtimeQuestView(showPaywall: .constant(false))
        .environmentObject(AppState.preview)
        .environmentObject(SubscriptionManager.shared)
}
