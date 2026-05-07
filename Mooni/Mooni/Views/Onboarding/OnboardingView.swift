import SwiftUI
import Combine

/// Extended high-converting onboarding flow.
///
/// Roughly 30 screens, designed to:
/// 1. Build emotional investment (pet, name, demo) before asking for anything
/// 2. Personalize through age/height/weight/behavior questions
/// 3. Surface a believable "we analyzed you" plan with a derived sleep score
/// 4. Drive commitment with a 3-stage pre-paywall animation
/// 5. Convert with the main paywall (hidden X) → discount paywall fallback
struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var health = HealthKitManager.shared
    @StateObject private var notifications = NotificationManager.shared

    // MARK: - Wizard state
    @State private var step: Step = .hero
    @State private var transitionDirection: TransitionDirection = .forward

    // Pet
    @State private var species: PetSpecies = .owl
    @State private var petName: String = PetSpecies.owl.defaultName

    // Goal & schedule
    @State private var sleepGoal: SleepGoal? = nil
    @State private var bedtime: Date = Date.todayAt(hour: 22, minute: 45)
    @State private var wakeTime: Date = Date.todayAt(hour: 7, minute: 0)
    @State private var weekendWake: Date = Date.todayAt(hour: 8, minute: 30)
    @State private var separateWeekends: Bool = false

    // Room
    @State private var room: PetRoom = .moonBedroom

    // Onboarding profile (the new personalization data)
    @State private var profile: OnboardingProfile = OnboardingProfile()

    // Demo screen state
    @State private var demoStage: Int = 0   // 0 short / 1 long / 2 consistent

    // Loading screens
    @State private var planMessageIndex: Int = 0
    @State private var planProgress: Double = 0
    @State private var analyzingProgress: Double = 0
    @State private var analyzingStep: Int = 0

    // Paywall flow
    @State private var paywallSheet: PaywallStage? = nil

    // MARK: - Step Enum
    enum Step: Int, CaseIterable {
        case hero
        case sleepImpactStat
        case pickPet
        case namePet
        case bondMessage              // emotional copy after naming
        case demo
        case ageQuestion
        case genderQuestion
        case heightQuestion
        case weightQuestion
        case bodyFact                 // animated chart: how body shapes sleep needs
        case sleepGoal
        case motivationQuestion
        case struggleDuration
        case biggestProblem
        case typicalSleepHours
        case sleepDebtFact            // animated chart: sleep debt accumulating
        case phoneBeforeBed
        case phoneScreenTime
        case phoneFact                // animated melatonin/blue-light chart
        case caffeineCutoff
        case caffeineFact             // animated half-life decay chart
        case stressLevel
        case racingThoughts
        case stressFact               // animated cortisol curve
        case wakeFeeling
        case energyDip
        case napsDay
        case dayCycleFact             // circadian rhythm animation
        case roomEnvironment
        case environmentFact          // light/noise impact mini-chart
        case schedule
        case reflection
        case roomPicker
        case notificationPerm
        case healthPerm
        case analyzingAnswers         // loading 1 (long, variable)
        case sleepScoreReveal
        case topIssues
        case generatingPlan           // loading 2 (long, variable)
        case socialProof
        case simulatedResult
        case firstQuest
        case prePaywall               // 3-stage emotional pre-paywall

        var index: Int {
            Step.allCases.firstIndex(of: self) ?? 0
        }

        static var total: Int { Step.allCases.count }
    }

    enum TransitionDirection { case forward, backward }
    enum PaywallStage: Identifiable {
        case main
        case discount
        var id: String {
            switch self { case .main: return "main"; case .discount: return "discount" }
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Single, calm constant background everywhere — no per-screen swaps.
            MooniColor.background
                .ignoresSafeArea()
            StarsBackground(count: 80)

            if step == .prePaywall {
                // Pre-paywall takes over the screen — its own progress dots,
                // its own footer, no outer onboarding chrome.
                PrePaywallView(
                    petName: petName,
                    species: species,
                    profile: profile,
                    onContinue: { paywallSheet = .main }
                )
                .transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, 20)
                        .padding(.top, 14)

                    ScrollView(showsIndicators: false) {
                        content
                            .padding(.top, 16)
                            .frame(maxWidth: .infinity)
                            .id(step)
                            .transition(transition)
                    }

                    footer
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)
                }
                .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(item: $paywallSheet) { stage in
            switch stage {
            case .main:
                PaywallView(
                    hideCloseButton: true,
                    onSoftDismiss: {
                        paywallSheet = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            paywallSheet = .discount
                        }
                    },
                    onPurchased: {
                        paywallSheet = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            finishOnboarding()
                        }
                    }
                )
            case .discount:
                DiscountPaywallView(
                    petName: petName,
                    onAccept: {
                        paywallSheet = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            finishOnboarding()
                        }
                    },
                    onDecline: {
                        paywallSheet = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            finishOnboarding()
                        }
                    }
                )
            }
        }
    }

    // MARK: - Transition

    private var transition: AnyTransition {
        switch transitionDirection {
        case .forward:
            return .asymmetric(
                insertion: .opacity.combined(with: .move(edge: .trailing)),
                removal: .opacity.combined(with: .move(edge: .leading)))
        case .backward:
            return .asymmetric(
                insertion: .opacity.combined(with: .move(edge: .leading)),
                removal: .opacity.combined(with: .move(edge: .trailing)))
        }
    }

    // MARK: - Top progress bar

    private var topBar: some View {
        HStack(spacing: 12) {
            if step.index > 0 && !isLoadingScreen {
                Button {
                    goBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(MooniColor.textSecondary)
                        .padding(8)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Circle())
                }
                .transition(.opacity)
            } else {
                Spacer().frame(width: 32, height: 32)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10))
                    Capsule()
                        .fill(LinearGradient(
                            colors: [MooniColor.accentSoft, MooniColor.accent],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(step.index + 1) / CGFloat(Step.total))
                        .animation(.spring(response: 0.4), value: step)
                }
            }
            .frame(height: 4)

            Text("\(step.index + 1)/\(Step.total)")
                .font(MooniFont.mono(11))
                .foregroundColor(MooniColor.textMuted)
                .frame(minWidth: 32)
        }
    }

    private var isLoadingScreen: Bool {
        step == .analyzingAnswers || step == .generatingPlan
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch step {
        case .hero:                HeroScreen(species: species)
        case .sleepImpactStat:     SleepImpactStatScreen()
        case .pickPet:             PickPetScreen(selected: $species, onPick: { picked in
            species = picked
            petName = picked.defaultName
        })
        case .namePet:             NamePetScreen(species: species, name: $petName)
        case .bondMessage:         BondMessageScreen(petName: petName, species: species)
        case .demo:                DemoScreen(species: species, stage: $demoStage)
        case .ageQuestion:         AgeScreen(profile: $profile)
        case .genderQuestion:      GenderScreen(profile: $profile)
        case .heightQuestion:      HeightScreen(profile: $profile)
        case .weightQuestion:      WeightScreen(profile: $profile)
        case .bodyFact:            BodyFactScreen(profile: profile)
        case .sleepGoal:           GoalScreen(selection: $sleepGoal)
        case .motivationQuestion:  MotivationScreen(profile: $profile)
        case .struggleDuration:    StruggleDurationScreen(profile: $profile)
        case .biggestProblem:      BiggestProblemScreen(profile: $profile)
        case .typicalSleepHours:   TypicalSleepHoursScreen(profile: $profile)
        case .sleepDebtFact:       SleepDebtFactScreen(profile: profile)
        case .phoneBeforeBed:      PhoneBeforeBedScreen(profile: $profile)
        case .phoneScreenTime:     PhoneScreenTimeScreen(profile: $profile)
        case .phoneFact:           PhoneFactScreen(profile: profile)
        case .caffeineCutoff:      CaffeineCutoffScreen(profile: $profile)
        case .caffeineFact:        CaffeineFactScreen()
        case .stressLevel:         StressLevelScreen(profile: $profile)
        case .racingThoughts:      RacingThoughtsScreen(profile: $profile, petName: petName)
        case .stressFact:          StressFactScreen()
        case .wakeFeeling:         WakeFeelingScreen(profile: $profile)
        case .energyDip:           EnergyDipScreen(profile: $profile)
        case .napsDay:             NapsScreen(profile: $profile)
        case .dayCycleFact:        DayCycleFactScreen()
        case .roomEnvironment:     RoomEnvironmentScreen(profile: $profile)
        case .environmentFact:     EnvironmentFactScreen(profile: profile)
        case .schedule:            ScheduleScreen(bedtime: $bedtime, wakeTime: $wakeTime,
                                                  separateWeekends: $separateWeekends, weekendWake: $weekendWake)
        case .reflection:          ReflectionScreen(petName: petName, bedtime: bedtime, wakeTime: wakeTime)
        case .roomPicker:          RoomPickerScreen(species: species, name: petName, selection: $room)
        case .notificationPerm:    NotificationPermissionScreen(petName: petName, state: notifications.authState)
        case .healthPerm:          HealthPermissionScreen(petName: petName, state: health.authState)
        case .analyzingAnswers:
            AnalyzingAnswersScreen(progress: $analyzingProgress, currentStep: $analyzingStep, petName: petName)
                .onAppear { runAnalyzingAnimation() }
        case .sleepScoreReveal:    SleepScoreRevealScreen(profile: profile, petName: petName)
        case .topIssues:           TopIssuesScreen(profile: profile)
        case .generatingPlan:
            GeneratingPlanScreen(progress: $planProgress, messageIndex: $planMessageIndex, petName: petName)
                .onAppear { runGeneratingAnimation() }
        case .socialProof:         SocialProofScreen()
        case .simulatedResult:     SimulatedResultScreen(species: species, name: petName)
        case .firstQuest:          FirstQuestScreen(petName: petName, bedtime: bedtime, wakeTime: wakeTime)
        case .prePaywall:          EmptyView()    // rendered full-screen above; never reaches here
        }
    }

    // MARK: - Footer

    private var footer: some View {
        Group {
            switch step {
            case .notificationPerm:
                VStack(spacing: 10) {
                    PrimaryButton(title: "Yes, remind me", icon: "bell.fill") {
                        Task {
                            if notifications.authState == .notDetermined {
                                _ = await notifications.requestAuthorization()
                            }
                            advance()
                        }
                    }
                    SecondaryButton(title: "Not now") { advance() }
                }
            case .healthPerm:
                VStack(spacing: 10) {
                    PrimaryButton(
                        title: health.authState == .authorized ? "Continue" : "Connect Apple Health",
                        icon: health.authState == .authorized ? "checkmark.seal.fill" : "heart.text.square.fill"
                    ) {
                        Task {
                            if health.authState == .notDetermined && health.isAvailable {
                                _ = await health.requestAuthorization()
                                if health.authState == .authorized {
                                    await appState.importHealthKitSleep()
                                }
                            }
                            advance()
                        }
                    }
                    if health.authState != .authorized {
                        SecondaryButton(title: "I'll add sleep manually") { advance() }
                    }
                }
            case .analyzingAnswers, .generatingPlan, .prePaywall:
                EmptyView()
            default:
                PrimaryButton(title: primaryTitle) { advance() }
                    .disabled(!canAdvance)
                    .opacity(canAdvance ? 1 : 0.55)
            }
        }
    }

    private var primaryTitle: String {
        switch step {
        case .hero:               return "Meet your sleep pet"
        case .sleepImpactStat:    return "Continue"
        case .pickPet:            return "Choose \(species.defaultName)"
        case .namePet:            return "\(petName.isEmpty ? species.defaultName : petName) is officially yours"
        case .bondMessage:        return "Continue"
        case .demo:               return demoStage < 2 ? "Continue" : "I get it"
        case .ageQuestion:        return profile.age == nil ? "Pick an age" : "Continue"
        case .genderQuestion:     return "Continue"
        case .heightQuestion:     return profile.heightCm == nil ? "Set your height" : "Continue"
        case .weightQuestion:     return profile.weightKg == nil ? "Set your weight" : "Continue"
        case .bodyFact:           return "Got it"
        case .sleepGoal:          return sleepGoal == nil ? "Pick one to continue" : "Continue"
        case .motivationQuestion: return "Continue"
        case .struggleDuration:   return "Continue"
        case .biggestProblem:     return "Continue"
        case .typicalSleepHours:  return "Continue"
        case .sleepDebtFact:      return "I want to fix this"
        case .phoneBeforeBed:     return "Continue"
        case .phoneScreenTime:    return "Continue"
        case .phoneFact:          return "I get it"
        case .caffeineCutoff:     return "Continue"
        case .caffeineFact:       return "Wow, continue"
        case .stressLevel:        return "Continue"
        case .racingThoughts:     return "Continue"
        case .stressFact:         return "Continue"
        case .wakeFeeling:        return "Continue"
        case .energyDip:          return "Continue"
        case .napsDay:            return "Continue"
        case .dayCycleFact:       return "Continue"
        case .roomEnvironment:    return "Continue"
        case .environmentFact:    return "Continue"
        case .schedule:           return "Continue"
        case .reflection:         return "Continue"
        case .roomPicker:         return "Build \(petName)'s room"
        case .sleepScoreReveal:   return "Show me the issues"
        case .topIssues:          return "Build my plan"
        case .socialProof:        return "Continue"
        case .simulatedResult:    return "See how it works"
        case .firstQuest:         return "Accept tonight's quest"
        default:                  return "Continue"
        }
    }

    private var canAdvance: Bool {
        switch step {
        case .pickPet:           return true
        case .namePet:           return !petName.trimmingCharacters(in: .whitespaces).isEmpty
        case .ageQuestion:       return profile.age != nil
        case .heightQuestion:    return profile.heightCm != nil
        case .weightQuestion:    return profile.weightKg != nil
        case .sleepGoal:         return sleepGoal != nil
        default:                 return true
        }
    }

    // MARK: - Navigation

    private func advance() {
        // Demo screen has 3 sub-stages
        if step == .demo && demoStage < 2 {
            withAnimation(.easeInOut) { demoStage += 1 }
            return
        }
        let nextIndex = step.index + 1
        guard nextIndex < Step.total else { return }
        transitionDirection = .forward
        withAnimation(.easeInOut(duration: 0.35)) {
            step = Step.allCases[nextIndex]
        }
    }

    private func goBack() {
        if step == .demo && demoStage > 0 {
            withAnimation(.easeInOut) { demoStage -= 1 }
            return
        }
        let prevIndex = step.index - 1
        guard prevIndex >= 0 else { return }
        transitionDirection = .backward
        withAnimation(.easeInOut(duration: 0.35)) {
            step = Step.allCases[prevIndex]
        }
    }

    // MARK: - Loading animations
    //
    // Both loops use uneven progress jumps + uneven dwell times so it feels like
    // real work is happening — *not* a constant-rate progress bar.

    /// (progressTarget, secondsToHoldAfterReaching) per step.
    private static let analyzingScript: [(Double, Double)] = [
        (0.06, 0.9),   // reading answers (slow start)
        (0.14, 1.4),   // mapping chronotype (long pause — feels deep)
        (0.27, 0.7),
        (0.31, 1.6),   // calculating debt (long pause)
        (0.46, 0.8),
        (0.58, 1.3),   // identifying issues
        (0.63, 0.6),
        (0.78, 1.2),
        (0.86, 0.6),
        (0.94, 1.0),
        (1.00, 0.6)
    ]

    private static let generatingScript: [(Double, Double)] = [
        (0.04, 0.7),
        (0.11, 1.2),   // building bedtime quest
        (0.19, 0.8),
        (0.26, 1.6),   // tuning wake-up window
        (0.41, 0.7),
        (0.49, 1.4),   // composing wind-down breath
        (0.62, 0.8),
        (0.71, 1.3),
        (0.82, 0.8),
        (0.91, 1.1),
        (1.00, 0.7)
    ]

    private func runAnalyzingAnimation() {
        analyzingProgress = 0
        analyzingStep = 0
        runScript(
            Self.analyzingScript,
            progress: { v in analyzingProgress = v },
            stepIndex: { i in analyzingStep = i },
            messageGroups: AnalyzingAnswersScreen.stepBoundaries,
            onDone: { advance() }
        )
    }

    private func runGeneratingAnimation() {
        planProgress = 0
        planMessageIndex = 0
        runScript(
            Self.generatingScript,
            progress: { v in planProgress = v },
            stepIndex: { i in planMessageIndex = i },
            messageGroups: GeneratingPlanScreen.stepBoundaries,
            onDone: { advance() }
        )
    }

    /// Walks through the scripted (target, hold) pairs. After each progress jump
    /// it waits `hold` seconds — so the bar visibly *pauses* at believable
    /// moments instead of climbing at a constant rate.
    private func runScript(
        _ script: [(Double, Double)],
        progress: @escaping (Double) -> Void,
        stepIndex: @escaping (Int) -> Void,
        messageGroups: [Int],          // script index where each message advances
        onDone: @escaping () -> Void
    ) {
        var t: Double = 0
        for (i, entry) in script.enumerated() {
            let (target, hold) = entry
            let firstFireDelay = t
            DispatchQueue.main.asyncAfter(deadline: .now() + firstFireDelay) {
                withAnimation(.easeInOut(duration: 0.55)) {
                    progress(target)
                    if let msgIdx = messageGroups.firstIndex(where: { $0 == i }) {
                        stepIndex(msgIdx)
                    }
                }
            }
            t += hold
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + t + 0.4) { onDone() }
    }

    // MARK: - Finish

    private func finishOnboarding() {
        appState.completeOnboarding(
            species: species,
            name: petName,
            goal: sleepGoal ?? .wakeUpLessTired,
            goalHours: hoursBetween(bedtime, wakeTime),
            bedtime: bedtime,
            wakeTime: wakeTime,
            weekendWake: separateWeekends ? weekendWake : nil,
            room: room,
            profile: profile
        )

        if notifications.authState == .authorized {
            notifications.scheduleNightlyBedtimeNudge(petName: petName, bedtime: bedtime)
        }
    }

    private func hoursBetween(_ a: Date, _ b: Date) -> Double {
        let cal = Calendar.current
        var end = b
        if end <= a { end = cal.date(byAdding: .day, value: 1, to: end) ?? end }
        let mins = cal.dateComponents([.minute], from: a, to: end).minute ?? 0
        return Double(mins) / 60.0
    }
}

