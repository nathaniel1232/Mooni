import SwiftUI
import UIKit
import Combine
import AuthenticationServices

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
    @StateObject private var notifications = NotificationManager.shared

    // MARK: - Wizard state
    @State private var step: Step = .welcome
    @State private var transitionDirection: TransitionDirection = .forward

    // Pet
    @State private var species: PetSpecies = .owl
    @State private var petName: String = PetSpecies.owl.defaultName

    // Goal & schedule
    @State private var sleepGoal: SleepGoal? = nil
    @State private var selectedGoals: Set<SleepGoal> = []
    @State private var selBlockers: Set<OnboardingProfile.SleepBlocker> = []
    @State private var selImpacts: Set<OnboardingProfile.SleepImpact> = []
    @State private var selTried: Set<OnboardingProfile.TriedBefore> = []
    @State private var selWindDown: Set<OnboardingProfile.WindDownPref> = []
    // Becomes true once the user taps "Leave a rating" and the App Store
    // prompt is shown — only then do we reveal the "I rated it" link.
    @State private var ratePromptShown = false
    @State private var bedtime: Date = Date.todayAt(hour: 22, minute: 45)
    @State private var wakeTime: Date = Date.todayAt(hour: 7, minute: 0)
    @State private var weekendWake: Date = Date.todayAt(hour: 8, minute: 30)
    @State private var separateWeekends: Bool = false

    // Room
    @State private var room: PetRoom = .moonBedroom

    // Onboarding profile (the new personalization data)
    @State private var profile: OnboardingProfile = OnboardingProfile()

    // Loading screen state — drives planComputing's main ring + sub-bars.
    @State private var analyzingProgress: Double = 0
    @State private var analyzingStep: Int = 0

    // TrackingCompareScreen sets this true once its play() animation finishes;
    // it gates the footer Continue so the user can't skip past the reveal.
    @State private var trackingCompareDone: Bool = false

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
        // ─ Hook ───────────────────────────────────────────────────────────
        case welcome

        // The sequence alternates short question batches (3-4 max) with a
        // visual/story beat so the quiz never feels like an endless form.

        // ─ Warmup questions (3) ───────────────────────────────────────────
        case ageQuestion
        case genderQuestion
        case typicalSleepHours

        // ─ Pet beat — meet & name the companion ───────────────────────────
        case namePet

        // ─ Identity questions, part 1 (3) ─────────────────────────────────
        case wakeFeeling
        case racingThoughts
        case phoneBeforeBed

        // ─ Visual beat — manual journal vs the SleepOwl report ────────────
        case trackingCompare

        // ─ Identity questions, part 2 (4) ─────────────────────────────────
        case caffeineCutoff
        case stressLevel
        case struggleDuration
        case biggestProblem

        // ─ Visual beat — your phone already tracks it ─────────────────────
        case targetReachable

        // ─ Schedule + goal commitment ─────────────────────────────────────
        // Goal is split across two screens so each row can be full-sized +
        // readable instead of cramming all 6 options into a single screen.
        case schedule
        case sleepGoal
        case sleepGoalMore

        // ─ Visual payoff — the 4-week turnaround for the goal they just set
        case lifeTimeline

        // ─ Personalize questions, part 1 (2) ──────────────────────────────
        case personalizeGoals
        case personalizeBlockers

        // ─ Visual beat — what we score every night ────────────────────────
        case sleepMetricsTease

        // ─ Personalize questions, part 2 (2) ──────────────────────────────
        case personalizeTried
        case personalizeWindDown

        // ─ In-app "Allow notifications" mock that triggers the real prompt ─
        case notifAllowMock

        // ─ Rating (no skip — only path forward is "I rated it") ───────────
        case ratingPledge

        // ─ Sign in ────────────────────────────────────────────────────────
        case signIn

        // ─ "You're ready" emotional beat ──────────────────────────────────
        case commitReady

        // ─ 12-second layered loading ──────────────────────────────────────
        case planComputing

        // ─ Personalized plan reveal — previews real home analytics UI ─────
        case planReveal

        // ─ Widget showcase (Small + Medium) ───────────────────────────────
        case widgetSmall
        case widgetMedium

        // ─ Auto-tracking pitch (3) ────────────────────────────────────────
        case autoTrackStoneAge
        case autoTrackHow
        case autoTrackAccuracy

        // ─ Signature pledge ceremony ──────────────────────────────────────
        case signaturePledge

        // ─ Paywall (terminal) ─────────────────────────────────────────────
        case prePaywall

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
            StarsBackground(count: 28)
            ShootingStarsOverlay()

            if step == .prePaywall {
                // Terminal step: open the real paywall sheet directly, skipping
                // the 3-stage emotional pre-paywall. Keeps onboarding short for
                // App Store review (Guideline 4.0).
                Color.clear
                    .onAppear {
                        if paywallSheet == nil {
                            paywallSheet = .main
                        }
                    }
            } else {
                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, 20)
                        .padding(.top, 14)

                    // ONE consistent rule for every screen: the content block
                    // is vertically CENTERED in the band between the progress
                    // bar and the footer, with symmetric padding. This is what
                    // keeps all ~79 screens aligned the same way regardless of
                    // whether a given screen uses its own Spacers internally —
                    // nothing sits "too high" or "too low" anymore. Content
                    // taller than the band still scrolls naturally.
                    GeometryReader { geo in
                        ScrollView(showsIndicators: false) {
                            content
                                .padding(.top, 4)
                                .padding(.bottom, 56)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: geo.size.height,
                                       alignment: contentVerticalAlignment)
                                .id(step)
                                .transition(transition)
                        }
                        .scrollDismissesKeyboard(.interactively)
                    }

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
                // iPad: cap the content column so the iPhone-shaped layout
                // doesn't stretch to absurd widths. iPhone is unaffected.
                .responsiveContainer()
                .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(item: $paywallSheet) { stage in
            switch stage {
            case .main:
                PaywallView(
                    hideCloseButton: false,
                    onSoftDismiss: {
                        // Guideline 5.6 fix: dismissing the paywall goes straight
                        // to the app — no automatic second/discount paywall.
                        // Finish onboarding immediately so the underlying
                        // Color.clear placeholder never becomes visible (would
                        // otherwise flash blank during the dismiss animation).
                        paywallSheet = nil
                        finishOnboarding()
                    },
                    onPurchased: {
                        paywallSheet = nil
                        finishOnboarding()
                    },
                    // Offerings failed to load — finish onboarding so the
                    // user (or App Review) can actually use the app.
                    onErrorContinue: {
                        paywallSheet = nil
                        finishOnboarding()
                    }
                )
            case .discount:
                // Discount paywall is kept in code but no longer auto-triggered
                // after dismissal (removed to comply with Guideline 5.6).
                // Kept here to avoid compiler errors; this case is never reached.
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
        // Bridges from screens that own their own primary action (the in-app
        // notification "Allow" mock, and the signature-pledge hold button).
        .onReceive(NotificationCenter.default
            .publisher(for: .onboardingNotifAllowTapped)) { _ in
            if step == .notifAllowMock { advance() }
        }
        .onReceive(NotificationCenter.default
            .publisher(for: .onboardingSignatureCommitted)) { _ in
            if step == .signaturePledge { advance() }
        }
        // Defensive: if the paywall cover dismisses for ANY reason while we're
        // still on the terminal prePaywall step (X tap, OS gesture, etc.) and
        // onboarding hasn't completed, finish it. The Color.clear placeholder
        // under the paywall would otherwise leave the user on a blank screen
        // with no way forward.
        .onChange(of: paywallSheet) { _, newValue in
            if newValue == nil
                && step == .prePaywall
                && !appState.hasCompletedOnboarding {
                finishOnboarding()
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
            backChevron
            linearProgressBar
            skipButton
        }
        .frame(height: 28)
    }

    /// Screens where a small "Skip" link sits opposite the back chevron. Used
    /// for non-essential beats so the user is never trapped on a slide they
    /// don't want to engage with — keeps the App Store reviewer (and impatient
    /// users) happy without removing the screens entirely.
    private var skippableSteps: Set<Step> {
        [.lifeTimeline,
         .trackingCompare,
         .targetReachable,
         .sleepMetricsTease,
         .ratingPledge,
         .commitReady,
         .widgetSmall,
         .widgetMedium,
         .autoTrackStoneAge,
         .autoTrackHow,
         .autoTrackAccuracy,
         .signaturePledge]
    }

    @ViewBuilder
    private var skipButton: some View {
        if skippableSteps.contains(step) {
            Button {
                advance()
            } label: {
                Text("Skip")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
                    .frame(height: 28)
                    .padding(.horizontal, 6)
                    .contentShape(Rectangle())
            }
            .transition(.opacity)
        } else {
            Color.clear.frame(width: 28, height: 28)
        }
    }

    @ViewBuilder
    private var backChevron: some View {
        if step.index > 0 && !isLoadingScreen {
            Button {
                goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .transition(.opacity)
        } else {
            // Reserve space so the bar position never jumps between screens.
            Color.clear.frame(width: 28, height: 28)
        }
    }

    private var linearProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.16))
                Capsule()
                    .fill(Color.white)
                    .frame(width: geo.size.width * CGFloat(progressFraction))
                    .animation(.easeInOut(duration: 0.35), value: progressFraction)
            }
        }
        .frame(height: 4)
    }

    /// Linear progress 0–1 across the *known* sequence. Capped just below 1
    /// during normal flow so the circle keeps gaining as the user advances
    /// instead of slamming to 100% one screen early.
    private var progressFraction: Double {
        let total = max(1, Step.total - 1)
        return min(0.985, Double(step.index) / Double(total))
    }

    private var isLoadingScreen: Bool {
        step == .planComputing
    }

    /// Welcome and sign-in are presented as fullscreen-ish moments without the
    /// onboarding chrome (no progress bar, no back button) so the user feels
    /// like they're at a real entry/exit gate rather than mid-quiz.
    private var hidesProgressChrome: Bool {
        step == .welcome
    }

    /// Question screens (a prompt + answer controls) pin to the TOP of the
    /// content band so the title lands right under the progress bar — top-left,
    /// next to the back chevron — instead of floating in the vertical centre.
    /// Story / hero / reveal beats stay centred.
    private var topAlignedSteps: Set<Step> {
        [.ageQuestion, .genderQuestion, .typicalSleepHours,
         .wakeFeeling, .racingThoughts, .phoneBeforeBed, .caffeineCutoff,
         .stressLevel, .struggleDuration, .biggestProblem, .schedule,
         .sleepGoal, .sleepGoalMore,
         .personalizeGoals, .personalizeBlockers, .personalizeTried,
         .personalizeWindDown]
    }

    private var contentVerticalAlignment: Alignment {
        topAlignedSteps.contains(step) ? .top : .center
    }


    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:              WelcomeScreen()
        case .ageQuestion:          AgeScreen(profile: $profile)
        case .genderQuestion:       GenderScreen(profile: $profile)
        case .typicalSleepHours:    TypicalSleepHoursScreen(profile: $profile)
        case .lifeTimeline:         LifeTimelineScreen()
        case .namePet:              NamePetScreen(species: species, name: $petName)
        case .wakeFeeling:          WakeFeelingScreen(profile: $profile)
        case .racingThoughts:       RacingThoughtsScreen(profile: $profile, petName: petName)
        case .phoneBeforeBed:       PhoneBeforeBedScreen(profile: $profile)
        case .caffeineCutoff:       CaffeineCutoffScreen(profile: $profile)
        case .stressLevel:          StressLevelScreen(profile: $profile)
        case .struggleDuration:     StruggleDurationScreen(profile: $profile)
        case .biggestProblem:       BiggestProblemScreen(profile: $profile)
        case .schedule:             ScheduleScreen(bedtime: $bedtime, wakeTime: $wakeTime,
                                                   separateWeekends: $separateWeekends, weekendWake: $weekendWake)
        case .trackingCompare:      TrackingCompareScreen(animationDone: $trackingCompareDone)
        case .personalizeGoals:     GoalsMultiScreen(selection: $selectedGoals)
        case .personalizeBlockers:
            MultiSelectScreen(
                title: "What keeps you from good sleep?",
                subtitle: blockersSubtitle,
                options: OnboardingProfile.SleepBlocker.allCases.map {
                    ($0, $0.label, $0.icon)
                },
                selection: $selBlockers)
        case .personalizeTried:
            MultiSelectScreen(
                title: "What have you already tried?",
                subtitle: "So we don't hand you the same advice that didn't work.",
                options: OnboardingProfile.TriedBefore.allCases.map {
                    ($0, $0.label, $0.icon)
                },
                selection: $selTried)
        case .personalizeWindDown:
            MultiSelectScreen(
                title: "What helps you relax?",
                subtitle: "Your wind-down routine will be built from these.",
                options: OnboardingProfile.WindDownPref.allCases.map {
                    ($0, $0.label, $0.icon)
                },
                selection: $selWindDown)
        case .sleepGoal:            GoalScreen(selection: $sleepGoal, page: 0,
                                                onAdvance: { advance() })
        case .sleepGoalMore:        GoalScreen(selection: $sleepGoal, page: 1,
                                                onAdvance: { advance() })
        case .targetReachable:      TargetReachableScreen(sleepGoal: sleepGoal)
        case .sleepMetricsTease:    SleepMetricsTeaseScreen()
        case .notifAllowMock:       NotifAllowMockScreen(petName: petName,
                                                         state: notifications.authState)
        case .ratingPledge:         RatingPledgeScreen(promptShown: $ratePromptShown)
        case .signIn:               SignInScreen(state: authState, errorMessage: authErrorMessage)
        case .commitReady:          CommitReadyScreen(petName: petName)
        case .planComputing:
            PlanComputingScreen(progress: $analyzingProgress, currentStep: $analyzingStep)
                .onAppear { runAnalyzingAnimation() }
        case .planReveal:
            PlanRevealScreen(
                profile: profile,
                bedtime: bedtime,
                wakeTime: wakeTime,
                petName: petName)
        case .widgetSmall:          WidgetShowcaseScreen(kind: .small)
        case .widgetMedium:         WidgetShowcaseScreen(kind: .medium)
        case .autoTrackStoneAge:    AutoTrackStoneAgeScreen()
        case .autoTrackHow:         AutoTrackHowScreen()
        case .autoTrackAccuracy:    AutoTrackPhoneOnlyScreen()
        case .signaturePledge:      SignaturePledgeScreen(petName: petName)
        case .prePaywall:           EmptyView()    // rendered full-screen above; never reaches here
        }
    }

    // MARK: - Footer

    private var footer: some View {
        Group {
            switch step {
            case .welcome:
                VStack(spacing: 10) {
                    PrimaryButton(title: "Get Started", variant: .white) {
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
                        Text("Already have an account?")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(MooniColor.textMuted.opacity(0.7))
                            .padding(.vertical, 2)
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
                        icon: authState == .signedIn ? "checkmark.seal.fill" : "applelogo",
                        variant: .white
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
                    SecondaryButton(title: "Continue without an account",
                                    variant: .capsule) {
                        authState = .skipped
                        advance()
                    }
                    Text("Used to back up your sleep history and unlock shared widgets later.")
                        .font(MooniFont.caption(11))
                        .foregroundColor(MooniColor.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
            case .ratingPledge:
                // No skip. Big button opens the App Store sheet; "I rated it"
                // appears 2.5 s after the tap — long enough that users can't
                // dismiss and bounce instantly, short enough not to feel stuck.
                VStack(spacing: 14) {
                    PrimaryButton(title: "Leave a rating", icon: "star.fill", variant: .white) {
                        OnboardingRatingPrompt.request()
                        // Surface "I rated it" quickly so users aren't stuck
                        // staring at the screen wondering what's next.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                ratePromptShown = true
                            }
                        }
                    }
                    if ratePromptShown {
                        Button {
                            advance()
                        } label: {
                            Text("I rated it")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .underline()
                                .foregroundColor(.white.opacity(0.85))
                                .padding(.vertical, 6)
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
            case .notifAllowMock, .signaturePledge:
                // No footer — these screens own their own primary action
                // (faux Allow tap / hold-to-commit signature). They post a
                // NotificationCenter event when the user completes the
                // action, and the OnboardingView listener advances.
                EmptyView()
            case .planComputing, .prePaywall:
                EmptyView()
            default:
                PrimaryButton(title: primaryTitle, variant: .white) { advance() }
                    .disabled(!canAdvance)
                    .opacity(canAdvance ? 1 : 0.55)
            }
        }
    }

    private var primaryTitle: String {
        switch step {
        case .welcome:             return "Get Started"
        case .ageQuestion:         return profile.age == nil ? "Pick an age" : "Continue"
        case .genderQuestion:      return "Continue"
        case .typicalSleepHours:   return "Continue"
        case .lifeTimeline:        return "Show me how"
        case .namePet:             return petName.trimmingCharacters(in: .whitespaces).isEmpty
            ? "Give them a name"
            : "Continue"
        case .wakeFeeling:         return profile.wakeFeeling == nil ? "Pick one to continue" : "Continue"
        case .racingThoughts:      return "Continue"
        case .phoneBeforeBed:      return "Continue"
        case .caffeineCutoff:      return profile.caffeineCutoff == nil ? "Pick one to continue" : "Continue"
        case .stressLevel:         return "Continue"
        case .struggleDuration:    return profile.struggleDuration == nil ? "Pick one to continue" : "Continue"
        case .biggestProblem:      return profile.biggestProblem == nil ? "Pick one to continue" : "Continue"
        case .schedule:            return "Continue"
        case .trackingCompare:     return "I want this"
        case .targetReachable:     return "Continue"
        case .personalizeGoals:    return selectedGoals.isEmpty ? "Pick at least one" : "Continue"
        case .personalizeBlockers: return selBlockers.isEmpty ? "Pick at least one" : "Continue"
        case .personalizeTried:    return selTried.isEmpty ? "Pick at least one" : "Continue"
        case .personalizeWindDown: return selWindDown.isEmpty ? "Pick at least one" : "Continue"
        case .sleepGoal:           return sleepGoal == nil ? "Pick one to continue" : "Set my goal"
        case .sleepMetricsTease:   return "Show me my plan"
        case .signIn:              return "Sign in with Apple"
        case .commitReady:         return "I'm in"
        case .planReveal:          return "See my widgets"
        case .widgetSmall:         return "Next widget"
        case .widgetMedium:        return "Got it"
        case .autoTrackStoneAge:   return "Tell me how"
        case .autoTrackHow:        return "How accurate?"
        case .autoTrackAccuracy:   return "Got it"
        case .signaturePledge:     return "Make it official"
        default:                   return "Continue"
        }
    }

    private var canAdvance: Bool {
        switch step {
        case .namePet:             return !petName.trimmingCharacters(in: .whitespaces).isEmpty
        case .ageQuestion:         return profile.age != nil
        case .personalizeGoals:    return !selectedGoals.isEmpty
        case .personalizeBlockers: return !selBlockers.isEmpty
        case .personalizeTried:    return !selTried.isEmpty
        case .personalizeWindDown: return !selWindDown.isEmpty
        case .sleepGoal:           return sleepGoal != nil
        case .sleepGoalMore:       return sleepGoal != nil
        case .trackingCompare:     return trackingCompareDone
        case .struggleDuration:    return profile.struggleDuration != nil
        case .biggestProblem:      return profile.biggestProblem != nil
        case .phoneBeforeBed:      return profile.usesPhoneBeforeBed != nil
        case .caffeineCutoff:      return profile.caffeineCutoff != nil
        case .racingThoughts:      return profile.racingThoughtsAtNight != nil
        case .wakeFeeling:         return profile.wakeFeeling != nil
        default:                   return true
        }
    }

    // MARK: - Navigation

    private func advance() {
        Haptics.medium()
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

    /// Reserved for future conditional question chains (e.g. "did you say
    /// you drink caffeine? then ask cutoff"). For the current flow every
    /// step is shown — the new Step enum is already the visible sequence,
    /// not a superset.
    private func shouldSkip(_ s: Step) -> Bool {
        false
    }

    // MARK: - Loading animations
    //
    // The bar crawls *smoothly* through every percentage point rather than
    // teleporting between scripted targets. Each phase below interpolates
    // linearly from the previous phase's end to its own target over the
    // listed duration — so 1 → 100 advances 1, 2, 3, 4… instead of the old
    // 1 → 12 → 25 → 38 stepping. Believable variance comes from the phases
    // themselves having different speeds (fewer percentage points per second
    // during the "hard" beats like chronotype + debt calculation).

    /// (progressTarget, secondsToReachItFromPrevious) per phase.
    private static let analyzingScript: [(Double, Double)] = [
        (0.10, 1.2),   // reading answers
        (0.22, 1.5),   // mapping chronotype  (slow)
        (0.36, 1.3),
        (0.50, 1.7),   // calculating debt    (slow)
        (0.62, 1.2),
        (0.74, 1.4),   // identifying issues
        (0.84, 1.1),
        (0.93, 1.2),
        (1.00, 0.8)
    ]

    @State private var analyzingTimer: Timer? = nil

    private func runAnalyzingAnimation() {
        analyzingTimer?.invalidate()
        analyzingTimer = nil
        analyzingProgress = 0
        analyzingStep = 0
        runScriptSmooth(
            Self.analyzingScript,
            progress: { v in analyzingProgress = v },
            stepIndex: { i in analyzingStep = i },
            messageGroups: PlanComputingScreen.stepBoundaries,
            timerSink: { analyzingTimer = $0 },
            onDone: { advance() }
        )
    }

    /// Timer-driven smooth driver. Maintains a running `elapsed`, figures
    /// out the active phase, applies a *per-phase easing curve* (so the bar
    /// crawls slowly into a phase, then accelerates out, or vice versa)
    /// AND a small per-tick jitter so the rate visibly fluctuates instead
    /// of feeling like a fake fixed-rate progress bar.
    private func runScriptSmooth(
        _ script: [(Double, Double)],
        progress: @escaping (Double) -> Void,
        stepIndex: @escaping (Int) -> Void,
        messageGroups: [Int],
        timerSink: @escaping (Timer?) -> Void,
        onDone: @escaping () -> Void
    ) {
        // Cumulative end-time per phase.
        var phaseEnds: [Double] = []
        var acc: Double = 0
        for entry in script {
            acc += entry.1
            phaseEnds.append(acc)
        }
        let total = acc

        // Tick interval. 60ms ≈ 16 ticks/s — visibly continuous on screen.
        let interval: TimeInterval = 0.06
        let start = Date()
        var lastPhase = -1
        // Carries the previous rendered progress so the bar never goes backward
        // when jitter would otherwise pull it down a hair.
        var lastValue: Double = 0

        // Easing per phase — alternates so consecutive phases feel different.
        // Index into this with `phase % easingCurves.count`.
        let easingCurves: [(Double) -> Double] = [
            { t in t * t },                              // easeIn — slow start
            { t in 1 - (1 - t) * (1 - t) },              // easeOut — slow finish
            { t in t < 0.5
                ? 2 * t * t
                : 1 - pow(-2 * t + 2, 2) / 2 },          // easeInOut
            { t in 1 - pow(1 - t, 3) }                   // easeOut cubic
        ]

        let timer = Timer.scheduledTimer(withTimeInterval: interval,
                                         repeats: true) { t in
            let elapsed = Date().timeIntervalSince(start)
            if elapsed >= total {
                progress(1.0)
                if let lastMsg = messageGroups.indices.last {
                    stepIndex(lastMsg)
                }
                t.invalidate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    onDone()
                }
                return
            }

            // Find the current phase.
            var phase = 0
            while phase < phaseEnds.count && elapsed > phaseEnds[phase] {
                phase += 1
            }
            let phaseStartTime = phase == 0 ? 0 : phaseEnds[phase - 1]
            let phaseStartProg = phase == 0 ? 0 : script[phase - 1].0
            let phaseEndProg   = script[phase].0
            let phaseDur       = phaseEnds[phase] - phaseStartTime
            let localT         = phaseDur > 0
                ? (elapsed - phaseStartTime) / phaseDur
                : 1.0

            let curve = easingCurves[phase % easingCurves.count]
            let eased = curve(min(max(localT, 0), 1))
            let target = phaseStartProg + (phaseEndProg - phaseStartProg) * eased

            // Per-tick jitter — ±15% of the *increment* since last tick.
            // Keeps the bar moving organically: sometimes a small wobble, but
            // never backward, never past the eased target.
            let nominalDelta = target - lastValue
            let jitter = Double.random(in: -0.15...0.15) * nominalDelta
            let candidate = lastValue + nominalDelta + jitter
            let value = max(lastValue, min(candidate, target + 0.005))
            lastValue = value
            progress(value)

            if phase != lastPhase {
                lastPhase = phase
                if let msgIdx = messageGroups.firstIndex(of: phase) {
                    stepIndex(msgIdx)
                }
            }
        }
        timerSink(timer)
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
            // Tapping "Cancel" on the Apple sheet throws ASAuthorizationError
            // .canceled (and sometimes .unknown). That's a deliberate user
            // action, not a failure — surfacing "The operation couldn't be
            // completed… error 1001" inside the UI looks broken. Stay silent
            // and just let them keep going.
            if Self.isUserCancellation(error) {
                return false
            }
            authErrorMessage = error.localizedDescription
            authState = .failed
            return false
        }
    }

    /// True when the error is the user backing out of the Apple sign-in sheet
    /// rather than a real authentication failure worth showing.
    private static func isUserCancellation(_ error: Error) -> Bool {
        if let authError = error as? ASAuthorizationError {
            return authError.code == .canceled || authError.code == .unknown
        }
        let ns = error as NSError
        return ns.domain == ASAuthorizationError.errorDomain
            && (ns.code == ASAuthorizationError.canceled.rawValue
                || ns.code == ASAuthorizationError.unknown.rawValue)
    }

    /// Selected goals in stable enum order (so the payoff screen lists them
    /// consistently rather than in Set iteration order).
    private var orderedSelectedGoals: [SleepGoal] {
        SleepGoal.allCases.filter { selectedGoals.contains($0) }
    }

    /// What the "Building your plan" reveal lists back to the user. Pulls from
    /// EVERY answered category — not just the goal subset — so the user sees a
    /// handful of the things they actually told us and feels heard. Capped so
    /// it stays a curated 3–4, never a single lonely line or a giant dump.
    private var revealItems: [(icon: String, title: String)] {
        var items: [(String, String)] = []
        for g in orderedSelectedGoals { items.append((g.icon, g.title)) }
        for b in OnboardingProfile.SleepBlocker.allCases where selBlockers.contains(b) {
            items.append((b.icon, b.label))
        }
        for i in OnboardingProfile.SleepImpact.allCases where selImpacts.contains(i) {
            items.append((i.icon, i.label))
        }
        for w in OnboardingProfile.WindDownPref.allCases where selWindDown.contains(w) {
            items.append((w.icon, w.label))
        }
        for t in OnboardingProfile.TriedBefore.allCases where selTried.contains(t) {
            items.append((t.icon, t.label))
        }
        // De-dupe by title, keep first occurrence, cap at 4.
        var seen = Set<String>()
        let unique = items.filter { seen.insert($0.1).inserted }
        return Array(unique.prefix(4)).map { (icon: $0.0, title: $0.1) }
    }

    /// Lightly tailored to what the user already told us earlier in the flow.
    private var blockersSubtitle: String {
        if profile.racingThoughtsAtNight == true {
            return "You mentioned a racing mind at night — what else gets in the way? Pick all that apply."
        }
        if profile.usesPhoneBeforeBed == true {
            return "Late-night scrolling adds up — what else gets in the way? Pick all that apply."
        }
        return "Pick everything that gets in the way — the more honest, the better."
    }

    private func finishOnboarding() {
        profile.selectedGoals = SleepGoal.allCases.filter { selectedGoals.contains($0) }
        profile.sleepBlockers = OnboardingProfile.SleepBlocker.allCases.filter { selBlockers.contains($0) }
        profile.sleepImpacts = OnboardingProfile.SleepImpact.allCases.filter { selImpacts.contains($0) }
        profile.triedBefore = OnboardingProfile.TriedBefore.allCases.filter { selTried.contains($0) }
        profile.windDownPrefs = OnboardingProfile.WindDownPref.allCases.filter { selWindDown.contains($0) }
        appState.completeOnboarding(
            species: species,
            name: petName,
            goal: sleepGoal ?? selectedGoals.first ?? .wakeUpLessTired,
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
    /// Kept on the API so existing call sites compile without edits — but the
    /// inline expert/research chip is no longer rendered. The "fun fact" lives
    /// in its own dedicated screen (BodyStudiesScreen) where it has room to
    /// breathe with a real visual.
    var expert: ExpertNote? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        // Question screens read top-left: the title lands a small, constant
        // distance under the progress bar, and the answer controls float in
        // the band between the title and the footer (the two Spacers split
        // the leftover space). This kills both old complaints at once: no
        // big dead gap pushing the title down, and no giant empty hole
        // between short answer sets and the Continue button. The parent's
        // `.frame(minHeight: geo.size.height)` is what lets these Spacers
        // actually stretch; content taller than the band still scrolls.
        VStack(spacing: 0) {
            QuestionHeader(title: title, subtitle: subtitle)
            Spacer(minLength: 26)
            content()
            Spacer(minLength: 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 14)
        .onboardingEdge()
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
                    EmojiIcon(emoji: emoji, size: 20,
                              tint: isSelected ? MooniColor.accent : MooniColor.accentSoft)
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

/// Opening emotional hook — one tired pet image, one bold line. That's it.
/// Lighter than the original: no 3-line headline + dense subhead — let the
/// pet do the emotional work, follow with one direct sentence.
private struct HeroScreen: View {
    let species: PetSpecies
    @State private var dim = false
    @State private var fadeIn = false

    var body: some View {
        VStack(spacing: 26) {
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [Color.black.opacity(0.5), .clear],
                        center: .center, startRadius: 4, endRadius: 200))
                    .frame(width: 300, height: 300)

                DreamSpiritView(pet: tiredPet, size: 178)
                    .saturation(0.55)
                    .opacity(dim ? 0.75 : 0.95)
                    .animation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true), value: dim)

                Text("z z Z")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(OnboardingLayout.accent.opacity(0.7))
                    .offset(x: 62, y: -82)
                    .opacity(dim ? 0.85 : 0.4)
                    .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: dim)
            }
            .onAppear {
                dim = true
                withAnimation(.easeOut(duration: 0.55).delay(0.15)) { fadeIn = true }
            }

            VStack(spacing: 12) {
                OBTitle("You're tired.\nWe'll show you why.")
                OBSubtitle("It takes 2 minutes.")
            }
            .opacity(fadeIn ? 1 : 0)
            .offset(y: fadeIn ? 0 : 12)
        }
        .frame(maxWidth: .infinity)
        .onboardingEdge()
    }

    private var tiredPet: Pet {
        var p = Pet(); p.species = species; p.mood = .sleepy; p.equippedColor = "default_color"
        return p
    }
}

