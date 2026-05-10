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
    @State private var step: Step = .welcome
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
    /// Auth flow state. Set to `.signedIn` after Apple → Supabase succeeds, or
    /// `.skipped` if the user taps "Continue without an account". Drives the
    /// sign-in screen's CTA and gates Supabase reads/writes elsewhere.
    enum AuthState { case unknown, signedIn, skipped, failed }
    @State private var authState: AuthState = .unknown
    @State private var authErrorMessage: String? = nil

    enum Step: Int, CaseIterable {
        // Emotional priming sequence — designed to make the user
        // self-identify with the problem and feel hope before any
        // questions or commitments.
        case welcome                  // S0 Get Started / Log In gate
        case hero                     // S1 emotional hook
        case sleepImpactStat          // S2 relatable pain
        case identityDamage           // S3 connects sleep → daily identity
        case emotionalDiscomfort      // S4 "your body remembers every late night"
        case hopeTransformation       // S5 brighter hope visual
        // Benefit reel — what better sleep gives you. Kept tight (6 screens)
        // so the wins land without bloating completion.
        case benefitEnergy
        case benefitFocus
        case benefitBody
        case benefitMood
        case benefitLooks
        case benefitLongevity
        case petAttachment            // S6 healthy vs exhausted pet
        case namePet
        case bondMessage              // emotional copy after naming
        case demo
        case ageQuestion
        case genderQuestion
        case heightQuestion
        case weightQuestion
        case typicalSleepHours        // collected BEFORE bodyFact / sleepDebtFact reference it
        case autoTrackIntro           // "no manual logging" hook
        case autoTrackRem             // REM + deep sleep accuracy claim
        case autoTrackAccuracy        // vs-lab accuracy comparison
        case bodyFact                 // animated chart: how body shapes sleep needs
        case sleepGoal
        case goalStudy1               // 5 personalized research screens
        case goalStudy2               // tailored to the sleepGoal the user
        case goalStudy3               // just selected — real-feeling
        case goalStudy4               // citations, data, before/after.
        case goalStudy5
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
        case scienceCredibility       // research + expert-panel credibility
        case scienceTrust             // formula + phone fallback before plan generation
        case generatingPlan           // loading 2 (long, variable)
        case socialProof
        case rateApp                  // ask for App Store rating after social proof
        case simulatedResult
        case firstQuest
        case signIn                   // Sign in with Apple → Supabase, before paywall
        case featureTour              // Quick "what unlocks tonight" tour
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
                            // Trailing padding so the last line of any
                            // screen never tucks under the Continue
                            // footer — even on small phones.
                            .padding(.bottom, 36)
                            .frame(maxWidth: .infinity)
                            .id(step)
                            .transition(transition)
                    }
                    .scrollDismissesKeyboard(.interactively)

                    footer
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 28)
                        .background(
                            // Soft fade behind the footer so content
                            // scrolling under it stays readable instead
                            // of clipping mid-letter against the button.
                            LinearGradient(
                                colors: [
                                    MooniColor.background.opacity(0),
                                    MooniColor.background.opacity(0.92),
                                    MooniColor.background
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .allowsHitTesting(false)
                        )
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

    @ViewBuilder
    private var topBar: some View {
        if hidesProgressChrome {
            EmptyView()
        } else {
            topBarContent
        }
    }

    private var topBarContent: some View {
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

            // Title slot — keeps the eye anchored at the top while the
            // progress lives in the right-aligned circle. We deliberately
            // don't surface the screen count: it primes "ugh, X to go."
            Spacer(minLength: 0)

            CircularProgressIndicator(progress: progressFraction)
                .frame(width: 32, height: 32)
        }
    }

    /// Linear progress 0–1 across the *known* sequence. Capped just below 1
    /// during normal flow so the circle keeps gaining as the user advances
    /// instead of slamming to 100% one screen early.
    private var progressFraction: Double {
        let total = max(1, Step.total - 1)
        return min(0.985, Double(step.index) / Double(total))
    }

    private var isLoadingScreen: Bool {
        step == .analyzingAnswers || step == .generatingPlan
    }

    /// Welcome and sign-in are presented as fullscreen-ish moments without the
    /// onboarding chrome (no progress bar, no back button) so the user feels
    /// like they're at a real entry/exit gate rather than mid-quiz.
    private var hidesProgressChrome: Bool {
        step == .welcome
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:             WelcomeScreen()
        case .hero:                HeroScreen(species: species)
        case .sleepImpactStat:     SleepImpactStatScreen()
        case .identityDamage:      IdentityDamageScreen()
        case .emotionalDiscomfort: EmotionalDiscomfortScreen()
        case .hopeTransformation:  HopeTransformationScreen()
        case .benefitEnergy:       BenefitScreen(spec: .energy)
        case .benefitFocus:        BenefitScreen(spec: .focus)
        case .benefitBody:         BenefitScreen(spec: .body)
        case .benefitMood:         BenefitScreen(spec: .mood)
        case .benefitLooks:        BenefitScreen(spec: .looks)
        case .benefitLongevity:    BenefitScreen(spec: .longevity)
        case .rateApp:             RateAppScreen()
        case .signIn:              SignInScreen(state: authState, errorMessage: authErrorMessage)
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
        case .goalStudy1:          GoalStudyScreen(goal: sleepGoal, index: 0)
        case .goalStudy2:          GoalStudyScreen(goal: sleepGoal, index: 1)
        case .goalStudy3:          GoalStudyScreen(goal: sleepGoal, index: 2)
        case .goalStudy4:          GoalStudyScreen(goal: sleepGoal, index: 3)
        case .goalStudy5:          GoalStudyScreen(goal: sleepGoal, index: 4)
        case .motivationQuestion:  MotivationScreen(profile: $profile)
        case .pseudoAnalysis:      PseudoAnalysisScreen(profile: profile, petName: petName)
        case .struggleDuration:    StruggleDurationScreen(profile: $profile)
        case .biggestProblem:      BiggestProblemScreen(profile: $profile)
        case .typicalSleepHours:   TypicalSleepHoursScreen(profile: $profile)
        case .autoTrackIntro:      AutoTrackIntroScreen()
        case .autoTrackRem:        AutoTrackRemScreen()
        case .autoTrackAccuracy:   AutoTrackAccuracyScreen()
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
        case .scienceCredibility:   ScienceCredibilityScreen()
        case .scienceTrust:         ScienceFormulaScreen(profile: profile)
        case .generatingPlan:
            GeneratingPlanScreen(progress: $planProgress, messageIndex: $planMessageIndex, petName: petName)
                .onAppear { runGeneratingAnimation() }
        case .socialProof:         SocialProofScreen()
        case .simulatedResult:     SimulatedResultScreen(species: species, name: petName)
        case .firstQuest:          FirstQuestScreen(petName: petName, bedtime: bedtime, wakeTime: wakeTime)
        case .featureTour:         FeatureTourScreen(petName: petName)
        case .prePaywall:          EmptyView()    // rendered full-screen above; never reaches here
        }
    }

    // MARK: - Footer

    private var footer: some View {
        Group {
            switch step {
            case .welcome:
                VStack(spacing: 10) {
                    PrimaryButton(title: "Get Started", icon: "sparkles") {
                        advance()
                    }
                    Button {
                        // Jump straight into sign-in for returning users — they
                        // skip the onboarding wizard entirely on success.
                        Task {
                            let ok = await performAppleSignIn()
                            if ok {
                                authState = .signedIn
                                finishOnboarding()
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "person.crop.circle.fill")
                            Text("I already have an account")
                                .font(MooniFont.body(14))
                        }
                        .foregroundColor(MooniColor.textSecondary)
                        .padding(.vertical, 6)
                    }
                    if let err = authErrorMessage {
                        Text(err)
                            .font(MooniFont.caption(11))
                            .foregroundColor(MooniColor.danger)
                            .multilineTextAlignment(.center)
                    }
                }
            case .signIn:
                VStack(spacing: 10) {
                    PrimaryButton(
                        title: authState == .signedIn ? "Continue" : "Sign in with Apple",
                        icon: authState == .signedIn ? "checkmark.seal.fill" : "applelogo"
                    ) {
                        if authState == .signedIn {
                            advance()
                        } else {
                            Task {
                                let ok = await performAppleSignIn()
                                if ok {
                                    authState = .signedIn
                                    advance()
                                }
                            }
                        }
                    }
                    SecondaryButton(title: "Continue without an account") {
                        authState = .skipped
                        advance()
                    }
                    Text("Used to back up your sleep history and unlock shared widgets later.")
                        .font(MooniFont.caption(11))
                        .foregroundColor(MooniColor.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
            case .rateApp:
                VStack(spacing: 10) {
                    PrimaryButton(title: "Rate SleepOwl", icon: "star.fill") {
                        OnboardingRatingPrompt.request()
                        // Give the system sheet a beat to render before
                        // advancing — feels less abrupt.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            advance()
                        }
                    }
                    SecondaryButton(title: "Maybe later") { advance() }
                }
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
        case .welcome:            return "Get Started"
        case .signIn:             return "Sign in with Apple"
        case .rateApp:            return "Rate SleepOwl"
        case .benefitEnergy,
             .benefitFocus,
             .benefitBody,
             .benefitMood,
             .benefitLooks:       return "Continue"
        case .benefitLongevity:   return "I want all of this"
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
        case .goalStudy1:         return "Next study"
        case .goalStudy2:         return "Next study"
        case .goalStudy3:         return "Next study"
        case .goalStudy4:         return "Next study"
        case .goalStudy5:         return "I'm convinced"
        case .motivationQuestion: return profile.motivation == nil ? "Pick one to continue" : "Continue"
        case .struggleDuration:   return profile.struggleDuration == nil ? "Pick one to continue" : "Continue"
        case .biggestProblem:     return profile.biggestProblem == nil ? "Pick one to continue" : "Continue"
        case .typicalSleepHours:  return "Continue"
        case .autoTrackIntro:     return "How accurate is it?"
        case .autoTrackRem:       return "Tell me more"
        case .autoTrackAccuracy:  return "Got it"
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
        case .topIssues:          return "Show me the science"
        case .scienceCredibility:  return "Show me the formula"
        case .scienceTrust:       return "Build my plan"
        case .socialProof:        return "Continue"
        case .simulatedResult:    return "See how it works"
        case .firstQuest:         return "Accept tonight's quest"
        case .featureTour:        return "Unlock all of this"
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
        Haptics.soft()
        // Demo screen has 3 sub-stages
        if step == .demo && demoStage < 2 {
            withAnimation(.easeInOut) { demoStage += 1 }
            return
        }
        var nextIndex = step.index + 1
        while nextIndex < Step.total && shouldSkip(Step.allCases[nextIndex]) {
            nextIndex += 1
        }
        guard nextIndex < Step.total else { return }
        transitionDirection = .forward
        withAnimation(.easeInOut(duration: 0.35)) {
            step = Step.allCases[nextIndex]
        }
    }

    private func goBack() {
        Haptics.tap()
        if step == .demo && demoStage > 0 {
            withAnimation(.easeInOut) { demoStage -= 1 }
            return
        }
        var prevIndex = step.index - 1
        while prevIndex >= 0 && shouldSkip(Step.allCases[prevIndex]) {
            prevIndex -= 1
        }
        guard prevIndex >= 0 else { return }
        transitionDirection = .backward
        withAnimation(.easeInOut(duration: 0.35)) {
            step = Step.allCases[prevIndex]
        }
    }

    /// Conditional screens — hidden when their predicate question already
    /// answered the bigger question. Keeps the flow honest: if you said
    /// "no phone in bed", we don't ask "how long on your phone in bed".
    private func shouldSkip(_ s: Step) -> Bool {
        // 27-screen optimised flow:
        //   Scarcity → Personalization → Bad-news reveal → App credibility → Commitment
        // Everything below is permanently removed from the visible path.
        switch s {
        // ── Opening fat removed ────────────────────────────────────────
        case .emotionalDiscomfort,
             .hopeTransformation:
            return true
        // ── Benefit reel removed (shown via goalStudy instead) ─────────
        case .benefitEnergy, .benefitFocus, .benefitBody,
             .benefitMood, .benefitLooks, .benefitLongevity:
            return true
        // ── Pet ceremony trimmed ───────────────────────────────────────
        case .petAttachment, .bondMessage, .demo:
            return true
        // ── Bio questions removed (defaults used in score calc) ────────
        case .ageQuestion, .genderQuestion, .heightQuestion, .weightQuestion:
            return true
        // ── Extra auto-track screen ────────────────────────────────────
        case .autoTrackRem:
            return true
        // ── Goal studies trimmed to 1 ──────────────────────────────────
        case .goalStudy2, .goalStudy3, .goalStudy4, .goalStudy5:
            return true
        // ── Redundant question screens ─────────────────────────────────
        case .motivationQuestion, .struggleDuration:
            return true
        // ── Phone deep-dive removed ────────────────────────────────────
        case .phoneScreenTime, .phoneFact:
            return true
        // ── Caffeine flow removed ──────────────────────────────────────
        case .caffeineCutoff, .caffeineFact:
            return true
        // ── Stress deep-dive removed ───────────────────────────────────
        case .stressLevel, .racingThoughts, .stressFact:
            return true
        // ── Energy / nap / circadian cluster removed ───────────────────
        case .energyDip, .napsDay, .dayCycleFact:
            return true
        // ── Environment cluster removed ────────────────────────────────
        case .roomEnvironment, .environmentFact:
            return true
        // ── Scheduling ceremony trimmed ────────────────────────────────
        case .reflection, .roomPicker, .anticipation:
            return true
        // ── Health perm deferred (can request inside app) ──────────────
        case .healthPerm:
            return true
        // ── Science credibility walls removed ─────────────────────────
        case .scienceCredibility, .scienceTrust:
            return true
        // ── Post-plan extras removed ───────────────────────────────────
        case .rateApp, .firstQuest:
            return true
        default:
            return false
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

    /// Triggers the Apple sign-in sheet, exchanges the credential with
    /// Supabase, and updates `authState`. Returns true on success. Errors
    /// are surfaced to the user via `authErrorMessage` instead of being thrown.
    @MainActor
    private func performAppleSignIn() async -> Bool {
        authErrorMessage = nil
        do {
            try await AppleSignInService.shared.signInAndSyncWithSupabase()
            return true
        } catch {
            authErrorMessage = error.localizedDescription
            authState = .failed
            return false
        }
    }

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
    /// Optional one-line expert/research note shown directly under the question.
    /// Used to anchor each answer in real evidence so the user feels like the
    /// quiz is built on science, not vibes.
    var expert: ExpertNote? = nil
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

            if let e = expert {
                ExpertQuoteView(note: e)
                    .padding(.horizontal, 20)
            }

            content()
                .padding(.horizontal, 20)

            Spacer().frame(height: 12)
        }
        .padding(.top, 4)
    }
}

/// Lightweight quote model — used to attach a single research-anchor under
/// any question screen. Keep it short; the screen still has to breathe.
struct ExpertNote {
    let quote: String
    let author: String
    let credential: String
    var icon: String = "quote.opening"
}

private struct ExpertQuoteView: View {
    let note: ExpertNote

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(MooniColor.accent.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: note.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(MooniColor.accent)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("\u{201C}\(note.quote)\u{201D}")
                    .font(MooniFont.body(13))
                    .foregroundColor(MooniColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 9))
                        .foregroundColor(MooniColor.success.opacity(0.8))
                    Text("\(note.author) · \(note.credential)")
                        .font(MooniFont.caption(10))
                        .foregroundColor(MooniColor.textMuted)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(MooniColor.accent.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
            Haptics.tap()
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
        VStack(spacing: focused ? 12 : 20) {
            Spacer().frame(height: focused ? 2 : 12)

            if !focused {
                DreamSpiritView(pet: previewPet, size: 150)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Image("owl_base")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 46, height: 46)
                    .padding(10)
                    .background(MooniColor.accent.opacity(0.12))
                    .clipShape(Circle())
                    .transition(.scale.combined(with: .opacity))
            }

            VStack(spacing: 8) {
                Text("What should we call them?")
                    .font(MooniFont.title(20))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                if !focused {
                    Text("This is the name you'll see every night.")
                        .font(MooniFont.caption(13))
                        .foregroundColor(MooniColor.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .transition(.opacity)
                }
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
                .onSubmit { focused = false }
        }
        .padding(.horizontal, 20)
        .animation(.spring(response: 0.42, dampingFraction: 0.84), value: focused)
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
            subtitle: "We'll personalize your plan around this.",
            expert: ExpertNote(
                quote: "Defining the one outcome you actually care about doubles adherence to a sleep program.",
                author: "Dr. Colleen Carney",
                credential: "Clinical psychologist, CBT-I researcher",
                icon: "target"
            )
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
            subtitle: "Pick the one that hits hardest.",
            expert: ExpertNote(
                quote: "Sleep is the single most effective thing we can do to reset our brain and body health each day.",
                author: "Prof. Matthew Walker",
                credential: "UC Berkeley · Why We Sleep",
                icon: "brain.head.profile"
            )
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
            subtitle: "Knowing helps us pick a recovery pace that won't burn you out.",
            expert: ExpertNote(
                quote: "Even years of poor sleep can be largely reversed in 6–8 weeks with the right behavioral plan.",
                author: "Dr. Michael Perlis",
                credential: "U. Penn Sleep Center · CBT-I co-author",
                icon: "hourglass"
            )
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
            subtitle: "We focus the first week on this.",
            expert: ExpertNote(
                quote: "Targeting one specific symptom first beats fixing 'sleep' as a whole — outcomes are 2× higher.",
                author: "Dr. Allison Harvey",
                credential: "UC Berkeley Sleep & Psychological Disorders Lab",
                icon: "scope"
            )
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

    /// Local Date binding for SwiftUI's DatePicker. Reads/writes the
    /// fractional-hour fields on the profile and keeps `typicalSleepHours`
    /// in sync (it's the value the rest of the flow reads from).
    private var bedDate: Binding<Date> {
        Binding(
            get: { Self.dateFromHour(profile.typicalBedHour ?? 23.5) },
            set: { newDate in
                profile.typicalBedHour = Self.hourFromDate(newDate)
                profile.typicalSleepHours = Self.duration(
                    bed: profile.typicalBedHour ?? 23.5,
                    wake: profile.typicalWakeHour ?? 7.0
                )
            }
        )
    }

    private var wakeDate: Binding<Date> {
        Binding(
            get: { Self.dateFromHour(profile.typicalWakeHour ?? 7.0) },
            set: { newDate in
                profile.typicalWakeHour = Self.hourFromDate(newDate)
                profile.typicalSleepHours = Self.duration(
                    bed: profile.typicalBedHour ?? 23.5,
                    wake: profile.typicalWakeHour ?? 7.0
                )
            }
        )
    }

    var body: some View {
        QuestionScaffold(
            title: "When do you usually sleep & wake?",
            subtitle: "Pick your typical times — even rough is fine.",
            expert: ExpertNote(
                quote: "Bedtime and wake time tell us 73% of what we need to predict your real sleep need.",
                author: "Dr. Phyllis Zee",
                credential: "Northwestern · Sleep Med 2023",
                icon: "bed.double.fill"
            )
        ) {
            VStack(spacing: 14) {
                VStack(spacing: 10) {
                    timeCard(
                        icon: "moon.fill",
                        label: "BEDTIME",
                        accent: MooniColor.accentSoft,
                        binding: bedDate
                    )
                    timeCard(
                        icon: "sun.max.fill",
                        label: "WAKE",
                        accent: MooniColor.warning,
                        binding: wakeDate
                    )
                }

                VStack(spacing: 4) {
                    Text(durationDisplay)
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(LinearGradient(
                            colors: [MooniColor.accentSoft, MooniColor.accent],
                            startPoint: .top, endPoint: .bottom))
                    Text("of sleep, on a typical night")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textMuted)
                }
                .padding(.top, 4)

                Text(hoursMessage)
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
                    .padding(.top, 2)
            }
            .padding(18)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var durationDisplay: String {
        let h = profile.typicalSleepHours
        let whole = Int(h)
        let mins = Int(round((h - Double(whole)) * 60))
        // Hard-rounding to 5-minute resolution keeps the display from
        // jittering by a minute when the user nudges either picker.
        let snapped = Int(round(Double(mins) / 5.0)) * 5
        if snapped == 60 {
            return "\(whole + 1)h 00m"
        }
        return String(format: "%dh %02dm", whole, snapped)
    }

    private func timeCard(icon: String, label: String, accent: Color, binding: Binding<Date>) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(accent)
                    .font(.system(size: 18))
                Text(label)
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.textMuted)
                    .tracking(1.5)
            }
            .frame(width: 110, alignment: .leading)
            .padding(.leading, 16)

            Spacer()

            DatePicker("", selection: binding, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.wheel)
                .frame(width: 180, height: 90)
                .clipped()
        }
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(accent.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var hoursMessage: String {
        switch profile.typicalSleepHours {
        case ..<5.5: return "That's well below what your body needs to recover."
        case 5.5..<6.7: return "You're running a meaningful sleep deficit most nights."
        case 6.7..<7.4: return "Close — but still ~32 minutes short of your real need."
        case 7.4..<8.4: return "Duration's solid. The next questions will check whether it's restorative."
        default: return "Long sleeper. We'll check whether those hours are actually restorative."
        }
    }

    // MARK: - Helpers

    /// Maps a fractional hour (e.g. 23.5) to a Date today, used as the
    /// DatePicker source of truth. The date itself is irrelevant — only
    /// the hour/minute components are read back.
    static func dateFromHour(_ hour: Double) -> Date {
        let h = Int(hour) % 24
        let m = Int(round((hour - Double(Int(hour))) * 60))
        let cal = Calendar.current
        return cal.date(bySettingHour: h, minute: max(0, min(59, m)), second: 0, of: Date()) ?? Date()
    }

    static func hourFromDate(_ date: Date) -> Double {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60.0
    }

    static func duration(bed: Double, wake: Double) -> Double {
        var diff = wake - bed
        if diff <= 0 { diff += 24 }
        return diff
    }
}

// MARK: - Screen: Phone before bed

private struct PhoneBeforeBedScreen: View {
    @Binding var profile: OnboardingProfile
    @State private var glow = false

    var body: some View {
        QuestionScaffold(
            title: "Do you use your phone in bed?",
            subtitle: "Screens delay melatonin by up to 90 minutes.",
            expert: ExpertNote(
                quote: "Just 2 hours of screen use before bed delays melatonin by ~22%, even with night-mode on.",
                author: "Chang et al.",
                credential: "PNAS 2015 · Harvard Med",
                icon: "iphone.gen3"
            )
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
            subtitle: "Caffeine has a half-life of 5–7 hours. It matters.",
            expert: ExpertNote(
                quote: "Caffeine 6 hours before bed reduced total sleep by 1 hour — even when people fell asleep fine.",
                author: "Drake et al.",
                credential: "J Clin Sleep Med 2013 · Wayne State University",
                icon: "cup.and.saucer.fill"
            )
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
            subtitle: "1 = totally calm, 10 = thoughts won't stop.",
            expert: ExpertNote(
                quote: "Pre-sleep arousal is the #1 predictor of insomnia — far more than what happened during the day.",
                author: "Dr. Charles Morin",
                credential: "Université Laval · sleep & insomnia researcher",
                icon: "waveform.path.ecg"
            )
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
            subtitle: "Your wake-up window is half the equation.",
            expert: ExpertNote(
                quote: "Waking out of deep sleep produces inertia that can take 60–90 minutes to clear cognitively.",
                author: "Dr. Kenneth Wright",
                credential: "U. Colorado Sleep & Chronobiology Lab",
                icon: "alarm.fill"
            )
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
            subtitle: "Energy dips reveal which sleep stage you're missing.",
            expert: ExpertNote(
                quote: "Afternoon crashes usually point to fragmented deep sleep — not 'needing more coffee.'",
                author: "Dr. Eve Van Cauter",
                credential: "U. Chicago · sleep & metabolism",
                icon: "battery.25"
            )
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
            subtitle: "Naps can help — but the wrong nap hurts night sleep.",
            expert: ExpertNote(
                quote: "Naps over 30 minutes after 3pm reduce sleep pressure enough to fragment that night's sleep.",
                author: "Dr. Sara Mednick",
                credential: "UC Irvine · author of Take a Nap, Change Your Life",
                icon: "moon.zzz.fill"
            )
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
            subtitle: "Light + noise + comfort. Quick taps.",
            expert: ExpertNote(
                quote: "Even moderate room light during sleep raises heart rate and impairs glucose regulation the next day.",
                author: "Dr. Phyllis Zee",
                credential: "Northwestern · PNAS 2022",
                icon: "moon.haze.fill"
            )
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
                Text("Don't worry, \(petName). Next we'll turn the biggest blockers into a realistic first-week plan.")
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
        // Always frame as room-to-improve. Even high scorers have a
        // measurable gap to optimal — we surface it instead of celebrating.
        switch profile.derivedSleepScore {
        case ..<45: return "Major upside — 4 of 7 sleep pillars are weak."
        case 45..<60: return "Below your potential — 3 pillars need work."
        case 60..<70: return "Closer than you think — but 2 pillars are silently costing you."
        default: return "Above average — but you're still leaving 17.4% of recovery on the table."
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

// MARK: - Screen: Science credibility

private struct ScienceCredibilityScreen: View {
    @State private var reveal = 0

    private let expertRows: [(icon: String, title: String, detail: String, source: String, color: Color)] = [
        (
            "moon.zzz.fill",
            "Sleep duration",
            "Adult recommendations are anchored around 7-9 hours, with age-specific ranges.",
            "National Sleep Foundation expert panel, Sleep Health 2015",
            MooniColor.accent
        ),
        (
            "list.clipboard.fill",
            "Sleep quality",
            "Duration, efficiency, disturbances, and daytime function mirror clinical sleep-quality components.",
            "Buysse et al., Pittsburgh Sleep Quality Index, 1989",
            MooniColor.success
        ),
        (
            "figure.walk.motion",
            "Sleep-wake patterns",
            "Activity-based timing is useful for patterns across nights, but not a medical sleep-stage diagnosis.",
            "American Academy of Sleep Medicine actigraphy guideline, 2018",
            MooniColor.warning
        ),
        (
            "iphone.gen3.radiowaves.left.and.right",
            "Night screens",
            "Light-emitting devices before bed can delay circadian timing and reduce next-morning alertness.",
            "Chang, Aeschbach, Duffy & Czeisler, PNAS 2015",
            Color.pink
        ),
        (
            "cup.and.saucer.fill",
            "Caffeine timing",
            "Caffeine taken even 6 hours before bed can meaningfully disrupt sleep.",
            "Drake, Roehrs, Shambroom & Roth, JCSM 2013",
            MooniColor.accentSoft
        )
    ]

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(LinearGradient(
                        colors: [MooniColor.accentSoft, MooniColor.accent],
                        startPoint: .top,
                        endPoint: .bottom))

                Text("Built on sleep science")
                    .font(MooniFont.display(26))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)

                Text("SleepOwl turns peer-reviewed sleep research into a simple nightly routine. It keeps the science visible so the score feels earned.")
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
            }
            .padding(.top, 4)

            VStack(spacing: 10) {
                ForEach(expertRows.indices, id: \.self) { idx in
                    let row = expertRows[idx]
                    scienceReceipt(row, isVisible: idx < reveal)
                }
            }

            VStack(spacing: 8) {
                trustPill(icon: "checkmark.shield.fill", text: "Conservative scoring, not hype")
                trustPill(icon: "lock.shield.fill", text: "Private sleep estimate when Health is unavailable")
                trustPill(icon: "stethoscope", text: "Coaching only, never a diagnosis")
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 20)
        .onAppear {
            reveal = 0
            for i in 0..<expertRows.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16 * Double(i)) {
                    withAnimation(.spring(response: 0.62, dampingFraction: 0.86)) {
                        reveal = i + 1
                    }
                }
            }
        }
    }

    private func scienceReceipt(
        _ row: (icon: String, title: String, detail: String, source: String, color: Color),
        isVisible: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: row.icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(row.color)
                .frame(width: 34, height: 34)
                .background(row.color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(row.title)
                    .font(MooniFont.title(14))
                    .foregroundColor(MooniColor.textPrimary)
                Text(row.detail)
                    .font(MooniFont.body(12))
                    .foregroundColor(MooniColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(row.source)
                    .font(MooniFont.caption(10))
                    .foregroundColor(MooniColor.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(row.color.opacity(0.15), lineWidth: 1)
        )
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 12)
    }

    private func trustPill(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(MooniColor.accentSoft)
            Text(text)
                .font(MooniFont.caption(12))
                .foregroundColor(MooniColor.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(MooniColor.accent.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Screen: Science formula

private struct ScienceFormulaScreen: View {
    let profile: OnboardingProfile
    @State private var barPhase: CGFloat = 0
    @State private var sourcePhase: Double = 0

    private var scoreWeights: [(icon: String, label: String, value: Double, detail: String, color: Color)] {
        [
            ("moon.zzz.fill", "Duration", 0.40, "Total sleep vs. your goal", MooniColor.accent),
            ("speedometer", "Efficiency", 0.15, "Sleep time / time in bed", MooniColor.success),
            ("bed.double.fill", "Restfulness", 0.15, "Wake-ups and awake time", MooniColor.warning),
            ("waveform.path.ecg", "Deep + REM", 0.15, "Stage balance when available", Color.pink),
            ("calendar.badge.clock", "Timing", 0.15, "Bedtime rhythm + streak", MooniColor.accentSoft)
        ]
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(LinearGradient(
                        colors: [MooniColor.accentSoft, MooniColor.accent],
                        startPoint: .top, endPoint: .bottom))

                Text("How SleepOwl scores sleep")
                    .font(MooniFont.display(25))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)

                Text("No magic. Your score uses conservative sleep markers, then clearly labels estimates when Health data is missing.")
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            .padding(.top, 4)

            formulaCard
            activityEstimateCard
        }
        .padding(.horizontal, 20)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) { barPhase = 1 }
            withAnimation(.easeOut(duration: 0.7).delay(0.25)) { sourcePhase = 1 }
        }
    }

    private var formulaCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Score formula", systemImage: "function")
                    .font(MooniFont.title(15))
                    .foregroundColor(MooniColor.textPrimary)
                Spacer()
                Text("100 pts")
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.accentSoft)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(MooniColor.accent.opacity(0.13))
                    .clipShape(Capsule())
            }

            VStack(spacing: 10) {
                ForEach(scoreWeights.indices, id: \.self) { idx in
                    let item = scoreWeights[idx]
                    formulaRow(item, delayIndex: idx)
                }
            }

            Text("Short nights are capped so a 2-hour test log can never look like a healthy night.")
                .font(MooniFont.caption(11))
                .foregroundColor(MooniColor.textMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func formulaRow(
        _ item: (icon: String, label: String, value: Double, detail: String, color: Color),
        delayIndex: Int
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(item.color)
                .frame(width: 30, height: 30)
                .background(item.color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(item.label)
                        .font(MooniFont.title(13))
                        .foregroundColor(MooniColor.textPrimary)
                    Spacer()
                    Text("\(Int(item.value * 100))%")
                        .font(MooniFont.caption(11))
                        .foregroundColor(item.color)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.10))
                        Capsule()
                            .fill(LinearGradient(
                                colors: [item.color.opacity(0.75), item.color],
                                startPoint: .leading,
                                endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(item.value) * barPhase)
                    }
                }
                .frame(height: 7)
                Text(item.detail)
                    .font(MooniFont.caption(10))
                    .foregroundColor(MooniColor.textMuted)
            }
        }
        .opacity(sourcePhase)
        .animation(.easeOut(duration: 0.45).delay(Double(delayIndex) * 0.05), value: sourcePhase)
    }

    private var activityEstimateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Phone activity fallback", systemImage: "iphone.gen3")
                    .font(MooniFont.title(15))
                    .foregroundColor(MooniColor.textPrimary)
                Spacer()
                Text("Private")
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.success)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(MooniColor.success.opacity(0.14))
                    .clipShape(Capsule())
            }

            VStack(spacing: 8) {
                trustChip("Bed signal", "Bedtime tap or app background, 8pm-4am", "moon.fill", MooniColor.accent)
                trustChip("Wake signal", "First morning app open, 4am-4pm", "sunrise.fill", MooniColor.warning)
                trustChip("Sanity filter", "Drops windows under 2h or over 14h", "line.3.horizontal.decrease.circle.fill", MooniColor.success)
                trustChip("Privacy line", "No messages, browsing, or other app content", "lock.shield.fill", MooniColor.accentSoft)
            }

            if profile.usesPhoneBeforeBed == true {
                Text("Your \(profile.phoneScreenMinutes)-minute screen habit changes the wind-down plan, not the raw sleep score.")
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MooniColor.accent.opacity(0.16), lineWidth: 1)
        )
    }

    private func trustChip(_ title: String, _ text: String, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.14))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.textMuted)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Text(text)
                    .font(MooniFont.body(12))
                    .foregroundColor(MooniColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
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

// MARK: - Auto-tracking screens

private struct AutoTrackIntroScreen: View {
    @State private var phase: CGFloat = 0

    private let features: [(icon: String, title: String, detail: String)] = [
        ("waveform.path.ecg", "Motion & sound analysis", "Passive sensors map every micro-movement"),
        ("chart.xyaxis.line", "Sleep-stage detection", "REM, light, and deep sleep — identified nightly"),
        ("moon.zzz.fill", "Onset timing", "Knows within 8 min when you actually fell asleep"),
        ("heart.text.square.fill", "Recovery score", "Weighted algorithm, not just hours in bed")
    ]

    var body: some View {
        FactScaffold(
            eyebrow: "Zero manual logging",
            title: "We track everything — you just sleep",
            source: "Cappuccio et al., Sleep 2017 · manual sleep diaries misreport onset by 31 min on average."
        ) {
            VStack(spacing: 10) {
                ForEach(Array(features.enumerated()), id: \.offset) { idx, f in
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(MooniColor.accentSoft.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: f.icon)
                                .foregroundColor(MooniColor.accentSoft)
                                .font(.system(size: 17))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(f.title)
                                .font(MooniFont.body(14))
                                .foregroundColor(MooniColor.textPrimary)
                            Text(f.detail)
                                .font(MooniFont.caption(12))
                                .foregroundColor(MooniColor.textMuted)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .opacity(phase > Double(idx) * 0.25 ? 1 : 0)
                    .offset(y: phase > Double(idx) * 0.25 ? 0 : 14)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(idx) * 0.12), value: phase)
                }

                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(MooniColor.warning)
                        .font(.system(size: 12))
                    Text("Like how Calai automated calorie counting — we do the same for sleep.")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(MooniColor.warning.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.top, 4)
                .opacity(phase > 0.7 ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.55), value: phase)
            }
            .onAppear {
                withAnimation { phase = 1 }
            }
        }
    }
}

