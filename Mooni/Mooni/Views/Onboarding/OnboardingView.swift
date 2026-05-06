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
    @State private var species: PetSpecies = .fox
    @State private var petName: String = PetSpecies.fox.defaultName

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

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 14)

                ScrollView(showsIndicators: false) {
                    content
                        .padding(.top, 36)              // breathing room from progress bar
                        .frame(maxWidth: .infinity)
                        .id(step)
                        .transition(transition)
                }

                footer
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
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
        case .prePaywall:
            PrePaywallEmbedded(
                petName: petName, species: species, profile: profile,
                onContinue: { paywallSheet = .main }
            )
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
                    PrimaryButton(title: "Connect Apple Health", icon: "heart.text.square.fill") {
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
                    SecondaryButton(title: "I'll add sleep manually") { advance() }
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

private struct PrePaywallEmbedded: View {
    let petName: String
    let species: PetSpecies
    let profile: OnboardingProfile
    let onContinue: () -> Void

    var body: some View {
        PrePaywallView(
            petName: petName,
            species: species,
            profile: profile,
            onContinue: onContinue
        )
        .frame(minHeight: 700)
    }
}

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
        case .asLongAsRemember: return "questionmark.circle.fill"
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

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text("We found your top 3 sleep blockers")
                    .font(MooniFont.display(22))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                Text("Mooni Pro fixes each one with a tailored exercise.")
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            .padding(.top, 8)

            VStack(spacing: 10) {
                ForEach(Array(profile.topIssues.enumerated()), id: \.offset) { idx, issue in
                    issueCard(index: idx + 1, text: issue)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 20)
    }

    private func issueCard(index: Int, text: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(MooniColor.warning.opacity(0.20))
                    .frame(width: 40, height: 40)
                Text("\(index)")
                    .font(MooniFont.title(16))
                    .foregroundColor(MooniColor.warning)
            }
            Text(text)
                .font(MooniFont.title(14))
                .foregroundColor(MooniColor.textPrimary)
                .multilineTextAlignment(.leading)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(MooniColor.textMuted)
                .font(.system(size: 13, weight: .semibold))
        }
        .padding(14)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MooniColor.warning.opacity(0.30), lineWidth: 1)
        )
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
        VStack(spacing: 26) {
            Spacer().frame(height: 14)

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
                    Image(systemName: "sparkle")
                        .foregroundColor(.white.opacity(0.85))
                        .font(.system(size: 9))
                        .offset(x: 90)
                        .rotationEffect(.degrees(orbit + Double(i) * 120))
                }
                Image(systemName: "sparkles")
                    .font(.system(size: 42))
                    .foregroundColor(MooniColor.accentSoft)
                    .scaleEffect(sparkleScale)
                VStack(spacing: 2) {
                    Spacer().frame(height: 56)
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(MooniColor.textPrimary)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.4), value: progress)
                }
            }
            .onAppear {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) { orbit = 360 }
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { sparkleScale = 1.15 }
            }

            Text(msgs[min(messageIndex, msgs.count - 1)])
                .font(MooniFont.title(17))
                .foregroundColor(MooniColor.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .id(messageIndex)
                .transition(.opacity.combined(with: .move(edge: .bottom)))

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(msgs.enumerated()), id: \.offset) { idx, m in
                    HStack(spacing: 12) {
                        ZStack {
                            if idx < messageIndex {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(MooniColor.success)
                            } else if idx == messageIndex {
                                Circle()
                                    .stroke(MooniColor.accent, lineWidth: 1.5)
                                    .frame(width: 18, height: 18)
                                Circle()
                                    .fill(MooniColor.accent)
                                    .frame(width: 8, height: 8)
                            } else {
                                Image(systemName: "circle.dashed")
                                    .foregroundColor(MooniColor.textMuted)
                            }
                        }
                        .frame(width: 22)
                        Text(m)
                            .font(MooniFont.body(14))
                            .foregroundColor(idx <= messageIndex ? MooniColor.textPrimary : MooniColor.textSecondary)
                            .strikethrough(idx < messageIndex, color: MooniColor.textMuted)
                        Spacer()
                    }
                }
            }
            .padding(18)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 24)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Screen: Social proof

private struct SocialProofScreen: View {
    @State private var index: Int = 0
    private let timer = Timer.publish(every: 2.6, on: .main, in: .common).autoconnect()