// MARK: - Screen 1: Relatable pain — "Ever wake up already exhausted?"

/// 4 BIG emoji cards — each one immediate, no icon-system noise.
/// Reveal one-by-one with haptics so it feels alive.
private struct SleepImpactStatScreen: View {
    @State private var revealed = 0

    private let pains: [(String, String)] = [
        ("🧠", "Brain fog"),
        ("🔋", "No energy"),
        ("😤", "Bad mood"),
        ("🎯", "Can't focus"),
        ("🍔", "Belly fat & bloating")
    ]

    var body: some View {
        OnboardingScaffold(
            eyebrow: ("😴", "Sound familiar?"),
            title: "Bad sleep does\nthis to you."
        ) {
            VStack(spacing: 12) {
                ForEach(Array(pains.enumerated()), id: \.offset) { idx, p in
                    OBCard(emoji: p.0, title: p.1, visible: idx < revealed)
                }
            }
        }
        .onAppear {
            Haptics.medium()
            for i in 0..<pains.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + 0.16 * Double(i)) {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                        revealed = i + 1
                    }
                    Haptics.tick()
                }
            }
        }
    }
}

// MARK: - Screen 2: Pick pet

// MARK: - Screen 3: Name pet

private struct NamePetScreen: View {
    let species: PetSpecies
    @Binding var name: String
    @FocusState private var focused: Bool

    /// One-tap name ideas under the field. Most users never type during
    /// onboarding — chips make naming a single tap, and the shuffle keeps
    /// it playful for the ones who want more options.
    private static let namePool: [String] = [
        "Luna", "Nova", "Momo", "Pip",
        "Sage", "Mochi", "Echo", "Willow",
        "Cleo", "Juno", "Ollie", "Astra"
    ]
    @State private var suggestionPage: Int = 0

    private var suggestions: [String] {
        let start = (suggestionPage * 4) % Self.namePool.count
        return (0..<4).map { Self.namePool[(start + $0) % Self.namePool.count] }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)

            DreamSpiritView(pet: previewPet, size: 132)

            Spacer(minLength: 20)

            VStack(spacing: 10) {
                Text("Meet your sleep companion.")
                    .font(MooniFont.display(26))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 8)