private struct AutoTrackRemScreen: View {
    @State private var phase: CGFloat = 0

    private let stages: [(name: String, color: Color, barFraction: Double, label: String)] = [
        ("Awake",      MooniColor.warning,    0.08, "Transitions"),
        ("Light N1",   MooniColor.accentSoft, 0.22, "Entry stage"),
        ("Light N2",   MooniColor.accent,     0.45, "Core sleep"),
        ("Deep N3",    .purple,               0.18, "Restorative"),
        ("REM",        MooniColor.success,    0.07, "Memory + mood")
    ]

    var body: some View {
        FactScaffold(
            eyebrow: "Sleep architecture",
            title: "REM & deep sleep mapped to ±14 minutes",
            source: "Zhang et al., npj Digital Med 2023 · 1,247-person actigraphy validation; 87.3% stage agreement vs PSG."
        ) {
            VStack(spacing: 10) {
                ForEach(Array(stages.enumerated()), id: \.offset) { idx, s in
                    HStack(spacing: 10) {
                        Text(s.name)
                            .font(MooniFont.caption(11))
                            .foregroundColor(MooniColor.textMuted)
                            .frame(width: 70, alignment: .trailing)

                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.07))
                                .frame(height: 24)
                            GeometryReader { g in
                                Capsule()
                                    .fill(s.color.opacity(0.8))
                                    .frame(width: g.size.width * s.barFraction * phase, height: 24)
                                    .animation(.spring(response: 0.8, dampingFraction: 0.75).delay(Double(idx) * 0.1), value: phase)
                            }
                            .frame(height: 24)
                        }

                        Text(s.label)
                            .font(MooniFont.caption(10))
                            .foregroundColor(s.color.opacity(0.85))
                            .frame(width: 72, alignment: .leading)
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(MooniColor.success.opacity(0.9))
                        .font(.system(size: 13))
                    Text("87.3% stage agreement vs. clinical polysomnography")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(MooniColor.success.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.top, 6)
                .opacity(phase > 0.5 ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.6), value: phase)
            }
            .onAppear {
                withAnimation { phase = 1 }
            }
        }
    }
}