    private struct Review {
        let text: String
        let author: String
        let stat: String
    }
    private let reviews: [Review] = [
        Review(text: "I haven't woken up tired in 3 weeks. The pet thing actually worked on me.",
               author: "Sarah, 28", stat: "+38% energy"),
        Review(text: "Stopped scrolling in bed because I didn't want my fox to be sad. Wild.",
               author: "Marco, 34", stat: "1.2 hrs more sleep"),
        Review(text: "First app that actually fixed my schedule. Tiny daily wins compound.",
               author: "Priya, 41", stat: "14-day streak"),
        Review(text: "I sleep when my pet sleeps. It rewired me in a week.",
               author: "Jake, 22", stat: "Score: 86 / 100")
    ]

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    ForEach(0..<5) { _ in
                        Image(systemName: "star.fill").foregroundColor(MooniColor.warning)
                    }
                }
                Text("Loved by 2.4 million sleepers")
                    .font(MooniFont.display(22))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text("4.9 average rating. Real people, real change.")
                    .font(MooniFont.body(13))
                    .foregroundColor(MooniColor.textSecondary)
            }
            .padding(.top, 8)

            ZStack {
                ForEach(reviews.indices, id: \.self) { i in
                    if i == index {
                        reviewCard(reviews[i])
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                removal: .opacity.combined(with: .scale(scale: 1.05))))
                    }
                }
            }
            .frame(minHeight: 200)
            .animation(.easeInOut(duration: 0.45), value: index)
            .padding(.horizontal, 24)

            HStack(spacing: 6) {
                ForEach(reviews.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == index ? MooniColor.accent : Color.white.opacity(0.20))
                        .frame(width: i == index ? 22 : 8, height: 4)
                        .animation(.spring(response: 0.4), value: index)
                }
            }
        }
        .onReceive(timer) { _ in
            withAnimation { index = (index + 1) % reviews.count }
        }
    }

    private func reviewCard(_ review: Review) -> some View {
        VStack(spacing: 14) {
            Text("\u{201C}\(review.text)\u{201D}")
                .font(MooniFont.body(15))
                .foregroundColor(MooniColor.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            HStack(spacing: 10) {
                Text(review.author)
                    .font(MooniFont.caption(13))
                    .foregroundColor(MooniColor.textSecondary)
                Text("·").foregroundColor(MooniColor.textMuted)
                Text(review.stat)
                    .font(MooniFont.caption(13))
                    .foregroundColor(MooniColor.success)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
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
                questRow(icon: "leaf.fill", title: "Start wind-down by \(windDownTime)")
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

    var body: some View {
        VStack(spacing: 18) {
            Text(eyebrow)
                .font(MooniFont.caption(12))
                .foregroundColor(MooniColor.accentSoft)
                .tracking(2)
                .textCase(.uppercase)

            Text(title)
                .font(MooniFont.display(24))
                .foregroundColor(MooniColor.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            content()
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 4)

            if let s = source {
                Text(s)
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

// MARK: - Fact: Body needs

private struct BodyFactScreen: View {
    let profile: OnboardingProfile
    @State private var animatedNeed: Double = 0

    private var idealHours: Double {
        switch profile.age ?? 28 {
        case ..<18: return 9.0
        case 18..<25: return 8.0
        case 25..<45: return 7.5
        case 45..<65: return 7.0
        default: return 7.0
        }
    }

    var body: some View {
        FactScaffold(
            eyebrow: "Did you know",
            title: "Your body needs ~\(String(format: "%.1f", idealHours)) hours",
            source: "Based on age, weight & National Sleep Foundation guidelines."
        ) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 14)
                        .frame(width: 200, height: 200)
                    Circle()
                        .trim(from: 0, to: animatedNeed / 12)
                        .stroke(LinearGradient(colors: [MooniColor.accentSoft, MooniColor.accent],
                                               startPoint: .top, endPoint: .bottom),
                                style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 200, height: 200)
                    VStack(spacing: 0) {
                        Text(String(format: "%.1f", animatedNeed))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(MooniColor.textPrimary)
                            .contentTransition(.numericText())
                        Text("hours / night")
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.textMuted)
                    }
                }
                .padding(.top, 4)

                HStack(spacing: 10) {
                    factChip(icon: "figure.run", text: "Recovery")
                    factChip(icon: "brain.head.profile", text: "Memory")
                    factChip(icon: "heart.fill", text: "Heart")
                }
                .padding(.top, 4)
            }
            .padding(.top, 4)
            .onAppear {
                withAnimation(.easeOut(duration: 1.6)) { animatedNeed = idealHours }
            }
        }
    }

    private func factChip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundColor(MooniColor.success)
            Text(text).font(MooniFont.caption(12)).foregroundColor(MooniColor.textPrimary)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color.white.opacity(0.07))
        .clipShape(Capsule())
    }
}