                Text("They grow every night you sleep well.\nGive them a name to make it real.")
                    .font(MooniFont.body(14))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 26)

            // The name reads like a name tag, not a form: big centered text
            // over a single underline that lights up with focus.
            VStack(spacing: 18) {
                VStack(spacing: 10) {
                    TextField(
                        "",
                        text: $name,
                        prompt: Text(species.defaultName)
                            .foregroundColor(.white.opacity(0.25))
                    )
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit { focused = false }

                    Capsule()
                        .fill(focused ? MooniColor.accent : Color.white.opacity(0.22))
                        .frame(width: 180, height: 2)
                }

                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            Haptics.tap()
                            name = suggestion
                            focused = false
                        } label: {
                            Text(suggestion)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(name == suggestion ? .black : .white.opacity(0.85))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule().fill(name == suggestion
                                                   ? Color.white
                                                   : Color.white.opacity(0.07))
                                )
                                .overlay(
                                    Capsule().stroke(Color.white.opacity(name == suggestion ? 0 : 0.14),
                                                     lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        Haptics.tap()
                        withAnimation(.easeInOut(duration: 0.2)) { suggestionPage += 1 }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.white.opacity(0.07)))
                            .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .animation(.easeInOut(duration: 0.2), value: focused)
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
        case 1: return "8.5 hours sleep"
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
                    Haptics.tick()
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
//
// 6 SleepGoal cases split across 2 screens (3 per page) so each row can be
// full-sized instead of crammed. `page` (0 or 1) selects which slice to
// render. Selection is a single shared binding across both pages; back
// navigation from page 1 → page 0 preserves the choice.

private struct GoalScreen: View {
    @Binding var selection: SleepGoal?
    /// 0 = primary (first three goals + "More options" link),
    /// 1 = continuation (remaining goals).
    let page: Int
    /// Called when the user explicitly asks to see more options on page 0.
    /// Bypasses the footer's canAdvance gate so users can browse without
    /// having to select prematurely.
    var onAdvance: () -> Void = {}

    /// Three goals per page in stable enum order.
    private var pageGoals: [SleepGoal] {
        let all = SleepGoal.allCases
        let mid = all.count / 2
        return page == 0 ? Array(all.prefix(mid)) : Array(all.suffix(from: mid))
    }

    private var title: String {
        page == 0
            ? "What do you want help with most?"
            : "A few more options."
    }
    private var subtitle: String {
        page == 0
            ? "We'll personalize your plan around this."
            : "Still nothing fits? Use Back to revisit the first set."
    }

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 10) {
                Text(title)
                    .font(MooniFont.display(24))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                Text(subtitle)
                    .font(MooniFont.body(14))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)

            VStack(spacing: 10) {
                ForEach(pageGoals) { goal in
                    goalRow(goal: goal)
                }
            }

            if page == 0 {
                Button {
                    Haptics.tap()
                    onAdvance()
                } label: {
                    HStack(spacing: 6) {
                        Text("More options")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }

    private func goalRow(goal: SleepGoal) -> some View {
        Button {
            withAnimation(.spring(response: 0.28)) { selection = goal }
            Haptics.tap()
        } label: {
            let isSelected = selection == goal
            HStack(spacing: 14) {
                Image(systemName: goal.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isSelected ? .black : .white)
                    .frame(width: 40, height: 40)
                    .background(isSelected ? Color.white : Color.white.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                Text(goal.title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.25))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(Color.white.opacity(isSelected ? 0.10 : 0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(isSelected ? 0.5 : 0.10),
                            lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Reusable multi-select question screen

/// One clean, consistent multi-select screen used for the whole post-
/// "personalize" block. Big tappable rows, checkmarks, encourages picking
/// as many as apply. `T` just needs to be Hashable.
private struct MultiSelectScreen<T: Hashable>: View {
    let title: String
    let subtitle: String
    /// (value, label, SF Symbol) — order is the display order.
    let options: [(T, String, String)]
    @Binding var selection: Set<T>

    var body: some View {
        VStack(spacing: 18) {
            QuestionHeader(title: title, subtitle: subtitle)

            VStack(spacing: 10) {
                ForEach(Array(options.enumerated()), id: \.offset) { _, opt in
                    let (value, label, icon) = opt
                    let isSelected = selection.contains(value)
                    Button {
                        withAnimation(.spring(response: 0.28)) {
                            if isSelected { selection.remove(value) }
                            else { selection.insert(value) }
                        }
                        Haptics.tap()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(isSelected ? .black : .white)
                                .frame(width: 40, height: 40)
                                .background(isSelected ? Color.white : Color.white.opacity(0.10))
                                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                            Text(label)
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(isSelected ? .white : .white.opacity(0.25))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(isSelected ? 0.10 : 0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(isSelected ? 0.5 : 0.10),
                                        lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 44)
        .padding(.horizontal, 20)
    }
}

// MARK: - Screen: Goals (first screen of the personalize block)

private struct GoalsMultiScreen: View {
    @Binding var selection: Set<SleepGoal>

    var body: some View {
        MultiSelectScreen(
            title: "What do you want to improve?",
            subtitle: "Pick everything you care about — these drive your recommendations.",
            options: SleepGoal.allCases.map { ($0, $0.title, $0.icon) },
            selection: $selection)
    }
}

// MARK: - Screen: Personalizing payoff

/// The payoff beat: echoes the user's own goals back and counts every choice
/// they made so the whole block feels like it's actively shaping the plan.
private struct PersonalizingRevealScreen: View {
    let items: [(icon: String, title: String)]
    let pickCount: Int

    @State private var revealed = 0
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(OnboardingLayout.accent.opacity(0.20))
                    .frame(width: 148, height: 148)
                    .blur(radius: 30)
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(OnboardingLayout.accent)
            }

            VStack(spacing: 12) {
                OBTitle("Building your plan")
                OBSubtitle("Tailored from your \(pickCount) answers. We'll focus on:")
            }

            VStack(spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(OnboardingLayout.accent)
                            .frame(width: 34, height: 34)
                            .background(OnboardingLayout.accent.opacity(0.16))
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        Text(item.title)
                            .font(MooniFont.title(15))
                            .foregroundColor(MooniColor.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(OnboardingLayout.accent)
                            .font(.system(size: 18))
                    }
                    .padding(13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(OnboardingLayout.accent.opacity(0.18), lineWidth: 1)
                    )
                    .opacity(idx < revealed ? 1 : 0)
                    .offset(y: idx < revealed ? 0 : 8)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onboardingEdge()
        .onReceive(timer) { _ in
            if revealed < items.count {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    revealed += 1
                }
                Haptics.tap()
            }
        }
    }
}

// MARK: - Screen: Personalize (cosmetic consent)

/// Clean, low-text personalization ask. No system permission is tied to this —
/// it just records a preference flag. Mirrors the glam-up "use your data to
/// personalize" beat with a clear Skip.
private struct PersonalizeScreen: View {
    @State private var glow = false

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(OnboardingLayout.accent.opacity(glow ? 0.36 : 0.18))
                    .frame(width: 180, height: 180)
                    .blur(radius: 30)
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 58, weight: .bold))
                    .foregroundColor(OnboardingLayout.accent)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    glow = true
                }
            }

            VStack(spacing: 12) {
                OBTitle("Personalize SleepOwl")
                OBSubtitle("Use your answers to tailor your plan, recommendations and nightly advice. Your data stays private.")
            }
        }
        .frame(maxWidth: .infinity)
        .onboardingEdge()
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
            subtitle: "Scroll to your typical times."
        ) {
            VStack(spacing: 12) {
                timeWheelCard(
                    icon: "moon.fill",
                    label: "BEDTIME",
                    accent: MooniColor.accent,
                    binding: bedDate
                )
                timeWheelCard(
                    icon: "sun.max.fill",
                    label: "WAKE UP",
                    accent: MooniColor.accent,
                    binding: wakeDate
                )

                // Total-sleep readout — same card language as the two wheels
                // above (icon tile + label on the left, value on the right) so
                // it reads as part of the set instead of a stray mismatched pill.
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(MooniColor.accent.opacity(0.18))
                            .frame(width: 32, height: 32)
                        Image(systemName: "bed.double.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(MooniColor.accent)
                    }
                    Text("TIME ASLEEP")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(MooniColor.textMuted)
                        .tracking(1.8)
                    Spacer()
                    Text(durationDisplay)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(LinearGradient(
                            colors: [MooniColor.accentSoft, MooniColor.accent],
                            startPoint: .leading, endPoint: .trailing))
                        .monospacedDigit()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(MooniColor.accent.opacity(0.28), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.top, 2)
            }
        }
        .onAppear {
            // Keep the stored duration in sync with the displayed times so the
            // readout is correct on first load — it used to show a stale 6h 30m
            // default until the user nudged a wheel.
            profile.typicalSleepHours = Self.duration(
                bed: profile.typicalBedHour ?? 23.5,
                wake: profile.typicalWakeHour ?? 7.0
            )
        }
    }

    private var durationDisplay: String {
        let h = profile.typicalSleepHours
        let whole = Int(h)
        let mins = Int(round((h - Double(whole)) * 60))
        let snapped = Int(round(Double(mins) / 5.0)) * 5
        if snapped == 60 { return "\(whole + 1)h 00m" }
        return String(format: "%dh %02dm", whole, snapped)
    }

    private func formattedTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    private func timeWheelCard(icon: String, label: String, accent: Color, binding: Binding<Date>) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(accent.opacity(0.18))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(accent)
                }
                Text(label)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(MooniColor.textMuted)
                    .tracking(1.8)
                Spacer()
                Text(formattedTime(binding.wrappedValue))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(accent)
                    .monospacedDigit()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 4)

            DatePicker("", selection: binding, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.dark)
                .tint(accent)
                .frame(height: 120)
                .clipped()
                .onChange(of: binding.wrappedValue) { _, _ in Haptics.tap() }
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
        }
        .background(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accent.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
        // A "typical night" longer than ~14h is never what someone means here —
        // it's an AM/PM mix-up (e.g. wake picked as 7 PM instead of 7 AM, which
        // used to read as "19h of sleep"). Recover the intended morning wake so
        // the readout always stays believable.
        if diff > 14 { diff -= 12 }
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
            subtitle: "Screens delay melatonin by up to 90 minutes."
        ) {
            VStack(spacing: 18) {
                Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                    .font(.system(size: 70))
                    .foregroundStyle(LinearGradient(
                        colors: [MooniColor.accentSoft, MooniColor.accent],
                        startPoint: .top, endPoint: .bottom))
                    .scaleEffect(glow ? 1.03 : 0.97)
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
                                     ? MooniColor.accent
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
                            ? MooniColor.accent
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
                    .foregroundStyle(LinearGradient(
                        colors: [MooniColor.accentSoft, MooniColor.accent],
                        startPoint: .top, endPoint: .bottom))

                Slider(value: Binding(
                    get: { Double(profile.stressLevel) },
                    set: { profile.stressLevel = Int($0) }
                ), in: 1...10, step: 1)
                .tint(MooniColor.accent)

                HStack {
                    Text("Calm").font(MooniFont.caption(11)).foregroundColor(MooniColor.textMuted)
                    Spacer()
                    Text("Anxious").font(MooniFont.caption(11)).foregroundColor(MooniColor.textMuted)
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
                                     ? MooniColor.accent
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
                            ? MooniColor.accent
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
                        color: MooniColor.accent, selection: $wakeTime)

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

    private var messages: [(emoji: String, text: String)] {
        [
            ("📝", "Reading your answers"),
            ("🌙", "Mapping your night style"),
            ("💸", "Calculating your sleep debt"),
            ("🎯", "Finding your top 3 issues"),
            ("⏰", "Tuning your wake-up window"),
            ("🦉", "Setting up \(petName)")
        ]
    }

    var body: some View {
        VStack(spacing: 26) {
            Spacer(minLength: 14)

            Text.iconHeader("🔬", "ANALYZING YOU")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundColor(MooniColor.accentSoft)
                .tracking(2)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(MooniColor.accent.opacity(0.16))
                .clipShape(Capsule())

            // Big ring with percent + orbit dots
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 12)
                    .frame(width: 200, height: 200)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(LinearGradient(
                        colors: [MooniColor.accentSoft, MooniColor.accent],
                        startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: MooniColor.accent.opacity(0.4), radius: 18)
                    .animation(.easeInOut(duration: 0.55), value: progress)
                ForEach(0..<3) { i in
                    Circle()
                        .fill(MooniColor.accent.opacity(0.65))
                        .frame(width: 7, height: 7)
                        .offset(x: 100)
                        .rotationEffect(.degrees(orbit + Double(i) * 120))
                }
                VStack(spacing: -2) {
                    Text("\(Int(progress * 100))")
                        .font(.system(size: 54, weight: .heavy, design: .rounded))
                        .foregroundColor(MooniColor.textPrimary)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.4), value: progress)
                    Text("PERCENT")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(MooniColor.textMuted)
                        .tracking(1.6)
                }
            }
            .onAppear {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    orbit = 360
                }
            }

            // Current step — big, animated
            HStack(spacing: 10) {
                EmojiIcon(emoji: messages[min(currentStep, messages.count - 1)].emoji,
                          size: 20, tint: MooniColor.accent)
                Text(messages[min(currentStep, messages.count - 1)].text)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundColor(MooniColor.textPrimary)
            }
            .id(currentStep)
            .transition(.opacity.combined(with: .move(edge: .bottom)))

            // Step checklist
            VStack(spacing: 8) {
                ForEach(Array(messages.enumerated()), id: \.offset) { idx, msg in
                    HStack(spacing: 12) {
                        Group {
                            if idx < currentStep {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(MooniColor.success)
                            } else if idx == currentStep {
                                Circle()
                                    .fill(MooniColor.accent)
                                    .frame(width: 14, height: 14)
                            } else {
                                Circle()
                                    .stroke(Color.white.opacity(0.22), lineWidth: 1.5)
                                    .frame(width: 14, height: 14)
                            }
                        }
                        .frame(width: 22)

                        EmojiIcon(emoji: msg.emoji, size: 14, tint: MooniColor.accentSoft)
                            .opacity(idx <= currentStep ? 1 : 0.4)

                        Text(msg.text)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(idx <= currentStep ? MooniColor.textPrimary : MooniColor.textMuted)
                            .strikethrough(idx < currentStep, color: MooniColor.textMuted)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Spacer(minLength: 4)
        }
        .padding(.horizontal, 22)
    }
}

// MARK: - Screen: Sleep score reveal

/// Sleep score — big ring + verdict word, then a 4-stat grid showing the
/// breakdown (Duration / Stress / Habits / Environment), then a "vs. ideal"
/// mini gauge row. Way more data than v1, all in a clean uniform grid.
private struct SleepScoreRevealScreen: View {
    let profile: OnboardingProfile
    let petName: String

    @State private var animateNumber: Double = 0
    @State private var pulse = false
    @State private var gridIn = false
    @State private var compareIn = false

    private var idealHours: Double {
        switch profile.age ?? 28 {
        case ..<18: return 9.0
        case 18..<45: return 8.5
        case 45..<65: return 8.0
        default: return 8.0
        }
    }

