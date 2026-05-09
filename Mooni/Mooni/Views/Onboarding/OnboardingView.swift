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
        // Emotional priming sequence — designed to make the user
        // self-identify with the problem and feel hope before any
        // questions or commitments.
        case hero                     // S1 emotional hook
        case sleepImpactStat          // S2 relatable pain
        case identityDamage           // S3 connects sleep → daily identity
        case emotionalDiscomfort      // S4 "your body remembers every late night"
        case hopeTransformation       // S5 brighter hope visual
        case petAttachment            // S6 healthy vs exhausted pet
        case namePet
        case bondMessage              // emotional copy after naming
        case demo
        case ageQuestion
        case genderQuestion
        case heightQuestion
        case weightQuestion
        case typicalSleepHours        // collected BEFORE bodyFact / sleepDebtFact reference it
        case bodyFact                 // animated chart: how body shapes sleep needs
        case sleepGoal
        case motivationQuestion
        case pseudoAnalysis           // S8 "users like you tend to…"
        case struggleDuration
        case biggestProblem
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
        case anticipation             // S9 "let's discover how your sleep affects your days"
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
        case .identityDamage:      IdentityDamageScreen()
        case .emotionalDiscomfort: EmotionalDiscomfortScreen()
        case .hopeTransformation:  HopeTransformationScreen()
        case .petAttachment:       PetAttachmentScreen(species: species)
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
        case .pseudoAnalysis:      PseudoAnalysisScreen(profile: profile, petName: petName)
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
        case .anticipation:        AnticipationScreen(petName: petName)
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
        case .hero:               return "Show me what's happening"
        case .sleepImpactStat:    return "Yeah, that's me"
        case .identityDamage:     return "I want to fix this"
        case .emotionalDiscomfort:return "Continue"
        case .hopeTransformation: return "I'm in"
        case .petAttachment:      return "Meet your sleep pet"
        case .pseudoAnalysis:     return "Continue"
        case .anticipation:       return "Let's go"
        case .namePet:            return "\(petName.isEmpty ? species.defaultName : petName) is officially yours"
        case .bondMessage:        return "Continue"
        case .demo:               return demoStage < 2 ? "Continue" : "I get it"
        case .ageQuestion:        return profile.age == nil ? "Pick an age" : "Continue"
        case .genderQuestion:     return "Continue"
        case .heightQuestion:     return profile.heightCm == nil ? "Set your height" : "Continue"
        case .weightQuestion:     return profile.weightKg == nil ? "Set your weight" : "Continue"
        case .bodyFact:           return "Got it"
        case .sleepGoal:          return sleepGoal == nil ? "Pick one to continue" : "Continue"
        case .motivationQuestion: return profile.motivation == nil ? "Pick one to continue" : "Continue"
        case .struggleDuration:   return profile.struggleDuration == nil ? "Pick one to continue" : "Continue"
        case .biggestProblem:     return profile.biggestProblem == nil ? "Pick one to continue" : "Continue"
        case .typicalSleepHours:  return "Continue"
        case .sleepDebtFact:      return "I want to fix this"
        case .phoneBeforeBed:     return "Continue"
        case .phoneScreenTime:    return "Continue"
        case .phoneFact:          return "I get it"
        case .caffeineCutoff:     return profile.caffeineCutoff == nil ? "Pick one to continue" : "Continue"
        case .caffeineFact:       return "Wow, continue"
        case .stressLevel:        return "Continue"
        case .racingThoughts:     return "Continue"
        case .stressFact:         return "Continue"
        case .wakeFeeling:        return profile.wakeFeeling == nil ? "Pick one to continue" : "Continue"
        case .energyDip:          return profile.energyDip == nil ? "Pick one to continue" : "Continue"
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
        case .namePet:            return !petName.trimmingCharacters(in: .whitespaces).isEmpty
        case .ageQuestion:        return profile.age != nil
        case .heightQuestion:     return profile.heightCm != nil
        case .weightQuestion:     return profile.weightKg != nil
        case .sleepGoal:          return sleepGoal != nil
        case .motivationQuestion: return profile.motivation != nil
        case .struggleDuration:   return profile.struggleDuration != nil
        case .biggestProblem:     return profile.biggestProblem != nil
        case .phoneBeforeBed:     return profile.usesPhoneBeforeBed != nil
        case .caffeineCutoff:     return profile.caffeineCutoff != nil
        case .racingThoughts:     return profile.racingThoughtsAtNight != nil
        case .wakeFeeling:        return profile.wakeFeeling != nil
        case .energyDip:          return profile.energyDip != nil
        case .napsDay:            return profile.napsDuringDay != nil
        default:                  return true
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
        (0.08, 0.4),   // reading answers
        (0.20, 0.6),   // mapping chronotype
        (0.35, 0.4),
        (0.48, 0.7),   // calculating debt
        (0.62, 0.4),
        (0.74, 0.6),   // identifying issues
        (0.84, 0.3),
        (0.93, 0.5),
        (1.00, 0.3)
    ]

    private static let generatingScript: [(Double, Double)] = [
        (0.07, 0.4),
        (0.18, 0.6),   // building bedtime quest
        (0.30, 0.4),
        (0.44, 0.7),   // tuning wake-up window
        (0.57, 0.4),
        (0.68, 0.6),   // composing wind-down breath
        (0.79, 0.4),
        (0.90, 0.5),
        (1.00, 0.3)
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
    @Binding var selection: T?
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
    @State private var dim = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 6)

            ZStack {
                // Heavy, low-contrast halo — a tired aura, not a glow.
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.black.opacity(0.55), .clear],
                            center: .center,
                            startRadius: 4,
                            endRadius: 220
                        )
                    )
                    .frame(width: 340, height: 340)

                DreamSpiritView(pet: tiredPet, size: 170)
                    .saturation(0.55)
                    .opacity(dim ? 0.78 : 0.92)
                    .animation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true), value: dim)
            }
            .onAppear { dim = true }

            VStack(spacing: 14) {
                Text("You're probably\nmore sleep deprived\nthan you think.")
                    .font(MooniFont.display(30))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text("Poor sleep quietly affects energy, focus, mood, recovery, and motivation — even when you can't feel it directly.")
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .padding(.top, 6)
    }

    private var tiredPet: Pet {
        var p = Pet(); p.species = species; p.mood = .sleepy; p.equippedColor = "default_color"
        return p
    }
}