// MARK: - Fact: Sleep debt

private struct SleepDebtFactScreen: View {
    let profile: OnboardingProfile
    @State private var phase: CGFloat = 0

    /// Sample debt accumulation across 7 days based on user's typical hours.
    private var dataPoints: [Double] {
        let deficit = max(0.0, 8.0 - profile.typicalSleepHours)
        return (0..<7).map { day in deficit * Double(day + 1) }
    }

    var body: some View {
        FactScaffold(
            eyebrow: "Sleep debt",
            title: "It compounds — even when you don't feel it",
            source: "1 hour of debt per night → 7 hours by Sunday."
        ) {
            VStack(spacing: 14) {
                AnimatedLineChart(
                    data: dataPoints,
                    phase: phase,
                    accent: MooniColor.danger,
                    fillTop: MooniColor.danger.opacity(0.45),
                    fillBottom: MooniColor.danger.opacity(0.0)
                )
                .frame(height: 180)

                HStack {
                    ForEach(["Mon","Tue","Wed","Thu","Fri","Sat","Sun"], id: \.self) { d in
                        Text(d)
                            .font(MooniFont.caption(10))
                            .foregroundColor(MooniColor.textMuted)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 4)

                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(MooniColor.warning)
                    Text("By Sunday you'll be \(String(format: "%.1f", dataPoints.last ?? 0)) hrs short.")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.warning)
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(MooniColor.warning.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(20)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .onAppear {
                withAnimation(.easeOut(duration: 1.8)) { phase = 1 }
            }
        }
    }
}

// MARK: - Fact: Phone before bed

private struct PhoneFactScreen: View {
    let profile: OnboardingProfile
    @State private var phase: CGFloat = 0

    /// Melatonin curve — normal vs phone-suppressed.
    private var normalCurve: [Double] { [0.05, 0.08, 0.18, 0.42, 0.78, 0.95, 1.00, 0.92, 0.78] }
    private var phoneCurve:  [Double] { [0.05, 0.06, 0.08, 0.12, 0.20, 0.42, 0.65, 0.82, 0.78] }

    var body: some View {
        FactScaffold(
            eyebrow: "Blue light & melatonin",
            title: "Phones delay sleep onset by ~58 min",
            source: "Harvard Health · Chang et al., 2014. Brigham & Women's study."
        ) {
            VStack(spacing: 14) {
                ZStack(alignment: .topLeading) {
                    AnimatedLineChart(data: normalCurve, phase: phase,
                                      accent: MooniColor.success,
                                      fillTop: MooniColor.success.opacity(0.0),
                                      fillBottom: MooniColor.success.opacity(0.0))
                    AnimatedLineChart(data: phoneCurve, phase: phase,
                                      accent: MooniColor.danger,
                                      fillTop: MooniColor.danger.opacity(0.0),
                                      fillBottom: MooniColor.danger.opacity(0.0))
                }
                .frame(height: 160)

                HStack(spacing: 16) {
                    legendDot(color: MooniColor.success, label: "No phone")
                    legendDot(color: MooniColor.danger,  label: "Your habit")
                }

                HStack(spacing: 10) {
                    Image(systemName: "iphone.slash").foregroundColor(MooniColor.warning)
                    Text("Your \(profile.phoneScreenMinutes) min flattens your melatonin peak.")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.warning)
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(MooniColor.warning.opacity(0.10))
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

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(MooniFont.caption(11)).foregroundColor(MooniColor.textSecondary)
        }
    }
}

// MARK: - Fact: Caffeine

private struct CaffeineFactScreen: View {
    @State private var phase: CGFloat = 0
    @State private var markerOffset: CGFloat = 0

    /// Caffeine concentration over 12 hours — exponential decay.
    private var data: [Double] {
        (0..<13).map { i in pow(0.5, Double(i) / 5.0) }
    }

    var body: some View {
        FactScaffold(
            eyebrow: "Caffeine half-life",
            title: "12 hours later, half is still in your system",
            source: "Caffeine half-life: 5–7 hrs · Roehrs & Roth, Sleep Med Reviews."
        ) {
            VStack(spacing: 14) {
                AnimatedLineChart(
                    data: data, phase: phase,
                    accent: MooniColor.warning,
                    fillTop: MooniColor.warning.opacity(0.55),
                    fillBottom: MooniColor.warning.opacity(0.0)
                )
                .frame(height: 180)

                HStack {
                    Text("Coffee at 2pm").font(MooniFont.caption(10)).foregroundColor(MooniColor.textMuted)
                    Spacer()
                    Text("Bedtime").font(MooniFont.caption(10)).foregroundColor(MooniColor.warning)
                }
                .padding(.horizontal, 4)

                HStack(spacing: 10) {
                    Image(systemName: "cup.and.saucer.fill").foregroundColor(MooniColor.warning)
                    Text("That afternoon coffee = a quarter-cup at bedtime.")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.warning)
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(MooniColor.warning.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(20)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .onAppear {
                withAnimation(.easeOut(duration: 1.8)) { phase = 1 }
            }
        }
    }
}

// MARK: - Fact: Stress

private struct StressFactScreen: View {
    @State private var bar1: CGFloat = 0
    @State private var bar2: CGFloat = 0

    var body: some View {
        FactScaffold(
            eyebrow: "Cortisol & deep sleep",
            title: "Stress can cut deep sleep by 40%",
            source: "American Psychological Association, sleep & cortisol meta-analysis."
        ) {
            VStack(spacing: 16) {
                HStack(alignment: .bottom, spacing: 30) {
                    barColumn(label: "Calm night", value: bar1, color: MooniColor.success, hours: "1.8 hrs deep")
                    barColumn(label: "Stressed", value: bar2, color: MooniColor.danger, hours: "1.1 hrs deep")
                }
                .frame(height: 200)
                .padding(.top, 8)

                HStack(spacing: 10) {
                    Image(systemName: "wind").foregroundColor(MooniColor.accent)
                    Text("Mooni's wind-down lowers cortisol so deep sleep returns.")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.accentSoft)
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(MooniColor.accent.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(20)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .onAppear {
                withAnimation(.easeOut(duration: 1.4)) { bar1 = 1.0 }
                withAnimation(.easeOut(duration: 1.4).delay(0.25)) { bar2 = 0.6 }
            }
        }
    }

    private func barColumn(label: String, value: CGFloat, color: Color, hours: String) -> some View {
        VStack(spacing: 8) {
            Spacer()
            Text(hours)
                .font(MooniFont.caption(11))
                .foregroundColor(color)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(
                    colors: [color.opacity(0.85), color.opacity(0.45)],
                    startPoint: .top, endPoint: .bottom))
                .frame(width: 64, height: max(8, 140 * value))
                .animation(.easeOut(duration: 1.0), value: value)
            Text(label)
                .font(MooniFont.caption(12))
                .foregroundColor(MooniColor.textPrimary)
        }
    }
}

// MARK: - Fact: Day cycle

private struct DayCycleFactScreen: View {
    @State private var rotation: Double = 0
    @State private var pulse = false

    var body: some View {
        FactScaffold(
            eyebrow: "Your circadian rhythm",
            title: "Your body runs on a 24-hour clock",
            source: "Anchoring wake time stabilizes the entire rhythm."
        ) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(LinearGradient(
                            colors: [MooniColor.accent, MooniColor.warning, MooniColor.accentSoft, MooniColor.accent],
                            startPoint: .leading, endPoint: .trailing),
                                lineWidth: 6)
                        .frame(width: 220, height: 220)

                    // Sleep arc
                    Circle()
                        .trim(from: 0.04, to: 0.32)
                        .stroke(MooniColor.accent.opacity(0.4),
                                style: StrokeStyle(lineWidth: 22, lineCap: .round))
                        .frame(width: 220, height: 220)
                        .rotationEffect(.degrees(-90))

                    // Hour ticks
                    ForEach(0..<24, id: \.self) { h in
                        Capsule()
                            .fill(Color.white.opacity(h % 6 == 0 ? 0.95 : 0.30))
                            .frame(width: 2, height: h % 6 == 0 ? 12 : 5)
                            .offset(y: -110)
                            .rotationEffect(.degrees(Double(h) * 15))
                    }

                    // Sun marker rotating
                    Image(systemName: "sun.max.fill")
                        .foregroundStyle(LinearGradient(colors: [.yellow, MooniColor.warning],
                                                        startPoint: .top, endPoint: .bottom))
                        .font(.system(size: 22))
                        .offset(y: -110)
                        .rotationEffect(.degrees(rotation))
                        .scaleEffect(pulse ? 1.1 : 1.0)

                    // Center label
                    VStack(spacing: 2) {
                        Text("CYCLE")
                            .font(MooniFont.caption(10))
                            .foregroundColor(MooniColor.textMuted)
                            .tracking(2)
                        Text("24 hr")
                            .font(MooniFont.title(20))
                            .foregroundColor(MooniColor.textPrimary)
                    }
                }
                .padding(.top, 4)
                .onAppear {
                    withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) { rotation = 360 }
                    withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { pulse = true }
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

// MARK: - Fact: Environment

private struct EnvironmentFactScreen: View {
    let profile: OnboardingProfile
    @State private var darkVal: CGFloat = 0
    @State private var quietVal: CGFloat = 0
    @State private var comfyVal: CGFloat = 0

    var body: some View {
        FactScaffold(
            eyebrow: "Environment matters",
            title: "Three things gate deep sleep",
            source: "Sleep Foundation · environmental sleep hygiene."
        ) {
            VStack(spacing: 12) {
                envBar(label: "Darkness", icon: "moon.fill",
                       impact: profile.roomDarkness == .dark ? 1.0 :
                               profile.roomDarkness == .someLight ? 0.6 : 0.25,
                       color: MooniColor.accent, value: darkVal)
                envBar(label: "Quiet", icon: "ear.badge.checkmark",
                       impact: profile.roomNoise == .quiet ? 1.0 :
                               profile.roomNoise == .someNoise ? 0.6 : 0.25,
                       color: MooniColor.success, value: quietVal)
                envBar(label: "Comfort", icon: "bed.double.fill",
                       impact: profile.bedComfort == .comfortable ? 1.0 :
                               profile.bedComfort == .okay ? 0.6 : 0.25,
                       color: MooniColor.warning, value: comfyVal)

                Text("We'll work around what we can't control.")
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textSecondary)
                    .padding(.top, 6)
            }
            .padding(20)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .onAppear {
                withAnimation(.easeOut(duration: 1.4)) {
                    darkVal = profile.roomDarkness == .dark ? 1.0 :
                              profile.roomDarkness == .someLight ? 0.6 : 0.25
                }
                withAnimation(.easeOut(duration: 1.4).delay(0.15)) {
                    quietVal = profile.roomNoise == .quiet ? 1.0 :
                               profile.roomNoise == .someNoise ? 0.6 : 0.25
                }
                withAnimation(.easeOut(duration: 1.4).delay(0.3)) {
                    comfyVal = profile.bedComfort == .comfortable ? 1.0 :
                               profile.bedComfort == .okay ? 0.6 : 0.25
                }
            }
        }
    }

    private func envBar(label: String, icon: String, impact: CGFloat, color: Color, value: CGFloat) -> some View {
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
                        .foregroundColor(MooniColor.textMuted)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.10))
                        Capsule()
                            .fill(LinearGradient(colors: [color.opacity(0.85), color],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * value)
                    }
                }
                .frame(height: 6)
            }
        }
    }
}

// MARK: - Animated line chart used by fact screens

private struct AnimatedLineChart: View {
    let data: [Double]
    let phase: CGFloat              // 0…1 reveal animation
    let accent: Color
    let fillTop: Color
    let fillBottom: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let maxVal = max(data.max() ?? 1, 0.001)
            let stepX = data.count > 1 ? w / CGFloat(data.count - 1) : w