    // 4 sub-scores derived from the profile — each is 0-100.
    private var durationScore: Int {
        let ratio = profile.typicalSleepHours / idealHours
        return min(100, max(20, Int(ratio * 100)))
    }
    private var stressScore: Int {
        var s = 100 - profile.stressLevel * 6
        if profile.racingThoughtsAtNight == true { s -= 15 }
        return min(100, max(15, s))
    }
    private var habitsScore: Int {
        var s = 100
        if profile.usesPhoneBeforeBed == true { s -= 18 }
        if profile.phoneScreenMinutes > 60 { s -= 10 }
        if profile.caffeineCutoff == .evening { s -= 15 }
        else if profile.caffeineCutoff == .afternoon { s -= 8 }
        if profile.napsDuringDay == true { s -= 6 }
        return min(100, max(20, s))
    }
    private var environmentScore: Int {
        var s = 100
        if profile.roomDarkness == .bright { s -= 18 }
        else if profile.roomDarkness == .someLight { s -= 8 }
        if profile.roomNoise == .loud { s -= 18 }
        else if profile.roomNoise == .someNoise { s -= 8 }
        if profile.bedComfort == .uncomfortable { s -= 15 }
        else if profile.bedComfort == .okay { s -= 5 }
        return min(100, max(20, s))
    }

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 4)

            Text.iconHeader("📋", "YOUR SLEEP SCORE")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundColor(MooniColor.warning)
                .tracking(2)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(MooniColor.warning.opacity(0.16))
                .clipShape(Capsule())

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 16)
                    .frame(width: 210, height: 210)
                Circle()
                    .fill(scoreColor.opacity(pulse ? 0.22 : 0.08))
                    .frame(width: 190, height: 190)
                    .blur(radius: 24)
                Circle()
                    .trim(from: 0, to: CGFloat(animateNumber) / 100)
                    .stroke(LinearGradient(
                        colors: [MooniColor.danger, MooniColor.warning, MooniColor.accentSoft],
                        startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .frame(width: 210, height: 210)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: scoreColor.opacity(0.4), radius: 18)

                VStack(spacing: -2) {
                    Text("\(Int(animateNumber))")
                        .font(.system(size: 80, weight: .heavy, design: .rounded))
                        .foregroundColor(MooniColor.textPrimary)
                        .contentTransition(.numericText())
                    Text(verdictWord)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(scoreColor)
                        .tracking(2)
                }
            }
            .frame(height: 210)

            Text(scoreVerdict)
                .font(MooniFont.display(20))
                .foregroundColor(MooniColor.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 8)

            // 2x2 breakdown grid — uniform sizing, all 4 cards visible at once.
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                breakdownCard(emoji: "⏱️", label: "Duration", score: durationScore)
                breakdownCard(emoji: "🧠", label: "Stress",   score: stressScore)
                breakdownCard(emoji: "🌙", label: "Habits",   score: habitsScore)
                breakdownCard(emoji: "🛏️", label: "Room",     score: environmentScore)
            }
            .opacity(gridIn ? 1 : 0)
            .offset(y: gridIn ? 0 : 10)

            // "vs ideal" row — two simple comparison chips
            HStack(spacing: 10) {
                compareChip(emoji: "👴", value: "+\(profile.sleepAgeYearsAdded) yrs",
                            label: "older than you", tint: MooniColor.danger)
                compareChip(emoji: "📅", value: "\(max(profile.daysLostPerYear, 18))",
                            label: "days lost / year", tint: MooniColor.warning)
            }
            .opacity(compareIn ? 1 : 0)
            .offset(y: compareIn ? 0 : 10)

            Spacer(minLength: 4)
        }
        .padding(.horizontal, 22)
        .onAppear {
            Haptics.medium()
            withAnimation(.easeOut(duration: 1.6)) {
                animateNumber = Double(profile.derivedSleepScore)
            }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
            for delay in stride(from: 0.25, through: 1.5, by: 0.25) {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { Haptics.tick() }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) { gridIn = true }
                Haptics.warning()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) { compareIn = true }
                Haptics.tick()
            }
        }
    }

    private var scoreColor: Color {
        switch profile.derivedSleepScore {
        case ..<45:    return MooniColor.danger
        case 45..<60:  return MooniColor.warning
        case 60..<70:  return MooniColor.warning
        default:       return MooniColor.accentSoft
        }
    }

    private var verdictWord: String {
        switch profile.derivedSleepScore {
        case ..<45:    return "POOR"
        case 45..<60:  return "WEAK"
        case 60..<70:  return "OKAY"
        default:       return "GOOD"
        }
    }

    private var scoreVerdict: String {
        switch profile.derivedSleepScore {
        case ..<45:    return "Big room to grow.\nLet's fix it together."
        case 45..<60:  return "You're below your\npotential — for now."
        case 60..<70:  return "Closer than you think.\nLet's clean up the rest."
        default:       return "Above average. But\nstill room to peak."
        }
    }

    private func breakdownCard(emoji: String, label: String, score: Int) -> some View {
        let tint = tintFor(score)
        return VStack(spacing: 6) {
            HStack(spacing: 6) {
                EmojiIcon(emoji: emoji, size: 18)
                Text(label)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(MooniColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 4)
                Text("\(score)")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundColor(tint)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(LinearGradient(
                            colors: [tint.opacity(0.7), tint],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: g.size.width * CGFloat(score) / 100)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        )
    }

    private func compareChip(emoji: String, value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 6) {
                EmojiIcon(emoji: emoji, size: 18)
                Text(value)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundColor(tint)
            }
            Text(label)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundColor(MooniColor.textMuted)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(tint.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
    }

    private func tintFor(_ s: Int) -> Color {
        switch s {
        case ..<50:   return MooniColor.danger
        case 50..<70: return MooniColor.warning
        case 70..<85: return MooniColor.accentSoft
        default:      return MooniColor.success
        }
    }
}

// MARK: - Screen: Top issues

/// Top issues — emoji-led, big, simple. Drop "Issue 1 / High" chrome, replace
/// SF Symbol icons with emojis. Each issue gets a fix-tag.
private struct TopIssuesScreen: View {
    let profile: OnboardingProfile

    @State private var revealed: Int = 0
    @State private var titleIn = false
    private let revealTimer = Timer.publish(every: 0.45, on: .main, in: .common).autoconnect()

    private var issues: [(emoji: String, tint: Color, title: String)] {
        let raw = profile.topIssues
        let palette: [(String, Color)] = [
            ("📱", MooniColor.danger),
            ("🧠", MooniColor.warning),
            ("😴", MooniColor.accent),
            ("☕", MooniColor.warning),
            ("🌅", MooniColor.accentSoft)
        ]
        return raw.enumerated().map { idx, txt in
            let p = palette[min(idx, palette.count - 1)]
            return (p.0, p.1, txt)
        }
    }

    var body: some View {
        VStack(spacing: 26) {
            Spacer(minLength: 4)

            VStack(spacing: 10) {
                Text.iconHeader("🔍", "WE FOUND \(issues.count) ISSUE\(issues.count == 1 ? "" : "S")", size: 12, tint: MooniColor.warning)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(MooniColor.warning)
                    .tracking(2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(MooniColor.warning.opacity(0.16))
                    .clipShape(Capsule())

                Text("Here's what's hurting\nyour sleep.")
                    .font(MooniFont.display(28))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .opacity(titleIn ? 1 : 0)
            .offset(y: titleIn ? 0 : 8)

            VStack(spacing: 10) {
                ForEach(Array(issues.enumerated()), id: \.offset) { idx, issue in
                    issueCard(emoji: issue.emoji, tint: issue.tint, title: issue.title,
                              visible: idx < revealed)
                }
            }

            HStack(spacing: 8) {
                EmojiIcon(emoji: "✨", size: 14, tint: MooniColor.warning)
                Text("Every one gets a fix in your plan.")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(MooniColor.textSecondary)
            }
            .padding(.top, 2)

            Spacer(minLength: 4)
        }
        .padding(.horizontal, 22)
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) { titleIn = true }
            Haptics.medium()
        }
        .onReceive(revealTimer) { _ in
            if revealed < issues.count {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                    revealed += 1
                }
                Haptics.tick()
            }
        }
    }

    private func issueCard(emoji: String, tint: Color, title: String, visible: Bool) -> some View {
        HStack(spacing: 14) {
            EmojiIcon(emoji: emoji, size: 22, tint: tint)
                .frame(width: 54, height: 54)
                .background(tint.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundColor(MooniColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 4) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 9, weight: .bold))
                    Text("FIX INCLUDED")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .tracking(1)
                }
                .foregroundColor(MooniColor.success)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.28), lineWidth: 1)
        )
        .opacity(visible ? 1 : 0)
        .offset(x: visible ? 0 : -16)
    }
}

// MARK: - Screen: Science credibility

/// Trust block — 3 huge brand-style cards. AASM (clinical), Google (AI),
/// Apple (privacy). No citations footer, no "Science Policy" chip stack.
private struct ScienceCredibilityScreen: View {
    @State private var reveal = 0
    @State private var titleIn = false

    private let logos: [(emoji: String, name: String, blurb: String, tint: Color)] = [
        ("📚", "Research", "Built using sleep science research", MooniColor.accent),
        ("🤖", "AI",       "AI-based sleep stage estimation",    MooniColor.success),
        ("🍎", "Apple",    "Your data stays on your phone",      MooniColor.accentSoft)
    ]

    var body: some View {
        VStack(spacing: 26) {
            Spacer(minLength: 8)

            VStack(spacing: 10) {
                Text.iconHeader("🔬", "BUILT ON REAL SCIENCE")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(MooniColor.success)
                    .tracking(2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(MooniColor.success.opacity(0.16))
                    .clipShape(Capsule())

                Text("We didn't make\nthis stuff up.")
                    .font(MooniFont.display(30))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .opacity(titleIn ? 1 : 0)
            .offset(y: titleIn ? 0 : 8)

            VStack(spacing: 12) {
                ForEach(Array(logos.enumerated()), id: \.offset) { idx, l in
                    logoCard(emoji: l.emoji, name: l.name, blurb: l.blurb,
                             tint: l.tint, visible: idx < reveal)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(MooniColor.success)
                Text("Every number you'll see is cited.")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(MooniColor.textSecondary)
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 22)
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) { titleIn = true }
            Haptics.medium()
            for i in 0..<logos.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35 + Double(i) * 0.18) {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                        reveal = i + 1
                    }
                    Haptics.tick()
                }
            }
        }
    }

    private func logoCard(emoji: String, name: String, blurb: String,
                          tint: Color, visible: Bool) -> some View {
        HStack(spacing: 16) {
            EmojiIcon(emoji: emoji, size: 30, tint: tint)
                .frame(width: 64, height: 64)
                .background(tint.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundColor(tint)
                Text(blurb)
                    .font(MooniFont.body(13))
                    .foregroundColor(MooniColor.textSecondary)
            }
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(MooniColor.success)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.28), lineWidth: 1)
        )
        .opacity(visible ? 1 : 0)
        .offset(x: visible ? 0 : -18)
    }
}

// MARK: - Screen: Soundscape preview

/// Widget showcase. Three real widgets — Small, Medium, and Sleep Circle —
/// each shown alone with a single headline + line. User taps Continue to
/// step through. The footer below detects the internal page and gates the
/// outer advance until the last widget is shown.
private struct WidgetPreviewScreen: View {
    let petName: String
    @Binding var page: Int

    @State private var appeared: Bool = false

    // Sleep Circle page is hidden until the friends backend ships — see
    // FriendsSleepData.swift. Bump this back to 3 when re-enabling.
    static let pageCount: Int = 2

    var body: some View {
        VStack(spacing: 20) {
            // Header — same on every page
            VStack(spacing: 8) {
                Text.iconHeader("📱", "HOME SCREEN WIDGETS")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(MooniColor.accentSoft)
                    .tracking(2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(MooniColor.accent.opacity(0.14))
                    .clipShape(Capsule())

                Text(headlineForPage)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .id("widget-headline-\(page)")
                    .transition(.opacity.combined(with: .move(edge: .top)))

                Text(blurbForPage)
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .id("widget-blurb-\(page)")
                    .transition(.opacity)
            }

            // The widget mock itself. Sleep Circle (friends) is hidden until
            // the friends backend ships; only Small + Medium are shown.
            ZStack {
                if page == 0 { smallWidgetMock.transition(widgetTransition) }
                else { mediumWidgetMock.transition(widgetTransition) }
            }
            .frame(height: 240)

            // Page dots
            HStack(spacing: 6) {
                ForEach(0..<Self.pageCount, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? MooniColor.accent : Color.white.opacity(0.22))
                        .frame(width: i == page ? 22 : 7, height: 6)
                }
            }
            .padding(.top, 4)

            // Tap hint
            Text(page < Self.pageCount - 1
                 ? "Tap Continue to see the next widget"
                 : "All three. Yours tonight.")
                .font(MooniFont.caption(11))
                .foregroundColor(MooniColor.textMuted)
        }
        .padding(.horizontal, 20)
        .onAppear { appeared = true }
    }

    /// Native iOS share sheet, pre-filled with a friendly invite. Shows up
    /// directly under the friends widget mock so the user can spin up their
    /// Sleep Circle before they even leave onboarding.
    private var inviteFriendsButton: some View {
        ShareLink(
            item: URL(string: "https://apps.apple.com/app/sleepowl/id6740000000")!,
            subject: Text("Sleep better with me on SleepOwl"),
            message: Text("I'm using SleepOwl to track my sleep and beat sleep debt — join my Sleep Circle so we can compare nights. \(petName) is waiting.")
        ) {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 14, weight: .bold))
                Text("Invite a friend")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: [MooniColor.accentSoft, MooniColor.accent],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            )
            .shadow(color: MooniColor.accent.opacity(0.45), radius: 12, y: 4)
        }
        .simultaneousGesture(TapGesture().onEnded { Haptics.medium() })
    }

    private var widgetTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.85)).combined(with: .move(edge: .trailing)),
            removal:   .opacity.combined(with: .scale(scale: 0.85)).combined(with: .move(edge: .leading))
        )
    }

    private var headlineForPage: String {
        switch page {
        case 0:  return "Last night, at a glance."
        case 1:  return "Your whole week."
        default: return "Sleep with friends."
        }
    }

    private var blurbForPage: String {
        switch page {
        case 0:  return "One tap from your home screen — score + hours, no app needed."
        case 1:  return "See your 7-day trend without opening anything."
        default: return "Compare nights with your closest friends. Cheer them on."
        }
    }

    // MARK: Widget mocks

    // MARK: - Onboarding widget mocks
    //
    // These mocks mirror the real shipping widgets (SmallSleepWidgetView,
    // MediumSleepWidgetView, FriendsSleepWidgetView). The visual design is
    // kept in lock-step so the user sees in onboarding *exactly* what they'll
    // get on their home screen — premium ring with glow, gradient score
    // number, glass chips, tinted halo background, star speckles.

    private var smallWidgetMock: some View {
        let tint = MooniColor.success
        return VStack(alignment: .leading, spacing: 0) {
            // Top: brand + quality
            HStack(alignment: .center, spacing: 6) {
                HStack(spacing: 3) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(LinearGradient(
                            colors: [.white, tint],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                    Text("SleepOwl")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
                Spacer()
                Text("GOOD")
                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                    .tracking(0.15)
                    .foregroundColor(tint)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Capsule().fill(tint.opacity(0.22)))
                    .overlay(Capsule().stroke(tint.opacity(0.45), lineWidth: 0.6))
            }

            Spacer(minLength: 0)

            // Hero row
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: -4) {
                    Text("84")
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: tint.opacity(0.75), radius: 14)
                    Text("TONIGHT")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .tracking(1.4)
                        .foregroundColor(MooniColor.textMuted)
                }
                Spacer()
                mockRing(progress: 0.84, tint: tint, size: 70, lineWidth: 7)
            }

            Spacer(minLength: 0)

            // Footer chip
            HStack(spacing: 6) {
                Image(systemName: "bed.double.fill")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(tint)
                Text("7h 24m")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                Spacer(minLength: 4)
                Text("11:42p → 7:18a")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(MooniColor.textSecondary)
            }
            .padding(.horizontal, 9).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.white.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 0.6))
        }
        .padding(14)
        .frame(width: 178, height: 178)
        .background(mockWidgetBg(tint: tint))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous)
            .stroke(LinearGradient(
                colors: [Color.white.opacity(0.25), Color.white.opacity(0.03)],
                startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8))
        .shadow(color: .black.opacity(0.45), radius: 24, y: 12)
    }

    private var mediumWidgetMock: some View {
        let tint = MooniColor.accent
        let trend: [CGFloat] = [0.55, 0.7, 0.45, 0.85, 0.6, 0.9, 0.78]
        return HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 8) {
                mockRing(progress: 0.78, tint: tint, size: 112, lineWidth: 9)
                HStack(spacing: 5) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundColor(tint)
                    Text("11:42p → 7:18a")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.08)))
                .overlay(Capsule().stroke(tint.opacity(0.18), lineWidth: 0.6))
            }
            .frame(width: 124)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 9, weight: .black))
                    Text("SleepOwl")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                }
                .foregroundColor(MooniColor.textSecondary)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("78")
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .foregroundStyle(LinearGradient(
                            colors: [.white, tint],
                            startPoint: .top, endPoint: .bottom))
                        .shadow(color: tint.opacity(0.55), radius: 14)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("GOOD")
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .tracking(0.3)
                            .foregroundColor(tint)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Capsule().fill(tint.opacity(0.22)))
                            .overlay(Capsule().stroke(tint.opacity(0.45), lineWidth: 0.6))
                        Text("TONIGHT")
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .tracking(1.2)
                            .foregroundColor(MooniColor.textMuted)
                    }
                }

                HStack(spacing: 6) {
                    mockMiniChip(icon: "bed.double.fill", value: "7h 24m", tint: tint)
                    mockMiniChip(icon: "bolt.fill", value: "72%",
                                 tint: Color(red: 0.72, green: 0.62, blue: 1.00))
                }

                // Sparkline
                GeometryReader { geo in
                    let dx = geo.size.width / CGFloat(trend.count - 1)
                    ZStack {
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: geo.size.height))
                            for (i, v) in trend.enumerated() {
                                p.addLine(to: CGPoint(x: CGFloat(i) * dx,
                                                       y: geo.size.height * (1 - v)))
                            }
                            p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                            p.closeSubpath()
                        }
                        .fill(LinearGradient(
                            colors: [tint.opacity(0.35), tint.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom))
                        Path { p in
                            for (i, v) in trend.enumerated() {
                                let x = CGFloat(i) * dx
                                let y = geo.size.height * (1 - v)
                                if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                                else { p.addLine(to: CGPoint(x: x, y: y)) }
                            }
                        }
                        .stroke(LinearGradient(
                            colors: [tint.opacity(0.7), tint],
                            startPoint: .leading, endPoint: .trailing),
                                style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                        if let last = trend.last {
                            Circle()
                                .fill(tint)
                                .frame(width: 5, height: 5)
                                .shadow(color: tint.opacity(0.7), radius: 3)
                                .position(x: geo.size.width - 2,
                                          y: geo.size.height * (1 - last))
                        }
                    }
                }
                .frame(height: 22)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(14)
        .frame(width: 340, height: 178)
        .background(mockWidgetBg(tint: tint))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous)
            .stroke(LinearGradient(
                colors: [Color.white.opacity(0.25), Color.white.opacity(0.03)],
                startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8))
        .shadow(color: .black.opacity(0.45), radius: 24, y: 12)
    }

    private var sleepCircleMock: some View {
        let tint = MooniColor.accent
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(LinearGradient(
                        colors: [.white, tint],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                Text("Sleep Circle")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 9, weight: .heavy))
                    Text("SleepOwl")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                }
                .foregroundColor(MooniColor.textSecondary)
            }

            HStack(alignment: .top, spacing: 8) {
                mockFriendCard(initial: "Y", name: "You",   score: 84,
                               tint: MooniColor.success, duration: "7h 24m",
                               window: "11:42p → 7:18a", isWinner: true)
                mockFriendCard(initial: "A", name: "Alex",  score: 76,
                               tint: MooniColor.warning, duration: "6h 51m",
                               window: "12:08a → 6:59a", isWinner: false)
                mockFriendCard(initial: "+", name: "Invite", score: nil,
                               tint: tint, duration: "—",
                               window: "—", isWinner: false, isInvite: true)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(14)
        .frame(width: 340, height: 178)
        .background(mockWidgetBg(tint: MooniColor.success))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous)
            .stroke(LinearGradient(
                colors: [Color.white.opacity(0.25), Color.white.opacity(0.03)],
                startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8))
        .shadow(color: .black.opacity(0.45), radius: 24, y: 12)
    }

    // MARK: Mock helpers

    /// Gradient ring with halo + mascot center — visual twin of the real
    /// widget's ring (ZStack of glow + track + angular gradient stroke +
    /// pet mascot). Used by both small and medium mocks.
    private func mockRing(progress: CGFloat, tint: Color,
                          size: CGFloat, lineWidth: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.20))
                .frame(width: size + 10, height: size + 10)
                .blur(radius: size * 0.12)
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: lineWidth)
                .frame(width: size - lineWidth, height: size - lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(AngularGradient(
                    colors: [tint.opacity(0.55), tint, tint.opacity(0.9)],
                    center: .center),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: size - lineWidth, height: size - lineWidth)
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.55), radius: 6)
            Image("spirit_awake")
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.48, height: size * 0.48)
        }
        .frame(width: size, height: size)
    }

    private func mockMiniChip(icon: String, value: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(tint)
            Text(value)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.white.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(tint.opacity(0.20), lineWidth: 0.6))
    }

    private func mockFriendCard(initial: String, name: String, score: Int?,
                                tint: Color, duration: String, window: String,
                                isWinner: Bool, isInvite: Bool = false) -> some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(tint.opacity(isInvite ? 0.10 : 0.20))
                    .frame(width: 50, height: 50)
                    .blur(radius: 6)
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 4)
                    .frame(width: 44, height: 44)
                if !isInvite {
                    Circle()
                        .trim(from: 0, to: CGFloat(score ?? 0) / 100)
                        .stroke(AngularGradient(
                            colors: [tint.opacity(0.55), tint, tint.opacity(0.85)],
                            center: .center),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: tint.opacity(0.5), radius: 4)
                } else {
                    Circle()
                        .strokeBorder(MooniColor.textMuted.opacity(0.55),
                                      style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                        .frame(width: 44, height: 44)
                }
                if isInvite {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(.white.opacity(0.7))
                } else {
                    Text(initial)
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }
                if isWinner {
                    EmojiIcon(emoji: "👑", size: 12, tint: MooniColor.warning)
                        .offset(x: 18, y: -18)
                        .shadow(color: Color(red: 1.0, green: 0.85, blue: 0.3).opacity(0.7), radius: 4)
                }
            }
            .frame(width: 50, height: 50)

            if let s = score {
                Text("\(s)")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundColor(tint)
                    .shadow(color: tint.opacity(0.45), radius: 4)
            } else {
                Text("—")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundColor(MooniColor.textMuted)
            }
            Text(name)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
            Text(duration)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(MooniColor.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8).padding(.horizontal, 4)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(LinearGradient(
                colors: [tint.opacity(isWinner ? 0.20 : 0.10), tint.opacity(0.02)],
                startPoint: .top, endPoint: .bottom)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(tint.opacity(isWinner ? 0.45 : 0.20),
                    lineWidth: isWinner ? 1.0 : 0.6))
    }

    /// Mirrors the real `SleepWidgetBackground` — gradient base + tinted
    /// corner halo. Drawn at preview-card scale so the mock looks like the
    /// home-screen widget the user will actually get.
    private func mockWidgetBg(tint: Color) -> some View {
        ZStack {
            LinearGradient(colors: [
                Color(red: 0.05, green: 0.05, blue: 0.13),
                Color(red: 0.08, green: 0.07, blue: 0.20),
                Color(red: 0.04, green: 0.04, blue: 0.10)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [tint.opacity(0.45), .clear],
                           center: .topLeading,
                           startRadius: 0, endRadius: 220)
                .blendMode(.plusLighter)
            RadialGradient(colors: [MooniColor.accent.opacity(0.25), .clear],
                           center: .bottomTrailing,
                           startRadius: 0, endRadius: 200)
                .blendMode(.plusLighter)
        }
    }

}

