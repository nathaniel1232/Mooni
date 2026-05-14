import SwiftUI
import UIKit

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
        ["breathing", "journal", "no_phone"].compactMap { id in
            RoutineHabit.library.first { $0.id == id }
        }
    }

    private var isDayTime: Bool {
        switch TimeOfDay.current {
        case .morning, .day: return true
        case .evening, .night: return false
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MooniGradient.night.ignoresSafeArea()
                StarsBackground(count: 32)

                ScrollView {
                    VStack(spacing: 18) {
                        comingSoonBanner
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
            Text("Help \(appState.pet.name) get cozy before \(appState.targetBedtime.hourMinuteString).")
                .font(MooniFont.body(15))
                .foregroundColor(MooniColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var comingSoonBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(MooniColor.warning.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: "hammer.fill")
                    .foregroundColor(MooniColor.warning)
                    .font(.system(size: 14, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("COMING SOON")
                        .font(MooniFont.caption(10))
                        .foregroundColor(MooniColor.warning)
                        .tracking(1.4)
                    Circle()
                        .fill(MooniColor.warning)
                        .frame(width: 4, height: 4)
                    Text("PREVIEW")
                        .font(MooniFont.caption(10))
                        .foregroundColor(MooniColor.warning.opacity(0.85))
                        .tracking(1.4)
                }
                Text("Quests are still in development — feel free to peek around.")
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(MooniColor.warning.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MooniColor.warning.opacity(0.30), lineWidth: 1)
        )
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

                Text(completedCount == 3 ? "Tonight's rhythm is protected." : "Complete tonight's quest to earn dream stars and support \(appState.pet.name)'s rhythm.")
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
            HStack {
                Text("Programs")
                    .font(MooniFont.title(18))
                    .foregroundColor(MooniColor.textPrimary)
                Spacer()
                Text("Coming soon")
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.background)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(MooniColor.accentSoft)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 4)

            ForEach(SleepProgram.catalog) { program in
                programRow(program)
                    .opacity(0.55)
                    .allowsHitTesting(false)
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
                    Text("\(program.days)-day plan · launching soon")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "hourglass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(MooniColor.textMuted)
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
        let name = appState.pet.name
        switch completedCount {
        case 0: return "Help \(name) settle down"
        case 1: return "\(name) is getting calmer"
        case 2: return "Almost ready for sleep"
        default: return "\(name) feels cozy now"
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
        case 0: return "Breathe slowly for a softer bedtime."
        case 1: return "Let one thought rest before sleep."
        default: return "Phone away — last step before bed."
        }
    }

    private var lunaMicrocopy: String {
        switch index {
        case 0: return "Almost ready for sleep."
        case 1: return "That helped me feel calmer."
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
    /// Seconds elapsed in the breathing exercise — must reach 30 before
    /// the user can mark step 0 done. Stops shallow taps from speedrunning
    /// the quest.
    @State private var breathingElapsed: Int = 0
    @State private var phoneAwayHoldProgress: Double = 0
    @State private var holdTimer: Timer? = nil
    @State private var breathTimer: Timer? = nil

    private var questHabits: [RoutineHabit] {
        ["breathing", "journal", "no_phone"].compactMap { id in
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

                    if index == 0 {
                        breathingCircle
                        Text(breathingElapsed >= 30
                             ? "Nice. You're calmer."
                             : "Keep breathing… \(max(0, 30 - breathingElapsed))s")
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.textSecondary)
                            .frame(maxWidth: .infinity)
                    }

                    if index == 1 {
                        journalField
                        Text("\(journalText.trimmingCharacters(in: .whitespacesAndNewlines).count)/15 characters")
                            .font(MooniFont.caption(11))
                            .foregroundColor(MooniColor.textMuted)
                    }

                    if index == 2 && !showedMicrocopy {
                        phoneAwayHoldButton(habit: habit, index: index)
                    } else {
                        PrimaryButton(title: ctaTitle(for: index), icon: ctaIcon(for: index)) {
                            handleStepTap(habit: habit, index: index)
                        }
                        .disabled(!canCompleteStep(index: index))
                        .opacity(canCompleteStep(index: index) ? 1 : 0.5)
                    }

                    if index == 1 && !showedMicrocopy {
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
            if index == 0 {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    breathingExpanded = true
                }
                breathingElapsed = 0
                breathTimer?.invalidate()
                breathTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    Task { @MainActor in
                        if breathingElapsed < 30 {
                            breathingElapsed += 1
                        } else {
                            breathTimer?.invalidate()
                            breathTimer = nil
                        }
                    }
                }
            }
        }
        .onDisappear {
            breathTimer?.invalidate(); breathTimer = nil
            holdTimer?.invalidate(); holdTimer = nil
        }
    }

    private func canCompleteStep(index: Int) -> Bool {
        if showedMicrocopy { return true } // "Next" button stage — always enabled
        switch index {
        case 0: return breathingElapsed >= 30
        case 1: return journalText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 15
        default: return true
        }
    }

    /// Hold-to-confirm "phone away". Press for 2 seconds to register —
    /// makes the quest harder to fake with a single tap.
    private func phoneAwayHoldButton(habit: RoutineHabit, index: Int) -> some View {
        let progress = phoneAwayHoldProgress
        return ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(MooniColor.accent.opacity(0.22))
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [MooniColor.accentSoft, MooniColor.accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * CGFloat(progress))
            }
            HStack(spacing: 10) {
                Image(systemName: "iphone.slash")
                    .font(.system(size: 14, weight: .bold))
                Text(progress > 0.05 ? "Keep holding…" : "Hold to confirm phone away")
                    .font(MooniFont.title(15))
            }
            .foregroundColor(MooniColor.background)
        }
        .frame(height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if holdTimer == nil {
                        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                            Task { @MainActor in
                                phoneAwayHoldProgress = min(1, phoneAwayHoldProgress + 0.05 / 2.0)
                                if phoneAwayHoldProgress >= 1 {
                                    holdTimer?.invalidate(); holdTimer = nil
                                    handleStepTap(habit: habit, index: index)
                                }
                            }
                        }
                    }
                }
                .onEnded { _ in
                    holdTimer?.invalidate(); holdTimer = nil
                    if phoneAwayHoldProgress < 1 {
                        withAnimation { phoneAwayHoldProgress = 0 }
                    }
                }
        )
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
                    Text("\(appState.pet.name) is cozy now")
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
                        appState.enterSleepMode()
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
            withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) {
                appState.toggleHabitCompletion(habit)
            }
            appState.awardDreamStarsForQuestStep(habit, amount: index == 2 ? 10 : 5)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
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
        case 0: return "Breathe together"
        case 1: return "Quick journal"
        default: return "Put phone away"
        }
    }

    private func subtitle(for index: Int) -> String {
        switch index {
        case 0: return "Breathe slowly for a softer bedtime."
        case 1: return "What's one thought you want to let rest tonight?"
        default: return "Last step. Set the phone down so the room goes quiet."
        }
    }

    private func speech(for index: Int) -> String {
        switch index {
        case 0: return "Let's slow down together."
        case 1: return "One tiny thought can rest here."
        default: return "Time to put the phone away."
        }
    }

    private func microcopy(for index: Int) -> String {
        switch index {
        case 0: return "Almost cozy."
        case 1: return "That feels calmer."
        default: return "I feel cozy now."
        }
    }

    private func ctaTitle(for index: Int) -> String {
        if showedMicrocopy { return "Next" }
        switch index {
        case 0: return "Done"
        case 1: return "Save thought"
        default: return "I put it away"
        }
    }

    private func ctaIcon(for index: Int) -> String {
        if showedMicrocopy { return "arrow.right" }
        switch index {
        case 0: return "checkmark"
        case 1: return "sparkles"
        default: return "iphone.slash"
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
                    caption: "\(appState.pet.name) feels cozy now."
                )

                MooniCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ready for sleep")
                            .font(MooniFont.title(20))
                            .foregroundColor(MooniColor.textPrimary)
                        Text("Put the phone away and let tonight be simple. \(appState.pet.name) will wake up with you tomorrow.")
                            .font(MooniFont.body(14))
                            .foregroundColor(MooniColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                PrimaryButton(title: "Good night", icon: "moon.fill") {
                    appState.enterSleepMode()
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
