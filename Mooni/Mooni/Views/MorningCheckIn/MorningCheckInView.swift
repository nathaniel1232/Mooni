import SwiftUI

/// The morning check-in, rebuilt as a full-screen, multi-page intake.
///
/// One question per page, grouped into three chapters — **Last Night**,
/// **Yesterday**, **This Morning** — that the background gradient walks from
/// deep night toward dawn as you advance. Every detail we can use to sharpen
/// the night (and, later, the physiology read-out) is captured here, but a
/// "Skip the rest" affordance always jumps straight to the confirm + reveal so
/// a low-effort morning is never punished.
struct MorningCheckInView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = false

    /// When set, this entry replaces `appState.entryNeedingMorningCheckIn`
    /// as the subject of the flow — used when the user re-opens the
    /// check-in from the home screen to edit or add a missed night.
    var entryOverride: SleepEntry? = nil

    /// When true, the flow opens directly in "way off" edit-times mode so the
    /// user can correct bedtime / wake immediately. Used for the home-screen
    /// edit pencil and the missed-night entry point.
    var startInEditMode: Bool = false

    @State private var scene: Scene = .greeting

    // Tracks which question screens the user actually walked through, so that
    // "Skip the rest" leaves the remaining (optional) answers as nil rather
    // than silently recording their defaults.
    @State private var answered: Set<Scene> = []

    // Confirm scene — recap + accuracy
    @State private var accuracy: SleepAccuracyRating? = nil
    @State private var editedBedtime: Date = Date()
    @State private var editedWakeTime: Date = Date()

    // Last Night
    @State private var fallAsleepMinutes: Double = 12
    @State private var fallAsleepUnknown: Bool = false
    @State private var phoneToSleepMinutes: Double = 5
    @State private var phoneToSleepUnknown: Bool = false
    @State private var wakeUps: WakeUpFrequency = .none
    @State private var dreams: DreamRecall = .notSure
    @State private var roomFeel: RoomTemp = .justRight

    // Yesterday
    @State private var caffeineCount: Int = 0
    @State private var lastCaffeineTime: Date = Date.todayAt(hour: 15, minute: 0)
    @State private var lastMealTime: Date = Date.todayAt(hour: 19, minute: 0)
    @State private var lateHeavyMeal: Bool = false
    @State private var alcoholDrinks: Int = 0
    @State private var exerciseTime: ExerciseTiming = .none
    @State private var didNap: Bool = false
    @State private var napMinutes: Double = 20
    @State private var stressLevel: StressLevel = .normal

    // This Morning
    @State private var feeling: MorningFeeling = .okay
    @State private var bedDifficulty: BedDifficulty = .normal
    @State private var wakeToUpMinutes: Double = 10
    @State private var wakeToUpUnknown: Bool = false

    // Reveal
    @State private var revealScale: CGFloat = 0.85
    @State private var savedEntry: SleepEntry?
    @State private var showStory = false
    @State private var showAnalytics = false

    // MARK: - Scene model

    enum Scene: Int, CaseIterable, Hashable {
        case greeting
        // Last Night
        case onset, phoneToSleep, restless, dreams, roomTemp
        // Yesterday
        case caffeine, lastMeal, alcohol, movement, naps, stress
        // This Morning
        case feelingScene, outOfBed, wakeToUp
        case confirm, reveal

        enum Chapter: Int, CaseIterable {
            case lastNight, yesterday, thisMorning
            var label: String {
                switch self {
                case .lastNight:   return "Last Night"
                case .yesterday:   return "Yesterday"
                case .thisMorning: return "This Morning"
                }
            }
        }

        var chapter: Chapter? {
            switch self {
            case .onset, .phoneToSleep, .restless, .dreams, .roomTemp:
                return .lastNight
            case .caffeine, .lastMeal, .alcohol, .movement, .naps, .stress:
                return .yesterday
            case .feelingScene, .outOfBed, .wakeToUp:
                return .thisMorning
            case .greeting, .confirm, .reveal:
                return nil
            }
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            backgroundLayer
            StarsBackground(count: 60)
                .opacity(starOpacity)
                .animation(.easeInOut(duration: 0.8), value: scene)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 22)
                    .padding(.top, 16)

                if showsProgress {
                    chapterProgress
                        .padding(.horizontal, 22)
                        .padding(.top, 16)
                }

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        Color.clear.frame(height: 1).id("top")
                        sceneContent
                            .id(scene)
                            .transition(.opacity)
                            .padding(.horizontal, 22)
                            .padding(.top, 18)
                            .padding(.bottom, 40)
                            .frame(maxWidth: .infinity)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: scene) { _, _ in
                        proxy.scrollTo("top", anchor: .top)
                    }
                }

                footer
                    .padding(.horizontal, 22)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
                    .background(
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                            .overlay(alignment: .top) {
                                Rectangle()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(height: 1)
                            }
                            .ignoresSafeArea(edges: .bottom)
                    )
            }
            .responsiveContainer()
        }
        .interactiveDismissDisabled(scene != .reveal)
        .onAppear(perform: setupInitialTimes)
        .mooniPaywall(isPresented: $showPaywall)
        .fullScreenCover(isPresented: $showStory) {
            if let entry = savedEntry ?? entryOverride ?? appState.entryNeedingMorningCheckIn {
                SleepStoryView(
                    context: SleepStoryContext(
                        entry: entry,
                        pet: appState.pet,
                        petName: appState.pet.name,
                        history: appState.entries,
                        goalHours: appState.goalHours,
                        currentStreak: StreakManager.shared.current,
                        longestStreak: StreakManager.shared.longest,
                        consistencyDays: appState.bedtimeConsistencyDays,
                        leveledUpTo: appState.lastLevelUp
                    ),
                    onFinished: {
                        // The Sleep Story closes into the deep physiology
                        // read-out. Stagger the cover swap so the two
                        // transitions don't collide.
                        showStory = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            showAnalytics = true
                        }
                    }
                )
            }
        }
        .fullScreenCover(isPresented: $showAnalytics) {
            if let entry = savedEntry ?? entryOverride ?? appState.entryNeedingMorningCheckIn {
                NightAnalyticsView(entry: entry, onClose: { showAnalytics = false })
                    .environmentObject(appState)
                    .environmentObject(subscriptionManager)
            }
        }
    }

    // MARK: - Background ramp (night → dawn)

    private var backgroundLayer: some View {
        let t = backgroundT
        let top = Color(red: lerp(0.03, 0.30, t),
                        green: lerp(0.04, 0.18, t),
                        blue: lerp(0.16, 0.34, t))
        let bottom = Color(red: lerp(0.08, 0.80, t),
                           green: lerp(0.08, 0.46, t),
                           blue: lerp(0.24, 0.42, t))
        return LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.7), value: scene)
    }

    /// 0 at the greeting, 1 by the confirm scene — drives the dawn ramp.
    private var backgroundT: Double {
        let all = Scene.allCases
        guard let i = all.firstIndex(of: scene),
              let c = all.firstIndex(of: .confirm) else { return 0 }
        return min(1, Double(i) / Double(max(1, c)))
    }

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

    private var starOpacity: Double { max(0.08, 0.55 - backgroundT * 0.45) }

    private var spiritGlowColor: Color {
        switch backgroundT {
        case ..<0.4: return MooniColor.accent
        case ..<0.7: return MooniColor.accentSoft
        default:     return MooniColor.warning
        }
    }

    // MARK: - Chrome

    private var topBar: some View {
        HStack {
            if canSkip {
                Button {
                    Haptics.tap()
                    withAnimation(.easeInOut(duration: 0.6)) { scene = .confirm }
                } label: {
                    Text("Skip the rest")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textMuted)
                        .padding(.vertical, 4)
                }
            }
            Spacer()
            Button {
                appState.dismissMorningCheckIn()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.white.opacity(0.55))
            }
        }
    }

    /// Skipping only makes sense from inside the question chapters — not on the
    /// greeting, the night confirmation, or the reveal.
    private var canSkip: Bool { scene.chapter != nil }

    private var showsProgress: Bool { scene != .greeting && scene != .reveal }

    private var chapterProgress: some View {
        HStack(spacing: 10) {
            ForEach(Scene.Chapter.allCases, id: \.rawValue) { ch in
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.16))
                            Capsule()
                                .fill(MooniColor.warning)
                                .frame(width: geo.size.width * fill(for: ch))
                        }
                    }
                    .frame(height: 4)
                    Text(ch.label)
                        .font(MooniFont.caption(10))
                        .foregroundColor(scene.chapter == ch ? MooniColor.textPrimary : MooniColor.textMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .animation(.spring(response: 0.45), value: scene)
    }

    private func fill(for chapter: Scene.Chapter) -> CGFloat {
        let scenes = Scene.allCases.filter { $0.chapter == chapter }
        guard let current = scene.chapter else {
            // greeting → nothing started; confirm/reveal → everything done.
            return scene == .greeting ? 0 : 1
        }
        if chapter.rawValue < current.rawValue { return 1 }
        if chapter.rawValue > current.rawValue { return 0 }
        let idx = scenes.firstIndex(of: scene) ?? 0
        return CGFloat(idx) / CGFloat(max(1, scenes.count))
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if scene == .reveal {
                PrimaryButton(title: "Done", icon: "checkmark") { dismiss() }
                    .frame(maxWidth: 320)
            } else {
                if scene != .greeting {
                    SecondaryButton(title: "Back") {
                        withAnimation(.easeInOut(duration: 0.55)) {
                            scene = previous(of: scene)
                        }
                    }
                    .frame(width: 100)
                }
                PrimaryButton(title: primaryTitle, icon: nil) { advance() }
                    .frame(maxWidth: 320)
                    .opacity(canAdvance ? 1 : 0.45)
                    .disabled(!canAdvance)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var primaryTitle: String {
        switch scene {
        case .greeting: return "Let's check in"
        case .confirm:  return "See last night"
        default:        return "Next"
        }
    }

    private var canAdvance: Bool {
        switch scene {
        case .confirm: return accuracy != nil
        default:       return true
        }
    }

    // MARK: - Scenes router

    @ViewBuilder
    private var sceneContent: some View {
        switch scene {
        case .greeting:     greetingScene
        case .onset:        onsetScene
        case .phoneToSleep: phoneToSleepScene
        case .restless:     restlessScene
        case .dreams:       dreamsScene
        case .roomTemp:     roomTempScene
        case .caffeine:     caffeineScene
        case .lastMeal:     lastMealScene
        case .alcohol:      alcoholScene
        case .movement:     movementScene
        case .naps:         napsScene
        case .stress:       stressScene
        case .feelingScene: morningScene
        case .outOfBed:     outOfBedScene
        case .wakeToUp:     wakeToUpScene
        case .confirm:      confirmScene
        case .reveal:       revealScene
        }
    }

    // MARK: - Greeting

    private var greetingScene: some View {
        VStack(spacing: 26) {
            CheckInSpirit(pet: appState.pet, size: 132, glow: spiritGlowColor)
                .padding(.top, 8)

            VStack(spacing: 10) {
                Text("Good morning")
                    .font(MooniFont.display(34))
                    .foregroundColor(MooniColor.textPrimary)
                Text("\(petDisplayName) watched over you while you slept.")
                    .font(MooniFont.body(16))
                    .foregroundColor(MooniColor.accentSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            Text("Let's reconstruct your night — a few quick taps and we'll piece together how it really went.")
                .font(MooniFont.body(14))
                .foregroundColor(MooniColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 26)
        }
    }

    private var petDisplayName: String {
        let name = appState.pet.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "SleepOwl" : name
    }

    // MARK: - Last Night

    private var onsetScene: some View {
        StepScaffold(pet: appState.pet, glow: spiritGlowColor,
                     title: "How long did you take to fall asleep?") {
            MinutesStarStep(
                minutes: $fallAsleepMinutes,
                unknown: $fallAsleepUnknown,
                maxMinutes: 180,
                lowLabel: "instant",
                highLabel: "3+ hours",
                caption: fallAsleepCaption
            )
        }
    }

    private var phoneToSleepScene: some View {
        StepScaffold(pet: appState.pet, glow: spiritGlowColor,
                     title: "After you set your phone down…",
                     subtitle: "…how long until you actually drifted off? This sharpens your real bedtime.") {
            MinutesStarStep(
                minutes: $phoneToSleepMinutes,
                unknown: $phoneToSleepUnknown,
                maxMinutes: 60,
                lowLabel: "right away",
                highLabel: "1 hr+",
                caption: phoneToSleepCaption
            )
        }
    }

    private var restlessScene: some View {
        StepScaffold(pet: appState.pet, glow: spiritGlowColor,
                     title: "Restless last night?",
                     subtitle: "Drag to how often you stirred.") {
            EmojiScaleSlider(
                stops: WakeUpFrequency.allCases.map { (wakeUpEmoji($0), wakeUpLabel($0)) },
                index: Binding(
                    get: { WakeUpFrequency.allCases.firstIndex(of: wakeUps) ?? 0 },
                    set: { wakeUps = WakeUpFrequency.allCases[$0] }
                )
            )
            .padding(.top, 6)
        }
    }

    private var dreamsScene: some View {
        StepScaffold(pet: appState.pet, glow: spiritGlowColor,
                     title: "Did dreams visit you?") {
            HStack(spacing: 10) {
                ForEach(DreamRecall.allCases) { d in
                    CheckInChip(emoji: dreamEmoji(d), label: d.label,
                                selected: dreams == d, verticalPadding: 22, emojiSize: 34) {
                        dreams = d
                    }
                }
            }
        }
    }

    private var roomTempScene: some View {
        StepScaffold(pet: appState.pet, glow: spiritGlowColor,
                     title: "How did your room feel?",
                     subtitle: "A cool room helps deep sleep land.") {
            HStack(spacing: 8) {
                ForEach(RoomTemp.allCases) { r in
                    CheckInChip(emoji: r.emoji, label: r.label,
                                selected: roomFeel == r, verticalPadding: 16, emojiSize: 26) {
                        roomFeel = r
                    }
                }
            }
        }
    }

    // MARK: - Yesterday

    private var caffeineScene: some View {
        StepScaffold(pet: appState.pet, glow: spiritGlowColor,
                     title: "Caffeine yesterday?",
                     subtitle: "Coffee, tea, energy drinks, cola — all count.") {
            StepperWithTimeReveal(
                count: $caffeineCount,
                time: $lastCaffeineTime,
                maxCount: 6,
                unit: "drink",
                revealPrompt: "Last one at",
                revealIcon: "cup.and.saucer.fill"
            )
        }
    }

    private var lastMealScene: some View {
        StepScaffold(pet: appState.pet, glow: spiritGlowColor,
                     title: "When was your last meal?",
                     subtitle: "Eating late can keep your body too warm for deep sleep.") {
            TimeWheelStep(
                time: $lastMealTime,
                icon: "fork.knife",
                prompt: "Last bite at",
                toggleLabel: "It was late & heavy",
                toggleValue: $lateHeavyMeal
            )
        }
    }

    private var alcoholScene: some View {
        StepScaffold(pet: appState.pet, glow: spiritGlowColor,
                     title: "Any alcohol yesterday?",
                     subtitle: "Even a little can trim your dream sleep.") {
            HStack(spacing: 10) {
                ForEach(alcoholOptions, id: \.value) { opt in
                    CheckInChip(emoji: opt.emoji, label: opt.label,
                                selected: alcoholDrinks == opt.value, verticalPadding: 18) {
                        alcoholDrinks = opt.value
                    }
                }
            }
        }
    }

    private var movementScene: some View {
        StepScaffold(pet: appState.pet, glow: spiritGlowColor,
                     title: "When did you move most?",
                     subtitle: "Exercise builds deep sleep — unless it's right before bed.") {
            HStack(spacing: 8) {
                ForEach(ExerciseTiming.allCases) { e in
                    CheckInChip(emoji: e.emoji, label: e.label,
                                selected: exerciseTime == e, verticalPadding: 16, emojiSize: 24) {
                        exerciseTime = e
                    }
                }
            }
        }
    }

    private var napsScene: some View {
        StepScaffold(pet: appState.pet, glow: spiritGlowColor,
                     title: "Did you nap yesterday?",
                     subtitle: "Long late naps can soften tonight's sleep pressure.") {
            ToggleRevealStep(
                on: $didNap,
                minutes: $napMinutes,
                maxMinutes: 180,
                yesLabel: "Yes, I napped",
                noLabel: "No nap"
            )
        }
    }

    private var stressScene: some View {
        StepScaffold(pet: appState.pet, glow: spiritGlowColor,
                     title: "How was yesterday's stress?",
                     subtitle: "Drag to how wound-up the day felt.") {
            EmojiScaleSlider(
                stops: StressLevel.allCases.map { ($0.emoji, $0.label) },
                index: Binding(
                    get: { StressLevel.allCases.firstIndex(of: stressLevel) ?? 1 },
                    set: { stressLevel = StressLevel.allCases[$0] }
                )
            )
            .padding(.top, 6)
        }
    }

    // MARK: - This Morning

    private var morningScene: some View {
        StepScaffold(pet: appState.pet, glow: spiritGlowColor,
                     title: "And now you're here.",
                     subtitle: "How does this morning feel?") {
            HStack(spacing: 8) {
                ForEach(MorningFeeling.allCases) { f in
                    CheckInChip(emoji: feelingEmoji(f), label: f.label,
                                selected: feeling == f, verticalPadding: 16, emojiSize: 30) {
                        feeling = f
                    }
                }
            }
        }
    }

    private var outOfBedScene: some View {
        StepScaffold(pet: appState.pet, glow: spiritGlowColor,
                     title: "Getting out of bed?",
                     subtitle: "Drag to how hard it felt.") {
            EmojiScaleSlider(
                stops: BedDifficulty.allCases.map { (bedEmoji($0), bedLabel($0)) },
                index: Binding(
                    get: { BedDifficulty.allCases.firstIndex(of: bedDifficulty) ?? 1 },
                    set: { bedDifficulty = BedDifficulty.allCases[$0] }
                )
            )
            .padding(.top, 6)
        }
    }

    private var wakeToUpScene: some View {
        StepScaffold(pet: appState.pet, glow: spiritGlowColor,
                     title: "Waking to getting up?",
                     subtitle: "How long from opening your eyes to actually leaving bed?") {
            MinutesStarStep(
                minutes: $wakeToUpMinutes,
                unknown: $wakeToUpUnknown,
                maxMinutes: 60,
                lowLabel: "straight up",
                highLabel: "1 hr+",
                caption: wakeToUpCaption
            )
        }
    }

    // MARK: - Confirm the tracked night

    private var confirmScene: some View {
        VStack(spacing: 20) {
            CheckInSpirit(pet: appState.pet, size: 88, glow: MooniColor.warning)

            VStack(spacing: 6) {
                Text(isEditingTimes ? "Set your night" : "Here's your night")
                    .font(MooniFont.display(26))
                    .foregroundColor(MooniColor.textPrimary)
                    .animation(.easeInOut(duration: 0.25), value: isEditingTimes)
                Text("One last look before we score it.")
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
            }
            .multilineTextAlignment(.center)

            if let entry = entryForRecap {
                recapCard(entry: entry)
                accuracyPrompt
            } else {
                Text("Your night is still settling in. Check back in a few minutes.")
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
    }

    private var entryForRecap: SleepEntry? {
        entryOverride ?? appState.entryNeedingMorningCheckIn ?? savedEntry
    }

    private func recapCard(entry: SleepEntry) -> some View {
        MooniCard {
            VStack(spacing: 14) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(durationHours(entry))
                        .font(MooniFont.display(54))
                        .foregroundColor(MooniColor.textPrimary)
                        .contentTransition(.numericText())
                    Text("h")
                        .font(MooniFont.title(22))
                        .foregroundColor(MooniColor.textSecondary)
                        .padding(.trailing, 6)
                    Text(durationMinutes(entry))
                        .font(MooniFont.display(54))
                        .foregroundColor(MooniColor.textPrimary)
                        .contentTransition(.numericText())
                    Text("m")
                        .font(MooniFont.title(22))
                        .foregroundColor(MooniColor.textSecondary)
                }

                if isEditingTimes {
                    editTimesView.transition(.opacity)
                } else {
                    timesSummary(entry: entry).transition(.opacity)
                }

                sourceChip(for: entry)
            }
        }
    }

    private func timesSummary(entry: SleepEntry) -> some View {
        HStack(spacing: 14) {
            timeColumn(icon: "moon.fill", label: "Bedtime",
                       value: effectiveBedtime(entry).hourMinuteString)
            Image(systemName: "arrow.right")
                .foregroundColor(MooniColor.textMuted)
                .font(.system(size: 13, weight: .semibold))
            timeColumn(icon: "sun.max.fill", label: "Woke up",
                       value: effectiveWakeTime(entry).hourMinuteString)
        }
    }

    private func timeColumn(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(MooniColor.warning)
                    .font(.system(size: 11))
                Text(label)
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.textMuted)
            }
            Text(value)
                .font(MooniFont.title(18))
                .foregroundColor(MooniColor.textPrimary)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
    }

    private var editTimesView: some View {
        VStack(spacing: 10) {
            editRow(icon: "moon.fill", label: "Bedtime", binding: $editedBedtime)
            editRow(icon: "sun.max.fill", label: "Woke up", binding: $editedWakeTime)
        }
        .onChange(of: editedBedtime) { _, _ in normalizeEditedOrder() }
        .onChange(of: editedWakeTime) { _, _ in normalizeEditedOrder() }
    }

    private func editRow(icon: String, label: String, binding: Binding<Date>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(MooniColor.warning)
                .frame(width: 22)
            Text(label)
                .font(MooniFont.body(14))
                .foregroundColor(MooniColor.textSecondary)
            Spacer()
            DatePicker("", selection: binding, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .colorScheme(.dark)
        }
    }

    private func sourceChip(for entry: SleepEntry) -> some View {
        HStack(spacing: 6) {
            Image(systemName: sourceIcon(entry.resolvedSource))
                .font(.system(size: 10, weight: .semibold))
            Text(sourceLabel(entry.resolvedSource))
                .font(MooniFont.caption(11))
        }
        .foregroundColor(MooniColor.textMuted)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
    }

    private func sourceIcon(_ s: SleepDataSource) -> String {
        switch s {
        case .healthKit:           return "heart.fill"
        case .appActivityEstimate: return "wand.and.stars"
        case .userAdjusted:        return "pencil"
        }
    }

    private func sourceLabel(_ s: SleepDataSource) -> String {
        switch s {
        case .healthKit:           return "From Health"
        case .appActivityEstimate: return "Tracked from activity"
        case .userAdjusted:        return "You set this"
        }
    }

    private var accuracyPrompt: some View {
        VStack(spacing: 10) {
            Text(isEditingTimes ? "Drag the times that feel right." : "Does this match your night?")
                .font(MooniFont.body(14))
                .foregroundColor(MooniColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .animation(.easeInOut(duration: 0.25), value: isEditingTimes)

            HStack(spacing: 8) {
                accuracyChip(.spotOn)
                accuracyChip(.mostlyRight)
                accuracyChip(.wayOff)
            }
        }
    }

    private func accuracyChip(_ r: SleepAccuracyRating) -> some View {
        let selected = accuracy == r
        return Button {
            selectAccuracy(r)
        } label: {
            VStack(spacing: 6) {
                EmojiIcon(emoji: r.emoji, size: 20, tint: MooniColor.accentSoft)
                    .scaleEffect(selected ? 1.15 : 1.0)
                Text(r.label)
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(selected ? Color.white.opacity(0.22) : Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? MooniColor.warning : .white.opacity(0.08),
                            lineWidth: selected ? 1.5 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var isEditingTimes: Bool { accuracy == .wayOff }

    private func selectAccuracy(_ r: SleepAccuracyRating) {
        Haptics.tap()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            accuracy = r
        }
        if r != .wayOff, let entry = entryOverride ?? appState.entryNeedingMorningCheckIn {
            editedBedtime = entry.bedtime
            editedWakeTime = entry.wakeTime
        }
    }

    // MARK: - Reveal

    private var revealScene: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [MooniColor.warning.opacity(0.55), .clear],
                            center: .center, startRadius: 6, endRadius: 180
                        )
                    )
                    .frame(width: 340, height: 340)
                DreamSpiritView(pet: appState.pet, size: 170)
                    .scaleEffect(revealScale)
                    .shadow(color: MooniColor.warning.opacity(0.55), radius: 30)
            }
            .onAppear {
                revealScale = 0.85
                Haptics.celebrate()
                withAnimation(.spring(response: 0.95, dampingFraction: 0.6).delay(0.05)) {
                    revealScale = 1.1
                }
            }

            if let entry = savedEntry ?? entryOverride ?? appState.entryNeedingMorningCheckIn {
                VStack(spacing: 6) {
                    Text(entry.energyLevel
                         ?? SleepScoringManager.energyLevel(for: entry.readinessScore ?? entry.score))
                        .font(MooniFont.display(26))
                        .foregroundColor(MooniColor.textPrimary)
                    Text("\(appState.pet.name) \(entry.recoveryMessage ?? appState.pet.mood.message)")
                        .font(MooniFont.body(15))
                        .foregroundColor(MooniColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                MooniCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 16) {
                            SleepScoreRing(score: entry.score, size: 86, lineWidth: 9)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("\(entry.readinessScore ?? entry.score)")
                                        .font(MooniFont.display(34))
                                        .foregroundColor(MooniColor.textPrimary)
                                    Text("readiness")
                                        .font(MooniFont.caption(12))
                                        .foregroundColor(MooniColor.textSecondary)
                                }
                                Text("\(entry.formattedDuration) of sleep")
                                    .font(MooniFont.caption(13))
                                    .foregroundColor(MooniColor.textSecondary)
                            }
                            Spacer()
                        }
                        if let insight = entry.insight {
                            Text(insight)
                                .font(MooniFont.caption(13))
                                .foregroundColor(MooniColor.textSecondary)
                        }
                    }
                }

                Button {
                    Haptics.tap()
                    if subscriptionManager.isPro {
                        showStory = true
                    } else {
                        showPaywall = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: subscriptionManager.isPro ? "sparkles" : "lock.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("See your sleep story")
                            .font(MooniFont.title(15))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(MooniColor.textPrimary)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 13)
                    .frame(maxWidth: .infinity)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [MooniColor.accentSoft.opacity(0.35),
                                         MooniColor.accent.opacity(0.35)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                    )
                    .overlay(Capsule().stroke(MooniColor.accent.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            } else {
                Text("SleepOwl is still gathering last night's sleep.")
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - Copy helpers

    private func fallAsleepCaption(_ m: Int) -> String {
        switch m {
        case 0..<3:    return "Sleep was waiting for you."
        case 3..<10:   return "Sleep found you fast."
        case 10..<20:  return "A normal drift into sleep."
        case 20..<40:  return "Sleep took some coaxing."
        case 40..<70:  return "A long road to sleep tonight."
        case 70..<120: return "Sleep stayed far away."
        default:       return "Hours of tossing — that's hard."
        }
    }

    private func phoneToSleepCaption(_ m: Int) -> String {
        switch m {
        case 0..<3:   return "Phone down, lights out — beautiful."
        case 3..<10:  return "A quick, clean handoff to sleep."
        case 10..<25: return "A little wind-down after the screen."
        case 25..<45: return "The phone kept your brain buzzing a while."
        default:      return "A long gap — the screen may have delayed you."
        }
    }

    private func wakeToUpCaption(_ m: Int) -> String {
        switch m {
        case 0..<2:   return "Up and at it the moment you woke."
        case 2..<10:  return "A gentle, normal launch into the day."
        case 10..<25: return "A slow, cozy start this morning."
        case 25..<45: return "You lingered a good while in bed."
        default:      return "A long, heavy morning to get going."
        }
    }

    private func wakeUpLabel(_ w: WakeUpFrequency) -> String {
        switch w {
        case .none:     return "Slept through"
        case .once:     return "Stirred once"
        case .fewTimes: return "Up a few times"
        case .aLot:     return "Very restless"
        }
    }

    private func wakeUpEmoji(_ w: WakeUpFrequency) -> String {
        switch w {
        case .none:     return "😴"
        case .once:     return "🙂"
        case .fewTimes: return "😕"
        case .aLot:     return "😣"
        }
    }

    private func dreamEmoji(_ d: DreamRecall) -> String {
        switch d {
        case .yes:     return "💭"
        case .notSure: return "🌫️"
        case .no:      return "🌑"
        }
    }

    private func bedEmoji(_ b: BedDifficulty) -> String {
        switch b {
        case .easy:     return "🪶"
        case .normal:   return "🙂"
        case .hard:     return "😮‍💨"
        case .veryHard: return "🥵"
        }
    }

    private func bedLabel(_ b: BedDifficulty) -> String {
        switch b {
        case .easy:     return "Floated up"
        case .normal:   return "Smooth"
        case .hard:     return "Pushed through"
        case .veryHard: return "Dragged myself"
        }
    }

    private func feelingEmoji(_ f: MorningFeeling) -> String {
        switch f {
        case .great:     return "✨"
        case .okay:      return "🙂"
        case .tired:     return "😴"
        case .exhausted: return "😵‍💫"
        }
    }

    private var alcoholOptions: [(emoji: String, label: String, value: Int)] {
        [("🚫", "None", 0), ("🍷", "1", 1), ("🍻", "2", 2), ("🥂", "3+", 3)]
    }

    // MARK: - Time helpers

    private func effectiveBedtime(_ entry: SleepEntry) -> Date {
        isEditingTimes ? editedBedtime : entry.bedtime
    }

    private func effectiveWakeTime(_ entry: SleepEntry) -> Date {
        isEditingTimes ? editedWakeTime : entry.wakeTime
    }

    private func durationHours(_ entry: SleepEntry) -> String {
        let d = max(0, effectiveWakeTime(entry).timeIntervalSince(effectiveBedtime(entry)))
        return "\(Int(d) / 3600)"
    }

    private func durationMinutes(_ entry: SleepEntry) -> String {
        let d = max(0, effectiveWakeTime(entry).timeIntervalSince(effectiveBedtime(entry)))
        return String(format: "%02d", (Int(d) % 3600) / 60)
    }

    /// Keep editedBedtime strictly before editedWakeTime by sliding bedtime
    /// back a day when needed — DatePicker edits only hour/minute, so the two
    /// values can land on the same day even though they shouldn't.
    private func normalizeEditedOrder() {
        guard editedBedtime >= editedWakeTime else { return }
        let cal = Calendar.current
        editedBedtime = cal.date(byAdding: .day, value: -1, to: editedBedtime) ?? editedBedtime
    }

    // MARK: - Flow

    private func setupInitialTimes() {
        // Make sure the flow ALWAYS has a concrete entry to refine. For free
        // users (no HealthKit / no auto-capture) there may be no seeded entry
        // for last night — without this the recap shows "still settling in",
        // no times can be entered, and completeMorningCheckIn produces nothing.
        var seededPlaceholder = false
        if entryOverride == nil && appState.entryNeedingMorningCheckIn == nil {
            if appState.seedMissedNightEntry() != nil {
                seededPlaceholder = true
            }
        }

        if let entry = entryOverride ?? appState.entryNeedingMorningCheckIn {
            editedBedtime = entry.bedtime
            editedWakeTime = entry.wakeTime
        }
        if startInEditMode || seededPlaceholder {
            accuracy = .wayOff
        }
        // Re-opening from the home edit pencil is a pure time-correction —
        // jump straight to the night so the user isn't re-walked through every
        // subjective question just to nudge a bedtime.
        if startInEditMode {
            scene = .confirm
        }
    }

    private func advance() {
        // Forward navigation records that the user actually answered this
        // screen, so "Skip the rest" can leave the others as nil.
        answered.insert(scene)
        if scene == .confirm {
            save()
            withAnimation(.easeInOut(duration: 0.75)) { scene = .reveal }
            return
        }
        withAnimation(.easeInOut(duration: 0.55)) { scene = next(of: scene) }
    }

    private func next(of s: Scene) -> Scene {
        let all = Scene.allCases
        guard let i = all.firstIndex(of: s), i + 1 < all.count else { return s }
        return all[i + 1]
    }

    private func previous(of s: Scene) -> Scene {
        let all = Scene.allCases
        guard let i = all.firstIndex(of: s), i > 0 else { return s }
        return all[i - 1]
    }

    private func reached(_ s: Scene) -> Bool { answered.contains(s) }

    /// Derived legacy flag — kept populated for back-compat / analytics even
    /// though the new flow captures count + time directly.
    private var lateCaffeineDerived: Bool {
        guard caffeineCount >= 1 else { return false }
        return Calendar.current.component(.hour, from: lastCaffeineTime) >= 15
    }

    private func save() {
        let entry = entryOverride ?? appState.entryNeedingMorningCheckIn
        let date = entry?.wakeTime ?? Date()

        // Prefer the auto-captured wake→app-open delay; the self-reported
        // "wake to out of bed" gap supplements it.
        var autoDelay: Int? = nil
        if let wake = appState.wakeTappedAt,
           let opened = appState.appOpenedAfterWakeAt,
           opened > wake {
            autoDelay = max(0, Int(opened.timeIntervalSince(wake) / 60))
        }

        let onsetMins: Int? = fallAsleepUnknown ? nil : Int(fallAsleepMinutes.rounded())
        let correctedBed: Date? = isEditingTimes ? editedBedtime : nil
        let correctedWake: Date? = isEditingTimes ? editedWakeTime : nil

        let checkIn = MorningCheckIn(
            date: date,
            feeling: feeling,
            wakeUps: wakeUps,
            dreams: dreams,
            getOutOfBedDifficulty: bedDifficulty,
            lateCaffeine: reached(.caffeine) ? lateCaffeineDerived : nil,
            minutesToFallAsleep: onsetMins,
            minutesFromWakeToAppOpen: autoDelay,
            correctedBedtime: correctedBed,
            correctedWakeTime: correctedWake,
            accuracyRating: accuracy,
            minutesPhoneDownToSleep: reached(.phoneToSleep) && !phoneToSleepUnknown
                ? Int(phoneToSleepMinutes.rounded()) : nil,
            minutesWakeToOutOfBed: reached(.wakeToUp) && !wakeToUpUnknown
                ? Int(wakeToUpMinutes.rounded()) : nil,
            caffeineCount: reached(.caffeine) ? caffeineCount : nil,
            lastCaffeineTime: reached(.caffeine) && caffeineCount >= 1 ? lastCaffeineTime : nil,
            lastMealTime: reached(.lastMeal) ? lastMealTime : nil,
            lateHeavyMeal: reached(.lastMeal) ? lateHeavyMeal : nil,
            alcoholDrinks: reached(.alcohol) ? alcoholDrinks : nil,
            exerciseTime: reached(.movement) ? exerciseTime : nil,
            napMinutes: reached(.naps) ? (didNap ? Int(napMinutes.rounded()) : 0) : nil,
            stressLevel: reached(.stress) ? stressLevel : nil,
            screenInBed: nil,
            roomFeel: reached(.roomTemp) ? roomFeel : nil,
            bedtimeWasLate: nil
        )
        savedEntry = appState.completeMorningCheckIn(checkIn)
    }
}

#Preview {
    MorningCheckInView()
        .environmentObject(AppState.preview)
        .environmentObject(SubscriptionManager.shared)
}