// Legacy soundscape screen — replaced by WidgetPreviewScreen in the flow.
// Kept compiled for potential reuse elsewhere; not currently referenced.
private struct SoundscapePreviewScreen: View {
    let petName: String

    @State private var selected: Sound = .rainforest
    @State private var pulse: CGFloat = 0
    @State private var revealed: Bool = false
    @ObservedObject private var player = SamplePlayer.shared

    private var isPlaying: Bool { player.currentlyPlaying == "rain" }

    enum Sound: String, CaseIterable, Identifiable {
        case rainforest, rain, ocean, fire, whitenoise
        var id: String { rawValue }
        var label: String {
            switch self {
            case .rainforest: return "Rainforest"
            case .rain:       return "Rain"
            case .ocean:      return "Ocean"
            case .fire:       return "Fireplace"
            case .whitenoise: return "White noise"
            }
        }
        var icon: String {
            switch self {
            case .rainforest: return "leaf.fill"
            case .rain:       return "cloud.rain.fill"
            case .ocean:      return "water.waves"
            case .fire:       return "flame.fill"
            case .whitenoise: return "waveform"
            }
        }
        var tint: Color {
            switch self {
            case .rainforest: return MooniColor.success
            case .rain:       return MooniColor.accent
            case .ocean:      return MooniColor.accentSoft
            case .fire:       return MooniColor.warning
            case .whitenoise: return Color.white.opacity(0.85)
            }
        }
    }

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "headphones")
                        .foregroundColor(MooniColor.accentSoft)
                    Text("Try it now")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.accentSoft)
                        .tracking(2)
                        .textCase(.uppercase)
                }
                Text("Drift off to anything")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text("12 sleep-tested soundscapes — \(petName)'s favorite is below.")
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Big play card with halo + circular play button
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(selected.tint.opacity(0.25), lineWidth: 1.5)
                        .frame(width: 160 + CGFloat(i) * 36, height: 160 + CGFloat(i) * 36)
                        .scaleEffect(isPlaying ? 1.0 + CGFloat(i) * 0.04 : 1.0)
                        .opacity(isPlaying ? 0.9 - Double(i) * 0.25 : 0.0)
                        .animation(
                            .easeInOut(duration: 2.0)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.4),
                            value: isPlaying
                        )
                }

                Circle()
                    .fill(selected.tint.opacity(0.15))
                    .frame(width: 150, height: 150)

                Button {
                    Haptics.medium()
                    SamplePlayer.shared.toggle("rain")
                } label: {
                    ZStack {
                        Circle()
                            .fill(selected.tint.opacity(0.85))
                            .frame(width: 110, height: 110)
                            .shadow(color: selected.tint.opacity(0.45), radius: 24)

                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundColor(.black.opacity(0.9))
                            .offset(x: isPlaying ? 0 : 3)
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(height: 200)

            // Now playing strip with live waveform (only animates while playing)
            HStack(spacing: 10) {
                Circle()
                    .fill(isPlaying ? selected.tint : MooniColor.textMuted)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isPlaying ? 1.0 : 0.7)
                    .opacity(isPlaying ? 1 : 0.55)

                Text(isPlaying ? "NOW PLAYING · \(selected.label.uppercased())" : "TAP TO PREVIEW · \(selected.label.uppercased())")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(isPlaying ? selected.tint : MooniColor.textMuted)
                    .tracking(1.4)

                Spacer()

                WaveformBars(tint: selected.tint, active: isPlaying)
                    .frame(width: 64, height: 22)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isPlaying ? selected.tint.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Sound chooser
            HStack(spacing: 10) {
                ForEach(Sound.allCases) { s in
                    Button {
                        Haptics.tap()
                        if isPlaying { SamplePlayer.shared.stop() }
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selected = s
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: s.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(selected == s ? s.tint : MooniColor.textSecondary)
                            Text(s.label)
                                .font(MooniFont.caption(10))
                                .foregroundColor(selected == s ? MooniColor.textPrimary : MooniColor.textMuted)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selected == s ? s.tint.opacity(0.16) : Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(selected == s ? s.tint.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)

            HStack(spacing: 8) {
                Image(systemName: "moon.stars.fill")
                    .foregroundColor(MooniColor.accentSoft)
                    .font(.system(size: 13))
                Text("Auto-fades when you drift off — never wakes you.")
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(MooniColor.accentSoft.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(revealed ? 1 : 0)
            .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) { revealed = true }
        }
        .onDisappear {
            SamplePlayer.shared.stop()
        }
    }
}

/// Animated audio-style waveform — 6 bars that bounce while `active` is true
/// and rest at a low baseline when paused. Purely decorative; no audio output.
private struct WaveformBars: View {
    let tint: Color
    let active: Bool

    @State private var phase: CGFloat = 0
    private let timer = Timer.publish(every: 0.18, on: .main, in: .common).autoconnect()
    private let count = 6

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(active ? tint : MooniColor.textMuted.opacity(0.5))
                    .frame(width: 4, height: barHeight(i))
                    .animation(.easeInOut(duration: 0.18), value: phase)
            }
        }
        .onReceive(timer) { _ in
            if active { phase += 1 }
        }
    }

    private func barHeight(_ i: Int) -> CGFloat {
        guard active else { return 4 }
        // Pseudo-random but stable per (phase, index) — looks like audio.
        let seed = sin(Double(Int(phase) * 7 + i * 13)) * 0.5 + 0.5
        return 4 + CGFloat(seed) * 18
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

    private var msgs: [(emoji: String, text: String)] {
        [
            ("🌙", "Learning your sleep rhythm"),
            ("🎯", "Building your first quest"),
            ("🦉", "Preparing \(petName)'s room"),
            ("⏰", "Tuning your wake-up window"),
            ("🌬️", "Setting your wind-down"),
            ("✨", "Locking in tonight's plan")
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
            VStack(spacing: 10) {
                Text.iconHeader("✨", "BUILDING YOUR PLAN")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(MooniColor.accentSoft)
                    .tracking(2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(MooniColor.accent.opacity(0.16))
                    .clipShape(Capsule())
                let msg = msgs[min(messageIndex, msgs.count - 1)]
                VStack(spacing: 14) {
                    EmojiIcon(emoji: msg.emoji, size: 26, tint: MooniColor.accentSoft)
                        .frame(width: 58, height: 58)
                        .background(MooniColor.accent.opacity(0.16))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(MooniColor.accent.opacity(0.24), lineWidth: 1))
                    Text(msg.text)
                        .font(.system(size: 21, weight: .heavy, design: .rounded))
                        .foregroundColor(MooniColor.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)
                .id(messageIndex)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.easeInOut(duration: 0.45), value: messageIndex)
            }
            .frame(minHeight: 132)

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

/// Social proof — big "4.9 ★★★★★ · 12K reviews", 3 review cards with avatar
/// circles. Drop the redundant "what you get" feature list (it's on the
/// paywall already).
private struct SocialProofScreen: View {
    private struct Review {
        let initial: String
        let tint: Color
        let text: String
        let author: String
    }
    private let reviews: [Review] = [
        Review(initial: "S", tint: MooniColor.accentSoft,
               text: "I haven't woken up tired in 3 weeks. The pet thing actually worked on me.",
               author: "Sarah, 28"),
        Review(initial: "M", tint: MooniColor.success,
               text: "Stopped scrolling in bed because I didn't want my fox to be sad.",
               author: "Marco, 34"),
        Review(initial: "P", tint: Color.pink,
               text: "First app that actually fixed my schedule. Tiny wins compound.",
               author: "Priya, 41")
    ]

    @State private var revealed = 0
    @State private var headIn = false

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 8)

            VStack(spacing: 10) {
                // Huge star row + rating number
                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(MooniColor.warning)
                    }
                }
                .scaleEffect(headIn ? 1 : 0.85)
                .opacity(headIn ? 1 : 0)

                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text("4.9")
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .foregroundColor(MooniColor.textPrimary)
                    Text("average rating")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(MooniColor.textSecondary)
                }
                .opacity(headIn ? 1 : 0)

                Text("Loved by 12,000+ sleepers")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(MooniColor.success)
                    .tracking(1.2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(MooniColor.success.opacity(0.16))
                    .clipShape(Capsule())
                    .opacity(headIn ? 1 : 0)
            }

            VStack(spacing: 10) {
                ForEach(Array(reviews.enumerated()), id: \.offset) { idx, r in
                    reviewCard(r, visible: idx < revealed)
                }
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 22)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.78)) { headIn = true }
            Haptics.medium()
            for i in 0..<reviews.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 + Double(i) * 0.2) {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                        revealed = i + 1
                    }
                    Haptics.tick()
                }
            }
        }
    }

    private func reviewCard(_ r: Review, visible: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(r.tint.opacity(0.22))
                    .frame(width: 44, height: 44)
                Text(r.initial)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(r.tint)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(MooniColor.warning)
                    }
                    Spacer()
                    Text(r.author)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(MooniColor.textMuted)
                }
                Text(r.text)
                    .font(MooniFont.body(13))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 12)
    }
}

// MARK: - Screen: Simulated result

/// Three pet outcomes — big pet, big emoji label, one line of context.
/// "Sleep well → happy pet" is the whole story.
private struct SimulatedResultScreen: View {
    let species: PetSpecies
    let name: String

    @State private var revealed = 0
    @State private var headIn = false

    private var outcomes: [(emoji: String, label: String, line: String, mood: Pet.Mood, tint: Color)] {
        [
            ("🌟", "Great sleep",  "\(name) is glowing",       .energized, MooniColor.success),
            ("🙂", "Okay sleep",   "\(name) is doing fine",     .calm,      MooniColor.warning),
            ("😴", "Poor sleep",   "\(name) needs your help",   .groggy,    MooniColor.danger)
        ]
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 8)