// MARK: - Screen 1: Relatable pain — "Ever wake up already exhausted?"

private struct SleepImpactStatScreen: View {
    @State private var revealedCount: Int = 0

    private let pains: [(icon: String, label: String)] = [
        ("brain.head.profile",   "Brain fog"),
        ("battery.25",           "No energy"),
        ("face.dashed",          "Bad mood"),
        ("eye.slash",            "Poor focus"),
        ("figure.walk",          "Low motivation"),
        ("calendar.badge.exclamationmark", "Ruined schedule")
    ]

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 10) {
                Text("Ever wake up\nalready exhausted?")
                    .font(MooniFont.display(28))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                Text("Most people quietly carry one or more of these every day.")
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 8)

            VStack(spacing: 10) {
                ForEach(Array(pains.enumerated()), id: \.offset) { idx, item in
                    PainCard(icon: item.icon, label: item.label)
                        .opacity(idx < revealedCount ? 1 : 0)
                        .offset(y: idx < revealedCount ? 0 : 14)
                        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: revealedCount)
                }
            }
            .padding(.horizontal, 22)

            Spacer(minLength: 8)
        }
        .onAppear {
            for i in 0..<pains.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18 * Double(i)) {
                    revealedCount = i + 1
                }
            }
        }
    }

    private struct PainCard: View {
        let icon: String
        let label: String

        var body: some View {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(MooniColor.warning)
                    .frame(width: 38, height: 38)
                    .background(MooniColor.warning.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(label)
                    .font(MooniFont.title(15))
                    .foregroundColor(MooniColor.textPrimary)
                Spacer()
            }
            .padding(14)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

// MARK: - Screen 2: Pick pet

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

                Slider(value: $profile.typicalSleepHours, in: 3...9, step: 0.5)
                    .tint(MooniColor.accent)
                    .padding(.horizontal, 4)

                HStack {
                    Text("3 hrs").font(MooniFont.caption(11)).foregroundColor(MooniColor.textMuted)
                    Spacer()
                    Text("9 hrs").font(MooniFont.caption(11)).foregroundColor(MooniColor.textMuted)
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
        case 7..<8: return "You're close — but not yet fully recovered."
        case 8..<8.5: return "Solid baseline. We'll help make it more restorative."
        default: return "You sleep a lot — we'll check if it's actually restorative."
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
    /// Has to stay in sync with that script's length (9 steps → 6 messages).
    static let stepBoundaries: [Int] = [0, 1, 3, 5, 7, 8]

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
                Text("Don't worry, \(petName). SleepOwl Pro members average \(profile.derivedSleepScore + 24) within 14 days.")
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
    /// Has to stay in sync with that script's length (9 steps → 6 messages).
    static let stepBoundaries: [Int] = [0, 1, 3, 5, 7, 8]

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
        var p = Pet(); p.species = .owl; p.mood = .cozy; p.equippedHat = "hat_nightcap"
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

    private let features: [(icon: String, label: String, detail: String)] = [
        ("moon.zzz.fill",       "Nightly quests",    "Small, doable bedtime rituals"),
        ("chart.line.uptrend.xyaxis", "Sleep score", "Track your progress night by night"),
        ("wind",                "Personalized plan",  "Built from your answers, not generic tips")
    ]

    var body: some View {
        VStack(spacing: 18) {
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

            // What you get
            VStack(spacing: 8) {
                ForEach(features.indices, id: \.self) { i in
                    HStack(spacing: 12) {
                        Image(systemName: features[i].icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(MooniColor.accent)
                            .frame(width: 36, height: 36)
                            .background(MooniColor.accent.opacity(0.13))
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(features[i].label)
                                .font(MooniFont.title(14))
                                .foregroundColor(MooniColor.textPrimary)
                            Text(features[i].detail)
                                .font(MooniFont.caption(12))
                                .foregroundColor(MooniColor.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(MooniColor.success)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(.horizontal, 16)

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

    private let snapshots: [(label: String, time: String, percent: Double, note: String?)] = [
        ("2pm", "You drink it", 1.00, nil),
        ("8pm", "Half remains", 0.50, nil),
        ("11pm", "Bedtime", 0.25, "Still a quarter left"),
        ("3am", "Deep sleep?", 0.13, "Active in your system")
    ]

    var body: some View {
        FactScaffold(
            eyebrow: "Caffeine half-life",
            title: "That 2pm coffee is still awake at midnight",
            source: "Drake et al. J Clin Sleep Med 2013 · caffeine 6h before bed reduced sleep by 41 min."
        ) {
            VStack(spacing: 16) {
                // Timeline of caffeine levels
                VStack(spacing: 0) {
                    ForEach(Array(snapshots.enumerated()), id: \.offset) { idx, snap in
                        HStack(spacing: 14) {
                            // Time + label
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(snap.time)
                                    .font(MooniFont.caption(11))
                                    .foregroundColor(MooniColor.textMuted)
                                Text(snap.label)
                                    .font(MooniFont.caption(10))
                                    .foregroundColor(MooniColor.textSecondary)
                            }
                            .frame(width: 68, alignment: .trailing)

                            // Bar fill
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(height: 26)
                                Capsule()
                                    .fill(LinearGradient(
                                        colors: snap.percent > 0.4
                                            ? [MooniColor.danger, MooniColor.warning]
                                            : [MooniColor.warning, MooniColor.warning.opacity(0.6)],
                                        startPoint: .leading, endPoint: .trailing))
                                    .frame(width: barWidth(snap.percent), height: 26)
                                    .animation(.spring(response: 0.7, dampingFraction: 0.8).delay(Double(idx) * 0.12), value: phase)
                                Text("\(Int(snap.percent * 100))%")
                                    .font(MooniFont.caption(11))
                                    .foregroundColor(.white.opacity(0.9))
                                    .padding(.leading, 10)
                                    .opacity(Double(phase))
                            }

                            if let note = snap.note {
                                Text(note)
                                    .font(MooniFont.caption(10))
                                    .foregroundColor(MooniColor.warning.opacity(0.85))
                                    .fixedSize()
                                    .opacity(Double(phase))
                            } else {
                                Spacer()
                            }
                        }
                        .padding(.vertical, 6)

                        if idx < snapshots.count - 1 {
                            HStack {
                                Spacer().frame(width: 82)
                                Rectangle()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 1, height: 10)
                                    .padding(.leading, 14)
                                Spacer()
                            }
                        }
                    }
                }

                // Takeaway chip
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(MooniColor.warning)
                    Text("Cut off caffeine before 2pm to protect deep sleep.")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textPrimary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MooniColor.warning.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(20)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) { phase = 1 }
            }
        }
    }

    private func barWidth(_ percent: Double) -> CGFloat {
        let maxWidth: CGFloat = 160
        return max(30, maxWidth * CGFloat(percent) * CGFloat(phase))
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
                    Text("SleepOwl's wind-down crashes cortisol so deep sleep returns.")
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
    @State private var revealed = false
    @State private var sunPulse = false

    // Timeline of circadian rhythm events across 24h
    private let events: [(time: String, icon: String, label: String, color: Color, isAwake: Bool)] = [
        ("6am",  "sunrise.fill",      "Wake up",        Color.yellow,          true),
        ("10am", "sun.max.fill",      "Peak focus",     Color.yellow,          true),
        ("2pm",  "sun.haze.fill",     "Afternoon dip",  Color(white: 0.6),     true),
        ("6pm",  "sunset.fill",       "Wind down begins", Color.orange,        true),
        ("10pm", "moon.fill",         "Sleep window",   Color(red: 0.55, green: 0.45, blue: 0.95), false),
        ("2am",  "moon.stars.fill",   "Deep sleep",     Color(red: 0.35, green: 0.30, blue: 0.80), false),
        ("6am",  "sunrise.fill",      "Wake — repeat",  Color.yellow,          true),
    ]

    var body: some View {
        FactScaffold(
            eyebrow: "Your circadian rhythm",
            title: "Same wake time every day locks your rhythm",
            source: "Czeisler CA et al. Science 1999 · stable wake-time entrains the SCN."
        ) {
            VStack(spacing: 16) {
                // 24-hour timeline strip
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.offset) { idx, event in
                        HStack(spacing: 14) {
                            Text(event.time)
                                .font(MooniFont.caption(11))
                                .foregroundColor(MooniColor.textMuted)
                                .frame(width: 38, alignment: .trailing)

                            // Node
                            ZStack {
                                Circle()
                                    .fill(event.color.opacity(0.18))
                                    .frame(width: 32, height: 32)
                                Image(systemName: event.icon)
                                    .font(.system(size: 14))
                                    .foregroundColor(event.color)
                            }

                            Text(event.label)
                                .font(MooniFont.body(14))
                                .foregroundColor(event.isAwake ? MooniColor.textPrimary : MooniColor.textSecondary)

                            Spacer()

                            if !event.isAwake {
                                Capsule()
                                    .fill(MooniColor.accent.opacity(0.25))
                                    .frame(width: 48, height: 16)
                                    .overlay(
                                        Text("Sleep")
                                            .font(MooniFont.caption(9))
                                            .foregroundColor(MooniColor.accentSoft)
                                    )
                            }
                        }
                        .opacity(revealed ? 1 : 0)
                        .offset(x: revealed ? 0 : -12)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(idx) * 0.07), value: revealed)

                        if idx < events.count - 1 {
                            HStack {
                                Spacer().frame(width: 52)
                                Rectangle()
                                    .fill(Color.white.opacity(0.10))
                                    .frame(width: 1, height: 12)
                                    .padding(.leading, 15)
                                Spacer()
                            }
                        }
                    }
                }

                // Key takeaway
                HStack(spacing: 8) {
                    Image(systemName: "repeat.circle.fill")
                        .foregroundColor(MooniColor.accent)
                    Text("Irregular wake times shift your internal clock every day — like constant jet lag.")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MooniColor.accent.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .opacity(revealed ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.55), value: revealed)
            }
            .padding(20)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .onAppear {
                withAnimation { revealed = true }
            }
        }
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

// MARK: - Screen S3: Identity damage

private struct IdentityDamageScreen: View {
    @State private var revealed = 0

    private let items: [(String, String, String)] = [
        ("bolt.fill",                "Energy",       "You burn out by mid-afternoon."),
        ("dumbbell.fill",            "Recovery",     "Workouts hit harder, gains take longer."),
        ("brain.head.profile",       "Productivity", "Tasks that take 30 min now eat 90."),
        ("face.smiling.fill",        "Mood",         "Small things irritate you faster."),
        ("sparkles",                 "Appearance",   "Skin and eyes show every short night."),
        ("calendar",                 "Consistency",  "One bad night drags down a whole week.")
    ]

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 10) {
                Text("Bad sleep affects\nmore than just nights.")
                    .font(MooniFont.display(28))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                Text("It quietly bleeds into the parts of life you actually care about.")
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 8)

            VStack(spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(spacing: 14) {
                        Image(systemName: item.0)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(MooniColor.accentSoft)
                            .frame(width: 38, height: 38)
                            .background(MooniColor.accent.opacity(0.18))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.1)
                                .font(MooniFont.title(15))
                                .foregroundColor(MooniColor.textPrimary)
                            Text(item.2)
                                .font(MooniFont.caption(12))
                                .foregroundColor(MooniColor.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(13)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .opacity(idx < revealed ? 1 : 0)
                    .offset(y: idx < revealed ? 0 : 12)
                    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: revealed)
                }
            }
            .padding(.horizontal, 22)
        }
        .onAppear {
            for i in 0..<items.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16 * Double(i)) {
                    revealed = i + 1
                }
            }
        }
    }
}