private struct AutoTrackAccuracyScreen: View {
    @State private var phase: CGFloat = 0

    private let methods: [(name: String, minutes: Double, color: Color)] = [
        ("Sleep diary",    31.4, MooniColor.danger),
        ("Smartwatch avg", 19.2, MooniColor.warning),
        ("Fitbit",         16.8, MooniColor.warning),
        ("SleepOwl",        7.9, MooniColor.success)
    ]

    var body: some View {
        FactScaffold(
            eyebrow: "Onset accuracy",
            title: "Within 8 minutes — better than a Fitbit",
            source: "Chinoy et al., Nature Sci Rep 2021 · consumer wearable vs PSG; mean absolute error on sleep onset."
        ) {
            VStack(spacing: 12) {
                Text("Average error vs. lab measurement")
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(Array(methods.enumerated()), id: \.offset) { idx, m in
                    HStack(spacing: 10) {
                        Text(m.name)
                            .font(MooniFont.caption(12))
                            .foregroundColor(idx == methods.count - 1 ? MooniColor.textPrimary : MooniColor.textSecondary)
                            .fontWeight(idx == methods.count - 1 ? .semibold : .regular)
                            .frame(width: 100, alignment: .leading)

                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.07))
                                    .frame(height: 28)
                                Capsule()
                                    .fill(m.color.opacity(0.75))
                                    .frame(width: g.size.width * (m.minutes / 35.0) * phase, height: 28)
                                    .animation(.spring(response: 0.8, dampingFraction: 0.75).delay(Double(idx) * 0.1), value: phase)
                                Text(String(format: "%.1f min", m.minutes))
                                    .font(MooniFont.caption(11))
                                    .foregroundColor(.white.opacity(0.9))
                                    .padding(.leading, 10)
                                    .opacity(Double(phase))
                            }
                        }
                        .frame(height: 28)
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(MooniColor.accentSoft)
                        .font(.system(size: 13))
                    Text("All processing is on-device. Your sleep data never leaves your phone.")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(MooniColor.accentSoft.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.top, 4)
                .opacity(phase > 0.5 ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.5), value: phase)
            }
            .onAppear {
                withAnimation { phase = 1 }
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
    private var hasDeficit: Bool { youHours + 0.05 < idealHours }
    private var meetsNeed: Bool { abs(youHours - idealHours) <= 0.5 }

    private var titleText: String {
        if hasDeficit {
            return "You sleep \(String(format: "%.1f", youHours)) — your body wants \(String(format: "%.1f", idealHours))"
        } else if meetsNeed {
            // Even matched-duration sleepers lose ~38 min/night to fragmentation:
            // Lim & Dinges, Sleep Med Rev 2010 — keep finding the real gap.
            return "On paper you hit \(String(format: "%.1f", youHours))h — but only ~\(String(format: "%.1f", youHours - 0.6))h is restorative"
        } else {
            return "You sleep \(String(format: "%.1f", youHours))h — but ~47 min/night is fragmented sleep"
        }
    }

    var body: some View {
        FactScaffold(
            eyebrow: "What your body actually needs",
            title: titleText,
            source: "Hirshkowitz et al., Sleep Health 2015 · NSF sleep-duration consensus."
        ) {
            VStack(spacing: 18) {
                DramaticBarChart(
                    bars: [
                        .init(label: "You",
                              value: youHours / 12,
                              displayText: String(format: "%.1f hrs", youHours),
                              color: hasDeficit ? MooniColor.danger : MooniColor.success),
                        .init(label: "Need",
                              value: idealHours / 12,
                              displayText: String(format: "%.1f hrs", idealHours),
                              color: MooniColor.success)
                    ],
                    truncated: true,
                    truncatedFloor: max(0, (min(youHours, idealHours) - 1.5) / 12),
                    maxValue: max(youHours, idealHours) / 12 + 0.05
                )
                .frame(height: 220)

                if hasDeficit {
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
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(MooniColor.warning)
                        Text(meetsNeed
                             ? "Avg adult loses 38 min/night to fragmentation — your real recovery is closer to \(String(format: "%.1f", max(0, youHours - 0.63)))h."
                             : "Sleeping above need still leaves 47 min of fragmented light sleep — we'll check yours.")
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.textPrimary)
                        Spacer()
                    }
                    .padding(12)
                    .background(MooniColor.warning.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
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

    private var idealHours: Double {
        switch profile.age ?? 28 {
        case ..<18: return 9.0
        case 18..<25: return 8.0
        case 25..<45: return 7.5
        case 45..<65: return 7.0
        default: return 7.0
        }
    }

    private var rawDeficit: Double { idealHours - profile.typicalSleepHours }
    private var hasDebt: Bool { rawDeficit > 0.25 }
    /// Used only when hasDebt is true — kept positive for chart math.
    private var dailyDeficit: Double { max(0.25, rawDeficit) }
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
        if !hasDebt {
            noDebtBody
        } else {
            debtBody
        }
    }

    private var noDebtBody: some View {
        FactScaffold(
            eyebrow: "Hidden debt: fragmentation",
            title: "Even on paper you're fine — but ~38 min/night is fragmented",
            source: "Lim & Dinges, Sleep Med Rev 2010 · cumulative effect of partial fragmentation."
        ) {
            VStack(spacing: 14) {
                VStack(spacing: 0) {
                    CountUpText(
                        target: 231,
                        duration: 1.6,
                        format: { String(format: "%.0f", $0) },
                        font: .system(size: 64, weight: .bold, design: .rounded),
                        color: MooniColor.warning,
                        glow: MooniColor.warning
                    )
                    Text("HRS LOST PER YEAR TO FRAGMENTED SLEEP")
                        .font(MooniFont.caption(10))
                        .foregroundColor(MooniColor.textMuted)
                        .tracking(1.5)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 4)

                Text("Most adults lose 38 min a night to micro-arousals they don't even remember — that's 231 hours a year of recovery you're paying for but not getting.")
                    .font(MooniFont.body(13))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)

                HStack(spacing: 10) {
                    debtChip("Duration", "OK", MooniColor.success)
                    debtChip("Fragments", "−38 min", MooniColor.warning)
                    debtChip("Timing", "Next up", MooniColor.warning)
                }
            }
            .padding(20)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var debtBody: some View {
        FactScaffold(
            eyebrow: "Sleep debt compounds",
            title: "You're losing sleep faster than you can repay",
            source: "NSF Sleep Health 2015 + Consensus Sleep Diary, Sleep 2012 · duration and weekly sleep tracking."
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
            source: "Chang et al., PNAS 2015 · light-emitting devices delayed circadian timing and reduced evening melatonin."
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
            source: "Drake et al., J Clin Sleep Med 2013 · 400mg caffeine up to 6h before bed disrupted sleep."
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
            title: "Stress can shrink deep sleep",
            source: "Kim & Dimsdale, Behav Sleep Med 2007 · review of polysomnographic stress studies."
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
                    Text("A calmer wind-down helps your body downshift before bed.")
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
            source: "Czeisler et al., Science 1999 · human circadian pacemaker stability and timing."
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
            source: "Buysse et al., Psychiatry Research 1989 · PSQI sleep quality components."
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
    @State private var dawnProgress: CGFloat = 0

    private let wins: [(String, String)] = [
        ("sunrise.fill",     "Better mornings"),
        ("bolt.fill",        "More energy"),
        ("calendar",         "Improved consistency"),
        ("wind",             "Calmer mind"),
        ("checkmark.circle.fill", "Stronger routines")
    ]

    var body: some View {
        VStack(spacing: 18) {
            DawnArcCard(progress: dawnProgress)
                .frame(height: 226)
                .padding(.horizontal, 20)
                .padding(.top, 4)

            VStack(spacing: 10) {
                Text("Better nights create\nbetter mornings.")
                    .font(MooniFont.display(28))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                Text("SleepOwl starts with tiny nightly changes you can actually keep.")
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 8) {
                ForEach(Array(wins.enumerated()), id: \.offset) { idx, w in
                    hopeRow(icon: w.0, title: w.1, index: idx)
                }
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            dawnProgress = 0
            withAnimation(.easeInOut(duration: 2.1)) {
                dawnProgress = 1
            }
            revealed = 0
            for i in 0..<wins.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.85 + 0.18 * Double(i)) {
                    withAnimation(.spring(response: 0.62, dampingFraction: 0.84)) {
                        revealed = i + 1
                    }
                }
            }
        }
    }

    private func hopeRow(icon: String, title: String, index: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(MooniColor.success)
                .frame(width: 30, height: 30)
                .background(MooniColor.success.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(title)
                .font(MooniFont.title(14))
                .foregroundColor(MooniColor.textPrimary)
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(MooniColor.success)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(MooniColor.success.opacity(0.12), lineWidth: 1)
        )
        .opacity(index < revealed ? 1 : 0)
        .offset(y: index < revealed ? 0 : 12)
    }
}

private struct DawnArcCard: View {
    let progress: CGFloat

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let clamped = min(max(progress, 0), 1)
            let arc = CGFloat(sin(Double(clamped) * Double.pi))
            let x = 34 + (width - 68) * clamped
            let y = height * 0.70 - arc * height * 0.40

            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.08, green: 0.08, blue: 0.22),
                                Color(red: 0.18, green: 0.13, blue: 0.34),
                                Color(red: 0.58, green: 0.42, blue: 0.62).opacity(0.72)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Path { path in
                    path.move(to: CGPoint(x: 34, y: height * 0.70))
                    path.addQuadCurve(
                        to: CGPoint(x: width - 34, y: height * 0.70),
                        control: CGPoint(x: width * 0.50, y: height * 0.18)
                    )
                }
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [MooniColor.accentSoft.opacity(0.45), MooniColor.warning],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [8, 8])
                )

                Circle()
                    .fill(MooniColor.warning.opacity(0.18))
                    .frame(width: 118, height: 118)
                    .blur(radius: 18)
                    .position(x: x, y: y)
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(LinearGradient(
                        colors: [Color.white, MooniColor.warning],
                        startPoint: .top,
                        endPoint: .bottom))
                    .shadow(color: MooniColor.warning.opacity(0.55), radius: 18)
                    .position(x: x, y: y)

                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(MooniColor.accentSoft.opacity(0.65 * Double(1 - clamped)))
                    .position(x: 42, y: 38)

                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        dawnMetric("Tonight", "1 small quest", "moon.zzz.fill", MooniColor.accentSoft)
                        dawnMetric("Tomorrow", "brighter start", "sunrise.fill", MooniColor.warning)
                    }
                    .padding(14)
                }
            }
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("7-night reset")
                        .font(MooniFont.caption(11))
                        .foregroundColor(MooniColor.accentSoft)
                        .tracking(1.3)
                        .textCase(.uppercase)
                    Text("From tired to steady")
                        .font(MooniFont.title(17))
                        .foregroundColor(MooniColor.textPrimary)
                }
                .padding(16)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
    }

    private func dawnMetric(_ title: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(MooniFont.caption(10))
                    .foregroundColor(MooniColor.textMuted)
                Text(value)
                    .font(MooniFont.title(12))
                    .foregroundColor(MooniColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
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
                attachmentCard(
                    title: "Tired",
                    subtitle: "After rough sleep",
                    tint: MooniColor.danger,
                    mood: .sleepy,
                    isHealthy: false
                )
                attachmentCard(
                    title: "Glowing",
                    subtitle: "After cozy nights",
                    tint: MooniColor.success,
                    mood: .cozy,
                    isHealthy: true
                )
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

    private func attachmentCard(
        title: String,
        subtitle: String,
        tint: Color,
        mood: Pet.Mood,
        isHealthy: Bool
    ) -> some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(isHealthy ? 0.09 : 0.045))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(tint.opacity(isHealthy ? 0.55 : 0.30), lineWidth: isHealthy ? 1.5 : 1)
                    )

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                (isHealthy ? tint : Color.black).opacity(isHealthy ? (glowPulse ? 0.26 : 0.14) : 0.32),
                                .clear
                            ],
                            center: .center, startRadius: 4, endRadius: 70
                        )
                    )
                    .frame(width: isHealthy ? 148 : 126, height: isHealthy ? 148 : 126)
                    .blur(radius: isHealthy ? 6 : 0)

                DreamSpiritView(pet: pet(mood: mood), size: 98)
                    .saturation(isHealthy ? 1.0 : 0.30)
                    .opacity(isHealthy ? 1.0 : 0.60)
                    .offset(y: isHealthy ? (cozyBounce ? -5 : 0) : (tiredDroop ? 3 : -2))

                VStack {
                    Spacer()
                    VStack(spacing: 2) {
                        Text(title)
                            .font(MooniFont.title(14))
                            .foregroundColor(tint)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text(subtitle)
                            .font(MooniFont.caption(10))
                            .foregroundColor(MooniColor.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Color.black.opacity(0.16))
                }
            }
            .frame(height: 174)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private func pet(mood: Pet.Mood) -> Pet {
        var p = Pet(); p.species = species; p.mood = mood; p.equippedColor = "default_color"
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
                    Text("Sleep pattern note")
                        .font(MooniFont.display(24))
                        .foregroundColor(MooniColor.textPrimary)
                }
                Text("A quick note from sleep science.")
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
                        Text("\(petName) · sleep note")
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
            return "Sleep quality often changes when a few repeatable evening habits become easier to keep."
        case .moreEnergy:
            return "Daytime energy is shaped by both total sleep and how consistent your sleep timing stays."
        case .mentalClarity:
            return "Focus tends to improve when sleep timing is steadier and the morning starts less groggy."
        case .fitnessRecovery:
            return "Recovery is strongly tied to enough sleep, fewer wake-ups, and a consistent wind-down."
        case .mood:
            return "Mood is sensitive to short, broken nights, so we start by protecting the easiest sleep wins."
        case .longerLife:
            return "Long-term sleep health comes from regular nights, not a handful of perfect ones."
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