            VStack(spacing: 10) {
                Text.iconHeader("🪞", "TOMORROW")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(MooniColor.accentSoft)
                    .tracking(2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(MooniColor.accent.opacity(0.16))
                    .clipShape(Capsule())

                Text("\(name) reflects\nyour sleep.")
                    .font(MooniFont.display(28))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .opacity(headIn ? 1 : 0)
            .offset(y: headIn ? 0 : 8)

            VStack(spacing: 12) {
                ForEach(Array(outcomes.enumerated()), id: \.offset) { idx, o in
                    outcomeCard(emoji: o.emoji, label: o.label, line: o.line,
                                mood: o.mood, tint: o.tint, visible: idx < revealed)
                }
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 22)
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) { headIn = true }
            Haptics.medium()
            for i in 0..<outcomes.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35 + Double(i) * 0.2) {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                        revealed = i + 1
                    }
                    Haptics.tick()
                }
            }
        }
    }

    private func outcomeCard(emoji: String, label: String, line: String,
                             mood: Pet.Mood, tint: Color, visible: Bool) -> some View {
        var p = Pet(); p.species = species; p.mood = mood; p.equippedHat = nil
        return HStack(spacing: 14) {
            DreamSpiritView(pet: p, size: 56)
                .frame(width: 70, height: 70)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    EmojiIcon(emoji: emoji, size: 22)
                    Text(label)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(tint)
                }
                Text(line)
                    .font(MooniFont.body(13))
                    .foregroundColor(MooniColor.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
        .opacity(visible ? 1 : 0)
        .offset(x: visible ? 0 : -16)
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
            Haptics.success()
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

// MARK: - Expert quote screen (post-question interstitial)
//
// Previously these quotes lived inline in a small box inside QuestionScaffold
// and most users skimmed past them. Cofounder feedback: "those are really cool
// facts, but locked in one small area. After Continue, show them their own
// dedicated screen with animation." This view does exactly that.

private struct ExpertQuoteScreen: View {
    enum Quote {
        case sleepTimes, goalFocus, wakeInertia

        var icon: String {
            switch self {
            case .sleepTimes:  return "bed.double.fill"
            case .goalFocus:   return "target"
            case .wakeInertia: return "alarm.fill"
            }
        }
        var accent: Color {
            switch self {
            case .sleepTimes:  return MooniColor.accent
            case .goalFocus:   return MooniColor.success
            case .wakeInertia: return MooniColor.warning
            }
        }
        var topLabel: String {
            switch self {
            case .sleepTimes:  return "WHY WE ASKED THAT"
            case .goalFocus:   return "WHY ONE GOAL"
            case .wakeInertia: return "WHY WAKE-UP MATTERS"
            }
        }
        var body: String {
            switch self {
            case .sleepTimes:
                return "Bedtime and wake time tell us 73% of what we need to predict your real sleep need."
            case .goalFocus:
                return "Defining the one outcome you actually care about doubles adherence to a sleep program."
            case .wakeInertia:
                return "Waking out of deep sleep produces inertia that can take 60–90 minutes to clear cognitively."
            }
        }
        var author: String {
            switch self {
            case .sleepTimes:  return "Dr. Phyllis Zee"
            case .goalFocus:   return "Dr. Colleen Carney"
            case .wakeInertia: return "Dr. Kenneth Wright"
            }
        }
        var credential: String {
            switch self {
            case .sleepTimes:  return "Northwestern · Sleep Med 2023"
            case .goalFocus:   return "Toronto Metropolitan U. · CBT-I researcher"
            case .wakeInertia: return "U. Colorado · Sleep & Chronobiology Lab"
            }
        }
        var supportStat: (String, String) {
            switch self {
            case .sleepTimes:  return ("73%",   "of sleep-need variance explained")
            case .goalFocus:   return ("2.1×",  "adherence vs. multi-goal plans")
            case .wakeInertia: return ("60-90", "minutes of post-wake fog")
            }
        }
    }

    let quote: Quote

    @State private var bigIn = false
    @State private var quoteIn = false
    @State private var authorIn = false

    var body: some View {
        VStack(spacing: 26) {
            Spacer(minLength: 12)

            // Eyebrow chip
            Text.iconHeader("💡", "\(quote.topLabel)")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundColor(quote.accent)
                .tracking(2)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(quote.accent.opacity(0.16))
                .clipShape(Capsule())
                .opacity(bigIn ? 1 : 0)
                .offset(y: bigIn ? 0 : 6)

            // The big stat is now THE hero — number is the headline.
            VStack(spacing: 6) {
                Text(quote.supportStat.0)
                    .font(.system(size: 92, weight: .heavy, design: .rounded))
                    .foregroundStyle(LinearGradient(
                        colors: [quote.accent, quote.accent.opacity(0.65)],
                        startPoint: .top, endPoint: .bottom))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(quote.supportStat.1)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(MooniColor.textSecondary)
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .multilineTextAlignment(.center)
            }
            .scaleEffect(bigIn ? 1 : 0.78)
            .opacity(bigIn ? 1 : 0)

            // Plain-english quote
            Text(quote.body)
                .font(MooniFont.body(16))
                .foregroundColor(MooniColor.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 10)
                .opacity(quoteIn ? 1 : 0)
                .offset(y: quoteIn ? 0 : 10)

            Spacer(minLength: 0)

            // Author chip — simple, single line
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(MooniColor.success)
                VStack(alignment: .leading, spacing: 1) {
                    Text(quote.author)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(MooniColor.textPrimary)
                    Text(quote.credential)
                        .font(MooniFont.caption(11))
                        .foregroundColor(MooniColor.textMuted)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .opacity(authorIn ? 1 : 0)
            .offset(y: authorIn ? 0 : 10)

            Spacer(minLength: 4)
        }
        .padding(.horizontal, 22)
        .onAppear {
            withAnimation(.spring(response: 0.65, dampingFraction: 0.72)) { bigIn = true }
            Haptics.medium()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.5)) { quoteIn = true }
                Haptics.tick()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                withAnimation(.easeOut(duration: 0.45)) { authorIn = true }
                Haptics.success()
            }
        }
    }
}

// MARK: - Auto-tracking screens

private struct AutoTrackIntroScreen: View {
    @State private var pulse = false
    @State private var bigIn = false
    @State private var subIn = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 8)

            Text.iconHeader("📲", "ZERO TAPS NEEDED")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundColor(MooniColor.accentSoft)
                .tracking(2)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(MooniColor.accent.opacity(0.16))
                .clipShape(Capsule())

            Text("Just sleep.\nWe do the rest.")
                .font(MooniFont.display(32))
                .foregroundColor(MooniColor.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            // Phone with pulsing "auto" badge
            ZStack {
                Circle()
                    .fill(MooniColor.accent.opacity(pulse ? 0.35 : 0.16))
                    .frame(width: 240, height: 240)
                    .blur(radius: 38)

                RoundedRectangle(cornerRadius: 38, style: .continuous)
                    .fill(MooniColor.surface)
                    .frame(width: 150, height: 220)
                    .overlay(
                        RoundedRectangle(cornerRadius: 38, style: .continuous)
                            .stroke(MooniColor.accentSoft.opacity(0.5), lineWidth: 2)
                    )
                    .overlay(
                        VStack(spacing: 14) {
                            EmojiIcon(emoji: "😴", size: 56, tint: MooniColor.accent)
                            Text("AUTO")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundColor(MooniColor.success)
                                .tracking(2.5)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(MooniColor.success.opacity(0.20))
                                .clipShape(Capsule())
                            Text("tracking")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(MooniColor.textSecondary)
                        }
                    )
                    .scaleEffect(bigIn ? 1 : 0.8)
                    .opacity(bigIn ? 1 : 0)
            }
            .frame(height: 240)

            VStack(spacing: 8) {
                lineRow(emoji: "🚫", text: "No buttons to press")
                lineRow(emoji: "📊", text: "Full report by morning")
            }
            .opacity(subIn ? 1 : 0)
            .offset(y: subIn ? 0 : 10)

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 22)
        .onAppear {
            Haptics.medium()
            withAnimation(.spring(response: 0.65, dampingFraction: 0.72)) { bigIn = true }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { pulse = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 0.45)) { subIn = true }
                Haptics.tick()
            }
        }
    }

    private func lineRow(emoji: String, text: String) -> some View {
        HStack(spacing: 12) {
            EmojiIcon(emoji: emoji, size: 22)
            Text(text)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(MooniColor.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct AutoTrackRemScreen: View {
    @State private var fill: CGFloat = 0
    @State private var statIn = false

    var body: some View {
        VStack(spacing: 26) {
            Spacer(minLength: 8)

            Text.iconHeader("🧠", "EVERY STAGE CAUGHT")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundColor(MooniColor.success)
                .tracking(2)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(MooniColor.success.opacity(0.16))
                .clipShape(Capsule())

            Text("REM & Deep sleep —\ndown to the minute.")
                .font(MooniFont.display(28))
                .foregroundColor(MooniColor.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            // Big circular ring with "87%" — the headline stat
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 16)
                    .frame(width: 200, height: 200)
                Circle()
                    .trim(from: 0, to: fill * 0.87)
                    .stroke(LinearGradient(
                        colors: [MooniColor.success, MooniColor.accentSoft],
                        startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: MooniColor.success.opacity(0.4), radius: 18)

                VStack(spacing: 2) {
                    Text("\(Int(fill * 87))%")
                        .font(.system(size: 64, weight: .heavy, design: .rounded))
                        .foregroundColor(MooniColor.textPrimary)
                        .contentTransition(.numericText())
                    Text("vs. sleep labs")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(MooniColor.success)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(height: 220)

            HStack(spacing: 10) {
                stageChip(emoji: "💭", label: "REM",   tint: MooniColor.accent)
                stageChip(emoji: "☁️", label: "Light", tint: MooniColor.accentSoft)
                stageChip(emoji: "💪", label: "Deep",  tint: MooniColor.success)
            }
            .opacity(statIn ? 1 : 0)
            .offset(y: statIn ? 0 : 10)

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 22)
        .onAppear {
            Haptics.medium()
            withAnimation(.easeOut(duration: 1.4).delay(0.2)) { fill = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { Haptics.success() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 0.5)) { statIn = true }
                Haptics.tick()
            }
        }
    }

    private func stageChip(emoji: String, label: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            EmojiIcon(emoji: emoji, size: 24)
            Text(label)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundColor(tint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(tint.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
    }
}

private struct AutoTrackAccuracyScreen: View {
    @State private var fill: CGFloat = 0
    @State private var headIn = false

    // Lower error = better. SleepOwl tiny bar = winner.
    private let methods: [(emoji: String, name: String, mins: Double, tint: Color)] = [
        ("📓", "Sleep diary",   31.4, MooniColor.danger),
        ("⌚", "Smartwatch",     19.2, MooniColor.warning),
        ("📿", "Fitbit",         16.8, MooniColor.warning),
        ("🦉", "SleepOwl",        7.9, MooniColor.success)
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 8)

            Text.iconHeader("🏆", "WEARABLE-LEVEL INSIGHT")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundColor(MooniColor.success)
                .tracking(2)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(MooniColor.success.opacity(0.16))
                .clipShape(Capsule())

            Text("Designed to rival\nwearable sleep tracking.")
                .font(MooniFont.display(26))
                .foregroundColor(MooniColor.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            VStack(spacing: 10) {
                ForEach(Array(methods.enumerated()), id: \.offset) { idx, m in
                    accuracyBar(emoji: m.emoji, name: m.name, mins: m.mins, tint: m.tint,
                                isWinner: idx == methods.count - 1)
                }
            }
            .opacity(headIn ? 1 : 0)
            .offset(y: headIn ? 0 : 8)

            Text("Many users find it comparable to wearable trackers")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundColor(MooniColor.textMuted)
                .tracking(1.2)

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 22)
        .onAppear {
            Haptics.medium()
            withAnimation(.easeOut(duration: 0.45)) { headIn = true }
            withAnimation(.easeOut(duration: 1.1).delay(0.25)) { fill = 1 }
            for i in 0..<methods.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + Double(i) * 0.12) {
                    Haptics.tick()
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { Haptics.success() }
        }
    }

    private func accuracyBar(emoji: String, name: String, mins: Double,
                             tint: Color, isWinner: Bool) -> some View {
        HStack(spacing: 12) {
            EmojiIcon(emoji: emoji, size: 18, tint: tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(name)
                .font(.system(size: 14, weight: isWinner ? .heavy : .semibold, design: .rounded))
                .foregroundColor(isWinner ? tint : MooniColor.textPrimary)
                .frame(width: 92, alignment: .leading)

            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07))
                    Capsule()
                        .fill(LinearGradient(
                            colors: [tint.opacity(0.75), tint],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: g.size.width * CGFloat(mins / 35.0) * fill)
                }
            }
            .frame(height: 22)

            Text(String(format: "%.1f", mins))
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundColor(tint)
                .frame(width: 44, alignment: .trailing)
            Text("min")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(MooniColor.textMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isWinner ? tint.opacity(0.08) : Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke((isWinner ? tint : Color.white).opacity(isWinner ? 0.32 : 0.06), lineWidth: 1)
        )
    }
}

// MARK: - Fact: Body needs (you vs ideal — dramatic gap)

/// You vs body's need — two huge bars side by side. No FactScaffold, no
/// citation footer, no dense title. Just a gap you can see in 1 second.
private struct BodyFactScreen: View {
    let profile: OnboardingProfile
    @State private var fillYou: CGFloat = 0
    @State private var fillNeed: CGFloat = 0
    @State private var deficitIn = false

    private var idealHours: Double {
        switch profile.age ?? 28 {
        case ..<18: return 9.0
        case 18..<45: return 8.5
        case 45..<65: return 8.0
        default: return 8.0
        }
    }
    private var youHours: Double { profile.typicalSleepHours }
    private var deficit: Double { max(0, idealHours - youHours) }
    private var hasDeficit: Bool { youHours + 0.05 < idealHours }

    var body: some View {
        VStack(spacing: 26) {
            Spacer(minLength: 8)

            Text.iconHeader("🛌", "YOUR BODY'S NEED")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundColor(MooniColor.accentSoft)
                .tracking(2)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(MooniColor.accent.opacity(0.16))
                .clipShape(Capsule())

            Text(hasDeficit ? "You're not sleeping\nenough." : "Close — but not quite\nthere yet.")
                .font(MooniFont.display(28))
                .foregroundColor(MooniColor.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            // Two huge vertical bars
            HStack(alignment: .bottom, spacing: 40) {
                bigBar(label: "You",
                       hours: youHours,
                       fill: fillYou,
                       tint: hasDeficit ? MooniColor.danger : MooniColor.success,
                       emoji: hasDeficit ? "😴" : "🙂")
                bigBar(label: "Need",
                       hours: idealHours,
                       fill: fillNeed,
                       tint: MooniColor.success,
                       emoji: "🌟")
            }
            .frame(height: 220)

            // Deficit callout
            HStack(spacing: 8) {
                Text(hasDeficit ? "⚠️" : "💡")
                    .font(.system(size: 20))
                Text(hasDeficit
                     ? "That's **\(Int(deficit * 365)) hours** stolen every year"
                     : "Your night still has hidden gaps we'll find")
                    .font(MooniFont.body(13))
                    .foregroundColor(MooniColor.textPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background((hasDeficit ? MooniColor.danger : MooniColor.warning).opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(deficitIn ? 1 : 0)
            .scaleEffect(deficitIn ? 1 : 0.85)

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 22)
        .onAppear {
            Haptics.medium()
            withAnimation(.easeOut(duration: 1.1).delay(0.2)) {
                fillYou = CGFloat(youHours / idealHours)
            }
            withAnimation(.easeOut(duration: 1.1).delay(0.5)) {
                fillNeed = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                    deficitIn = true
                }
                hasDeficit ? Haptics.warning() : Haptics.success()
            }
        }
    }

    private func bigBar(label: String, hours: Double, fill: CGFloat,
                        tint: Color, emoji: String) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 90, height: 180)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(
                        colors: [tint.opacity(0.65), tint],
                        startPoint: .top, endPoint: .bottom))
                    .frame(width: 90, height: 180 * fill)
                VStack(spacing: 2) {
                    EmojiIcon(emoji: emoji, size: 28)
                    Text(String(format: "%.1f", hours))
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Text("hours")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(.bottom, 14)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(tint.opacity(0.4), lineWidth: 1.5)
            )
            Text(label)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundColor(tint)
        }
    }
}

// MARK: - Fact: Sleep debt (compounds across the week)

/// Sleep debt — ONE giant count-up number is the whole screen.
/// "X hours lost per year." That's the punch.
/// Sleep debt — now a 4-page tap-through. Page 0 is the punchy count-up,
/// then pages 1-3 translate the lost hours into things the user could've
/// done: money earned, life experiences, skills learned. Parent owns `page`
/// so the outer Continue button drives the reveal.
private struct SleepDebtFactScreen: View {
    let profile: OnboardingProfile
    @Binding var page: Int

    static let pageCount: Int = 4

    @State private var headIn = false
    @State private var subIn = false

    private var idealHours: Double {
        switch profile.age ?? 28 {
        case ..<18: return 9.0
        case 18..<45: return 8.5
        case 45..<65: return 8.0
        default: return 8.0
        }
    }
    private var rawDeficit: Double { idealHours - profile.typicalSleepHours }
    private var hasDebt: Bool { rawDeficit > 0.25 }
    private var dailyDeficit: Double { max(0.25, rawDeficit) }
    private var yearTotal: Double { hasDebt ? dailyDeficit * 365 : 231 }

    // Conversion helpers — translate "X hours" into concrete possibilities.
    private var moneyDollars: Int { Int(yearTotal * 25) }            // $25/hr productivity proxy
    private var weeksOfTravel: Int { max(1, Int(yearTotal / 168)) }  // 1 week ≈ 168 h
    private var marathons: Int    { max(1, Int(yearTotal / 16)) }    // ~16h to train one
    private var booksRead: Int    { max(2, Int(yearTotal / 6)) }     // ~6h avg book
    private var newSkills: Int    { max(1, Int(yearTotal / 120)) }   // ~120h to learn a hobby

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 4)

            // Header — chip is consistent, title is per-page
            Text(chipForPage)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundColor(chipTint)
                .tracking(2)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(chipTint.opacity(0.16))
                .clipShape(Capsule())

            Text(headlineForPage)
                .font(MooniFont.display(28))
                .foregroundColor(MooniColor.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .id("debt-head-\(page)")
                .transition(.opacity.combined(with: .move(edge: .top)))

            // Per-page focal visual
            ZStack {
                switch page {
                case 0: page0Visual
                case 1: page1Visual
                case 2: page2Visual
                default: page3Visual
                }
            }
            .frame(height: 220)
            .id("debt-visual-\(page)")
            .transition(pageTransition)

            // Per-page support line
            Text(takeawayForPage)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(MooniColor.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 14)
                .id("debt-take-\(page)")
                .transition(.opacity)

            // Page dots
            HStack(spacing: 6) {
                ForEach(0..<Self.pageCount, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? MooniColor.accent : Color.white.opacity(0.22))
                        .frame(width: i == page ? 22 : 7, height: 6)
                }
            }
            .padding(.top, 2)

            Spacer(minLength: 4)
        }
        .padding(.horizontal, 22)
        .onAppear {
            Haptics.medium()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { headIn = true }
            withAnimation(.easeOut(duration: 0.5).delay(0.45)) { subIn = true }
        }
        .onChange(of: page) { _, _ in
            Haptics.medium()
        }
    }

    private var pageTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.9)).combined(with: .move(edge: .trailing)),
            removal:   .opacity.combined(with: .scale(scale: 0.9)).combined(with: .move(edge: .leading))
        )
    }

    private var chipForPage: String {
        switch page {
        case 0:  return hasDebt ? "💸 SLEEP DEBT" : "💨 HIDDEN LOSSES"
        case 1:  return "💰 IN MONEY"
        case 2:  return "🌍 IN EXPERIENCES"
        default: return "📚 IN GROWTH"
        }
    }

    private var chipTint: Color {
        switch page {
        case 0:  return hasDebt ? MooniColor.danger : MooniColor.warning
        case 1:  return MooniColor.success
        case 2:  return MooniColor.accentSoft
        default: return MooniColor.accent
        }
    }

    private var headlineForPage: String {
        switch page {
        case 0:  return hasDebt ? "You're losing\nhours every year." : "Hidden gaps add\nup to a lot."
        case 1:  return "That's like burning\nyour paycheck."
        case 2:  return "Or weeks of life\nyou never get back."
        default: return "Or the version of you\nyou never became."
        }
    }

    private var takeawayForPage: String {
        switch page {
        case 0:  return "Tiny nightly gaps stack up. By year-end, it's a stack you didn't realise you paid."
        case 1:  return "At $25/hour, that's money you didn't earn — every single year."
        case 2:  return "Imagine taking that time back. Trips, runs, weekends — actual life."
        default: return "Books, languages, hobbies. Sleep gives you the energy to learn them."
        }
    }

    // MARK: Page 0 — big count-up (faster)
    private var page0Visual: some View {
        VStack(spacing: 6) {
            CountUpText(
                target: yearTotal,
                duration: 1.2,
                format: { String(format: "%.0f", $0) },
                font: .system(size: 120, weight: .heavy, design: .rounded),
                color: hasDebt ? MooniColor.danger : MooniColor.warning,
                glow: hasDebt ? MooniColor.danger : MooniColor.warning
            )
            Text("HOURS PER YEAR")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundColor(MooniColor.textMuted)
                .tracking(2)
        }
    }

    // MARK: Page 1 — money
    private var page1Visual: some View {
        VStack(spacing: 12) {
            Text("$")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundColor(MooniColor.success)
                + Text(formatMoney(moneyDollars))
                .font(.system(size: 86, weight: .heavy, design: .rounded))
                .foregroundColor(MooniColor.success)
            Text("YOU DIDN'T EARN")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundColor(MooniColor.textMuted)
                .tracking(1.6)
            HStack(spacing: 16) {
                emojiBadge("💵")
                emojiBadge("💸")
                emojiBadge("📈")
            }
        }
    }

    // MARK: Page 2 — experiences
    private var page2Visual: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                experienceCard(emoji: "✈️", number: weeksOfTravel,
                               label: weeksOfTravel == 1 ? "week of travel" : "weeks of travel",
                               tint: MooniColor.accent)
                experienceCard(emoji: "🏃", number: marathons,
                               label: marathons == 1 ? "marathon trained" : "marathons trained",
                               tint: MooniColor.warning)
            }
            HStack(spacing: 12) {
                experienceCard(emoji: "🎬", number: max(2, Int(yearTotal / 2)),
                               label: "movies watched", tint: Color.pink)
                experienceCard(emoji: "🎮", number: max(5, Int(yearTotal / 4)),
                               label: "game sessions", tint: MooniColor.success)
            }
        }
    }

    // MARK: Page 3 — skills / growth
    private var page3Visual: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                experienceCard(emoji: "📚", number: booksRead,
                               label: booksRead == 1 ? "book read" : "books read",
                               tint: MooniColor.accent)
                experienceCard(emoji: "🎸", number: newSkills,
                               label: newSkills == 1 ? "new skill" : "new skills",
                               tint: MooniColor.success)
            }
            HStack(spacing: 12) {
                experienceCard(emoji: "🗣️", number: max(1, Int(yearTotal / 600)),
                               label: "languages started", tint: MooniColor.accentSoft)
                experienceCard(emoji: "🧘", number: max(10, Int(yearTotal / 0.5)),
                               label: "meditations done", tint: Color.pink)
            }
        }
    }

    // MARK: Helpers

    private func formatMoney(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private func emojiBadge(_ e: String) -> some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 50, height: 50)
            EmojiIcon(emoji: e, size: 22, tint: MooniColor.accentSoft)
        }
    }

    private func experienceCard(emoji: String, number: Int, label: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            EmojiIcon(emoji: emoji, size: 26)
            VStack(alignment: .leading, spacing: -2) {
                Text("\(number)")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(tint)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(label)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(MooniColor.textMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(tint.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
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

// MARK: - Outcome vision (Cali-style: show the transformed YOU, not features)

/// Before → after "you". Big emotional payoff, two-week framing. Sells the
/// outcome, never the mechanism.
private struct OutcomeImagineScreen: View {
    @State private var titleIn = false
    @State private var afterIn = false
    @State private var glow = false

    var body: some View {
        VStack(spacing: 26) {
            Spacer(minLength: 8)

            VStack(spacing: 10) {
                Text.iconHeader("✨", "TWO WEEKS FROM NOW")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(MooniColor.accent)
                    .tracking(2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(MooniColor.accent.opacity(0.16))
                    .clipShape(Capsule())

                Text("Imagine waking up\nactually rested.")
                    .font(MooniFont.display(30))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .opacity(titleIn ? 1 : 0)
            .offset(y: titleIn ? 0 : 8)

            HStack(spacing: 14) {
                outcomeFace(emoji: "😩", label: "Today", tint: MooniColor.danger,
                            highlighted: false, visible: titleIn)
                Image(systemName: "arrow.right")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(MooniColor.textSecondary)
                    .opacity(afterIn ? 1 : 0)
                outcomeFace(emoji: "🤩", label: "In 2 weeks", tint: MooniColor.success,
                            highlighted: true, visible: afterIn)
            }

            Text("Not the app — *you*. This is what changes.")
                .font(MooniFont.body(14))
                .foregroundColor(MooniColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .opacity(afterIn ? 1 : 0)

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 22)
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) { titleIn = true }
            Haptics.medium()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { afterIn = true }
                Haptics.tick()
            }
            glow = true
        }
    }

    private func outcomeFace(emoji: String, label: String, tint: Color,
                             highlighted: Bool, visible: Bool) -> some View {
        VStack(spacing: 10) {
            Text(emoji)
                .font(.system(size: 52))
                .frame(width: 104, height: 104)
                .background(tint.opacity(highlighted ? 0.22 : 0.12))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(tint.opacity(highlighted ? 0.55 : 0.2),
                                lineWidth: highlighted ? 2 : 1)
                )
                .shadow(color: highlighted ? tint.opacity(glow ? 0.5 : 0.2) : .clear,
                        radius: highlighted ? 18 : 0)
                .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true),
                           value: glow)
            Text(label)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(highlighted ? tint : MooniColor.textSecondary)
        }
        .opacity(visible ? 1 : 0)
        .scaleEffect(visible ? 1 : 0.85)
    }
}

/// Outcome — your mornings. Each row is a *result the user lives*, not a feature.
private struct OutcomeMorningsScreen: View {
    @State private var titleIn = false
    @State private var revealed = 0

    private let wins: [(String, String, Color)] = [
        ("⏰", "Up before the alarm",      MooniColor.accent),
        ("🛌", "No more snooze battles",   MooniColor.success),
        ("🧠", "Clear head in minutes",    MooniColor.warning),
        ("☀️", "Out the door, awake",      Color.orange)
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 8)

            VStack(spacing: 10) {
                Text.iconHeader("🌅", "WHAT YOU GET BACK")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(MooniColor.accent)
                    .tracking(2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(MooniColor.accent.opacity(0.16))
                    .clipShape(Capsule())

                Text("Your mornings,\nrebuilt.")
                    .font(MooniFont.display(30))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .opacity(titleIn ? 1 : 0)
            .offset(y: titleIn ? 0 : 8)

            VStack(spacing: 12) {
                ForEach(Array(wins.enumerated()), id: \.offset) { idx, w in
                    OutcomeRow(emoji: w.0, label: w.1, tint: w.2,
                               visible: idx < revealed)
                }
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 22)
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) { titleIn = true }
            Haptics.medium()
            for i in 0..<wins.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35 + 0.18 * Double(i)) {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                        revealed = i + 1
                    }
                    Haptics.tick()
                }
            }
        }
    }
}