// MARK: - Embedded pre-paywall (so footer can be empty)

// MARK: - Common screen scaffolds

private struct QuestionScaffold<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text(title)
                    .font(MooniFont.display(26))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                if let s = subtitle {
                    Text(s)
                        .font(MooniFont.body(14))
                        .foregroundColor(MooniColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            .padding(.top, 8)

            content()
                .padding(.horizontal, 20)

            Spacer().frame(height: 12)
        }
        .padding(.top, 4)
    }
}

private struct OptionRow<T: Hashable>: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    let value: T
    @Binding var selection: T
    var emoji: String? = nil

    var isSelected: Bool { selection == value }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3)) { selection = value }
        } label: {
            HStack(spacing: 14) {
                if let emoji {
                    Text(emoji)
                        .font(.system(size: 26))
                        .frame(width: 38, height: 38)
                        .background((isSelected ? MooniColor.accent : MooniColor.accentSoft).opacity(0.16))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isSelected ? MooniColor.accent : MooniColor.accentSoft)
                        .frame(width: 38, height: 38)
                        .background((isSelected ? MooniColor.accent : MooniColor.accentSoft).opacity(0.16))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(MooniFont.title(15))
                        .foregroundColor(MooniColor.textPrimary)
                        .multilineTextAlignment(.leading)
                    if let subtitle {
                        Text(subtitle)
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.textSecondary)
                    }
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? MooniColor.accent : MooniColor.textMuted)
                    .font(.system(size: 20))
            }
            .padding(14)
            .background(Color.white.opacity(isSelected ? 0.13 : 0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? MooniColor.accent : Color.white.opacity(0.10),
                            lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Screen 0: Hero

private struct HeroScreen: View {
    let species: PetSpecies
    @State private var glow = false

    var body: some View {
        VStack(spacing: 26) {
            Spacer().frame(height: 4)
            ZStack {
                Image(systemName: "moon.fill")
                    .font(.system(size: 90))
                    .foregroundStyle(LinearGradient(
                        colors: [MooniColor.accentSoft, MooniColor.accent],
                        startPoint: .top, endPoint: .bottom))
                    .offset(x: 70, y: -90)
                    .opacity(0.85)
                DreamSpiritView(pet: previewPet, size: 180)
                    .scaleEffect(glow ? 1.02 : 0.98)
                    .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: glow)
            }
            VStack(spacing: 12) {
                Text("Your sleep shapes\ntheir world.")
                    .font(MooniFont.display(34))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                Text("Raise a pet by improving your sleep.")
                    .font(MooniFont.body(16))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                Text("⭐ 4.9 · 2.4M nights tracked")
                    .font(MooniFont.caption(13))
                    .foregroundColor(MooniColor.warning)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 28)
        }
        .padding(.top, 8)
        .onAppear { glow = true }
    }

    private var previewPet: Pet {
        var p = Pet(); p.species = species; p.mood = .cozy; p.equippedColor = "default_color"; p.equippedHat = "hat_nightcap"
        return p
    }
}

// MARK: - Screen 1: Sleep impact stat

private struct SleepImpactStatScreen: View {
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 24)
            ZStack {
                Circle()
                    .fill(MooniColor.warning.opacity(0.18))
                    .frame(width: 200, height: 200)
                    .blur(radius: 30)
                    .scaleEffect(pulse ? 1.05 : 0.95)
                Text("85%")
                    .font(.system(size: 92, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient(
                        colors: [MooniColor.accentSoft, MooniColor.accent],
                        startPoint: .top, endPoint: .bottom))
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { pulse = true }
            }

            VStack(spacing: 10) {
                Text("of adults wake up tired")
                    .font(MooniFont.display(24))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text("You're not alone. Mooni rewires your sleep, one cozy night at a time — and you'll feel the change in the first week.")
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Screen 2: Pick pet

private struct PickPetScreen: View {
    @Binding var selected: PetSpecies
    let onPick: (PetSpecies) -> Void

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text("Pick your sleep pet")
                    .font(MooniFont.display(28))
                    .foregroundColor(MooniColor.textPrimary)
                Text("Each one feels different. Pick the one that's most you.")
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 8)

            // Big preview of selected pet
            ZStack {
                Circle()
                    .fill(selected.tint.opacity(0.20))
                    .frame(width: 180, height: 180)
                    .blur(radius: 24)
                DreamSpiritView(pet: { var p = Pet(); p.species = selected; p.mood = .cozy; p.equippedHat = nil; return p }(), size: 140)
            }
            .id(selected)
            .transition(.scale.combined(with: .opacity))

            VStack(spacing: 10) {
                ForEach(PetSpecies.allCases) { sp in
                    PetCardRow(species: sp, isSelected: selected == sp) {
                        withAnimation(.spring(response: 0.35)) {
                            selected = sp
                            onPick(sp)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)

            Text("\(selected.defaultName) chose you too.")
                .font(MooniFont.caption(13))
                .foregroundColor(MooniColor.accentSoft)
                .transition(.opacity)
                .id(selected)
        }
        .padding(.horizontal, 20)
    }
}

private struct PetCardRow: View {
    let species: PetSpecies
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(species.tint.opacity(0.30))
                        .frame(width: 52, height: 52)
                    Image(systemName: species.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(species.tint)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(species.defaultName) the \(species.displayName)")
                        .font(MooniFont.title(16))
                        .foregroundColor(MooniColor.textPrimary)
                    Text(species.tagline)
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? MooniColor.accent : MooniColor.textMuted)
                    .font(.system(size: 22))
            }
            .padding(14)
            .background(Color.white.opacity(isSelected ? 0.13 : 0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? species.tint : Color.white.opacity(0.10),
                            lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Screen 3: Name pet

private struct NamePetScreen: View {
    let species: PetSpecies
    @Binding var name: String
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 12)
            DreamSpiritView(pet: previewPet, size: 150)
            VStack(spacing: 8) {
                Text("What should we call them?")
                    .font(MooniFont.title(20))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text("This is the name you'll see every night. Make it count.")
                    .font(MooniFont.caption(13))
                    .foregroundColor(MooniColor.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            TextField("", text: $name,
                      prompt: Text(species.defaultName).foregroundColor(MooniColor.textMuted))
                .font(MooniFont.title(22))
                .multilineTextAlignment(.center)
                .foregroundColor(MooniColor.textPrimary)
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(species.tint.opacity(0.45), lineWidth: 1)
                )
                .padding(.horizontal, 32)
                .focused($focused)
                .submitLabel(.done)
        }
        .padding(.horizontal, 20)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { focused = true }
        }
    }

    private var previewPet: Pet {
        var p = Pet(); p.species = species; p.mood = .cozy; p.equippedColor = "default_color"; p.equippedHat = nil
        return p
    }
}

// MARK: - Screen 4: Bond message

private struct BondMessageScreen: View {
    let petName: String
    let species: PetSpecies
    @State private var heart = false

    var body: some View {
        VStack(spacing: 22) {
            Spacer().frame(height: 16)
            ZStack {
                DreamSpiritView(
                    pet: { var p = Pet(); p.species = species; p.mood = .cozy; p.equippedHat = "hat_nightcap"; return p }(),
                    size: 160
                )
                Image(systemName: "heart.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.pink.opacity(0.85))
                    .offset(x: 70, y: -70)
                    .scaleEffect(heart ? 1.2 : 0.9)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { heart = true }
            }

            VStack(spacing: 10) {
                Text("\(petName) is now bonded to you.")
                    .font(MooniFont.display(24))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Every night you sleep well, \(petName) grows. Every restless night… you'll feel it together.")
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Screen 5: Demo (3 sub-stages)

private struct DemoScreen: View {
    let species: PetSpecies
    @Binding var stage: Int

    private var caption: String {
        switch stage {
        case 0: return "Short sleep makes \(species.defaultName) groggy."
        case 1: return "Good sleep helps \(species.defaultName) grow."
        default: return "Consistency unlocks new dreams."
        }
    }

    private var subtitle: String {
        switch stage {
        case 0: return "5 hours sleep"
        case 1: return "7.5 hours sleep"
        default: return "Consistent bedtime"
        }
    }

    private var demoPet: Pet {
        var p = Pet(); p.species = species
        p.mood = stage == 0 ? .groggy : (stage == 1 ? .cozy : .energized)
        p.equippedHat = stage == 2 ? "hat_nightcap" : nil
        return p
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer().frame(height: 16)
            DreamSpiritView(pet: demoPet, size: 170)
                .id(stage)
                .transition(.scale.combined(with: .opacity))
            VStack(spacing: 8) {
                Text(subtitle)
                    .font(MooniFont.caption(13))
                    .foregroundColor(MooniColor.textMuted)
                Text(caption)
                    .font(MooniFont.title(20))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            HStack(spacing: 6) {
                ForEach(0..<3) { i in
                    Capsule()
                        .fill(i <= stage ? MooniColor.accent : Color.white.opacity(0.18))
                        .frame(width: i == stage ? 22 : 10, height: 4)
                        .animation(.spring(response: 0.35), value: stage)
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Screen: Age

private struct AgeScreen: View {
    @Binding var profile: OnboardingProfile

    private let minAge = 13
    private let maxAge = 90
    @State private var ageValue: Int = 25

    var body: some View {
        QuestionScaffold(
            title: "How old are you?",
            subtitle: "We use age to match you against people who improved their sleep."
        ) {
            VStack(spacing: 20) {
                Text("\(ageValue)")
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient(
                        colors: [MooniColor.accentSoft, MooniColor.accent],
                        startPoint: .top, endPoint: .bottom))
                    .padding(.top, 12)

                Picker("Age", selection: $ageValue) {
                    ForEach(minAge...maxAge, id: \.self) { age in
                        Text("\(age)").tag(age)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 160)
                .colorScheme(.dark)
                .onChange(of: ageValue) { _, newValue in
                    profile.age = newValue
                }
            }
        }
        .onAppear {
            if let saved = profile.age { ageValue = saved } else { profile.age = ageValue }
        }
    }
}

// MARK: - Screen: Gender

private struct GenderScreen: View {
    @Binding var profile: OnboardingProfile

    var body: some View {
        QuestionScaffold(
            title: "How do you identify?",
            subtitle: "Optional — sleep needs differ slightly by hormones."
        ) {
            VStack(spacing: 10) {
                ForEach(OnboardingProfile.Gender.allCases) { g in
                    OptionRow(
                        title: g.label,
                        icon: g.icon,
                        value: g,
                        selection: $profile.gender
                    )
                }
            }
        }
    }
}

// MARK: - Screen: Height

private struct HeightScreen: View {
    @Binding var profile: OnboardingProfile

    @State private var feet: Int = 5
    @State private var inches: Int = 8
    @State private var cm: Int = 173
    @State private var unit: OnboardingProfile.UnitSystem = .imperial

    var body: some View {
        QuestionScaffold(
            title: "How tall are you?",
            subtitle: "Used to tune your wind-down breath cadence."
        ) {
            VStack(spacing: 18) {
                unitToggle

                if unit == .imperial {
                    HStack(spacing: 12) {
                        wheelColumn(label: "ft", range: 4...7, selection: $feet)
                        wheelColumn(label: "in", range: 0...11, selection: $inches)
                    }
                    .frame(height: 180)
                } else {
                    wheelColumn(label: "cm", range: 130...220, selection: $cm)
                        .frame(height: 180)
                }
            }
        }
        .onAppear {
            if let stored = profile.heightCm {
                cm = stored
                let total = Int((Double(stored) / 2.54).rounded())
                feet = total / 12
                inches = total % 12
                unit = profile.unitSystem
            } else {
                profile.heightCm = cm
            }
        }
        .onChange(of: feet) { _, _ in syncHeight() }
        .onChange(of: inches) { _, _ in syncHeight() }
        .onChange(of: cm) { _, _ in syncHeight() }
        .onChange(of: unit) { _, newUnit in
            profile.unitSystem = newUnit
            syncHeight()
        }
    }

    private func syncHeight() {
        switch unit {
        case .imperial:
            let total = feet * 12 + inches
            profile.heightCm = Int((Double(total) * 2.54).rounded())
        case .metric:
            profile.heightCm = cm
        }
    }

    private var unitToggle: some View {
        HStack(spacing: 0) {
            unitButton("ft / in", isSelected: unit == .imperial) { unit = .imperial }
            unitButton("cm", isSelected: unit == .metric) { unit = .metric }
        }
        .padding(4)
        .background(Color.white.opacity(0.07))
        .clipShape(Capsule())
    }

    private func unitButton(_ title: String, isSelected: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(MooniFont.caption(13))
                .foregroundColor(isSelected ? MooniColor.background : MooniColor.textPrimary)
                .padding(.vertical, 8)
                .padding(.horizontal, 18)
                .background(
                    Capsule().fill(isSelected ? Color.white.opacity(0.85) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    private func wheelColumn(label: String, range: ClosedRange<Int>, selection: Binding<Int>) -> some View {
        HStack {
            Picker("", selection: selection) {
                ForEach(range, id: \.self) { v in
                    Text("\(v)").tag(v)
                }
            }
            .pickerStyle(.wheel)
            .colorScheme(.dark)
            Text(label)
                .foregroundColor(MooniColor.textSecondary)
                .font(MooniFont.title(15))
        }
        .padding(.horizontal, 16)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Screen: Weight

private struct WeightScreen: View {
    @Binding var profile: OnboardingProfile

    @State private var pounds: Int = 150
    @State private var kg: Int = 68
    @State private var unit: OnboardingProfile.UnitSystem = .imperial

    var body: some View {
        QuestionScaffold(
            title: "How much do you weigh?",
            subtitle: "Recovery scales with your body. Used privately."
        ) {
            VStack(spacing: 18) {
                unitToggle

                if unit == .imperial {
                    weightWheel(range: 80...360, label: "lb", selection: $pounds)
                } else {
                    weightWheel(range: 35...160, label: "kg", selection: $kg)
                }
            }
        }
        .onAppear {
            unit = profile.unitSystem
            if let kgValue = profile.weightKg {
                kg = Int(kgValue.rounded())
                pounds = Int((kgValue * 2.20462).rounded())
            } else {
                profile.weightKg = Double(kg)
            }
        }
        .onChange(of: pounds) { _, _ in syncWeight() }
        .onChange(of: kg) { _, _ in syncWeight() }
        .onChange(of: unit) { _, newUnit in
            profile.unitSystem = newUnit
            syncWeight()
        }
    }

    private func syncWeight() {
        switch unit {
        case .imperial: profile.weightKg = Double(pounds) / 2.20462
        case .metric:   profile.weightKg = Double(kg)
        }
    }

    private var unitToggle: some View {
        HStack(spacing: 0) {
            Button { unit = .imperial } label: {
                Text("lb").font(MooniFont.caption(13))
                    .foregroundColor(unit == .imperial ? MooniColor.background : MooniColor.textPrimary)
                    .padding(.vertical, 8).padding(.horizontal, 22)
                    .background(Capsule().fill(unit == .imperial ? Color.white.opacity(0.85) : Color.clear))
            }
            Button { unit = .metric } label: {
                Text("kg").font(MooniFont.caption(13))
                    .foregroundColor(unit == .metric ? MooniColor.background : MooniColor.textPrimary)
                    .padding(.vertical, 8).padding(.horizontal, 22)
                    .background(Capsule().fill(unit == .metric ? Color.white.opacity(0.85) : Color.clear))
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.07))
        .clipShape(Capsule())
    }

    private func weightWheel(range: ClosedRange<Int>, label: String, selection: Binding<Int>) -> some View {
        HStack {
            Picker("", selection: selection) {
                ForEach(range, id: \.self) { v in
                    Text("\(v)").tag(v)
                }
            }
            .pickerStyle(.wheel)
            .colorScheme(.dark)
            .frame(maxWidth: .infinity)
            Text(label)
                .foregroundColor(MooniColor.textSecondary)
                .font(MooniFont.title(15))
        }
        .frame(height: 180)
        .padding(.horizontal, 16)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Screen: Sleep goal

private struct GoalScreen: View {
    @Binding var selection: SleepGoal?

    var body: some View {
        QuestionScaffold(
            title: "What do you want help with most?",
            subtitle: "We'll personalize your plan around this."
        ) {
            VStack(spacing: 10) {
                ForEach(SleepGoal.allCases) { goal in
                    Button {
                        withAnimation(.spring(response: 0.3)) { selection = goal }
                    } label: {
                        let isSelected = selection == goal
                        HStack(spacing: 14) {
                            Image(systemName: goal.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(isSelected ? MooniColor.accent : MooniColor.accentSoft)
                                .frame(width: 38, height: 38)
                                .background((isSelected ? MooniColor.accent : MooniColor.accentSoft).opacity(0.16))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            Text(goal.title)
                                .font(MooniFont.title(15))
                                .foregroundColor(MooniColor.textPrimary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isSelected ? MooniColor.accent : MooniColor.textMuted)
                                .font(.system(size: 20))
                        }
                        .padding(14)
                        .background(Color.white.opacity(isSelected ? 0.13 : 0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(isSelected ? MooniColor.accent : Color.white.opacity(0.10),
                                        lineWidth: isSelected ? 1.5 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Screen: Motivation

private struct MotivationScreen: View {
    @Binding var profile: OnboardingProfile

    var body: some View {
        QuestionScaffold(
            title: "What would great sleep unlock for you?",
            subtitle: "Pick the one that hits hardest."
        ) {
            VStack(spacing: 10) {
                ForEach(OnboardingProfile.Motivation.allCases) { m in
                    OptionRow(title: m.label, icon: m.icon, value: m, selection: $profile.motivation)
                }
            }
        }
    }
}

// MARK: - Screen: Struggle duration

private struct StruggleDurationScreen: View {
    @Binding var profile: OnboardingProfile

    var body: some View {
        QuestionScaffold(
            title: "How long has sleep been a problem?",
            subtitle: "Knowing helps us pick a recovery pace that won't burn you out."
        ) {
            VStack(spacing: 10) {
                ForEach(OnboardingProfile.StruggleDuration.allCases) { d in
                    OptionRow(title: d.label, icon: durationIcon(d), value: d, selection: $profile.struggleDuration)
                }
            }
        }
    }

    private func durationIcon(_ d: OnboardingProfile.StruggleDuration) -> String {
        switch d {
        case .fewWeeks: return "calendar"
        case .fewMonths: return "calendar.badge.clock"
        case .oneYear: return "hourglass"
        case .severalYears: return "infinity"
        case .asLongAsRemember: return "clock.arrow.circlepath"
        }
    }
}

// MARK: - Screen: Biggest problem

private struct BiggestProblemScreen: View {
    @Binding var profile: OnboardingProfile

    var body: some View {
        QuestionScaffold(
            title: "Which one bothers you most?",
            subtitle: "We focus the first week on this."
        ) {
            VStack(spacing: 10) {
                ForEach(OnboardingProfile.SleepProblem.allCases) { p in
                    OptionRow(title: p.label, icon: p.icon, value: p, selection: $profile.biggestProblem)
                }
            }
        }
    }
}

// MARK: - Screen: Typical sleep hours

private struct TypicalSleepHoursScreen: View {
    @Binding var profile: OnboardingProfile

    var body: some View {
        QuestionScaffold(
            title: "How many hours do you usually sleep?",
            subtitle: "Be honest — even rough is fine."
        ) {
            VStack(spacing: 18) {
                Text(String(format: "%.1f hrs", profile.typicalSleepHours))
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient(
                        colors: [MooniColor.accentSoft, MooniColor.accent],
                        startPoint: .top, endPoint: .bottom))

                Slider(value: $profile.typicalSleepHours, in: 3...10, step: 0.5)
                    .tint(MooniColor.accent)
                    .padding(.horizontal, 4)

                HStack {
                    Text("3 hrs").font(MooniFont.caption(11)).foregroundColor(MooniColor.textMuted)
                    Spacer()
                    Text("10 hrs").font(MooniFont.caption(11)).foregroundColor(MooniColor.textMuted)
                }

                Text(hoursMessage)
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
            }
            .padding(20)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var hoursMessage: String {
        switch profile.typicalSleepHours {
        case ..<5.5: return "That's well below what your body needs to recover."
        case 5.5..<7: return "You're running a meaningful sleep deficit."
        case 7..<8: return "You're close — but not yet recovered."
        default: return "Solid baseline. We'll help make it consistent."
        }
    }
}

// MARK: - Screen: Phone before bed

private struct PhoneBeforeBedScreen: View {
    @Binding var profile: OnboardingProfile
    @State private var glow = false

    var body: some View {
        QuestionScaffold(
            title: "Do you use your phone in bed?",
            subtitle: "Screens delay melatonin by up to 90 minutes."
        ) {
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(MooniColor.warning.opacity(0.18))
                        .frame(width: 130, height: 130)
                        .blur(radius: 24)
                        .scaleEffect(glow ? 1.05 : 0.95)
                    Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                        .font(.system(size: 70))
                        .foregroundStyle(LinearGradient(
                            colors: [MooniColor.warning, MooniColor.danger],
                            startPoint: .top, endPoint: .bottom))
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { glow = true }
                }

                HStack(spacing: 10) {
                    bigChoice(label: "Yes", isYes: true)
                    bigChoice(label: "No", isYes: false)
                }
                .padding(.horizontal, 8)
            }
        }
    }

    private func bigChoice(label: String, isYes: Bool) -> some View {
        Button {
            withAnimation(.spring()) { profile.usesPhoneBeforeBed = isYes }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: isYes ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(profile.usesPhoneBeforeBed == isYes
                                     ? (isYes ? MooniColor.warning : MooniColor.success)
                                     : MooniColor.textMuted)
                Text(label)
                    .font(MooniFont.title(18))
                    .foregroundColor(MooniColor.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(Color.white.opacity(profile.usesPhoneBeforeBed == isYes ? 0.13 : 0.06))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(profile.usesPhoneBeforeBed == isYes
                            ? (isYes ? MooniColor.warning : MooniColor.success)
                            : Color.white.opacity(0.12), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Screen: Phone screen time

private struct PhoneScreenTimeScreen: View {
    @Binding var profile: OnboardingProfile

    var body: some View {
        QuestionScaffold(
            title: "How long on your phone before sleep?",
            subtitle: "On the last hour before lights-out."
        ) {
            VStack(spacing: 18) {
                Text("\(profile.phoneScreenMinutes) min")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient(
                        colors: [MooniColor.warning, MooniColor.danger],
                        startPoint: .top, endPoint: .bottom))

                Slider(
                    value: Binding(
                        get: { Double(profile.phoneScreenMinutes) },
                        set: { profile.phoneScreenMinutes = Int($0) }
                    ),
                    in: 0...180, step: 5
                )
                .tint(MooniColor.warning)

                HStack {
                    Text("0 min").font(MooniFont.caption(11)).foregroundColor(MooniColor.textMuted)
                    Spacer()
                    Text("3 hrs").font(MooniFont.caption(11)).foregroundColor(MooniColor.textMuted)
                }

                if profile.phoneScreenMinutes >= 60 {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(MooniColor.warning)
                        Text("That's 1+ hour of melatonin suppression every night.")
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.warning)
                    }
                    .padding(10)
                    .background(MooniColor.warning.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding(20)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

// MARK: - Screen: Caffeine cutoff

private struct CaffeineCutoffScreen: View {
    @Binding var profile: OnboardingProfile

    var body: some View {
        QuestionScaffold(
            title: "When do you stop caffeine?",
            subtitle: "Caffeine has a half-life of 5–7 hours. It matters."
        ) {
            VStack(spacing: 10) {
                ForEach(OnboardingProfile.CaffeineCutoff.allCases) { c in
                    OptionRow(title: c.label, icon: caffeineIcon(c), value: c, selection: $profile.caffeineCutoff)
                }
            }
        }
    }

    private func caffeineIcon(_ c: OnboardingProfile.CaffeineCutoff) -> String {
        switch c {
        case .morning: return "sun.max.fill"
        case .afternoon: return "sun.haze.fill"
        case .evening: return "moon.fill"
        case .none: return "drop.fill"
        }
    }
}

// MARK: - Screen: Stress level

private struct StressLevelScreen: View {
    @Binding var profile: OnboardingProfile

    var body: some View {
        QuestionScaffold(
            title: "How stressed do you feel at night?",
            subtitle: "1 = totally calm, 10 = thoughts won't stop."
        ) {
            VStack(spacing: 16) {
                Text("\(profile.stressLevel)")
                    .font(.system(size: 76, weight: .bold, design: .rounded))
                    .foregroundColor(stressColor)

                Slider(value: Binding(
                    get: { Double(profile.stressLevel) },
                    set: { profile.stressLevel = Int($0) }
                ), in: 1...10, step: 1)
                .tint(stressColor)

                HStack {
                    Text("Calm").font(MooniFont.caption(11)).foregroundColor(MooniColor.success)
                    Spacer()
                    Text("Anxious").font(MooniFont.caption(11)).foregroundColor(MooniColor.danger)
                }

                Text(stressMessage)
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
            }
            .padding(20)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var stressColor: Color {
        switch profile.stressLevel {
        case ..<4: return MooniColor.success
        case 4..<7: return MooniColor.warning
        default: return MooniColor.danger
        }
    }

    private var stressMessage: String {
        switch profile.stressLevel {
        case ..<4: return "Great — your nervous system is on your side."
        case 4..<7: return "Some background noise. We'll add a wind-down."
        default: return "High stress flattens deep sleep. We'll fix this first."
        }
    }
}

// MARK: - Screen: Racing thoughts

private struct RacingThoughtsScreen: View {
    @Binding var profile: OnboardingProfile
    let petName: String

    var body: some View {
        QuestionScaffold(
            title: "Do thoughts race when you try to sleep?",
            subtitle: "If yes, \(petName)'s wind-down will include a brain dump."
        ) {
            HStack(spacing: 12) {
                bigYesNo(label: "Yes, often", isYes: true)
                bigYesNo(label: "Not really", isYes: false)
            }
        }
    }

    private func bigYesNo(label: String, isYes: Bool) -> some View {
        Button {
            withAnimation(.spring()) { profile.racingThoughtsAtNight = isYes }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: isYes ? "wind" : "checkmark.seal.fill")
                    .font(.system(size: 28))
                    .foregroundColor(profile.racingThoughtsAtNight == isYes
                                     ? (isYes ? MooniColor.warning : MooniColor.success)
                                     : MooniColor.textMuted)
                Text(label)
                    .font(MooniFont.title(15))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(Color.white.opacity(profile.racingThoughtsAtNight == isYes ? 0.13 : 0.06))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(profile.racingThoughtsAtNight == isYes
                            ? (isYes ? MooniColor.warning : MooniColor.success)
                            : Color.white.opacity(0.12), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Screen: Wake feeling

private struct WakeFeelingScreen: View {
    @Binding var profile: OnboardingProfile

    var body: some View {
        QuestionScaffold(
            title: "How do you usually wake up?",
            subtitle: "Your wake-up window is half the equation."
        ) {
            VStack(spacing: 10) {
                ForEach(OnboardingProfile.WakeFeeling.allCases) { f in
                    OptionRow(
                        title: f.label, icon: wakeIcon(f), value: f, selection: $profile.wakeFeeling
                    )
                }
            }
        }
    }

    private func wakeIcon(_ f: OnboardingProfile.WakeFeeling) -> String {
        switch f {
        case .refreshed: return "sun.max.fill"
        case .okay:      return "sun.haze.fill"
        case .groggy:    return "cloud.fill"
        case .exhausted: return "cloud.bolt.rain.fill"
        }
    }
}

// MARK: - Screen: Energy dip

private struct EnergyDipScreen: View {
    @Binding var profile: OnboardingProfile

    var body: some View {
        QuestionScaffold(
            title: "When do you crash during the day?",
            subtitle: "Energy dips reveal which sleep stage you're missing."
        ) {
            VStack(spacing: 10) {
                ForEach(OnboardingProfile.EnergyDip.allCases) { d in
                    OptionRow(title: d.label, icon: dipIcon(d), value: d, selection: $profile.energyDip)
                }
            }
        }
    }

    private func dipIcon(_ d: OnboardingProfile.EnergyDip) -> String {
        switch d {
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "sunset.fill"
        case .allDay: return "battery.25"
        case .never: return "bolt.fill"
        }
    }
}

// MARK: - Screen: Naps

private struct NapsScreen: View {
    @Binding var profile: OnboardingProfile

    var body: some View {
        QuestionScaffold(
            title: "Do you nap during the day?",
            subtitle: "Naps can help — but the wrong nap hurts night sleep."
        ) {
            HStack(spacing: 12) {
                bigYesNo(label: "Yes", isYes: true)
                bigYesNo(label: "No", isYes: false)
            }
        }
    }

    private func bigYesNo(label: String, isYes: Bool) -> some View {
        Button {
            withAnimation(.spring()) { profile.napsDuringDay = isYes }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: isYes ? "moon.zzz.fill" : "sun.max.fill")
                    .font(.system(size: 28))
                    .foregroundColor(profile.napsDuringDay == isYes ? MooniColor.accent : MooniColor.textMuted)
                Text(label).font(MooniFont.title(18)).foregroundColor(MooniColor.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(Color.white.opacity(profile.napsDuringDay == isYes ? 0.13 : 0.06))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(profile.napsDuringDay == isYes ? MooniColor.accent : Color.white.opacity(0.12), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Screen: Room environment

private struct RoomEnvironmentScreen: View {
    @Binding var profile: OnboardingProfile

    var body: some View {
        QuestionScaffold(
            title: "What's your bedroom like?",
            subtitle: "Light + noise + comfort. Quick taps."
        ) {
            VStack(spacing: 14) {
                envSection(
                    title: "Light",
                    options: [(.dark, "Pitch dark", "moon.fill"),
                              (.someLight, "Some light", "moon.haze.fill"),
                              (.bright, "Pretty bright", "sun.max.fill")],
                    binding: $profile.roomDarkness
                )
                envSection(
                    title: "Noise",
                    options: [(.quiet, "Quiet", "ear.badge.checkmark"),
                              (.someNoise, "Some noise", "ear"),
                              (.loud, "Loud / city", "speaker.wave.3.fill")],
                    binding: $profile.roomNoise
                )
                envSection(
                    title: "Bed",
                    options: [(.comfortable, "Comfy", "bed.double.fill"),
                              (.okay, "Okay", "bed.double"),
                              (.uncomfortable, "Uncomfy", "exclamationmark.bubble.fill")],
                    binding: $profile.bedComfort
                )
            }
        }
    }

    private func envSection(
        title: String,
        options: [(OnboardingProfile.RoomQuality, String, String)],
        binding: Binding<OnboardingProfile.RoomQuality>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(MooniFont.caption(12))
                .foregroundColor(MooniColor.textMuted)
                .textCase(.uppercase)
                .tracking(1)
            HStack(spacing: 8) {
                ForEach(options, id: \.0) { opt in
                    Button {
                        withAnimation(.spring()) { binding.wrappedValue = opt.0 }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: opt.2)
                                .font(.system(size: 18))
                                .foregroundColor(binding.wrappedValue == opt.0 ? MooniColor.accent : MooniColor.textMuted)
                            Text(opt.1).font(MooniFont.caption(11))
                                .foregroundColor(MooniColor.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(binding.wrappedValue == opt.0 ? 0.13 : 0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(binding.wrappedValue == opt.0 ? MooniColor.accent : Color.white.opacity(0.10),
                                        lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Screen: Schedule

private struct ScheduleScreen: View {
    @Binding var bedtime: Date
    @Binding var wakeTime: Date
    @Binding var separateWeekends: Bool
    @Binding var weekendWake: Date

    var body: some View {
        QuestionScaffold(
            title: "When do you want to sleep & wake?",
            subtitle: "We'll keep you on this rhythm gently."
        ) {
            VStack(spacing: 12) {
                timeRow(title: "Bedtime", icon: "moon.fill",
                        color: MooniColor.accent, selection: $bedtime)
                timeRow(title: "Wake up", icon: "sun.max.fill",
                        color: MooniColor.warning, selection: $wakeTime)

                Toggle(isOn: $separateWeekends) {
                    Text("Different wake time on weekends")
                        .font(MooniFont.caption(13))
                        .foregroundColor(MooniColor.textSecondary)
                }
                .tint(MooniColor.accent)
                .padding(.horizontal, 4)

                if separateWeekends {
                    timeRow(title: "Weekend wake", icon: "calendar",
                            color: MooniColor.accentSoft, selection: $weekendWake)
                }
            }
        }
    }

    private func timeRow(title: String, icon: String, color: Color,
                         selection: Binding<Date>) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 28)
            Text(title)
                .font(MooniFont.title(16))
                .foregroundColor(MooniColor.textPrimary)
            Spacer()
            DatePicker("", selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .colorScheme(.dark)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Screen: Reflection

private struct ReflectionScreen: View {
    let petName: String
    let bedtime: Date
    let wakeTime: Date

    private var windowText: String {
        "\(bedtime.hourMinuteString)–\(wakeTime.hourMinuteString)"
    }

    private var hoursText: String {
        let cal = Calendar.current
        var end = wakeTime
        if end <= bedtime { end = cal.date(byAdding: .day, value: 1, to: end) ?? end }
        let mins = cal.dateComponents([.minute], from: bedtime, to: end).minute ?? 0
        let h = mins / 60
        let m = mins % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer().frame(height: 14)
            ZStack {
                Circle()
                    .fill(MooniColor.accent.opacity(0.16))
                    .frame(width: 110, height: 110)
                    .blur(radius: 18)
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(LinearGradient(
                        colors: [MooniColor.accentSoft, MooniColor.accent],
                        startPoint: .top, endPoint: .bottom))
            }

            VStack(spacing: 10) {
                Text("Your target sleep window is")
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textSecondary)
                Text(windowText)
                    .font(MooniFont.display(36))
                    .foregroundColor(MooniColor.textPrimary)
                Text("That gives \(petName) about \(hoursText) to recover.")
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Text("Even 30 minutes less sleep each night can build up over the week.")
                .font(MooniFont.caption(13))
                .foregroundColor(MooniColor.warning)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 4)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Screen: Room picker

private struct RoomPickerScreen: View {
    let species: PetSpecies
    let name: String
    @Binding var selection: PetRoom

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text("Pick \(name)'s first room")
                    .font(MooniFont.display(24))
                    .foregroundColor(MooniColor.textPrimary)
                Text("You'll unlock more rooms as you grow.")
                    .font(MooniFont.caption(13))
                    .foregroundColor(MooniColor.textSecondary)
            }
            .padding(.top, 6)

            // Preview
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(selection.gradient)
                    .frame(height: 180)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
                DreamSpiritView(pet: previewPet, size: 110)
            }
            .padding(.horizontal, 4)

            // Picker
            HStack(spacing: 10) {
                ForEach(PetRoom.allCases) { r in
                    RoomChip(room: r, selected: selection == r) {
                        withAnimation(.spring(response: 0.35)) { selection = r }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 20)
    }

    private var previewPet: Pet {
        var p = Pet(); p.species = species; p.mood = .calm; p.equippedHat = nil
        return p
    }
}

private struct RoomChip: View {
    let room: PetRoom
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(room.gradient)
                        .frame(height: 64)
                    Image(systemName: room.icon)
                        .font(.system(size: 22))
                        .foregroundColor(.white.opacity(0.9))
                }
                Text(room.displayName)
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textPrimary)
            }
            .padding(8)
            .background(Color.white.opacity(selected ? 0.13 : 0.04))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? MooniColor.accent : Color.white.opacity(0.10),
                            lineWidth: selected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Screen: Notification permission

private struct NotificationPermissionScreen: View {
    let petName: String
    let state: NotificationManager.AuthState

    var body: some View {
        VStack(spacing: 22) {
            Spacer().frame(height: 14)
            ZStack {
                Circle().fill(MooniColor.warning.opacity(0.16))
                    .frame(width: 110, height: 110).blur(radius: 18)
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(LinearGradient(
                        colors: [Color.yellow, MooniColor.warning],
                        startPoint: .top, endPoint: .bottom))
            }
            VStack(spacing: 10) {
                Text("Should \(petName) remind you when it's time to wind down?")
                    .font(MooniFont.title(20))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                Text("We'll send gentle bedtime reminders, not spam.")
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            previewBubble
                .padding(.top, 8)

            if state == .authorized {
                Label("Reminders enabled", systemImage: "checkmark.seal.fill")
                    .font(MooniFont.caption(13))
                    .foregroundColor(MooniColor.success)
            } else if state == .denied {
                Text("You can enable reminders later in Settings.")
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.warning)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .padding(.horizontal, 20)
    }

    private var previewBubble: some View {
        HStack {
            Image(systemName: "bell.fill")
                .foregroundColor(MooniColor.accent)
                .padding(8)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("\(petName) is getting sleepy…")
                    .font(MooniFont.title(13))
                    .foregroundColor(MooniColor.textPrimary)
                Text("Tap to start tonight's wind-down.")
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
    }
}

// MARK: - Screen: Health permission

private struct HealthPermissionScreen: View {
    let petName: String
    let state: HealthKitManager.AuthState

    var body: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 14)
            ZStack {
                Circle().fill(MooniColor.danger.opacity(0.16))
                    .frame(width: 110, height: 110).blur(radius: 18)
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(LinearGradient(
                        colors: [Color.pink, MooniColor.danger],
                        startPoint: .top, endPoint: .bottom))
            }
            VStack(spacing: 10) {
                Text("Connect sleep data so \(petName) can wake up with you.")
                    .font(MooniFont.title(19))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                Text("Your sleep duration and consistency will shape \(petName)'s mood.")
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 8) {
                infoRow(icon: "moon.zzz.fill", title: "Auto-detect bedtime & wake-up")
                infoRow(icon: "lock.shield.fill", title: "Private — read only")
                infoRow(icon: "iphone.gen3", title: "Works without an Apple Watch")
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)

            if state == .authorized {
                Label("Connected to Apple Health", systemImage: "checkmark.seal.fill")
                    .font(MooniFont.caption(13))
                    .foregroundColor(MooniColor.success)
            } else if state == .denied {
                Text("Permission denied. You can enable it later in Settings → Health.")
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.warning)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .padding(.horizontal, 20)
    }

    private func infoRow(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(MooniColor.accent)
                .frame(width: 28)
            Text(title)
                .font(MooniFont.caption(13))
                .foregroundColor(MooniColor.textSecondary)
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Screen: Analyzing answers

private struct AnalyzingAnswersScreen: View {
    @Binding var progress: Double
    @Binding var currentStep: Int
    let petName: String

    /// Index inside `OnboardingView.analyzingScript` where each message begins.
    /// Has to stay in sync with that script's length (10 steps → 7 messages).
    static let stepBoundaries: [Int] = [0, 1, 3, 5, 7, 9]

    static let steps: [String] = stepBoundaries.map { _ in "" }

    @State private var orbit: Double = 0

    private var messages: [String] {
        [
            "Reading your answers…",
            "Mapping your chronotype…",
            "Calculating your sleep debt…",
            "Identifying your top 3 issues…",
            "Tuning your wake-up window…",
            "Aligning \(petName)'s growth schedule…"
        ]
    }

    var body: some View {
        VStack(spacing: 26) {
            Spacer().frame(height: 14)

            // Orbit halo around progress ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 8)
                    .frame(width: 180, height: 180)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(LinearGradient(colors: [MooniColor.accentSoft, MooniColor.accent],
                                           startPoint: .top, endPoint: .bottom),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.55), value: progress)
                ForEach(0..<3) { i in
                    Circle()
                        .fill(MooniColor.accent.opacity(0.6))
                        .frame(width: 6, height: 6)
                        .offset(x: 90)
                        .rotationEffect(.degrees(orbit + Double(i) * 120))
                }
                VStack(spacing: 2) {
                    Text("\(Int(progress * 100))")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(MooniColor.textPrimary)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.4), value: progress)
                    Text("%")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textMuted)
                }
            }
            .onAppear {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    orbit = 360
                }
            }

            // Currently animating message
            Text(messages[min(currentStep, messages.count - 1)])
                .font(MooniFont.title(17))
                .foregroundColor(MooniColor.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .id(currentStep)
                .transition(.opacity.combined(with: .move(edge: .bottom)))

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(messages.enumerated()), id: \.offset) { idx, msg in
                    HStack(spacing: 12) {
                        ZStack {
                            if idx < currentStep {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(MooniColor.success)
                                    .transition(.scale)
                            } else if idx == currentStep {
                                Circle()
                                    .stroke(MooniColor.accent, lineWidth: 1.5)
                                    .frame(width: 18, height: 18)
                                Circle()
                                    .fill(MooniColor.accent)
                                    .frame(width: 8, height: 8)
                                    .scaleEffect(idx == currentStep ? 1 : 0)
                            } else {
                                Image(systemName: "circle.dashed")
                                    .foregroundColor(MooniColor.textMuted)
                            }
                        }
                        .frame(width: 22)
                        Text(msg)
                            .font(MooniFont.body(14))
                            .foregroundColor(idx <= currentStep ? MooniColor.textPrimary : MooniColor.textSecondary)
                            .strikethrough(idx < currentStep, color: MooniColor.textMuted)
                        Spacer()
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 24)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Screen: Sleep score reveal

private struct SleepScoreRevealScreen: View {
    let profile: OnboardingProfile
    let petName: String

    @State private var animateNumber: Double = 0
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 22) {
            Text("YOUR CURRENT SLEEP SCORE")
                .font(MooniFont.caption(13))
                .foregroundColor(MooniColor.textMuted)
                .tracking(2)

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 14)
                    .frame(width: 220, height: 220)
                Circle()
                    .trim(from: 0, to: CGFloat(animateNumber) / 100)
                    .stroke(LinearGradient(
                        colors: [MooniColor.danger, MooniColor.warning, MooniColor.accentSoft],
                        startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .frame(width: 220, height: 220)
                    .rotationEffect(.degrees(-90))
                Circle()
                    .fill(MooniColor.warning.opacity(pulse ? 0.18 : 0.05))
                    .frame(width: 200, height: 200)
                    .blur(radius: 20)
                VStack(spacing: 4) {
                    Text("\(Int(animateNumber))")
                        .font(.system(size: 78, weight: .bold, design: .rounded))
                        .foregroundColor(MooniColor.textPrimary)
                    Text("/ 100")
                        .font(MooniFont.caption(13))
                        .foregroundColor(MooniColor.textMuted)
                }
            }

            VStack(spacing: 8) {
                Text(scoreVerdict)
                    .font(MooniFont.display(22))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Don't worry, \(petName). Mooni Pro members average \(profile.derivedSleepScore + 24) within 14 days.")
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            HStack(spacing: 12) {
                statBubble("Sleep age", "+\(profile.sleepAgeYearsAdded) yrs", color: MooniColor.danger)
                statBubble("Days lost / yr", "\(max(profile.daysLostPerYear, 18))", color: MooniColor.warning)
            }
            .padding(.horizontal, 24)
        }
        .padding(.horizontal, 16)
        .onAppear {
            withAnimation(.easeOut(duration: 1.6)) {
                animateNumber = Double(profile.derivedSleepScore)
            }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var scoreVerdict: String {
        switch profile.derivedSleepScore {
        case ..<45: return "There's real upside here."
        case 45..<60: return "You're below your potential."
        case 60..<70: return "You're closer than you think."
        default: return "Solid baseline — let's optimize."
        }
    }

    private func statBubble(_ label: String, _ value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(MooniFont.title(20))
                .foregroundColor(color)
            Text(label)
                .font(MooniFont.caption(11))
                .foregroundColor(MooniColor.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Screen: Top issues

private struct TopIssuesScreen: View {
    let profile: OnboardingProfile

    @State private var revealed: Int = 0
    private let revealTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private var issues: [(icon: String, tint: Color, title: String, severity: String)] {
        let raw = profile.topIssues
        let palette: [(String, Color, String)] = [
            ("iphone.gen3.radiowaves.left.and.right", MooniColor.danger,  "High"),
            ("brain.head.profile",                    MooniColor.warning, "High"),
            ("moon.zzz.fill",                         MooniColor.accent,  "Medium"),
            ("cup.and.saucer.fill",                   MooniColor.warning, "Medium"),
            ("sunrise.fill",                          MooniColor.accentSoft, "Medium")
        ]
        return raw.enumerated().map { idx, txt in
            let p = palette[min(idx, palette.count - 1)]
            return (p.0, p.1, txt, p.2)
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 36))
                    .foregroundStyle(LinearGradient(
                        colors: [MooniColor.accentSoft, MooniColor.accent],
                        startPoint: .top, endPoint: .bottom))
                    .padding(.bottom, 4)
                Text("Your sleep report")
                    .font(MooniFont.display(26))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text("\(issues.count) blocker\(issues.count == 1 ? "" : "s") found in your answers")
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                ForEach(Array(issues.enumerated()), id: \.offset) { idx, issue in
                    issueRow(index: idx, issue: issue, isRevealed: idx < revealed)
                }
            }
            .padding(.horizontal, 4)

            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundColor(MooniColor.accent)
                Text("Each one gets a tailored fix in your plan")
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textSecondary)
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .onReceive(revealTimer) { _ in
            if revealed < issues.count {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    revealed += 1
                }
            }
        }
    }

    private func issueRow(
        index: Int,
        issue: (icon: String, tint: Color, title: String, severity: String),
        isRevealed: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(issue.tint.opacity(0.18))
                    .frame(width: 48, height: 48)
                Image(systemName: issue.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(issue.tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Issue \(index + 1)")
                        .font(MooniFont.caption(11))
                        .foregroundColor(MooniColor.textMuted)
                        .tracking(1)
                    Text(issue.severity)
                        .font(MooniFont.caption(10))
                        .foregroundColor(issue.tint)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(issue.tint.opacity(0.18))
                        .clipShape(Capsule())
                }
                Text(issue.title)
                    .font(MooniFont.title(14))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(issue.tint.opacity(0.25), lineWidth: 1)
        )
        .opacity(isRevealed ? 1 : 0)
        .offset(y: isRevealed ? 0 : 12)
        .scaleEffect(isRevealed ? 1 : 0.96)
    }
}

// MARK: - Screen: Generating plan

private struct GeneratingPlanScreen: View {
    @Binding var progress: Double
    @Binding var messageIndex: Int
    let petName: String

    /// Index inside `OnboardingView.generatingScript` where each message advances.
    /// Has to stay in sync with that script's length (10 steps → 6 messages).
    static let stepBoundaries: [Int] = [0, 1, 3, 5, 7, 9]

    static let messages: [String] = stepBoundaries.map { _ in "" }

    @State private var orbit: Double = 0
    @State private var sparkleScale: CGFloat = 1

    private var msgs: [String] {
        [
            "Learning your sleep rhythm…",
            "Building your first bedtime quest…",
            "Preparing \(petName)'s dream room…",
            "Tuning your wake-up window…",
            "Composing wind-down breath cadence…",
            "Locking in tonight's plan…"
        ]
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer().frame(height: 4)

            // Single hero — pulsing orbital rings, no percentage chrome.
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [MooniColor.accent.opacity(0.55 - Double(i) * 0.15), .clear],
                                startPoint: .top, endPoint: .bottom),
                            lineWidth: 1.4
                        )
                        .frame(width: 130 + CGFloat(i) * 50, height: 130 + CGFloat(i) * 50)
                        .rotationEffect(.degrees(orbit * (i.isMultiple(of: 2) ? 1 : -1) * 0.6))
                        .opacity(0.85)
                }

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [MooniColor.accent.opacity(0.4), MooniColor.accentSoft.opacity(0.2), .clear],
                            center: .center, startRadius: 0, endRadius: 90)
                    )
                    .frame(width: 200, height: 200)
                    .blur(radius: 22)
                    .scaleEffect(sparkleScale)

                DreamSpiritView(pet: previewPet, size: 110)
                    .scaleEffect(sparkleScale * 0.98)
            }
            .frame(height: 230)
            .onAppear {
                withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) { orbit = 360 }
                withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { sparkleScale = 1.04 }
            }

            // Big single message — fades + slides between phases.
            VStack(spacing: 8) {
                Text("Building your plan")
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.accentSoft)
                    .tracking(2)
                    .textCase(.uppercase)
                Text(msgs[min(messageIndex, msgs.count - 1)])
                    .font(MooniFont.display(22))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .id(messageIndex)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(.easeInOut(duration: 0.45), value: messageIndex)
            }
            .frame(minHeight: 90)

            // Slim progress strip with no number — feels less mechanical.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10))
                    Capsule()
                        .fill(LinearGradient(colors: [MooniColor.accentSoft, MooniColor.accent],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(progress))
                        .animation(.easeInOut(duration: 0.55), value: progress)
                }
            }
            .frame(height: 5)
            .padding(.horizontal, 40)

            // Sub-line: pet name + dot pulse, no checklist.
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(MooniColor.accent.opacity(0.85))
                        .frame(width: 6, height: 6)
                        .scaleEffect(dotScale(i))
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(i) * 0.18),
                            value: sparkleScale)
                }
                Text("\(petName) is getting cozy…")
                    .font(MooniFont.caption(13))
                    .foregroundColor(MooniColor.textSecondary)
                    .padding(.leading, 6)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }

    private var previewPet: Pet {
        var p = Pet(); p.species = .fox; p.mood = .cozy; p.equippedHat = "hat_nightcap"
        return p
    }

    private func dotScale(_ index: Int) -> CGFloat {
        sparkleScale + CGFloat(index) * 0.02
    }
}

// MARK: - Screen: Social proof

private struct SocialProofScreen: View {
    private struct Review {
        let text: String
        let author: String
    }
    private let reviews: [Review] = [
        Review(text: "I haven't woken up tired in 3 weeks. The pet thing actually worked on me.",
               author: "Sarah, 28"),
        Review(text: "Stopped scrolling in bed because I didn't want my fox to be sad.",
               author: "Marco, 34"),
        Review(text: "First app that actually fixed my schedule. Tiny daily wins compound.",
               author: "Priya, 41")
    ]

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                HStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 13))
                            .foregroundColor(MooniColor.warning)
                    }
                    Text("4.9")
                        .font(MooniFont.title(13))
                        .foregroundColor(MooniColor.warning)
                        .padding(.leading, 4)
                }
                Text("Loved by sleepers like you")
                    .font(MooniFont.display(22))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 4)

            VStack(spacing: 10) {
                ForEach(reviews.indices, id: \.self) { i in
                    reviewCard(reviews[i])
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func reviewCard(_ review: Review) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(MooniColor.warning)
                }
            }
            Text("\u{201C}\(review.text)\u{201D}")
                .font(MooniFont.body(14))
                .foregroundColor(MooniColor.textPrimary)
                .multilineTextAlignment(.leading)
            Text("— \(review.author)")
                .font(MooniFont.caption(12))
                .foregroundColor(MooniColor.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Screen: Simulated result

private struct SimulatedResultScreen: View {
    let species: PetSpecies
    let name: String

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("Tomorrow morning, \(name) will wake up like this…")
                    .font(MooniFont.title(18))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 6)

            VStack(spacing: 12) {
                outcomeCard(mood: .energized, label: "Great sleep",
                            detail: "Bright room, happy pet, full energy.")
                outcomeCard(mood: .calm, label: "Okay sleep",
                            detail: "Steady mood. \(name) is normal.")
                outcomeCard(mood: .groggy, label: "Poor sleep",
                            detail: "Tired pet, dim room — easy to recover.")
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 20)
    }

    private func outcomeCard(mood: Pet.Mood, label: String, detail: String) -> some View {
        var p = Pet(); p.species = species; p.mood = mood; p.equippedHat = nil
        return HStack(spacing: 14) {
            DreamSpiritView(pet: p, size: 56)
                .frame(width: 80, height: 80)
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(MooniFont.title(15))
                    .foregroundColor(MooniColor.textPrimary)
                Text(detail)
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Screen: First quest

private struct FirstQuestScreen: View {
    let petName: String
    let bedtime: Date
    let wakeTime: Date

    private var windDownTime: String {
        let d = bedtime.addingTimeInterval(-30 * 60)
        return d.hourMinuteString
    }

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text("Tonight's quest")
                    .font(MooniFont.caption(14))
                    .foregroundColor(MooniColor.accentSoft)
                    .textCase(.uppercase)
                Text("Help \(petName) get cozy")
                    .font(MooniFont.display(26))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            VStack(spacing: 10) {
                questRow(icon: "moon.zzz.fill", title: "Start wind-down by \(windDownTime)")
                questRow(icon: "iphone.slash", title: "Avoid phone in bed")
                questRow(icon: "sun.max.fill", title: "Wake up around \(wakeTime.hourMinuteString)")
            }
            .padding(.horizontal, 4)

            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundColor(MooniColor.warning)
                Text("Reward: 20 dream stars")
                    .font(MooniFont.title(14))
                    .foregroundColor(MooniColor.textPrimary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 18)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
            .padding(.top, 6)
        }
        .padding(.horizontal, 20)
    }

    private func questRow(icon: String, title: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(MooniColor.accent)
                .frame(width: 36, height: 36)
                .background(MooniColor.accent.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(title)
                .font(MooniFont.title(15))
                .foregroundColor(MooniColor.textPrimary)
            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Fact interstitial scaffold

private struct FactScaffold<Content: View>: View {
    let eyebrow: String
    let title: String
    let source: String?
    @ViewBuilder var content: () -> Content

    @State private var titleAppear = false

    var body: some View {
        VStack(spacing: 18) {
            Text(eyebrow)
                .font(MooniFont.caption(12))
                .foregroundColor(MooniColor.accentSoft)
                .tracking(2)
                .textCase(.uppercase)
                .opacity(titleAppear ? 1 : 0)
                .offset(y: titleAppear ? 0 : 8)

            Text(title)
                .font(MooniFont.display(24))
                .foregroundColor(MooniColor.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .opacity(titleAppear ? 1 : 0)
                .offset(y: titleAppear ? 0 : 12)

            content()
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 4)

            if let s = source {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(MooniColor.success.opacity(0.7))
                        .font(.system(size: 9))
                    Text(s)
                        .font(MooniFont.caption(10))
                        .foregroundColor(MooniColor.textMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { titleAppear = true }
        }
    }
}

// MARK: - Cinematic count-up label

private struct CountUpText: View {
    let target: Double
    var duration: Double = 1.6
    var format: (Double) -> String = { String(format: "%.0f", $0) }
    var font: Font = .system(size: 64, weight: .bold, design: .rounded)
    var color: Color = MooniColor.textPrimary
    var glow: Color? = nil

    @State private var current: Double = 0

    var body: some View {
        Text(format(current))
            .font(font)
            .foregroundColor(color)
            .contentTransition(.numericText(value: current))
            .shadow(color: glow?.opacity(0.55) ?? .clear, radius: 12)
            .onAppear {
                withAnimation(.easeOut(duration: duration)) {
                    current = target
                }
            }
    }
}

// MARK: - Animated bar chart with deceptive-scale option

private struct DramaticBarChart: View {
    struct Bar: Identifiable {
        let id = UUID()
        let label: String        // small label under the bar
        let value: Double        // chart value 0…1 (visual height)
        let displayText: String  // text shown above the bar (e.g. "6.5 hrs")
        let color: Color
    }
    let bars: [Bar]
    /// When true, bars start from `truncatedFloor` (e.g. 0.6) so small percentage
    /// differences look enormous. Classic chart-trick.
    var truncated: Bool = false
    var truncatedFloor: Double = 0.5
    var maxValue: Double = 1.0

    @State private var animatedValues: [Double] = []

    private func barHeight(for value: Double, totalHeight: CGFloat) -> CGFloat {
        if truncated {
            let normalized = (value - truncatedFloor) / max(0.001, maxValue - truncatedFloor)
            return totalHeight * CGFloat(max(0.06, min(1.0, normalized)))
        } else {
            return totalHeight * CGFloat(max(0.04, min(1.0, value / maxValue)))
        }
    }

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            // Reserve fixed space for top label + bottom label so the bar height
            // is predictable and labels never overlap the bar itself.
            let labelTop: CGFloat = 28
            let labelBottom: CGFloat = 22
            let trackH = max(40, h - labelTop - labelBottom - 12)

            HStack(alignment: .bottom, spacing: 30) {
                ForEach(Array(bars.enumerated()), id: \.element.id) { idx, bar in
                    VStack(spacing: 6) {
                        Text(bar.displayText)
                            .font(MooniFont.title(16))
                            .foregroundColor(bar.color)
                            .frame(height: labelTop)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                                .frame(width: 70, height: trackH)
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(LinearGradient(
                                    colors: [bar.color.opacity(0.95), bar.color.opacity(0.55)],
                                    startPoint: .top, endPoint: .bottom))
                                .frame(
                                    width: 70,
                                    height: barHeight(
                                        for: animatedValues.indices.contains(idx) ? animatedValues[idx] : 0,
                                        totalHeight: trackH
                                    )
                                )
                                .shadow(color: bar.color.opacity(0.55), radius: 18, y: 4)
                        }
                        .frame(height: trackH)
                        Text(bar.label)
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.textPrimary)
                            .frame(height: labelBottom)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .onAppear {
            animatedValues = Array(repeating: 0, count: bars.count)
            for (i, bar) in bars.enumerated() {
                withAnimation(.spring(response: 0.9, dampingFraction: 0.65).delay(0.15 * Double(i))) {
                    if animatedValues.indices.contains(i) { animatedValues[i] = bar.value }
                }
            }
        }
    }
}

// MARK: - Axis-labeled line chart

/// Single-frame compare chart with two curves drawn against shared axes.
/// We avoid stacking two AxisLineCharts because their text labels would overlap.
private struct CortisolCompareChart: View {
    let calm: [Double]
    let stressed: [Double]
    let phase: CGFloat

    var body: some View {
        GeometryReader { geo in
            let leftInset: CGFloat = 32
            let bottomInset: CGFloat = 22
            let plotW = geo.size.width - leftInset
            let plotH = geo.size.height - bottomInset
            let allMax = max(calm.max() ?? 1, stressed.max() ?? 1, 0.001)
            let stepX = max(calm.count, stressed.count) > 1
                ? plotW / CGFloat(max(calm.count, stressed.count) - 1) : plotW

            ZStack(alignment: .topLeading) {
                // Y-axis labels
                VStack(alignment: .trailing) {
                    Text("high").font(MooniFont.caption(9)).foregroundColor(MooniColor.textMuted)
                    Spacer()
                    Text("low").font(MooniFont.caption(9)).foregroundColor(MooniColor.textMuted)
                }
                .frame(width: leftInset - 6, height: plotH, alignment: .trailing)
                .padding(.trailing, 6)

                // Grid lines
                ForEach(0..<4) { i in
                    let y = plotH * CGFloat(i) / 3
                    Path { p in
                        p.move(to: CGPoint(x: leftInset, y: y))
                        p.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(Color.white.opacity(i == 3 ? 0.16 : 0.05),
                            style: StrokeStyle(lineWidth: 1, dash: i == 3 ? [] : [2, 4]))
                }

                // Stressed area fill
                Path { p in
                    p.move(to: CGPoint(x: leftInset, y: plotH))
                    for (i, v) in stressed.enumerated() {
                        let x = leftInset + CGFloat(i) * stepX
                        let y = plotH - (CGFloat(v / allMax) * plotH * 0.92) - plotH * 0.04
                        if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                        else      { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    p.addLine(to: CGPoint(x: leftInset + CGFloat(stressed.count - 1) * stepX, y: plotH))
                    p.addLine(to: CGPoint(x: leftInset, y: plotH))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [MooniColor.danger.opacity(0.30), MooniColor.danger.opacity(0.0)],
                                     startPoint: .top, endPoint: .bottom))
                .mask(
                    Rectangle()
                        .frame(width: leftInset + plotW * phase, height: plotH, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                )

                // Stressed line
                line(stressed, leftInset: leftInset, plotW: plotW, plotH: plotH, stepX: stepX, max: allMax)
                    .trim(from: 0, to: phase)
                    .stroke(MooniColor.danger,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .shadow(color: MooniColor.danger.opacity(0.5), radius: 6)

                // Calm line
                line(calm, leftInset: leftInset, plotW: plotW, plotH: plotH, stepX: stepX, max: allMax)
                    .trim(from: 0, to: phase)
                    .stroke(MooniColor.success,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .shadow(color: MooniColor.success.opacity(0.5), radius: 6)

                // X-axis labels
                HStack(spacing: 0) {
                    ForEach(["6pm","9pm","12am","3am","6am"], id: \.self) { l in
                        Text(l)
                            .font(MooniFont.caption(9))
                            .foregroundColor(MooniColor.textMuted)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.leading, leftInset)
                .frame(width: geo.size.width, alignment: .leading)
                .offset(y: plotH + 6)
            }
        }
    }

    private func line(_ values: [Double], leftInset: CGFloat, plotW: CGFloat,
                      plotH: CGFloat, stepX: CGFloat, max: Double) -> Path {
        Path { p in
            for (i, v) in values.enumerated() {
                let x = leftInset + CGFloat(i) * stepX
                let y = plotH - (CGFloat(v / max) * plotH * 0.92) - plotH * 0.04
                if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                else      { p.addLine(to: CGPoint(x: x, y: y)) }
            }
        }
    }
}

private struct AxisLineChart: View {
    let data: [Double]
    let phase: CGFloat
    let accent: Color
    let fillTop: Color
    let fillBottom: Color
    var xLabels: [String] = []
    var yMaxLabel: String = ""
    var yMinLabel: String = ""
    var highlightLastLabel: String? = nil

    var body: some View {
        GeometryReader { geo in
            let leftInset: CGFloat = 28
            let bottomInset: CGFloat = 22
            let plotW = geo.size.width - leftInset
            let plotH = geo.size.height - bottomInset
            let maxVal = max(data.max() ?? 1, 0.001)
            let stepX = data.count > 1 ? plotW / CGFloat(data.count - 1) : plotW

            ZStack(alignment: .topLeading) {
                // Y-axis labels
                VStack(alignment: .trailing) {
                    Text(yMaxLabel).font(MooniFont.caption(9)).foregroundColor(MooniColor.textMuted)
                    Spacer()
                    Text(yMinLabel).font(MooniFont.caption(9)).foregroundColor(MooniColor.textMuted)
                }
                .frame(width: leftInset - 6, height: plotH, alignment: .trailing)
                .padding(.trailing, 6)

                // Grid lines
                ForEach(0..<4) { i in
                    let y = plotH * CGFloat(i) / 3
                    Path { p in
                        p.move(to: CGPoint(x: leftInset, y: y))
                        p.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(Color.white.opacity(i == 3 ? 0.16 : 0.05),
                            style: StrokeStyle(lineWidth: 1, dash: i == 3 ? [] : [2, 4]))
                }

                // Filled area
                Path { p in
                    p.move(to: CGPoint(x: leftInset, y: plotH))
                    for (i, v) in data.enumerated() {
                        let x = leftInset + CGFloat(i) * stepX
                        let y = plotH - (CGFloat(v / maxVal) * plotH * 0.92) - plotH * 0.04
                        if i == 0 {
                            p.move(to: CGPoint(x: x, y: y))
                        } else {
                            p.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    p.addLine(to: CGPoint(x: leftInset + CGFloat(data.count - 1) * stepX, y: plotH))
                    p.addLine(to: CGPoint(x: leftInset, y: plotH))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [fillTop, fillBottom],
                                     startPoint: .top, endPoint: .bottom))
                .mask(
                    Rectangle()
                        .frame(width: leftInset + plotW * phase, height: plotH, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                )

                // Line
                Path { p in
                    for (i, v) in data.enumerated() {
                        let x = leftInset + CGFloat(i) * stepX
                        let y = plotH - (CGFloat(v / maxVal) * plotH * 0.92) - plotH * 0.04
                        if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                        else      { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .trim(from: 0, to: phase)
                .stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .shadow(color: accent.opacity(0.5), radius: 6, y: 1)

                // End-marker pulse
                if let last = data.last {
                    let x = leftInset + CGFloat(data.count - 1) * stepX
                    let y = plotH - (CGFloat(last / maxVal) * plotH * 0.92) - plotH * 0.04
                    Circle()
                        .fill(accent)
                        .frame(width: 14, height: 14)
                        .position(x: x, y: y)
                        .opacity(Double(phase))
                        .shadow(color: accent.opacity(0.8), radius: 8)
                    Circle()
                        .stroke(accent.opacity(0.5), lineWidth: 1)
                        .frame(width: 28, height: 28)
                        .position(x: x, y: y)
                        .opacity(Double(phase) * 0.4)

                    if let label = highlightLastLabel {
                        Text(label)
                            .font(MooniFont.caption(11))
                            .foregroundColor(accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(accent.opacity(0.15))
                            .clipShape(Capsule())
                            .position(x: min(x - 8, geo.size.width - 60), y: max(y - 22, 12))
                            .opacity(Double(phase))
                    }
                }

                // X-axis labels
                if !xLabels.isEmpty {
                    HStack(spacing: 0) {
                        ForEach(xLabels.indices, id: \.self) { i in
                            Text(xLabels[i])
                                .font(MooniFont.caption(9))
                                .foregroundColor(MooniColor.textMuted)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.leading, leftInset)
                    .frame(width: geo.size.width, alignment: .leading)
                    .offset(y: plotH + 6)
                }
            }
        }
    }
}

// MARK: - Fact: Body needs (you vs ideal — dramatic gap)

private struct BodyFactScreen: View {
    let profile: OnboardingProfile

    private var idealHours: Double {
        switch profile.age ?? 28 {
        case ..<18: return 9.0
        case 18..<25: return 8.0
        case 25..<45: return 7.5
        case 45..<65: return 7.0
        default: return 7.0
        }
    }

    private var youHours: Double { profile.typicalSleepHours }

    private var deficit: Double { max(0, idealHours - youHours) }

    var body: some View {
        FactScaffold(
            eyebrow: "What your body actually needs",
            title: "You sleep \(String(format: "%.1f", youHours)) — your body wants \(String(format: "%.1f", idealHours))",
            source: "National Sleep Foundation · age-stratified sleep duration consensus, 2015."
        ) {
            VStack(spacing: 18) {
                DramaticBarChart(
                    bars: [
                        .init(label: "You",
                              value: youHours / 12,
                              displayText: String(format: "%.1f hrs", youHours),
                              color: MooniColor.danger),
                        .init(label: "Need",
                              value: idealHours / 12,
                              displayText: String(format: "%.1f hrs", idealHours),
                              color: MooniColor.success)
                    ],
                    truncated: true,
                    truncatedFloor: max(0, (youHours - 1.5) / 12),
                    maxValue: idealHours / 12 + 0.05
                )
                .frame(height: 220)

                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(MooniColor.danger)
                    Text("That's a \(String(format: "%.1f", deficit))-hour daily debt — \(Int(deficit * 365)) hrs / year.")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textPrimary)
                    Spacer()
                }
                .padding(12)
                .background(MooniColor.danger.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(20)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

// MARK: - Fact: Sleep debt (compounds across the week)

private struct SleepDebtFactScreen: View {
    let profile: OnboardingProfile
    @State private var phase: CGFloat = 0

    /// Curve to make a smooth-feeling compounding line (slight bend, not pure linear).
    private var dailyDeficit: Double { max(0.5, 8.0 - profile.typicalSleepHours) }
    private var weekTotal: Double { dailyDeficit * 7 }
    private var yearTotal: Double { dailyDeficit * 365 }

    /// Slight curvature so the chart reads as "compounding" instead of a perfect ramp.
    private var weekData: [Double] {
        (1...7).map { day in
            let t = Double(day)
            return dailyDeficit * (t + 0.06 * t * t)
        }
    }

    var body: some View {
        FactScaffold(
            eyebrow: "Sleep debt compounds",
            title: "You're losing sleep faster than you can repay",
            source: "Walker MP. Why We Sleep, Ch.7 · sleep-debt accumulation literature."
        ) {
            VStack(spacing: 14) {
                // Big dramatic counter — pass yearTotal directly so the count-up
                // actually animates (state-bound target captured at 0 = no animation).
                VStack(spacing: 0) {
                    CountUpText(
                        target: yearTotal,
                        duration: 2.0,
                        format: { String(format: "%.0f", $0) },
                        font: .system(size: 76, weight: .bold, design: .rounded),
                        color: MooniColor.danger,
                        glow: MooniColor.danger
                    )
                    Text("HOURS LOST PER YEAR")
                        .font(MooniFont.caption(11))
                        .foregroundColor(MooniColor.textMuted)
                        .tracking(2)
                }
                .padding(.top, 4)

                AxisLineChart(
                    data: weekData,
                    phase: phase,
                    accent: MooniColor.danger,
                    fillTop: MooniColor.danger.opacity(0.55),
                    fillBottom: MooniColor.danger.opacity(0.0),
                    xLabels: ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"],
                    yMaxLabel: String(format: "%.0fh", weekData.last ?? weekTotal),
                    yMinLabel: "0h",
                    highlightLastLabel: "−\(String(format: "%.0f", weekData.last ?? weekTotal))h"
                )
                .frame(height: 180)

                HStack(spacing: 10) {
                    debtChip("Per week", String(format: "%.0fh", weekTotal), MooniColor.warning)
                    debtChip("Per month", String(format: "%.0fh", weekTotal * 4.3), MooniColor.danger)
                    debtChip("Per year", String(format: "%.0fh", yearTotal), MooniColor.danger)
                }
            }
            .padding(20)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .onAppear {
                withAnimation(.easeOut(duration: 1.8)) { phase = 1 }
            }
        }
    }

    private func debtChip(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(MooniFont.title(15)).foregroundColor(color)
            Text(label).font(MooniFont.caption(10)).foregroundColor(MooniColor.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Fact: Phone before bed (melatonin gap)

private struct PhoneFactScreen: View {
    let profile: OnboardingProfile
    @State private var phase: CGFloat = 0
    @State private var counter: Double = 0

    /// Truncated y-axis melatonin curves — phone version stays low, no-phone rises sharply.
    /// The visual gap is intentional: phones suppress the natural curve.
    private var noPhoneCurve: [Double] { [0.05, 0.10, 0.22, 0.50, 0.82, 0.97, 1.00, 0.94, 0.84] }
    private var phoneCurve:   [Double] { [0.05, 0.06, 0.08, 0.11, 0.18, 0.32, 0.50, 0.66, 0.62] }

    /// Estimate of sleep stolen (mins) based on screen minutes used.
    private var sleepStolen: Double {
        // ~50 min stolen at 60min screen, scales sub-linearly
        let m = Double(profile.phoneScreenMinutes)
        return min(120, 30 + (m / 60.0) * 35)
    }

    var body: some View {
        FactScaffold(
            eyebrow: "Phones flatten melatonin",
            title: "Your habit costs ~\(Int(sleepStolen)) minutes of real sleep",
            source: "Chang et al. PNAS 2014 · iPad use suppresses evening melatonin by 23%."
        ) {
            VStack(spacing: 14) {
                // Big stolen-minutes counter
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    CountUpText(
                        target: sleepStolen,
                        duration: 1.4,
                        format: { String(format: "−%.0f", $0) },
                        font: .system(size: 60, weight: .bold, design: .rounded),
                        color: MooniColor.danger,
                        glow: MooniColor.danger
                    )
                    Text("min/night")
                        .font(MooniFont.body(15))
                        .foregroundColor(MooniColor.textMuted)
                        .padding(.bottom, 6)
                }
                .padding(.top, 4)

                ZStack {
                    AxisLineChart(
                        data: noPhoneCurve,
                        phase: phase,
                        accent: MooniColor.success,
                        fillTop: MooniColor.success.opacity(0.0),
                        fillBottom: MooniColor.success.opacity(0.0),
                        xLabels: ["8pm","9pm","10pm","11pm","12am"],
                        yMaxLabel: "peak",
                        yMinLabel: "low"
                    )
                    AxisLineChart(
                        data: phoneCurve,
                        phase: phase,
                        accent: MooniColor.danger,
                        fillTop: MooniColor.danger.opacity(0.45),
                        fillBottom: MooniColor.danger.opacity(0.0),
                        xLabels: [],
                        yMaxLabel: "",
                        yMinLabel: ""
                    )
                }
                .frame(height: 180)

                HStack(spacing: 16) {
                    legendDot(MooniColor.success, "No phone — natural rise")
                    legendDot(MooniColor.danger,  "Your habit — flatlined")
                }
                .font(MooniFont.caption(11))
            }
            .padding(20)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .onAppear {
                withAnimation(.easeOut(duration: 1.6)) { phase = 1 }
                counter = sleepStolen
            }
        }
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).foregroundColor(MooniColor.textSecondary)
        }
    }
}

// MARK: - Fact: Caffeine (cup-decay)

private struct CaffeineFactScreen: View {
    @State private var phase: CGFloat = 0
    @State private var pulse = false

    /// 13 hourly samples from 2pm coffee → 3am.
    private var data: [Double] { (0..<13).map { i in pow(0.5, Double(i) / 6.0) } }

    var body: some View {
        FactScaffold(
            eyebrow: "Caffeine half-life",
            title: "That 2pm coffee is still working at midnight",
            source: "Drake et al. J Clin Sleep Med 2013 · caffeine 6h before bed cut sleep 41 min."
        ) {
            VStack(spacing: 14) {
                // Coffee cups visualization showing decay
                HStack(alignment: .bottom, spacing: 10) {
                    cupAt(label: "2pm", percent: 1.00, danger: true)
                    cupAt(label: "8pm", percent: 0.50, danger: true)
                    cupAt(label: "Bedtime", percent: 0.25, danger: true)
                    cupAt(label: "3am", percent: 0.13, danger: true)
                }
                .frame(height: 110)

                AxisLineChart(
                    data: data,
                    phase: phase,
                    accent: MooniColor.warning,
                    fillTop: MooniColor.warning.opacity(0.55),
                    fillBottom: MooniColor.warning.opacity(0.0),
                    xLabels: ["2pm","6pm","10pm","2am"],
                    yMaxLabel: "100%",
                    yMinLabel: "0%",
                    highlightLastLabel: "13%"
                )
                .frame(height: 130)

                HStack(spacing: 8) {
                    Image(systemName: "cup.and.saucer.fill").foregroundColor(MooniColor.warning)
                    Text("Equivalent to ¼ cup of coffee in your bloodstream at bedtime.")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textPrimary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MooniColor.warning.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(20)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .onAppear {
                withAnimation(.easeOut(duration: 1.8)) { phase = 1 }
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { pulse = true }
            }
        }
    }

    private func cupAt(label: String, percent: Double, danger: Bool) -> some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottom) {
                // Cup body
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(MooniColor.textPrimary.opacity(0.45), lineWidth: 1.5)
                    .frame(width: 36, height: 50)
                // Coffee fill
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(LinearGradient(
                        colors: [MooniColor.warning, MooniColor.danger.opacity(0.8)],
                        startPoint: .top, endPoint: .bottom))
                    .frame(width: 32, height: max(4, 46 * percent))
                    .animation(.spring(response: 0.9, dampingFraction: 0.7), value: phase)
                    .padding(.bottom, 2)
                    .opacity(Double(phase))
                // Handle
                Circle()
                    .stroke(MooniColor.textPrimary.opacity(0.45), lineWidth: 1.5)
                    .frame(width: 10, height: 10)
                    .offset(x: 22, y: -8)
            }
            Text("\(Int(percent * 100))%")
                .font(MooniFont.caption(11))
                .foregroundColor(percent > 0.4 ? MooniColor.danger : MooniColor.warning)
            Text(label)
                .font(MooniFont.caption(10))
                .foregroundColor(MooniColor.textMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Fact: Stress (truncated-axis dramatization)

private struct StressFactScreen: View {
    @State private var bar1: Double = 0
    @State private var bar2: Double = 0
    @State private var phase: CGFloat = 0

    /// Cortisol-driven curve: a healthy night drops to ~10% before sleep.
    /// A stressed night flatlines around 50% — bigger gap = visceral.
    private var calmCurve:    [Double] { [0.85, 0.62, 0.40, 0.22, 0.12, 0.10, 0.10, 0.12, 0.18] }
    private var stressedCurve:[Double] { [0.85, 0.78, 0.70, 0.62, 0.58, 0.55, 0.54, 0.56, 0.60] }

    var body: some View {
        FactScaffold(
            eyebrow: "Cortisol blocks deep sleep",
            title: "Stress steals 40% of your deep sleep",
            source: "Kim & Dimsdale, Behav Sleep Med 2007 · stress & slow-wave sleep meta."
        ) {
            VStack(spacing: 16) {
                // Truncated-axis bar comparison
                DramaticBarChart(
                    bars: [
                        .init(label: "Calm night",
                              value: 1.8 / 2.0,
                              displayText: "1.8 hrs",
                              color: MooniColor.success),
                        .init(label: "Stressed",
                              value: 1.1 / 2.0,
                              displayText: "1.1 hrs",
                              color: MooniColor.danger)
                    ],
                    truncated: true,
                    truncatedFloor: 0.45,
                    maxValue: 0.95
                )
                .frame(height: 200)

                // Cortisol curve — single chart, two paths drawn inside
                CortisolCompareChart(
                    calm: calmCurve,
                    stressed: stressedCurve,
                    phase: phase
                )
                .frame(height: 150)
                .padding(.top, 4)

                HStack(spacing: 8) {
                    Image(systemName: "wind").foregroundColor(MooniColor.accent)
                    Text("Mooni's wind-down crashes cortisol so deep sleep returns.")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.accentSoft)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MooniColor.accent.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(20)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .onAppear {
                withAnimation(.easeOut(duration: 1.6)) { phase = 1 }
            }
        }
    }
}

// MARK: - Fact: Day cycle (cinematic 24h dial)

private struct DayCycleFactScreen: View {
    @State private var rotation: Double = 0
    @State private var pulse = false
    @State private var arcReveal: CGFloat = 0

    var body: some View {
        FactScaffold(
            eyebrow: "Your circadian dial",
            title: "Same wake time = stable rhythm",
            source: "Czeisler CA et al. Science 1999 · stable wake-time entrains the SCN."
        ) {
            VStack(spacing: 14) {
                ZStack {
                    // Day/night ring
                    Circle()
                        .stroke(LinearGradient(
                            colors: [
                                Color(red: 0.05, green: 0.07, blue: 0.20),
                                Color(red: 0.18, green: 0.10, blue: 0.30),
                                Color(red: 0.95, green: 0.78, blue: 0.55),
                                Color(red: 1.00, green: 0.85, blue: 0.62),
                                Color(red: 0.30, green: 0.20, blue: 0.45),
                                Color(red: 0.05, green: 0.07, blue: 0.20)
                            ],
                            startPoint: .top, endPoint: .bottom),
                                lineWidth: 8)
                        .frame(width: 220, height: 220)

                    // Hour ticks
                    ForEach(0..<24, id: \.self) { h in
                        Capsule()
                            .fill(Color.white.opacity(h % 6 == 0 ? 0.95 : 0.30))
                            .frame(width: 2, height: h % 6 == 0 ? 14 : 6)
                            .offset(y: -113)
                            .rotationEffect(.degrees(Double(h) * 15))
                    }

                    // Sleep window arc (10pm–7am)
                    Circle()
                        .trim(from: 0.04, to: arcReveal)
                        .stroke(MooniColor.accent.opacity(0.5),
                                style: StrokeStyle(lineWidth: 28, lineCap: .round))
                        .frame(width: 220, height: 220)
                        .rotationEffect(.degrees(-90))

                    // Sun marker rotating around dial
                    Image(systemName: "sun.max.fill")
                        .foregroundStyle(LinearGradient(colors: [.yellow, MooniColor.warning],
                                                        startPoint: .top, endPoint: .bottom))
                        .font(.system(size: 22))
                        .offset(y: -110)
                        .rotationEffect(.degrees(rotation))
                        .scaleEffect(pulse ? 1.1 : 1.0)
                        .shadow(color: .yellow.opacity(0.6), radius: 12)

                    // Center
                    VStack(spacing: 2) {
                        Text("STABLE WAKE")
                            .font(MooniFont.caption(10))
                            .foregroundColor(MooniColor.textMuted)
                            .tracking(2)
                        Text("24 hr")
                            .font(MooniFont.title(20))
                            .foregroundColor(MooniColor.textPrimary)
                        Text("locks rhythm")
                            .font(MooniFont.caption(10))
                            .foregroundColor(MooniColor.accent)
                    }
                }
                .padding(.top, 4)
                .onAppear {
                    withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) { rotation = 360 }
                    withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { pulse = true }
                    withAnimation(.easeOut(duration: 1.6)) { arcReveal = 0.32 }
                }

                HStack(spacing: 8) {
                    cycleChip("6am", "sunrise.fill", MooniColor.warning)
                    cycleChip("2pm", "sun.max.fill", MooniColor.warning)
                    cycleChip("10pm", "moon.fill", MooniColor.accent)
                    cycleChip("3am", "moon.stars.fill", MooniColor.accent)
                }
            }
            .padding(20)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func cycleChip(_ time: String, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundColor(color)
            Text(time).font(MooniFont.caption(10)).foregroundColor(MooniColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Fact: Environment (with overshoot bars)

private struct EnvironmentFactScreen: View {
    let profile: OnboardingProfile
    @State private var darkVal: CGFloat = 0
    @State private var quietVal: CGFloat = 0
    @State private var comfyVal: CGFloat = 0
    @State private var totalScore: Double = 0

    private var darkScore: Double {
        switch profile.roomDarkness {
        case .dark: return 0.95
        case .someLight: return 0.55
        default: return 0.18
        }
    }
    private var quietScore: Double {
        switch profile.roomNoise {
        case .quiet: return 0.95
        case .someNoise: return 0.55
        default: return 0.20
        }
    }
    private var comfyScore: Double {
        switch profile.bedComfort {
        case .comfortable: return 0.95
        case .okay: return 0.55
        default: return 0.22
        }
    }
    private var combined: Double {
        ((darkScore + quietScore + comfyScore) / 3) * 100
    }

    var body: some View {
        FactScaffold(
            eyebrow: "Environment audit",
            title: "Your room scores \(Int(combined))/100 for sleep",
            source: "Sleep Foundation · darkness, sound & comfort weight by Buysse PSQI."
        ) {
            VStack(spacing: 14) {
                // Big dramatic combined score
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 12)
                        .frame(width: 160, height: 160)
                    Circle()
                        .trim(from: 0, to: CGFloat(totalScore / 100))
                        .stroke(LinearGradient(colors: scoreGradient,
                                               startPoint: .top, endPoint: .bottom),
                                style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .frame(width: 160, height: 160)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: -2) {
                        CountUpText(
                            target: combined,
                            duration: 1.6,
                            format: { String(format: "%.0f", $0) },
                            font: .system(size: 52, weight: .bold, design: .rounded),
                            color: MooniColor.textPrimary
                        )
                        Text("/ 100")
                            .font(MooniFont.caption(11))
                            .foregroundColor(MooniColor.textMuted)
                    }
                }

                envBar("Darkness", "moon.fill", darkScore, MooniColor.accent, darkVal)
                envBar("Quiet",    "ear.badge.checkmark", quietScore, MooniColor.success, quietVal)
                envBar("Comfort",  "bed.double.fill", comfyScore, MooniColor.warning, comfyVal)

                Text("We'll work around what we can't control tonight.")
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textSecondary)
                    .padding(.top, 4)
            }
            .padding(20)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .onAppear {
                withAnimation(.spring(response: 0.9, dampingFraction: 0.7)) {
                    darkVal = CGFloat(darkScore)
                }
                withAnimation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.15)) {
                    quietVal = CGFloat(quietScore)
                }
                withAnimation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.30)) {
                    comfyVal = CGFloat(comfyScore)
                }
                totalScore = combined
            }
        }
    }

    private var scoreGradient: [Color] {
        if combined >= 75 { return [MooniColor.success, MooniColor.accentSoft] }
        if combined >= 50 { return [MooniColor.warning, MooniColor.accentSoft] }
        return [MooniColor.danger, MooniColor.warning]
    }

    private func envBar(_ label: String, _ icon: String, _ impact: Double, _ color: Color, _ value: CGFloat) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(label).font(MooniFont.caption(13)).foregroundColor(MooniColor.textPrimary)
                    Spacer()
                    Text("\(Int(impact * 100))%")
                        .font(MooniFont.caption(11))
                        .foregroundColor(impact > 0.7 ? MooniColor.success
                                          : impact > 0.4 ? MooniColor.warning
                                          : MooniColor.danger)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.10))
                        Capsule()
                            .fill(LinearGradient(colors: [color.opacity(0.85), color],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * value)
                            .shadow(color: color.opacity(0.55), radius: 6)
                    }
                }
                .frame(height: 8)
            }
        }
    }
}

#Preview {
    OnboardingView().environmentObject(AppState())
}