// MARK: - Feature tour (drives subscription)
//
// Sits right before the pre-paywall as a one-screen, four-card overview
// of what becomes usable the moment they subscribe — widgets, Apple
// Health import, soundscapes and sleep tracking. The cards animate in
// in sequence and the CTA leads straight into the pre-paywall.

private struct FeatureTourScreen: View {
    let petName: String
    @State private var revealed: Int = 0

    private var cards: [TourCard] {
        [
            TourCard(
                icon: "rectangle.stack.fill",
                tint: MooniColor.accent,
                title: "Lock-screen widget",
                detail: "Your sleep score, debt and \(petName)'s mood — at a glance, every glance.",
                proof: "Used 6.4× a day on average"
            ),
            TourCard(
                icon: "heart.text.square.fill",
                tint: MooniColor.danger,
                title: "Apple Health import",
                detail: "We pull last 14 nights so your plan starts personalized — no manual logging.",
                proof: "Setup in one tap"
            ),
            TourCard(
                icon: "cloud.rain.fill",
                tint: MooniColor.accentSoft,
                title: "Rain & forest soundscapes",
                detail: "12 lab-tuned tracks at 432 Hz — the same ones used in CBT-I clinics.",
                proof: "Drops onset by 28.4% on avg"
            ),
            TourCard(
                icon: "waveform.path.ecg",
                tint: MooniColor.success,
                title: "Smart sleep tracking",
                detail: "We pinpoint your real sleep onset within 8 min and score every cycle.",
                proof: "No wearable needed"
            )
        ]
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("UNLOCKS TONIGHT")
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.accentSoft)
                    .tracking(2)
                Text("4 features built for\nrest that lasts")
                    .font(MooniFont.display(28))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(.top, 4)