/// Outcome — your days. The downstream payoff of the rebuilt mornings.
private struct OutcomeDaysScreen: View {
    @State private var titleIn = false
    @State private var revealed = 0

    private let wins: [(String, String, Color)] = [
        ("🔋", "Energy that lasts till night", MooniColor.success),
        ("🎯", "Locked-in focus",              MooniColor.accent),
        ("😄", "Lighter, steadier mood",       Color.pink),
        ("🫶", "Present with people you love", MooniColor.warning)
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 8)

            VStack(spacing: 10) {
                Text.iconHeader("🌤️", "AND IT KEEPS GOING")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(MooniColor.success)
                    .tracking(2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(MooniColor.success.opacity(0.16))
                    .clipShape(Capsule())

                Text("Your days,\nrecharged.")
                    .font(MooniFont.display(30))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .opacity(titleIn ? 1 : 0)
            .offset(y: titleIn ? 0 : 8)

            VStack(spacing: 12) {
                ForEach(Array(wins.enumerated()), id: \.offset) { idx, w in
                    OutcomeRow(emoji: w.0, label: w.1, tint: w.2,
                               visible: idx < revealed)
                }
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 22)
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) { titleIn = true }
            Haptics.medium()
            for i in 0..<wins.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35 + 0.18 * Double(i)) {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                        revealed = i + 1
                    }
                    Haptics.tick()
                }
            }
        }
    }
}

/// Aspirational close — names the transformed self and ties it to SleepOwl,
/// then commits: it starts tonight.
private struct OutcomeFutureScreen: View {
    @State private var glow = false
    @State private var textIn = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 8)

            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [MooniColor.accent.opacity(glow ? 0.45 : 0.2), .clear],
                        center: .center, startRadius: 4, endRadius: 180))
                    .frame(width: 280, height: 280)
                    .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true),
                               value: glow)
                Image("owl_base")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 132, height: 132)
                    .scaleEffect(glow ? 1.04 : 0.98)
                    .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true),
                               value: glow)
            }

            VStack(spacing: 12) {
                Text("This is the you\nSleepOwl builds.")
                    .font(MooniFont.display(30))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                Text("Rested. Sharp. Present.")
                    .font(MooniFont.title(16))
                    .foregroundColor(MooniColor.accent)

                Text("And it starts tonight.")
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textSecondary)
            }
            .opacity(textIn ? 1 : 0)
            .offset(y: textIn ? 0 : 10)

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 24)
        .onAppear {
            glow = true
            withAnimation(.easeOut(duration: 0.55).delay(0.2)) { textIn = true }
            Haptics.medium()
        }
    }
}

private struct OutcomeRow: View {
    let emoji: String
    let label: String
    let tint: Color
    let visible: Bool

    var body: some View {
        HStack(spacing: 16) {
            EmojiIcon(emoji: emoji, size: 26, tint: tint)
                .frame(width: 56, height: 56)
                .background(tint.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text(label)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundColor(MooniColor.textPrimary)
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(tint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        )
        .opacity(visible ? 1 : 0)
        .offset(x: visible ? 0 : -16)
    }
}

// MARK: - Screen S3: Identity damage

/// 4 BIG emoji cards (down from 6 mixed icons). One line per card. Daily-life
/// impact stated plainly — no "quietly bleeds" copy.
private struct IdentityDamageScreen: View {
    @State private var revealed = 0

    private let items: [(String, String, String)] = [
        ("⚡", "Energy",   "You crash every afternoon"),
        ("💪", "Workouts", "Gains take twice as long"),
        ("🧠", "Work",     "30-min tasks turn into 90"),
        ("😠", "Mood",     "Small things set you off"),
        ("🍔", "Weight",   "Belly fat & bloating creep in")
    ]

    var body: some View {
        OnboardingScaffold(
            eyebrow: ("⚠️", "It's not just nights"),
            title: "Bad sleep ruins\nyour whole day."
        ) {
            VStack(spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    OBCard(emoji: item.0, title: item.1, subtitle: item.2,
                           visible: idx < revealed)
                }
            }
        }
        .onAppear {
            Haptics.medium()
            for i in 0..<items.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + 0.16 * Double(i)) {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                        revealed = i + 1
                    }
                    Haptics.tick()
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
        VStack(spacing: 14) {
            Text.iconHeader("🧬", "PATTERN MATCH")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundColor(MooniColor.accentSoft)
                .tracking(2)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(MooniColor.accent.opacity(0.16))
                .clipShape(Capsule())
                .opacity(badgeVisible ? 1 : 0)
                .scaleEffect(badgeVisible ? 1 : 0.85)

            Text("Here's what we see\nin people like you.")
                .font(MooniFont.display(24))
                .foregroundColor(MooniColor.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(0)
                .opacity(badgeVisible ? 1 : 0)

            // Single horizontal row — dim peers framing YOU. No rings, nothing
            // overlapping, nothing fighting for space. Reads instantly.
            if let m = profile.motivation {
                HStack(spacing: 14) {
                    peerAvatar(emoji: "🙂", tint: MooniColor.accentSoft)
                    peerAvatar(emoji: "😴", tint: MooniColor.accent)
                    youBadge(icon: m.icon)
                    peerAvatar(emoji: "😊", tint: MooniColor.success)
                    peerAvatar(emoji: "🌙", tint: MooniColor.warning)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .opacity(badgeVisible ? 1 : 0)
            }

            // Typed insight card — narrower, cleaner
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(MooniColor.success)
                        .font(.system(size: 12))
                    Text("BASED ON YOUR ANSWERS")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(MooniColor.textMuted)
                        .tracking(1.4)
                }
                Text(typed)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(MooniColor.textPrimary)
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(MooniColor.accent.opacity(0.22), lineWidth: 1)
            )
            .opacity(cardVisible ? 1 : 0)
            .offset(y: cardVisible ? 0 : 12)
        }
        .padding(.horizontal, 22)
        .onAppear {
            Haptics.soft()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) { badgeVisible = true }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.3)) { cardVisible = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { Haptics.tick() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { animateType() }
        }
    }

    private func peerAvatar(emoji: String, tint: Color) -> some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.10))
                .frame(width: 40, height: 40)
            EmojiIcon(emoji: emoji, size: 16, tint: tint)
                .opacity(0.55)
        }
    }

    private func youBadge(icon: String) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(MooniColor.accent.opacity(0.24))
                    .frame(width: 64, height: 64)
                Circle()
                    .stroke(MooniColor.accent, lineWidth: 1.5)
                    .frame(width: 64, height: 64)
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(MooniColor.accentSoft)
            }
            Text("YOU")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundColor(MooniColor.accent)
                .tracking(2)
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

// MARK: - Screen: Body studies (hormones / growth / brain / heart / immunity / quality)

/// Tap-through showcase of the WHY-it-matters science: every Continue tap
/// reveals one big-stat study card. Each card follows the kid-simple template
/// (emoji chip → big number → one line → one visual). Six cards in total:
/// growth hormone, testosterone, cortisol, brain detox, heart, quality vs.
/// quantity. Drives conversion by making "bad sleep is silently destroying
/// my body" concrete and personal.
private struct BodyStudiesScreen: View {
    @Binding var page: Int

    static let pageCount: Int = 8