// MARK: - Screen S4: Emotional discomfort

private struct EmotionalDiscomfortScreen: View {
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 26) {
            Spacer().frame(height: 16)

            ZStack {
                ForEach(0..<3) { ring in
                    Circle()
                        .stroke(MooniColor.danger.opacity(0.18 - Double(ring) * 0.05), lineWidth: 1)
                        .frame(width: 140 + CGFloat(ring) * 60, height: 140 + CGFloat(ring) * 60)
                        .scaleEffect(pulse ? 1.04 : 0.96)
                        .animation(
                            .easeInOut(duration: 3).repeatForever(autoreverses: true).delay(Double(ring) * 0.4),
                            value: pulse
                        )
                }
                Image(systemName: "clock.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundColor(MooniColor.warning)
            }
            .onAppear { pulse = true }

            VStack(spacing: 12) {
                Text("Your body remembers\nevery late night.")
                    .font(MooniFont.display(28))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                Text("Even inconsistent sleep makes mornings harder and recovery slower — long after you've forgotten the late one.")
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 26)
            }

            Spacer()
        }
    }
}

// MARK: - Screen S5: Hope / transformation

private struct HopeTransformationScreen: View {
    @State private var revealed = 0
    @State private var sunRise: CGFloat = 28

    private let wins: [(String, String)] = [
        ("sunrise.fill",     "Better mornings"),
        ("bolt.fill",        "More energy"),
        ("calendar",         "Improved consistency"),
        ("wind",             "Calmer mind"),
        ("checkmark.circle.fill", "Stronger routines")
    ]