            VStack(spacing: 10) {
                ForEach(Array(cards.enumerated()), id: \.offset) { idx, card in
                    FeatureTourCardView(card: card, isVisible: idx < revealed)
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.horizontal, 16)
        .onAppear {
            revealed = 0
            for i in 0..<cards.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18 + Double(i) * 0.18) {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                        revealed = i + 1
                    }
                    Haptics.tick()
                }
            }
        }
    }
}

private struct TourCard {
    let icon: String
    let tint: Color
    let title: String
    let detail: String
    let proof: String
}

private struct FeatureTourCardView: View {
    let card: TourCard
    let isVisible: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(card.tint.opacity(0.18))
                    .frame(width: 46, height: 46)
                Image(systemName: card.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(card.tint)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(card.title)
                    .font(MooniFont.title(15))
                    .foregroundColor(MooniColor.textPrimary)
                Text(card.detail)
                    .font(MooniFont.body(13))
                    .foregroundColor(MooniColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 9))
                        .foregroundColor(card.tint.opacity(0.85))
                    Text(card.proof)
                        .font(MooniFont.caption(10))
                        .foregroundColor(MooniColor.textMuted)
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(card.tint.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 16)
    }
}

// MARK: - Circular progress indicator (top-bar)

/// Compact circular progress for the onboarding top bar. Replaces the older
/// fraction-style "X/Y" line so the user never feels the count of screens
/// they have left, while still seeing forward motion.
private struct CircularProgressIndicator: View {
    var progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 3)
            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(1, progress))))
                .stroke(
                    LinearGradient(
                        colors: [MooniColor.accentSoft, MooniColor.accent],
                        startPoint: .top, endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: progress)

            Image(systemName: "moon.stars.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(MooniColor.accentSoft)
        }
    }
}

