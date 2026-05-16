import SwiftUI

/// Morning check-in told as a 5-scene dawn unfolding. The pet narrates,
/// the background morphs from deep night toward sunrise, and each scene
/// captures the data we need to refine last night's score.
struct MorningCheckInView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    /// When set, this entry replaces `appState.entryNeedingMorningCheckIn`
    /// as the subject of the flow — used when the user re-opens the
    /// check-in from the home screen to edit or add a missed night.
    var entryOverride: SleepEntry? = nil

    /// When true, the flow opens directly in "way off" edit-times mode
    /// so the user can correct bedtime / wake immediately. Used for the
    /// home-screen edit pencil and the missed-night entry point.
    var startInEditMode: Bool = false

    @State private var scene: Scene = .night

    // Night scene — recap + accuracy
    @State private var accuracy: SleepAccuracyRating? = nil
    @State private var editedBedtime: Date = Date()
    @State private var editedWakeTime: Date = Date()

    // Onset scene — slider
    @State private var fallAsleepMinutes: Double = 12
    @State private var fallAsleepUnknown: Bool = false

    // Between scene
    @State private var wakeUps: WakeUpFrequency = .none
    @State private var dreams: DreamRecall = .notSure

    // Morning scene
    @State private var feeling: MorningFeeling = .okay
    @State private var bedDifficulty: BedDifficulty = .normal

    // Echoes scene
    @State private var caffeine: CaffeineChoice = .notSure

    // Reveal scene
    @State private var revealScale: CGFloat = 0.85
    @State private var savedEntry: SleepEntry?
    @State private var showStory = false

    enum Scene: Int, CaseIterable, Hashable {
        // One question per screen.
        case night, onset, restless, dreams, morning, outOfBed, echoes, reveal

        var progressIndex: Int? {
            switch self {
            case .night:    return 0
            case .onset:    return 1
            case .restless: return 2
            case .dreams:   return 3
            case .morning:  return 4
            case .outOfBed: return 5
            case .echoes:   return 6
            case .reveal:   return nil
            }
        }

        /// Number of question screens (drives the progress dots).
        static let questionCount = 7

        var showsDots: Bool { self != .reveal }
    }

    private enum CaffeineChoice: String, CaseIterable, Identifiable {
        case yes, no, notSure
        var id: String { rawValue }

        var label: String {
            switch self {
            case .yes: return "Yes"
            case .no: return "No"
            case .notSure: return "Can't recall"
            }
        }

        var emoji: String {
            switch self {
            case .yes: return "☕️"
            case .no: return "🚫"
            case .notSure: return "🤷"
            }
        }

        var value: Bool? {
            switch self {
            case .yes: return true
            case .no: return false
            case .notSure: return nil
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

                progressDots
                    .padding(.horizontal, 22)
                    .padding(.top, 14)
                    .opacity(scene.showsDots ? 1 : 0)

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        Color.clear.frame(height: 1).id("top")
                        sceneContent
                            .id(scene)
                            .transition(.opacity)
                            .padding(.horizontal, 22)
                            .padding(.top, 18)
                            // Generous gap so the last control is never
                            // adjacent to the Continue button.
                            .padding(.bottom, 40)
                            .frame(maxWidth: .infinity)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: scene) { _, _ in
                        // Each screen starts at the top — no carried-over
                        // scroll offset, so it never "jumps".
                        proxy.scrollTo("top", anchor: .top)
                    }
                }

                footer
                    .padding(.horizontal, 22)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
                    .background(
                        // Visually separates the action bar from the
                        // scrolling content so accidental taps stop.
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
        }
        .interactiveDismissDisabled(scene != .reveal)
        .onAppear(perform: setupInitialTimes)
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
                    onFinished: { showStory = false }
                )
            }
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [Color(red: 0.03, green: 0.04, blue: 0.16),
                     Color(red: 0.08, green: 0.08, blue: 0.24)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private func gradient(for s: Scene) -> LinearGradient {
        switch s {
        case .night:
            return LinearGradient(
                colors: [Color(red: 0.03, green: 0.04, blue: 0.16),
                         Color(red: 0.08, green: 0.08, blue: 0.24)],
                startPoint: .top, endPoint: .bottom
            )
        case .onset:
            return LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.20),
                         Color(red: 0.14, green: 0.10, blue: 0.30)],
                startPoint: .top, endPoint: .bottom
            )
        case .restless, .dreams:
            return LinearGradient(
                colors: [Color(red: 0.09, green: 0.07, blue: 0.26),
                         Color(red: 0.32, green: 0.18, blue: 0.36)],
                startPoint: .top, endPoint: .bottom
            )
        case .morning, .outOfBed:
            return LinearGradient(
                colors: [Color(red: 0.20, green: 0.13, blue: 0.30),
                         Color(red: 0.55, green: 0.30, blue: 0.40)],
                startPoint: .top, endPoint: .bottom
            )
        case .echoes:
            return LinearGradient(
                colors: [Color(red: 0.30, green: 0.18, blue: 0.34),
                         Color(red: 0.72, green: 0.42, blue: 0.40)],
                startPoint: .top, endPoint: .bottom
            )
        case .reveal:
            return LinearGradient(
                colors: [Color(red: 0.10, green: 0.07, blue: 0.25),
                         Color(red: 0.34, green: 0.20, blue: 0.38)],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    private var starOpacity: Double {
        switch scene {
        case .night, .onset:    return 0.55
        case .restless, .dreams: return 0.40
        case .morning, .outOfBed: return 0.22
        case .echoes:           return 0.10
        case .reveal:           return 0.30
        }
    }

    // MARK: - Chrome

    private var topBar: some View {
        HStack {
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

    private var progressDots: some View {
        let count = Scene.questionCount
        let current = scene.progressIndex ?? -1
        return HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { idx in
                Capsule()
                    .fill(idx <= current ? MooniColor.warning : Color.white.opacity(0.18))
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)
                    .animation(.spring(response: 0.45), value: current)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if scene == .reveal {
                PrimaryButton(title: "Done", icon: "checkmark") { dismiss() }
                    .frame(maxWidth: 320)
            } else {
                if scene != .night {
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
        case .night:   return "Continue"
        case .echoes:  return "See last night"
        default:       return "Next"
        }
    }

    private var canAdvance: Bool {
        switch scene {
        case .night: return accuracy != nil
        default:     return true
        }
    }

    // MARK: - Scenes router

    @ViewBuilder
    private var sceneContent: some View {
        switch scene {
        case .night:    nightScene
        case .onset:    onsetScene
        case .restless: restlessScene
        case .dreams:   dreamsScene
        case .morning:  morningScene
        case .outOfBed: outOfBedScene
        case .echoes:   echoesScene
        case .reveal:   revealScene
        }
    }

    // MARK: - Scene 1: The Night

    private var nightScene: some View {
        VStack(spacing: 22) {
            spirit(size: 120)
                .padding(.top, 4)

            VStack(spacing: 6) {
                Text("Good morning")
                    .font(MooniFont.display(34))
                    .foregroundColor(MooniColor.textPrimary)
                Text("\(appState.pet.name) watched over you.")
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.accentSoft)
            }

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
                    editTimesView
                        .transition(.opacity)
                } else {
                    timesSummary(entry: entry)
                        .transition(.opacity)
                }

                sourceChip(for: entry)
            }
        }
    }

    private func timesSummary(entry: SleepEntry) -> some View {
        HStack(spacing: 14) {
            timeColumn(icon: "moon.fill",
                       label: "Bedtime",
                       value: effectiveBedtime(entry).hourMinuteString)
            Image(systemName: "arrow.right")
                .foregroundColor(MooniColor.textMuted)
                .font(.system(size: 13, weight: .semibold))
            timeColumn(icon: "sun.max.fill",
                       label: "Woke up",
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
        case .healthKit:          return "heart.fill"
        case .appActivityEstimate: return "wand.and.stars"
        case .userAdjusted:        return "pencil"
        }
    }

    private func sourceLabel(_ s: SleepDataSource) -> String {
        switch s {
        case .healthKit:          return "From Health"
        case .appActivityEstimate: return "Estimated from activity"
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

    // MARK: - Scene 2: Onset (slider)

    private var onsetScene: some View {
        VStack(spacing: 24) {
            spirit(size: 90)

            VStack(spacing: 6) {
                Text("How long did it take")
                    .font(MooniFont.display(26))
                    .foregroundColor(MooniColor.textPrimary)
                Text("to fall asleep?")
                    .font(MooniFont.display(26))
                    .foregroundColor(MooniColor.textPrimary)
            }
            .multilineTextAlignment(.center)

            VStack(spacing: 4) {
                Text(fallAsleepDisplay)
                    .font(MooniFont.display(44))
                    .foregroundColor(MooniColor.warning)
                    .contentTransition(.numericText())
                Text(fallAsleepCaption)
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 38)
            }
            .opacity(fallAsleepUnknown ? 0.30 : 1.0)
            .animation(.easeInOut(duration: 0.25), value: fallAsleepUnknown)

            starSlider
                .padding(.horizontal, 4)
                .padding(.top, 4)

            HStack {
                Text("instant")
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.textMuted)
                Spacer()
                Text("3+ hours")
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.textMuted)
            }
            .padding(.horizontal, 4)
            .opacity(fallAsleepUnknown ? 0.4 : 1)

            Toggle(isOn: $fallAsleepUnknown.animation(.easeInOut(duration: 0.2))) {
                Text("I'm not sure")
                    .font(MooniFont.body(13))
                    .foregroundColor(MooniColor.textSecondary)
            }
            .tint(MooniColor.warning)
            .padding(.horizontal, 40)
            .padding(.top, 8)
        }
    }

    private var fallAsleepDisplay: String {
        let m = Int(fallAsleepMinutes.rounded())
        if m >= 60 {
            let h = m / 60
            let rem = m % 60
            return rem == 0 ? "\(h) hr" : "\(h)h \(rem)m"
        }
        return "\(m) min"
    }

    private var fallAsleepCaption: String {
        let m = Int(fallAsleepMinutes.rounded())
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

    private var starSlider: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let pct = CGFloat(min(1, max(0, fallAsleepMinutes / 180)))
            let thumbX = pct * width

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 8)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [MooniColor.accent, MooniColor.warning],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(8, thumbX), height: 8)
                Image(systemName: "star.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(MooniColor.warning)
                    .shadow(color: MooniColor.warning.opacity(0.6), radius: 12)
                    .offset(x: thumbX - 12)
            }
            .frame(height: 36)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        guard !fallAsleepUnknown else { return }
                        let clamped = max(0, min(width, drag.location.x))
                        let raw = Double(clamped / max(1, width)) * 180.0
                        let rounded = raw.rounded()
                        if rounded != fallAsleepMinutes { Haptics.tick() }
                        fallAsleepMinutes = rounded
                    }
            )
        }
        .frame(height: 36)
        .opacity(fallAsleepUnknown ? 0.35 : 1.0)
    }

    // MARK: - Scene 3: Restless? (emoji slider)

    private var restlessScene: some View {
        VStack(spacing: 28) {
            spirit(size: 90)

            VStack(spacing: 4) {
                Text("Restless last night?")
                    .font(MooniFont.display(26))
                    .foregroundColor(MooniColor.textPrimary)
                Text("Drag to how often you stirred.")
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textSecondary)
            }
            .multilineTextAlignment(.center)

            EmojiScaleSlider(
                stops: WakeUpFrequency.allCases.map {
                    (wakeUpEmoji($0), wakeUpLabel($0))
                },
                index: Binding(
                    get: { WakeUpFrequency.allCases.firstIndex(of: wakeUps) ?? 0 },
                    set: { wakeUps = WakeUpFrequency.allCases[$0] }
                )
            )
            .padding(.top, 6)
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

    // MARK: - Scene 4: Dreams?

    private var dreamsScene: some View {
        VStack(spacing: 28) {
            spirit(size: 90)

            VStack(spacing: 4) {
                Text("Did dreams visit you?")
                    .font(MooniFont.display(26))
                    .foregroundColor(MooniColor.textPrimary)
            }
            .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                ForEach(DreamRecall.allCases) { d in
                    iconChoiceCard(
                        emoji: dreamEmoji(d),
                        label: d.label,
                        selected: dreams == d
                    ) {
                        withAnimation(.spring(response: 0.3)) { dreams = d }
                    }
                }
            }
        }
    }

    private func dreamEmoji(_ d: DreamRecall) -> String {
        switch d {
        case .yes:     return "💭"
        case .notSure: return "🌫️"
        case .no:      return "🌑"
        }
    }

    // MARK: - Scene 5: This morning (feeling)

    private var morningScene: some View {
        VStack(spacing: 28) {
            spirit(size: 90)

            VStack(spacing: 4) {
                Text("And now you're here.")
                    .font(MooniFont.display(26))
                    .foregroundColor(MooniColor.textPrimary)
                Text("How does this morning feel?")
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textSecondary)
            }
            .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                ForEach(MorningFeeling.allCases) { f in
                    feelingCard(f)
                }
            }
        }
    }

    // MARK: - Scene 6: Out of bed? (emoji slider)

    private var outOfBedScene: some View {
        VStack(spacing: 28) {
            spirit(size: 90)

            VStack(spacing: 4) {
                Text("Getting out of bed?")
                    .font(MooniFont.display(26))
                    .foregroundColor(MooniColor.textPrimary)
                Text("Drag to how hard it felt.")
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textSecondary)
            }
            .multilineTextAlignment(.center)

            EmojiScaleSlider(
                stops: BedDifficulty.allCases.map {
                    (bedEmoji($0), bedLabel($0))
                },
                index: Binding(
                    get: { BedDifficulty.allCases.firstIndex(of: bedDifficulty) ?? 1 },
                    set: { bedDifficulty = BedDifficulty.allCases[$0] }
                )
            )
            .padding(.top, 6)
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

    private func feelingEmoji(_ f: MorningFeeling) -> String {
        switch f {
        case .great:     return "✨"
        case .okay:      return "🙂"
        case .tired:     return "😴"
        case .exhausted: return "😵‍💫"
        }
    }

    private func feelingCard(_ f: MorningFeeling) -> some View {
        let selected = feeling == f
        return Button {
            Haptics.tap()
            withAnimation(.spring(response: 0.3)) { feeling = f }
        } label: {
            VStack(spacing: 6) {
                Text(feelingEmoji(f))
                    .font(.system(size: 30))
                    .scaleEffect(selected ? 1.18 : 1.0)
                Text(f.label)
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(selected ? Color.white.opacity(0.22) : Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? MooniColor.warning : .white.opacity(0.08),
                            lineWidth: selected ? 1.5 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func bedLabel(_ b: BedDifficulty) -> String {
        switch b {
        case .easy:     return "Floated up"
        case .normal:   return "Smooth"
        case .hard:     return "Pushed through"
        case .veryHard: return "Dragged myself"
        }
    }

    // MARK: - Scene 5: Yesterday's Echoes

    private var echoesScene: some View {
        VStack(spacing: 26) {
            spirit(size: 90)

            VStack(spacing: 6) {
                Text("Yesterday's echoes")
                    .font(MooniFont.display(26))
                    .foregroundColor(MooniColor.textPrimary)
                Text("What you did yesterday shapes tonight.")
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
            }

            VStack(spacing: 14) {
                Text("Caffeine after 3 pm?")
                    .font(MooniFont.title(17))
                    .foregroundColor(MooniColor.textPrimary)
                HStack(spacing: 10) {
                    ForEach(CaffeineChoice.allCases) { c in
                        caffeineCard(c)
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    private func caffeineCard(_ c: CaffeineChoice) -> some View {
        let selected = caffeine == c
        return Button {
            Haptics.tap()
            withAnimation(.spring(response: 0.3)) { caffeine = c }
        } label: {
            VStack(spacing: 8) {
                EmojiIcon(emoji: c.emoji, size: 26, tint: MooniColor.accentSoft)
                    .scaleEffect(selected ? 1.15 : 1.0)
                Text(c.label)
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(selected ? Color.white.opacity(0.22) : Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(selected ? MooniColor.warning : .white.opacity(0.08),
                            lineWidth: selected ? 1.5 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Scene 6: Reveal

    private var revealScene: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [MooniColor.warning.opacity(0.55), .clear],
                            center: .center,
                            startRadius: 6,
                            endRadius: 180
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
                    showStory = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
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

    // MARK: - Shared building blocks

    private func spirit(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [spiritGlowColor.opacity(0.35), .clear],
                        center: .center,
                        startRadius: 4,
                        endRadius: size
                    )
                )
                .frame(width: size * 1.9, height: size * 1.9)
            DreamSpiritView(pet: appState.pet, size: size)
        }
    }

    private var spiritGlowColor: Color {
        switch scene {
        case .night, .onset:                       return MooniColor.accent
        case .restless, .dreams:                   return MooniColor.accentSoft
        case .morning, .outOfBed, .echoes, .reveal: return MooniColor.warning
        }
    }

    /// A big tappable emoji+label card — used for the few questions that
    /// are genuine discrete choices (dreams, caffeine) rather than a scale.
    private func iconChoiceCard(emoji: String,
                                label: String,
                                selected: Bool,
                                action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            VStack(spacing: 10) {
                Text(emoji)
                    .font(.system(size: 34))
                    .scaleEffect(selected ? 1.15 : 1.0)
                Text(label)
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(selected ? Color.white.opacity(0.22) : Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(selected ? MooniColor.warning : .white.opacity(0.08),
                            lineWidth: selected ? 1.5 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
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
    /// back a day when needed — DatePicker edits only hour/minute, so the
    /// two values can land on the same day even though they shouldn't.
    private func normalizeEditedOrder() {
        guard editedBedtime >= editedWakeTime else { return }
        let cal = Calendar.current
        editedBedtime = cal.date(byAdding: .day, value: -1, to: editedBedtime) ?? editedBedtime
    }

    // MARK: - Flow

    private func setupInitialTimes() {
        if let entry = entryOverride ?? appState.entryNeedingMorningCheckIn {
            editedBedtime = entry.bedtime
            editedWakeTime = entry.wakeTime
        }
        if startInEditMode {
            accuracy = .wayOff
        }
    }

    private func advance() {
        if scene == .echoes {
            save()
            withAnimation(.easeInOut(duration: 0.75)) { scene = .reveal }
            return
        }
        withAnimation(.easeInOut(duration: 0.55)) { scene = next(of: scene) }
    }

    private func next(of s: Scene) -> Scene {
        switch s {
        case .night:    return .onset
        case .onset:    return .restless
        case .restless: return .dreams
        case .dreams:   return .morning
        case .morning:  return .outOfBed
        case .outOfBed: return .echoes
        case .echoes:   return .reveal
        case .reveal:   return .reveal
        }
    }

    private func previous(of s: Scene) -> Scene {
        switch s {
        case .night:    return .night
        case .onset:    return .night
        case .restless: return .onset
        case .dreams:   return .restless
        case .morning:  return .dreams
        case .outOfBed: return .morning
        case .echoes:   return .outOfBed
        case .reveal:   return .echoes
        }
    }

    private func save() {
        let entry = entryOverride ?? appState.entryNeedingMorningCheckIn
        let date = entry?.wakeTime ?? Date()

        // Prefer auto-captured wake→app-open delay; this question was
        // removed from the user-facing flow.
        var delay: Int? = nil
        if let wake = appState.wakeTappedAt,
           let opened = appState.appOpenedAfterWakeAt,
           opened > wake {
            delay = max(0, Int(opened.timeIntervalSince(wake) / 60))
        }

        let mins: Int? = fallAsleepUnknown ? nil : Int(fallAsleepMinutes.rounded())

        let correctedBed: Date? = isEditingTimes ? editedBedtime : nil
        let correctedWake: Date? = isEditingTimes ? editedWakeTime : nil

        let checkIn = MorningCheckIn(
            date: date,
            feeling: feeling,
            wakeUps: wakeUps,
            dreams: dreams,
            getOutOfBedDifficulty: bedDifficulty,
            lateCaffeine: caffeine.value,
            minutesToFallAsleep: mins,
            minutesFromWakeToAppOpen: delay,
            correctedBedtime: correctedBed,
            correctedWakeTime: correctedWake,
            accuracyRating: accuracy
        )
        savedEntry = appState.completeMorningCheckIn(checkIn)
    }
}

/// A horizontal slider that snaps between discrete emoji+label stops.
/// Almost nothing to read — you drag a thumb and the big emoji + one
/// short label update live. Used for the subjective scale questions.
private struct EmojiScaleSlider: View {
    let stops: [(emoji: String, label: String)]
    @Binding var index: Int

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 8) {
                Text(stops[safe: index]?.emoji ?? "🙂")
                    .font(.system(size: 66))
                    .contentTransition(.opacity)
                    .id(index)
                Text(stops[safe: index]?.label ?? "")
                    .font(MooniFont.title(20))
                    .foregroundColor(MooniColor.warning)
                    .contentTransition(.opacity)
            }

            GeometryReader { geo in
                let count = max(2, stops.count)
                let w = geo.size.width
                let stepW = w / CGFloat(count - 1)
                let clampedIndex = min(count - 1, max(0, index))
                let fillW = stepW * CGFloat(clampedIndex)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 6)
                    Capsule()
                        .fill(MooniColor.warning)
                        .frame(width: max(6, fillW), height: 6)

                    ForEach(0..<count, id: \.self) { i in
                        Circle()
                            .fill(i <= clampedIndex ? MooniColor.warning : Color.white.opacity(0.22))
                            .frame(width: 9, height: 9)
                            .offset(x: stepW * CGFloat(i) - 4.5)
                    }

                    Circle()
                        .fill(MooniColor.warning)
                        .frame(width: 30, height: 30)
                        .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 2))
                        .shadow(color: MooniColor.warning.opacity(0.6), radius: 8)
                        .offset(x: fillW - 15)
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            let raw = max(0, min(w, v.location.x))
                            let i = Int((raw / stepW).rounded())
                            let clamped = min(count - 1, max(0, i))
                            if clamped != index {
                                Haptics.tap()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    index = clamped
                                }
                            }
                        }
                )
            }
            .frame(height: 44)

            HStack {
                Text(stops.first?.label ?? "")
                Spacer()
                Text(stops.last?.label ?? "")
            }
            .font(MooniFont.caption(11))
            .foregroundColor(MooniColor.textMuted)
        }
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? {
        indices.contains(i) ? self[i] : nil
    }
}

#Preview {
    MorningCheckInView().environmentObject(AppState.preview)
}