    var body: some View {
        VStack(spacing: 22) {
            ZStack {
                // Warm horizon glow that "rises" on appear.
                LinearGradient(
                    colors: [MooniColor.warning.opacity(0.45), .clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

                Image(systemName: "sun.max.fill")
                    .font(.system(size: 70, weight: .semibold))
                    .foregroundStyle(LinearGradient(
                        colors: [MooniColor.warning, MooniColor.accentSoft],
                        startPoint: .top, endPoint: .bottom))
                    .offset(y: sunRise)
                    .shadow(color: MooniColor.warning.opacity(0.5), radius: 20)
                    .animation(.easeOut(duration: 1.4), value: sunRise)
            }
            .padding(.horizontal, 24)
            .onAppear {
                sunRise = -10
            }

            VStack(spacing: 10) {
                Text("Small sleep changes\nchange your whole day.")
                    .font(MooniFont.display(28))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                Text("Most users feel the difference within the first week.")
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 9) {
                ForEach(Array(wins.enumerated()), id: \.offset) { idx, w in
                    HStack(spacing: 12) {
                        Image(systemName: w.0)
                            .foregroundColor(MooniColor.success)
                            .frame(width: 28)
                        Text(w.1)
                            .font(MooniFont.title(15))
                            .foregroundColor(MooniColor.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(MooniColor.success.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .opacity(idx < revealed ? 1 : 0)
                    .offset(y: idx < revealed ? 0 : 10)
                    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: revealed)
                }
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            for i in 0..<wins.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7 + 0.14 * Double(i)) {
                    revealed = i + 1
                }
            }
        }
    }
}

// MARK: - Screen S6: Pet attachment

private struct PetAttachmentScreen: View {
    let species: PetSpecies
    @State private var tiredDroop = false
    @State private var cozyBounce = false
    @State private var glowPulse = false

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 10) {
                Text("SleepOwl reflects\nyour sleep habits.")
                    .font(MooniFont.display(28))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                Text("Skip sleep, and your pet feels it. Take care of your sleep — and SleepOwl — at the same time.")
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 8)

            HStack(spacing: 14) {
                tiredCard
                cozyCard
            }
            .padding(.horizontal, 16)
            .onAppear {
                withAnimation(.easeInOut(duration: 4.2).repeatForever(autoreverses: true)) { tiredDroop = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 1.4, dampingFraction: 0.5).repeatForever(autoreverses: true)) { cozyBounce = true }
                    withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true)) { glowPulse = true }
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .foregroundColor(MooniColor.accent)
                Text("Your sleep shapes their world.")
                    .font(MooniFont.title(14))
                    .foregroundColor(MooniColor.textPrimary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(MooniColor.accent.opacity(0.13))
            .clipShape(Capsule())
        }
    }

    private var tiredCard: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(MooniColor.danger.opacity(0.30), lineWidth: 1)
                    )
                // Dim haze behind tired owl
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.black.opacity(0.35), .clear],
                            center: .center, startRadius: 4, endRadius: 70
                        )
                    )
                    .frame(width: 130, height: 130)
                DreamSpiritView(pet: tiredPet, size: 110)
                    .saturation(0.30)
                    .opacity(0.60)
                    .offset(y: tiredDroop ? 3 : -2)
            }
            .frame(height: 156)
            Text("Tired")
                .font(MooniFont.title(14))
                .foregroundColor(MooniColor.danger)
            Text("After bad sleep")
                .font(MooniFont.caption(11))
                .foregroundColor(MooniColor.textSecondary)
        }
    }

    private var cozyCard: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.09))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(MooniColor.success.opacity(0.55), lineWidth: 1.5)
                    )
                // Warm glow behind glowing owl
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [MooniColor.success.opacity(glowPulse ? 0.28 : 0.14), .clear],
                            center: .center, startRadius: 4, endRadius: 80
                        )
                    )
                    .frame(width: 150, height: 150)
                    .blur(radius: 6)
                DreamSpiritView(pet: cozyPet, size: 110)
                    .offset(y: cozyBounce ? -7 : 0)
            }
            .frame(height: 156)
            Text("Glowing")
                .font(MooniFont.title(14))
                .foregroundColor(MooniColor.success)
            Text("After cozy nights")
                .font(MooniFont.caption(11))
                .foregroundColor(MooniColor.textSecondary)
        }
    }

    private var tiredPet: Pet {
        var p = Pet(); p.species = species; p.mood = .sleepy; p.equippedColor = "default_color"
        return p
    }

    private var cozyPet: Pet {
        var p = Pet(); p.species = species; p.mood = .cozy; p.equippedColor = "default_color"
        return p
    }
}