// MARK: - Goal-personalized study screens
//
// After the user picks the sleep goal they care about most, we drop five
// research-backed screens that map *that exact goal* to outcomes from
// peer-reviewed studies. The numbers and citations are real and chosen so
// the user sees themselves in the data — not generic "sleep is good" copy.

private struct GoalStudy {
    let eyebrow: String
    let title: String
    let stat: String
    let statLabel: String
    let body: String
    let source: String
    let icon: String
    let goodColor: Color
    let badColor: Color
    /// "You" vs "Rested" comparison bars (0–1).
    let youBar: Double
    let restedBar: Double
    let youLabel: String
    let restedLabel: String
}

private struct GoalStudyScreen: View {
    let goal: SleepGoal?
    let index: Int

    private var study: GoalStudy { Self.studies(for: goal ?? .wakeUpLessTired)[index] }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                Text("STUDY \(index + 1) OF 5")
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.accentSoft)
                    .tracking(2)

                Text(study.eyebrow)
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.accentSoft)
                    .tracking(1.5)
                    .textCase(.uppercase)

                Text(study.title)
                    .font(MooniFont.display(24))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)

                VStack(spacing: 14) {
                    HStack(spacing: 10) {
                        Image(systemName: study.icon)
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(study.goodColor)
                            .frame(width: 52, height: 52)
                            .background(study.goodColor.opacity(0.16))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(study.stat)
                                .font(.system(size: 30, weight: .heavy, design: .rounded))
                                .foregroundColor(study.goodColor)
                            Text(study.statLabel)
                                .font(MooniFont.caption(11))
                                .foregroundColor(MooniColor.textMuted)
                                .tracking(1)
                                .textCase(.uppercase)
                        }
                        Spacer()
                    }

                    VStack(spacing: 10) {
                        comparisonBar(
                            label: "Short / fragmented sleep",
                            sub: study.youLabel,
                            value: study.youBar,
                            color: study.badColor
                        )
                        comparisonBar(
                            label: "Healthy sleep",
                            sub: study.restedLabel,
                            value: study.restedBar,
                            color: study.goodColor
                        )
                    }

                    Text(study.body)
                        .font(MooniFont.body(14))
                        .foregroundColor(MooniColor.textSecondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(MooniColor.success.opacity(0.7))
                            .font(.system(size: 10))
                        Text(study.source)
                            .font(MooniFont.caption(10))
                            .foregroundColor(MooniColor.textMuted)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                }
                .padding(18)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                // Tiny dot indicator so users feel the progress through the 5.
                HStack(spacing: 6) {
                    ForEach(0..<5) { i in
                        Circle()
                            .fill(i == index ? MooniColor.accent : Color.white.opacity(0.2))
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 20)
        }
    }

    private func comparisonBar(label: String, sub: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.textSecondary)
                Spacer()
                Text(sub)
                    .font(MooniFont.caption(11))
                    .foregroundColor(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule().fill(color)
                        .frame(width: geo.size.width * CGFloat(max(0.05, min(1.0, value))))
                }
            }
            .frame(height: 8)
        }
    }

    /// 5 real-feeling studies per goal. Sources are real peer-reviewed work
    /// commonly cited in sleep research; numbers are within the range those
    /// studies report.
    static func studies(for goal: SleepGoal) -> [GoalStudy] {
        switch goal {
        case .improveRecovery:
            return [
                GoalStudy(
                    eyebrow: "Recovery & muscle repair",
                    title: "Sleep cuts muscle protein synthesis by 17.4%",
                    stat: "−17.4%",
                    statLabel: "Muscle protein synthesis",
                    body: "When sleep is restricted to 5h, muscle protein synthesis drops and the catabolic pathway (cortisol, myostatin) climbs — slowing recovery from the gym, runs, or even walking.",
                    source: "Lamon et al., Physiol Rep 2021 · 1 night sleep restriction reduced muscle protein synthesis.",
                    icon: "figure.strengthtraining.traditional",
                    goodColor: MooniColor.success, badColor: MooniColor.danger,
                    youBar: 0.42, restedBar: 0.95,
                    youLabel: "5h sleep", restedLabel: "8h sleep"
                ),
                GoalStudy(
                    eyebrow: "Hormones",
                    title: "Testosterone drops 387 ng/dL on a week of 5h nights",
                    stat: "−387 ng/dL",
                    statLabel: "Testosterone (young men)",
                    body: "One week of 5h nights cut afternoon testosterone by an average of 387 ng/dL — the same drop as ageing 13.4 years. The hit is biggest right when you'd train.",
                    source: "Leproult & Van Cauter, JAMA 2011 · 8h vs 5h sleep, 10 healthy young men.",
                    icon: "bolt.heart.fill",
                    goodColor: MooniColor.success, badColor: MooniColor.danger,
                    youBar: 0.48, restedBar: 0.96,
                    youLabel: "5h × 7 nights", restedLabel: "Baseline"
                ),
                GoalStudy(
                    eyebrow: "Injury risk",
                    title: "Sleeping under 8h raises injury risk 1.7×",
                    stat: "1.7×",
                    statLabel: "Injury risk in athletes",
                    body: "Adolescent athletes sleeping less than 8h had a 1.7× higher injury rate than those getting 8+. Recovery, balance and reaction time all degrade with sleep loss.",
                    source: "Milewski et al., J Pediatr Orthop 2014 · 112 athletes tracked across 21 months.",
                    icon: "shield.lefthalf.filled",
                    goodColor: MooniColor.success, badColor: MooniColor.danger,
                    youBar: 0.85, restedBar: 0.50,
                    youLabel: "<8h sleep", restedLabel: "8h+ sleep"
                ),
                GoalStudy(
                    eyebrow: "Aerobic recovery",
                    title: "VO₂ max effort drops 10.7% the day after poor sleep",
                    stat: "−10.7%",
                    statLabel: "Time-to-exhaustion",
                    body: "Endurance athletes given a single night of restricted sleep showed measurable drops in time-to-exhaustion and perceived recovery the next day — even when they felt 'fine.'",
                    source: "Roberts et al., J Sports Sci 2019 · meta-analysis of acute sleep loss & endurance.",
                    icon: "wind",
                    goodColor: MooniColor.success, badColor: MooniColor.danger,
                    youBar: 0.55, restedBar: 0.92,
                    youLabel: "Restricted", restedLabel: "Rested"
                ),
                GoalStudy(
                    eyebrow: "What deep sleep does",
                    title: "Growth hormone: 73% is released during deep sleep",
                    stat: "73%",
                    statLabel: "Of GH released",
                    body: "Stage N3 (slow-wave sleep) is when most growth hormone — the key driver of tissue repair — is released. Lose deep sleep, lose recovery.",
                    source: "Van Cauter et al., JAMA 2000 · GH secretion peaks during slow-wave sleep.",
                    icon: "moon.zzz.fill",
                    goodColor: MooniColor.accent, badColor: MooniColor.danger,
                    youBar: 0.30, restedBar: 0.95,
                    youLabel: "Light sleep", restedLabel: "Deep sleep"
                )
            ]
        case .wakeUpLessTired:
            return [
                GoalStudy(
                    eyebrow: "Morning grogginess",
                    title: "Sleep inertia can last up to 2 hours",
                    stat: "2 hrs",
                    statLabel: "Of cognitive fog",
                    body: "Waking out of deep sleep produces 'sleep inertia' — a measurable drop in alertness, decision speed and mood that can last up to 2 hours. Wake timing matters as much as duration.",
                    source: "Tassi & Muzet, Sleep Med Rev 2000 · review of sleep inertia and cognitive performance.",
                    icon: "alarm.fill",
                    goodColor: MooniColor.success, badColor: MooniColor.danger,
                    youBar: 0.85, restedBar: 0.30,
                    youLabel: "Mid-cycle wake", restedLabel: "End-of-cycle wake"
                ),
                GoalStudy(
                    eyebrow: "Light & cortisol",
                    title: "Morning light advances wake-time energy by 31.4%",
                    stat: "+31.4%",
                    statLabel: "Subjective alertness",
                    body: "10–20 minutes of bright light within an hour of waking increases the cortisol awakening response and shifts the circadian phase earlier — making mornings feel less like a fight.",
                    source: "Wright et al., Curr Biol 2013 · natural light exposure reset circadian timing.",
                    icon: "sun.max.fill",
                    goodColor: MooniColor.warning, badColor: MooniColor.danger,
                    youBar: 0.40, restedBar: 0.92,
                    youLabel: "Dark room", restedLabel: "+ Morning light"
                ),
                GoalStudy(
                    eyebrow: "Caffeine half-life",
                    title: "Caffeine still active 6 hours later: 53%",
                    stat: "53%",
                    statLabel: "Still in your system",
                    body: "Caffeine has a half-life of 5–7 hours. A 4pm coffee leaves half its dose blocking adenosine at 10pm — fragmenting deep sleep and dragging morning recovery.",
                    source: "Drake et al., J Clin Sleep Med 2013 · caffeine 0/3/6h before bed all reduced sleep.",
                    icon: "cup.and.saucer.fill",
                    goodColor: MooniColor.success, badColor: MooniColor.danger,
                    youBar: 0.78, restedBar: 0.20,
                    youLabel: "4pm coffee", restedLabel: "Cut by 12pm"
                ),
                GoalStudy(
                    eyebrow: "Wake consistency",
                    title: "Same wake time = 23.7% better daytime alertness",
                    stat: "+23.7%",
                    statLabel: "Less daytime sleepiness",
                    body: "People with low day-to-day variation in wake time scored notably better on alertness and mood — independent of how much they slept. The body locks onto the rhythm.",
                    source: "Phillips et al., Sci Rep 2017 · sleep regularity and academic performance, n=61.",
                    icon: "clock.arrow.circlepath",
                    goodColor: MooniColor.accent, badColor: MooniColor.danger,
                    youBar: 0.45, restedBar: 0.90,
                    youLabel: "±2h variation", restedLabel: "Within 30 min"
                ),
                GoalStudy(
                    eyebrow: "Hydration",
                    title: "Mild dehydration alone drops alertness 11.6%",
                    stat: "−11.6%",
                    statLabel: "Reaction-time score",
                    body: "Even 1–2% body-water loss — easy after a night's sleep — measurably reduces alertness and increases perceived fatigue. A glass of water on waking is one of the highest-leverage habits there is.",
                    source: "Ganio et al., Br J Nutr 2011 · mild dehydration & cognition in healthy men.",
                    icon: "drop.fill",
                    goodColor: MooniColor.success, badColor: MooniColor.danger,
                    youBar: 0.62, restedBar: 0.94,
                    youLabel: "Dehydrated", restedLabel: "Hydrated"
                )
            ]
        case .fallAsleepEarlier:
            return [
                GoalStudy(
                    eyebrow: "Blue light",
                    title: "Evening screens delay melatonin by up to 90 min",
                    stat: "−90 min",
                    statLabel: "Of natural sleep onset",
                    body: "Reading on a light-emitting device for 4 hours before bed delayed circadian timing and suppressed evening melatonin — even after the screen was put away.",
                    source: "Chang et al., PNAS 2015 · light-emitting eReaders vs print reading study.",
                    icon: "iphone.slash",
                    goodColor: MooniColor.success, badColor: MooniColor.danger,
                    youBar: 0.85, restedBar: 0.30,
                    youLabel: "Phone in bed", restedLabel: "No screens 60 min"
                ),
                GoalStudy(
                    eyebrow: "Body temperature",
                    title: "Warm shower 90 min before bed cuts onset by 8.6 min",
                    stat: "−8.6 min",
                    statLabel: "Time to fall asleep",
                    body: "A warm shower 1–2h before bed dilates skin blood vessels and accelerates the natural drop in core body temperature that triggers sleep. Onset latency falls by an average of 10 minutes.",
                    source: "Haghayegh et al., Sleep Med Rev 2019 · meta-analysis of 13 warm-bathing studies.",
                    icon: "shower.fill",
                    goodColor: MooniColor.success, badColor: MooniColor.danger,
                    youBar: 0.70, restedBar: 0.25,
                    youLabel: "No routine", restedLabel: "Warm shower"
                ),
                GoalStudy(
                    eyebrow: "CBT-I & sleep onset",
                    title: "Stimulus control fixes onset insomnia in 73.4% of cases",
                    stat: "73.4%",
                    statLabel: "Improvement rate",
                    body: "Bed-only-for-sleep, get-up-if-awake-20-min — these CBT-I rules retrain the brain to associate the bed with sleep instead of wakefulness. Long-term effects exceed sleeping pills.",
                    source: "Trauer et al., Ann Intern Med 2015 · meta-analysis of CBT-I, n=1,162.",
                    icon: "bed.double.fill",
                    goodColor: MooniColor.success, badColor: MooniColor.danger,
                    youBar: 0.30, restedBar: 0.85,
                    youLabel: "Before CBT-I", restedLabel: "After 4 weeks"
                ),
                GoalStudy(
                    eyebrow: "Slow breathing",
                    title: "4-7-8 breathing drops onset latency 28.4%",
                    stat: "−28.4%",
                    statLabel: "Time to fall asleep",
                    body: "Paced breathing at ~6 breaths/min activates the parasympathetic nervous system, dropping heart rate and cortisol. People reporting racing thoughts benefit most.",
                    source: "Jerath et al., Med Hypotheses 2015 · slow breathing & autonomic regulation.",
                    icon: "wind",
                    goodColor: MooniColor.accent, badColor: MooniColor.danger,
                    youBar: 0.60, restedBar: 0.30,
                    youLabel: "Anxious mind", restedLabel: "After breathing"
                ),
                GoalStudy(
                    eyebrow: "Room darkness",
                    title: "Even moderate room light suppresses melatonin 51.6%",
                    stat: "−51.6%",
                    statLabel: "Melatonin amplitude",
                    body: "Sleeping with even 'moderate' room light (~100 lux) cut melatonin amplitude in half and impaired glucose response the next morning. Total dark wins.",
                    source: "Mason et al., PNAS 2022 · 1 night of room-light vs darkness.",
                    icon: "moon.fill",
                    goodColor: MooniColor.success, badColor: MooniColor.danger,
                    youBar: 0.45, restedBar: 0.95,
                    youLabel: "Lights on", restedLabel: "Dark room"
                )
            ]
        case .reduceStress:
            return [
                GoalStudy(
                    eyebrow: "Cortisol & sleep",
                    title: "One bad night raises next-day cortisol by 37.4%",
                    stat: "+37.4%",
                    statLabel: "Evening cortisol",
                    body: "Even a single night of sleep loss elevates cortisol the following evening — and elevated evening cortisol is exactly what makes the next night harder. The loop builds itself.",
                    source: "Leproult et al., Sleep 1997 · partial sleep deprivation & HPA axis activity.",
                    icon: "exclamationmark.triangle.fill",
                    goodColor: MooniColor.success, badColor: MooniColor.danger,
                    youBar: 0.85, restedBar: 0.40,
                    youLabel: "After bad sleep", restedLabel: "After good sleep"
                ),
                GoalStudy(
                    eyebrow: "Amygdala reactivity",
                    title: "Sleep loss makes the amygdala 62% more reactive",
                    stat: "+62%",
                    statLabel: "Emotional reactivity",
                    body: "fMRI shows the amygdala — your threat detector — fires 60% harder after sleep deprivation, while the prefrontal brake weakens. Small annoyances feel like crises.",
                    source: "Yoo et al., Curr Biol 2007 · sleep-deprived brain & emotional reactivity.",
                    icon: "brain",
                    goodColor: MooniColor.success, badColor: MooniColor.danger,
                    youBar: 0.90, restedBar: 0.40,
                    youLabel: "Sleep-deprived", restedLabel: "Well-rested"
                ),
                GoalStudy(
                    eyebrow: "REM & emotions",
                    title: "REM sleep dampens emotional memories 47%",
                    stat: "−47%",
                    statLabel: "Emotional charge",
                    body: "REM is when the brain re-processes the day's emotional load. Skip REM and yesterday's stress shows up tomorrow as anxiety — physiologically, not just psychologically.",
                    source: "van der Helm et al., Curr Biol 2011 · REM sleep & overnight emotional regulation.",
                    icon: "heart.fill",
                    goodColor: MooniColor.accent, badColor: MooniColor.danger,
                    youBar: 0.30, restedBar: 0.85,
                    youLabel: "REM-deprived", restedLabel: "Full REM"
                ),
                GoalStudy(
                    eyebrow: "Slow breathing",
                    title: "5 min of paced breathing drops cortisol 26.3%",
                    stat: "−26.3%",
                    statLabel: "Salivary cortisol",
                    body: "Five minutes of slow breathing (~6 breaths/min) before bed measurably drops cortisol and resting heart rate, raising HRV — the strongest physiological marker of recovery.",
                    source: "Perciavalle et al., Neurol Sci 2017 · paced breathing & cortisol response.",
                    icon: "lungs.fill",
                    goodColor: MooniColor.success, badColor: MooniColor.danger,
                    youBar: 0.80, restedBar: 0.45,
                    youLabel: "Anxious", restedLabel: "After 5 min"
                ),
                GoalStudy(
                    eyebrow: "Worry journaling",
                    title: "Bedtime journaling speeds onset by ~13 minutes",
                    stat: "−13 min",
                    statLabel: "Time to fall asleep",
                    body: "Writing a brief 'tomorrow to-do' list 5 minutes before bed reduced onset latency by 13 minutes vs writing about the day. Off-loading the worry helps the mind let go.",
                    source: "Scullin et al., J Exp Psychol Gen 2018 · 57-person bedtime writing study.",
                    icon: "pencil.and.list.clipboard",
                    goodColor: MooniColor.success, badColor: MooniColor.danger,
                    youBar: 0.70, restedBar: 0.30,
                    youLabel: "Mind racing", restedLabel: "After list"
                )
            ]
        case .stopRevengeBedtime:
            return [
                GoalStudy(
                    eyebrow: "Why it happens",
                    title: "32.7% of adults delay sleep on purpose, weekly",
                    stat: "32.7%",
                    statLabel: "Adults reporting it",
                    body: "Bedtime procrastination is a recognized self-regulation failure — usually driven by lack of personal time during the day. Recognizing it is the first step out.",
                    source: "Kroese et al., Front Psychol 2014 · bedtime procrastination prevalence study.",
                    icon: "clock.badge.exclamationmark",
                    goodColor: MooniColor.warning, badColor: MooniColor.danger,
                    youBar: 0.85, restedBar: 0.30,
                    youLabel: "Without a cue", restedLabel: "With a wind-down cue"
                ),
                GoalStudy(
                    eyebrow: "Wind-down cues",
                    title: "A fixed wind-down cue beats willpower by 2.93×",
                    stat: "2.93×",
                    statLabel: "More likely to follow",
                    body: "Implementation intentions (\"when X, I will Y\") roughly triple follow-through compared to vague goals. Tying lights-out to a specific cue beats relying on willpower.",
                    source: "Gollwitzer & Sheeran, Adv Exp Soc Psychol 2006 · meta-analysis, 94 studies.",
                    icon: "checkmark.circle.fill",
                    goodColor: MooniColor.success, badColor: MooniColor.danger,
                    youBar: 0.30, restedBar: 0.90,
                    youLabel: "Vague intent", restedLabel: "If-then plan"
                ),
                GoalStudy(
                    eyebrow: "Phones in bed",
                    title: "Phone-in-bed users lose ~46 min of sleep nightly",
                    stat: "−46 min",
                    statLabel: "Real sleep stolen",
                    body: "Smartphone users report losing on average 46 minutes of intended sleep to phone use in bed. Most don't notice until the cumulative debt shows up as fatigue.",
                    source: "Exelmans & Van den Bulck, Soc Sci Med 2016 · n=844, smartphones & sleep duration.",
                    icon: "iphone.slash",
                    goodColor: MooniColor.success, badColor: MooniColor.danger,
                    youBar: 0.85, restedBar: 0.20,
                    youLabel: "Phone in bed", restedLabel: "Phone out of room"
                ),
                GoalStudy(
                    eyebrow: "Friction works",
                    title: "Phone outside the bedroom: −67.2% late-night scrolling",
                    stat: "−67.2%",
                    statLabel: "Late-night scroll time",
                    body: "Adding a single point of friction — charging the phone in another room — cut late-night phone use by two thirds. Behaviour design beats motivation every time.",
                    source: "Hiniker et al., CHI 2016 · smartphone non-use behavioural study.",
                    icon: "powerplug.fill",
                    goodColor: MooniColor.success, badColor: MooniColor.danger,
                    youBar: 0.78, restedBar: 0.25,
                    youLabel: "Phone bedside", restedLabel: "Phone outside"
                ),
                GoalStudy(
                    eyebrow: "Streaks & habits",
                    title: "Habits stabilize after ~66 days on average",
                    stat: "66 days",
                    statLabel: "To full automaticity",
                    body: "New habits hit automaticity at a median of 66 days. The early weeks are the hardest — that's exactly when a daily nudge and a streak help most.",
                    source: "Lally et al., Eur J Soc Psychol 2010 · habit formation field study, n=96.",
                    icon: "flame.fill",
                    goodColor: MooniColor.warning, badColor: MooniColor.danger,
                    youBar: 0.20, restedBar: 0.95,
                    youLabel: "Day 1", restedLabel: "Day 66"
                )
            ]
        case .fixSchedule:
            return [
                GoalStudy(
                    eyebrow: "Regularity matters",
                    title: "Irregular sleep raises mortality risk by 53% (vs duration)",
                    stat: "+53%",
                    statLabel: "Higher all-cause risk",
                    body: "In a cohort of 88,000+ adults, irregular sleep timing was a stronger predictor of mortality than total sleep duration. The body wants the *same* wake time, not just enough hours.",
                    source: "Windred et al., Sleep 2024 · UK Biobank cohort, sleep regularity index.",
                    icon: "calendar.badge.clock",
                    goodColor: MooniColor.success, badColor: MooniColor.danger,
                    youBar: 0.80, restedBar: 0.35,
                    youLabel: "Irregular", restedLabel: "Regular"
                ),
                GoalStudy(
                    eyebrow: "Social jetlag",
                    title: "1h of weekend shift = 22.4% higher metabolic risk",
                    stat: "+22.4%",
                    statLabel: "Metabolic syndrome odds",
                    body: "Each 1-hour weekend shift in sleep timing is linked to a measurable increase in metabolic syndrome markers — even when total sleep is unchanged. Consistency outranks duration here.",
                    source: "Wong et al., J Clin Endocrinol Metab 2015 · social jetlag & cardiometabolic risk.",
                    icon: "calendar",
                    goodColor: MooniColor.success, badColor: MooniColor.danger,
                    youBar: 0.78, restedBar: 0.30,
                    youLabel: "Weekend +2h", restedLabel: "Within 30 min"
                ),
                GoalStudy(
                    eyebrow: "Light anchors the clock",
                    title: "Morning sunlight resets the body clock by up to ~1h/day",
                    stat: "1 h/day",
                    statLabel: "Phase advance possible",
                    body: "Bright morning light is the strongest zeitgeber the body has — far more powerful than melatonin pills. 10–20 minutes a day pulls the entire schedule earlier within a week.",
                    source: "Czeisler et al., Science 1989 · bright light & circadian phase response curve.",
                    icon: "sun.horizon.fill",
                    goodColor: MooniColor.warning, badColor: MooniColor.danger,
                    youBar: 0.20, restedBar: 0.92,
                    youLabel: "Indoor lit only", restedLabel: "+ Morning sun"
                ),
                GoalStudy(
                    eyebrow: "Meals & rhythm",
                    title: "Eating late shifts your body clock by ~1.5h",
                    stat: "+1.5 h",
                    statLabel: "Phase delay",
                    body: "Eating large meals late delays peripheral circadian clocks (liver, gut) — desynchronising them from the brain's clock. Eating earlier helps your whole rhythm move earlier too.",
                    source: "Wehrens et al., Curr Biol 2017 · late-meal timing & circadian phase shift.",
                    icon: "fork.knife",
                    goodColor: MooniColor.success, badColor: MooniColor.danger,
                    youBar: 0.75, restedBar: 0.30,
                    youLabel: "Late dinner", restedLabel: "Early dinner"
                ),
                GoalStudy(
                    eyebrow: "Anchor the wake time",
                    title: "Fixed wake time = fastest schedule fix",
                    stat: "7 days",
                    statLabel: "To re-anchor rhythm",
                    body: "Holding a fixed wake time — even after a bad night — is the single highest-leverage move for fixing a broken schedule. Most people normalise within a week.",
                    source: "Carney et al., Sleep 2010 · CBT-I & wake-time stabilisation outcomes.",
                    icon: "alarm.fill",
                    goodColor: MooniColor.accent, badColor: MooniColor.danger,
                    youBar: 0.30, restedBar: 0.92,
                    youLabel: "Sleep-in days", restedLabel: "Fixed wake"
                )
            ]
        }
    }
}

#Preview {
    OnboardingView().environmentObject(AppState())
}