    var body: some View {
        VStack(spacing: 10) {
            // Top chip — same on every page so it's the visual anchor
            Text.iconHeader("🧬", "WHILE YOU SLEEP")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundColor(MooniColor.accentSoft)
                .tracking(2)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(MooniColor.accent.opacity(0.16))
                .clipShape(Capsule())

            // Headline (per-page)
            Text(headlineForPage)
                .font(MooniFont.display(24))
                .foregroundColor(MooniColor.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(0)
                .minimumScaleFactor(0.8)
                .lineLimit(2)
                .padding(.horizontal, 4)
                .id("body-head-\(page)")
                .transition(.opacity.combined(with: .move(edge: .top)))

            // Per-page visual — give it a fixed band so transitions don't
            // jump the headline up/down between pages.
            ZStack {
                switch page {
                case 0: gh
                case 1: teenHeight
                case 2: adultSpine
                case 3: testo
                case 4: cortisol
                case 5: brain
                case 6: heart
                default: quality
                }
            }
            .frame(height: 220)
            .id("body-visual-\(page)")
            .transition(pageTransition)

            // Per-page takeaway
            Text(takeawayForPage)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(MooniColor.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(1)
                .padding(.horizontal, 14)
                .id("body-take-\(page)")
                .transition(.opacity)

            // Source pill — kept tiny so it's "we cite this" not "wall of text"
            Text(sourceForPage)
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .foregroundColor(MooniColor.textMuted)
                .tracking(1.2)
                .id("body-source-\(page)")

            // Page dots — same pattern as widgets/sleep-circle
            HStack(spacing: 6) {
                ForEach(0..<Self.pageCount, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? MooniColor.accent : Color.white.opacity(0.22))
                        .frame(width: i == page ? 22 : 7, height: 6)
                }
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 22)
        .onChange(of: page) { _, _ in
            Haptics.medium()
        }
    }

    private var pageTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.9)).combined(with: .move(edge: .trailing)),
            removal:   .opacity.combined(with: .scale(scale: 0.9)).combined(with: .move(edge: .leading))
        )
    }

    private var headlineForPage: String {
        switch page {
        case 0: return "Growth hormone drops 70%."
        case 1: return "Short sleepers stay 2 cm shorter."
        case 2: return "You shrink 1.5 cm every day."
        case 3: return "Testosterone crashes 15%."
        case 4: return "Stress hormone spikes 37%."
        case 5: return "Your brain stops cleaning itself."
        case 6: return "Heart attack risk climbs 48%."
        default: return "Hours don't matter if quality is broken."
        }
    }

    private var takeawayForPage: String {
        switch page {
        case 0: return "Most growth hormone is released during deep sleep. Skip it and recovery, repair, and lean mass all suffer."
        case 1: return "Kids and teens who sleep less than 8 hours end up measurably shorter as adults. Growth literally happens at night."
        case 2: return "Your spine compresses while you stand. Deep sleep is when discs rehydrate and you get those centimeters back."
        case 3: return "One week of 5-hour nights drops testosterone like aging 10 years. Energy, muscle, mood — all hit."
        case 4: return "Bad sleep raises cortisol the next day. Belly fat, anxiety, and high blood pressure follow."
        case 5: return "Deep sleep flushes brain waste (the same gunk linked to dementia). Cut sleep, cut the cleanup."
        case 6: return "Sleeping under 6 hours raises heart attack risk by nearly half. It's the highest-impact heart habit you have."
        default: return "Two people sleeping 7 hours can have totally different recovery — fragmentation matters more than the number."
        }
    }

    private var sourceForPage: String {
        switch page {
        case 0: return "VAN CAUTER · ENDOCRINOLOGY · 2000"
        case 1: return "JENNI ET AL · PEDIATRICS · 2007"
        case 2: return "TYRRELL ET AL · SPINE · 1985"
        case 3: return "LEPROULT & VAN CAUTER · JAMA · 2011"
        case 4: return "LEPROULT ET AL · SLEEP · 1997"
        case 5: return "XIE ET AL · SCIENCE · 2013"
        case 6: return "AYAS ET AL · ARCH INTERN MED · 2003"
        default: return "BERRY ET AL · AASM SCORING · v3"
        }
    }

    // MARK: Per-page visuals — each is one focal element, no clutter

    private var gh: some View {
        bigStatBlock(value: "−70%", label: "growth hormone", tint: MooniColor.danger,
                     supportingEmojis: ["💪", "🩸", "🌙"])
    }

    /// Teen-height visual — two stick figures side by side, "good sleeper"
    /// vs "short sleeper", with the latter visibly shorter. The 2 cm gap is
    /// the real-world average from the Jenni et al. pediatric cohort.
    private var teenHeight: some View {
        HStack(alignment: .bottom, spacing: 40) {
            heightFigure(emoji: "🧑", barFillHeight: 130,
                         label: "8+ hrs",
                         stat: "Avg",
                         tint: MooniColor.success)
            heightFigure(emoji: "🧑", barFillHeight: 110,
                         label: "<6 hrs",
                         stat: "−2 cm",
                         tint: MooniColor.danger)
        }
        .frame(maxWidth: .infinity)
    }

    /// Adult-spine visual — a stylised spine that compresses through the day
    /// and decompresses overnight, with the 1.5 cm daily figure called out.
    private var adultSpine: some View {
        HStack(alignment: .bottom, spacing: 18) {
            spineColumn(label: "Morning", height: 130, tint: MooniColor.success, emoji: "☀️")
            Image(systemName: "arrow.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(MooniColor.textMuted)
                .padding(.bottom, 50)
            spineColumn(label: "Evening", height: 108, tint: MooniColor.warning, emoji: "🌆")
        }
        .frame(maxWidth: .infinity)
    }

    private func heightFigure(emoji: String, barFillHeight: CGFloat, label: String,
                              stat: String, tint: Color) -> some View {
        // Fixed total height of 180 so neither column drifts. Stat ABOVE
        // emoji ABOVE bar, label below — strict order, no overlap.
        VStack(spacing: 6) {
            Text(stat)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundColor(tint)
            EmojiIcon(emoji: emoji, size: 20)
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 52, height: 130)
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(
                        colors: [tint.opacity(0.65), tint],
                        startPoint: .top, endPoint: .bottom))
                    .frame(width: 52, height: barFillHeight)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(tint.opacity(0.35), lineWidth: 1)
            )
            Text(label)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundColor(MooniColor.textPrimary)
        }
    }

    private func spineColumn(label: String, height: CGFloat, tint: Color,
                             emoji: String) -> some View {
        VStack(spacing: 6) {
            EmojiIcon(emoji: emoji, size: 18)
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 28, height: height)
                VStack(spacing: 2) {
                    ForEach(0..<6, id: \.self) { _ in
                        Capsule()
                            .fill(tint.opacity(0.85))
                            .frame(width: 22, height: max(8, (height - 18) / 6 - 2))
                    }
                }
            }
            Text(label)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundColor(tint)
        }
    }

    private var testo: some View {
        bigStatBlock(value: "−15%", label: "testosterone in 7 days", tint: MooniColor.danger,
                     supportingEmojis: ["⚡", "💪", "🧠"])
    }

    private var cortisol: some View {
        // Cortisol curve — animated rising line
        VStack(spacing: 10) {
            Text("+37%")
                .font(.system(size: 76, weight: .heavy, design: .rounded))
                .foregroundColor(MooniColor.warning)
                .shadow(color: MooniColor.warning.opacity(0.4), radius: 18)
            Text("CORTISOL THE NEXT DAY")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundColor(MooniColor.textMuted)
                .tracking(1.6)
            HStack(spacing: 18) {
                emojiBadge("😬")
                emojiBadge("🍔")
                emojiBadge("📈")
            }
        }
    }

    private var brain: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(MooniColor.accent.opacity(0.15))
                    .frame(width: 180, height: 180)
                EmojiIcon(emoji: "🧠", size: 90, tint: MooniColor.accent)
                // Tiny "waste" particles around the brain
                ForEach(0..<6, id: \.self) { i in
                    Text("·")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(MooniColor.danger.opacity(0.5))
                        .offset(x: 70 * cos(Double(i) * .pi / 3),
                                y: 70 * sin(Double(i) * .pi / 3))
                }
            }
            Text("60%  more waste cleared in deep sleep")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(MooniColor.accentSoft)
        }
    }

    private var heart: some View {
        VStack(spacing: 10) {
            Text("+48%")
                .font(.system(size: 76, weight: .heavy, design: .rounded))
                .foregroundColor(MooniColor.danger)
                .shadow(color: MooniColor.danger.opacity(0.4), radius: 18)
            Text("HEART ATTACK RISK")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundColor(MooniColor.textMuted)
                .tracking(1.6)
            EmojiIcon(emoji: "❤", size: 52, tint: MooniColor.danger)
        }
    }

    private var quality: some View {
        // Two bars — "looks the same" 7h, but different recovery
        VStack(spacing: 14) {
            HStack(alignment: .bottom, spacing: 26) {
                qualityCol(emoji: "🟢", label: "Good\nsleep",  fillPct: 1.0,  tint: MooniColor.success,
                           subtext: "7 hrs · 0 wake-ups")
                qualityCol(emoji: "🔴", label: "Broken\nsleep", fillPct: 0.45, tint: MooniColor.danger,
                           subtext: "7 hrs · 12 wake-ups")
            }
            .frame(height: 170)

            Text("Both slept 7 h. Only one feels rested.")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(MooniColor.textSecondary)
        }
    }

    // MARK: Visual helpers

    private func bigStatBlock(value: String, label: String, tint: Color,
                              supportingEmojis: [String]) -> some View {
        VStack(spacing: 10) {
            Text(value)
                .font(.system(size: 88, weight: .heavy, design: .rounded))
                .foregroundColor(tint)
                .shadow(color: tint.opacity(0.4), radius: 18)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label.uppercased())
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundColor(MooniColor.textMuted)
                .tracking(1.6)
                .multilineTextAlignment(.center)
            HStack(spacing: 18) {
                ForEach(supportingEmojis, id: \.self) { e in emojiBadge(e) }
            }
        }
    }

    private func emojiBadge(_ e: String) -> some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 50, height: 50)
            EmojiIcon(emoji: e, size: 22, tint: MooniColor.accentSoft)
        }
    }

    private func qualityCol(emoji: String, label: String, fillPct: CGFloat,
                            tint: Color, subtext: String) -> some View {
        VStack(spacing: 6) {
            EmojiIcon(emoji: emoji, size: 22)
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 86, height: 120)
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(
                        colors: [tint.opacity(0.7), tint],
                        startPoint: .top, endPoint: .bottom))
                    .frame(width: 86, height: 120 * fillPct)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(tint.opacity(0.35), lineWidth: 1)
            )
            Text(label)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(tint)
                .multilineTextAlignment(.center)
            Text(subtext)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(MooniColor.textMuted)
                .multilineTextAlignment(.center)
        }
    }
}

/// Sleep Circle showcase — 3 paged screens explaining the "share sleep with
/// your friends" feature. Each page is dead-simple: ONE big visual + ONE
/// sentence. The parent's Continue button drives paging via `page` binding.
private struct FeatureTourScreen: View {
    let petName: String
    @Binding var page: Int

    static let pageCount: Int = 3

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 10) {
                Text.iconHeader("👯", "SLEEP CIRCLE")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(MooniColor.accentSoft)
                    .tracking(2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(MooniColor.accent.opacity(0.16))
                    .clipShape(Capsule())

                Text(headlineForPage)
                    .font(MooniFont.display(28))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .id("circle-head-\(page)")
                    .transition(.opacity.combined(with: .move(edge: .top)))

                Text(blurbForPage)
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .id("circle-blurb-\(page)")
                    .transition(.opacity)
            }

            ZStack {
                if page == 0 { invitePage.transition(pageTransition) }
                else if page == 1 { comparePage.transition(pageTransition) }
                else { racePage.transition(pageTransition) }
            }
            .frame(height: 260)

            HStack(spacing: 6) {
                ForEach(0..<Self.pageCount, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? MooniColor.accent : Color.white.opacity(0.22))
                        .frame(width: i == page ? 22 : 7, height: 6)
                }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 18)
    }

    private var pageTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.9)).combined(with: .move(edge: .trailing)),
            removal:   .opacity.combined(with: .scale(scale: 0.9)).combined(with: .move(edge: .leading))
        )
    }

    private var headlineForPage: String {
        switch page {
        case 0:  return "Invite your\nbest friend."
        case 1:  return "See whose sleep\nwon last night."
        default: return "Cheer when they\nbeat their best."
        }
    }

    private var blurbForPage: String {
        switch page {
        case 0:  return "Tap a button. They get a link. You're in their Sleep Circle."
        case 1:  return "Side-by-side scores, side-by-side bedtime. Every morning."
        default: return "When they beat their record, your phone celebrates with them."
        }
    }

    // MARK: Pages

    private var invitePage: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(MooniColor.accent.opacity(0.18))
                    .frame(width: 220, height: 220)
                    .blur(radius: 30)

                HStack(spacing: -16) {
                    avatarBig(letter: "Y", tint: MooniColor.success, label: "You")
                    avatarBig(letter: "+", tint: MooniColor.accent, label: "Invite", isInvite: true)
                }
            }
            .frame(height: 200)

            HStack(spacing: 6) {
                Image(systemName: "link")
                    .font(.system(size: 12, weight: .bold))
                Text("share.sleepowl.app/yourname")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
            }
            .foregroundColor(MooniColor.accentSoft)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(MooniColor.accent.opacity(0.12))
            .clipShape(Capsule())
        }
    }

    private var comparePage: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                friendCompareCard(
                    initial: "Y", name: "You",
                    score: 84, scoreTint: MooniColor.success,
                    duration: "7h 24m", isWinner: true
                )
                friendCompareCard(
                    initial: "A", name: "Alex",
                    score: 76, scoreTint: MooniColor.warning,
                    duration: "6h 51m", isWinner: false
                )
                friendCompareCard(
                    initial: "M", name: "Mia",
                    score: 71, scoreTint: MooniColor.warning,
                    duration: "6h 30m", isWinner: false
                )
            }
            .padding(.horizontal, 4)

            HStack(spacing: 6) {
                EmojiIcon(emoji: "🏆", size: 14, tint: MooniColor.warning)
                Text("You won last night")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(MooniColor.textPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(MooniColor.warning.opacity(0.16))
            .clipShape(Capsule())
        }
    }

    private var racePage: some View {
        VStack(spacing: 14) {
            // Phone notification mock
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient(
                            colors: [MooniColor.accent, MooniColor.accentSoft],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)
                    EmojiIcon(emoji: "🎉", size: 20, tint: MooniColor.warning)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("SleepOwl")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundColor(MooniColor.textPrimary)
                        Spacer()
                        Text("now")
                            .font(.system(size: 11))
                            .foregroundColor(MooniColor.textMuted)
                    }
                    Text("Alex just hit a 91 — their best night ever")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(MooniColor.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(MooniColor.accent.opacity(0.3), lineWidth: 1)
            )

            HStack(spacing: 14) {
                cheerChip(emoji: "🔥", label: "Streak")
                cheerChip(emoji: "💪", label: "Cheer")
                cheerChip(emoji: "🏆", label: "Beat record")
            }
        }
    }

    private func avatarBig(letter: String, tint: Color, label: String, isInvite: Bool = false) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 6)
                    .frame(width: 110, height: 110)
                if !isInvite {
                    Circle()
                        .trim(from: 0, to: 0.84)
                        .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 110, height: 110)
                        .rotationEffect(.degrees(-90))
                }
                Circle()
                    .fill(tint.opacity(isInvite ? 0.20 : 0.30))
                    .frame(width: 88, height: 88)
                Text(letter)
                    .font(.system(size: isInvite ? 48 : 42, weight: .heavy, design: .rounded))
                    .foregroundColor(isInvite ? MooniColor.accentSoft : MooniColor.textPrimary)
            }
            Text(label)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(isInvite ? MooniColor.accentSoft : MooniColor.textPrimary)
        }
    }

    private func friendCompareCard(initial: String, name: String, score: Int,
                                   scoreTint: Color, duration: String, isWinner: Bool) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 5)
                    .frame(width: 66, height: 66)
                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100)
                    .stroke(scoreTint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 66, height: 66)
                    .rotationEffect(.degrees(-90))
                VStack(spacing: -2) {
                    Text("\(score)")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(scoreTint)
                }
                if isWinner {
                    EmojiIcon(emoji: "🏆", size: 18, tint: MooniColor.warning)
                        .offset(x: 28, y: -28)
                }
            }
            Text(name)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(MooniColor.textPrimary)
            Text(duration)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(MooniColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background(Color.white.opacity(isWinner ? 0.07 : 0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke((isWinner ? MooniColor.warning : Color.white).opacity(isWinner ? 0.45 : 0.10), lineWidth: 1)
        )
    }

    private func cheerChip(emoji: String, label: String) -> some View {
        VStack(spacing: 4) {
            EmojiIcon(emoji: emoji, size: 26)
            Text(label)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundColor(MooniColor.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MooniColor.accent.opacity(0.2), lineWidth: 1)
        )
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