            ZStack {
                // Grid lines
                ForEach(0..<4) { i in
                    let y = h * CGFloat(i) / 3
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: w, y: y))
                    }
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                }

                // Filled area
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h))
                    for (i, v) in data.enumerated() {
                        let x = CGFloat(i) * stepX
                        let y = h - (CGFloat(v / maxVal) * h * 0.92) - h * 0.04
                        if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                        else      { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    p.addLine(to: CGPoint(x: w, y: h))
                    p.addLine(to: CGPoint(x: 0, y: h))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [fillTop, fillBottom],
                                     startPoint: .top, endPoint: .bottom))
                .mask(
                    Rectangle().frame(width: w * phase, height: h, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                )

                // Line
                Path { p in
                    for (i, v) in data.enumerated() {
                        let x = CGFloat(i) * stepX
                        let y = h - (CGFloat(v / maxVal) * h * 0.92) - h * 0.04
                        if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                        else      { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .trim(from: 0, to: phase)
                .stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .shadow(color: accent.opacity(0.5), radius: 6, y: 1)

                // End dot
                if let last = data.last {
                    let x = CGFloat(data.count - 1) * stepX
                    let y = h - (CGFloat(last / maxVal) * h * 0.92) - h * 0.04
                    Circle()
                        .fill(accent)
                        .frame(width: 8, height: 8)
                        .position(x: x, y: y)
                        .opacity(Double(phase))
                }
            }
        }
    }
}

#Preview {
    OnboardingView().environmentObject(AppState())
}