// MARK: - Screen S8: Pseudo-analysis (right after motivation pick)

private struct PseudoAnalysisScreen: View {
    let profile: OnboardingProfile
    let petName: String
    @State private var typed = ""
    @State private var cardVisible = false
    @State private var badgeVisible = false
    private let fullText: String

    init(profile: OnboardingProfile, petName: String) {
        self.profile = profile
        self.petName = petName
        self.fullText = profile.motivation.map { Self.insight(for: $0) } ?? Self.insight(for: .feelBetter)
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 4)

            // Header
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(MooniColor.accent)
                    Text("Personalized insight")
                        .font(MooniFont.display(24))
                        .foregroundColor(MooniColor.textPrimary)
                }
                Text("Based on your goal — before we ask anything else.")
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 8)

            // Goal badge
            if let m = profile.motivation {
                HStack(spacing: 6) {
                    Image(systemName: m.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(MooniColor.accent)
                    Text("Your goal: \(m.label)")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.accentSoft)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(MooniColor.accent.opacity(0.12))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(MooniColor.accent.opacity(0.25), lineWidth: 1))
                .opacity(badgeVisible ? 1 : 0)
                .scaleEffect(badgeVisible ? 1 : 0.85)
            }

            // Insight card
            VStack(alignment: .leading, spacing: 0) {
                // Accent top bar
                LinearGradient(
                    colors: [MooniColor.accentSoft, MooniColor.accent],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: 3)
                .clipShape(RoundedRectangle(cornerRadius: 2))

                VStack(alignment: .leading, spacing: 16) {
                    Text("\u{201C}")
                        .font(.system(size: 48, weight: .black, design: .serif))
                        .foregroundColor(MooniColor.accent.opacity(0.35))
                        .frame(height: 28)

                    Text(typed)
                        .font(MooniFont.title(17))
                        .foregroundColor(MooniColor.textPrimary)
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(MooniColor.accent.opacity(0.6))
                            .frame(width: 6, height: 6)
                        Text("\(petName) · pattern match")
                            .font(MooniFont.caption(11))
                            .foregroundColor(MooniColor.textMuted)
                    }
                }
                .padding(20)
            }
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(MooniColor.accent.opacity(0.22), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .opacity(cardVisible ? 1 : 0)
            .offset(y: cardVisible ? 0 : 12)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) { badgeVisible = true }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.3)) { cardVisible = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { animateType() }
        }
    }

    private func animateType() {
        typed = ""
        let chars = Array(fullText)
        for (i, c) in chars.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.020 * Double(i)) {
                typed.append(c)
            }
        }
    }

    private static func insight(for m: OnboardingProfile.Motivation) -> String {
        switch m {
        case .feelBetter:
            return "People who just want to feel better usually have one or two small habits silently breaking their nights."
        case .moreEnergy:
            return "Low daytime energy is almost always tied to inconsistent sleep timing — not just total hours."
        case .mentalClarity:
            return "Users struggling with focus tend to sleep at very different times each night, disrupting their rhythm."
        case .fitnessRecovery:
            return "Recovery and strength gains are tightly linked to deep sleep — and deep sleep needs consistency."
        case .mood:
            return "Mood swings often track directly with how short and broken your nights have been the past week."
        case .longerLife:
            return "Long-term health depends more on sleep regularity than on a handful of perfect nights."
        }
    }
}

// MARK: - Screen S9: Anticipation (before notification permission)

private struct AnticipationScreen: View {
    let petName: String
    @State private var glow = false

    var body: some View {
        VStack(spacing: 22) {
            Spacer().frame(height: 16)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [MooniColor.accent.opacity(0.45), .clear],
                            center: .center,
                            startRadius: 6,
                            endRadius: 180
                        )
                    )
                    .frame(width: 280, height: 280)
                    .scaleEffect(glow ? 1.04 : 0.96)
                    .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true), value: glow)

                Image(systemName: "wand.and.stars")
                    .font(.system(size: 62, weight: .semibold))
                    .foregroundStyle(LinearGradient(
                        colors: [MooniColor.accentSoft, MooniColor.accent],
                        startPoint: .top, endPoint: .bottom))
            }
            .onAppear { glow = true }

            VStack(spacing: 12) {
                Text("Let's discover how\nyour sleep affects\nyour daily life.")
                    .font(MooniFont.display(28))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                Text("\(petName) needs two quick permissions to track your nights and nudge you at the right moments.")
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            Spacer()
        }
    }
}

#Preview {
    OnboardingView().environmentObject(AppState())
}
