import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Binding var showPaywall: Bool

    @StateObject private var healthKit = HealthKitManager.shared
    @StateObject private var streak = StreakManager.shared
    @State private var showWindDown = false
    @State private var showStartSleep = false
    @State private var showWhy = false
    @State private var showRecoveryPlan = false
    @State private var showLostStreak = false
    @State private var showAutoWakeUp = false
    @State private var showSleepStory = false
    @State private var showManualOptions = false
    @State private var showInviteFriends = false
    @State private var showFallAsleepSheet = false

    /// Currently-displayed speech bubble text. Set by `handleOwlTap()` after
    /// the user taps the hero owl; auto-clears after a short delay. nil
    /// means no bubble is showing.
    @State private var heroSpeech: String?
    @State private var heroSpeechToken: UUID = UUID()

    /// In-flight celebration toast (level-up / streak milestone / etc).
    /// Set by `maybeFireCelebration()` and cleared by the toast's dismiss.
    @State private var celebration: CelebrationToast.Payload?

    /// The last streak day count we've already celebrated. Prevents the same
    /// milestone from re-firing on every refresh. Persists in UserDefaults so
    /// a backgrounded app doesn't replay celebrations on warm starts.
    @AppStorage("mooni.home.lastCelebratedStreak") private var lastCelebratedStreak: Int = 0
    @AppStorage("mooni.home.lastCelebratedLevel") private var lastCelebratedLevel: Int = 0
    /// Day key (yyyy-MM-dd) currently selected in the week strip. Nil = the
    /// most-recent night's entry. Drives the day-detail card and insight.
    @State private var selectedDayKey: String? = nil
    /// Entry currently being edited via the home-screen edit pencil or
    /// missed-night entry point. Presenting this sheet re-launches the
    /// full morning check-in flow, pre-set to "way off" edit-times mode.
    @State private var editingEntry: SleepEntry? = nil

    private enum HomeMode {
        case firstNight
        case evening
        case morning(SleepEntry)
        case recovery(SleepEntry)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            MooniGradient.night.ignoresSafeArea()
            StarsBackground(count: 48)

            ScrollView {
                LazyVStack(spacing: 22) {
                    headerBar

                    heroCard

                    // Action-first: tonight's plan and (in the evening) a
                    // sounds shortcut come right under the hero. Deep dives
                    // like SleepBreakdown / DayPlan / week strip / history
                    // live on the Sleep tab — Home stays a short, fun page.
                    tonightPlanCard

                    fallAsleepShortcutSection

                    // League / friends section hidden until backend sleep-sync
                    // ships. Without it friends' scores stay "—" forever, which
                    // reads as broken to anyone who adds a friend.
                    //   leagueSection

                    if shouldShowMissedNightCard {
                        missedNightCard
                    }

                    Color.clear.frame(height: 24)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 96)
            }
            // iPad: cap content width so the iPhone-shaped layout doesn't
            // stretch absurdly wide. Background gradient still full-bleed.
            .responsiveContainer()
        }
        .onAppear {
            if streak.hasUnseenLoss { showLostStreak = true }
            checkAutoWakeUp()
            maybeFireCelebration()
        }
        .onChange(of: streak.current) { _, _ in maybeFireCelebration() }
        .onChange(of: appState.pet.level) { _, _ in maybeFireCelebration() }
        .celebrationToast(payload: $celebration)
        .alert("You lost your \(streak.lostStreakLength)-day streak", isPresented: $showLostStreak) {
            Button("Start fresh") { streak.acknowledgeLostStreak() }
        } message: {
            Text("All freezes were used up. Log tonight's sleep to start a new streak — each level unlocks another freeze so you can miss a day without losing it.")
        }
        .sheet(isPresented: $showWindDown, onDismiss: {
            if !appState.isSleeping {
                WindDownDimController.shared.end()
            }
        }) {
            WindDownSheet()
                .onAppear { WindDownDimController.shared.begin() }
        }
        .sheet(isPresented: $showStartSleep) {
            StartSleepSheet()
        }
        .sheet(isPresented: $showWhy) {
            if let entry = appState.lastEntry {
                MorningWhySheet(entry: entry, showPaywall: $showPaywall)
            }
        }
        .sheet(isPresented: $showRecoveryPlan) {
            RecoveryPlanSheet(showPaywall: $showPaywall)
        }
        .sheet(isPresented: $showAutoWakeUp) {
            if let entry = appState.lastEntry {
                AutoWakeUpSheet(entry: entry, petName: appState.pet.name, showPaywall: $showPaywall)
            }
        }
        .fullScreenCover(isPresented: $showSleepStory) {
            if let entry = appState.lastEntry {
                SleepStoryView(
                    context: SleepStoryContext(
                        entry: entry,
                        pet: appState.pet,
                        petName: appState.pet.name,
                        history: appState.entries,
                        goalHours: appState.goalHours,
                        currentStreak: streak.current,
                        longestStreak: streak.longest,
                        consistencyDays: appState.bedtimeConsistencyDays,
                        leveledUpTo: appState.lastLevelUp
                    ),
                    onFinished: {
                        showSleepStory = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            showWhy = true
                        }
                    }
                )
            }
        }
        .sheet(item: $editingEntry) { entry in
            MorningCheckInView(entryOverride: entry, startInEditMode: true)
                .environmentObject(appState)
        }
        .sheet(isPresented: $showInviteFriends) {
            InviteFriendsView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showFallAsleepSheet) {
            FallAsleepView()
                .environmentObject(appState)
                .environmentObject(subscriptionManager)
        }
    }

    // MARK: - Missed night

    /// True when there's no logged sleep entry for last night and we're
    /// past 8 AM today — i.e. the auto-detection and morning check-in both
    /// failed to capture the night, so the user needs a manual way in.
    private var shouldShowMissedNightCard: Bool {
        guard appState.hasCompletedOnboarding else { return false }
        // SAFETY NET (mechanism 10): if there's a logged-but-unconfirmed
        // night, always offer a way in — at ANY hour. The user must never
        // be stuck staring at stale sleep with no way to log it.
        if appState.hasUnconfirmedNight { return true }
        let now = Date()
        let cal = Calendar.current
        guard cal.component(.hour, from: now) >= 8 else { return false }
        let todayKey = now.dayKey
        if appState.entries.contains(where: { $0.dayKey == todayKey }) { return false }
        return true
    }

    private var missedNightCard: some View {
        MooniCard(padding: 16, cornerRadius: 22) {
            HStack(spacing: 12) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(MooniColor.warning)
                    .frame(width: 38, height: 38)
                    .background(MooniColor.warning.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(appState.hasUnconfirmedNight ? "Confirm last night's sleep" : "SleepOwl missed last night")
                        .font(MooniFont.title(14))
                        .foregroundColor(MooniColor.textPrimary)
                    Text("Add the times you slept so your streak and score stay accurate.")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Button {
                    Haptics.tap()
                    if appState.hasUnconfirmedNight {
                        // An entry exists but isn't confirmed — go straight
                        // to the morning check-in for it.
                        appState.showMorningCheckIn = true
                    } else if let seeded = appState.seedMissedNightEntry() {
                        editingEntry = seeded
                    }
                } label: {
                    Text(appState.hasUnconfirmedNight ? "Log" : "Add")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.background)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(MooniColor.warning)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Mode

    private var mode: HomeMode {
        guard let entry = appState.lastEntry else { return .firstNight }

        let now = Date()
        let isRecentMorningResult = Calendar.current.isDateInToday(entry.wakeTime)
            && Calendar.current.component(.hour, from: now) < 17

        if isRecentMorningResult {
            return entry.score < 60 ? .recovery(entry) : .morning(entry)
        }

        if TimeOfDay.current == .evening || TimeOfDay.current == .night {
            return .evening
        }

        return entry.score < 60 ? .recovery(entry) : .morning(entry)
    }

    private var morningBriefing: HomeIntelligence.Briefing? {
        switch mode {
        case .morning(let entry), .recovery(let entry):
            return HomeIntelligence.briefing(
                for: entry,
                all: appState.entries,
                targetBedtime: appState.targetBedtime,
                targetWakeTime: appState.targetWakeTime,
                goalHours: appState.goalHours,
                petName: appState.pet.name
            )
        default:
            return nil
        }
    }

    // MARK: - Header

    private var isDayTime: Bool {
        switch TimeOfDay.current {
        case .morning, .day: return true
        case .evening, .night: return false
        }
    }

    private var headerBar: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                SleepOwlBrandMark(size: .prominent)
                Spacer(minLength: 8)
                // Duolingo-style streak: tappable, opens streak detail / freeze
                // info via the existing lost-streak alert plumbing.
                StreakFireBadge(
                    count: streak.current,
                    state: streakBadgeState,
                    size: .compact,
                    tappable: true
                )
            }

            HStack(alignment: .center, spacing: 4) {
                Text(greeting + ",")
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textSecondary)
                Text(appState.pet.name)
                    .font(MooniFont.title(16))
                    .foregroundColor(MooniColor.accentSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }

            // XP / level progress — sits just under the greeting so the
            // gamification loop reads at-a-glance every time the user opens
            // the app.
            XPBar(
                value: appState.pet.levelProgress,
                level: appState.pet.level,
                title: appState.pet.levelTitle,
                recentDelta: appState.lastEarnedEnergy
            )
            .padding(.top, 2)
        }
        .padding(.top, 6)
    }

    /// Map StreakManager state to the visual state expected by `StreakFireBadge`.
    /// We surface a `.lost` flame the moment the user has acknowledged a reset,
    /// `.frozen` when a freeze is shielding the streak overnight, and `.active`
    /// while the streak is alive.
    private var streakBadgeState: StreakFireBadge.Status {
        if streak.current == 0 && streak.hasUnseenLoss { return .lost }
        if streak.current > 0 && streak.freezesRemaining > 0 && streak.current % 7 == 0 {
            // Mild celebration: every 7-day mark hints a fresh freeze is
            // available. Kept subtle — the toast on Phase 3 handles the loud
            // milestone moment.
            return .active
        }
        return streak.current > 0 ? .active : (streak.hasUnseenLoss ? .lost : .active)
    }

    // MARK: - Fall-asleep shortcut

    /// "Drift off" shortcut. Shown only in the evening / night window when a
    /// sleep sound is contextually useful — out of morning view it would just
    /// be clutter.
    @ViewBuilder
    private var fallAsleepShortcutSection: some View {
        let tod = TimeOfDay.current
        if tod == .evening || tod == .night {
            FallAsleepShortcutCard(
                recommendation: FallAsleepShortcutCard.recommend(profile: appState.profile),
                onTap: { showFallAsleepSheet = true }
            )
        }
    }

    // MARK: - League card

    /// Weekly league card. Until Phase 5 plugs in real friends, we render the
    /// empty/invite slate so the social hook is visible from day one. The
    /// invite CTA currently routes to ProfileView's invite section — Phase 5
    /// will surface a dedicated InviteFriendsView.
    private var leagueSection: some View {
        // Project the local friends list into the LeagueCard's mini-leaderboard
        // shape. Friends' scores come from the projection in FriendsManager —
        // 0 until backend sync lands, so the rank is "fair" with only the
        // user populated. Adding real friends still bumps the count and the
        // card flips out of the invite slate.
        let manager = FriendsManager.shared
        let members: [LeagueCard.Member] = manager.friends.prefix(3).map { f in
            LeagueCard.Member(
                initial: f.avatarInitial,
                score: 0,
                isYou: false,
                color: MooniColor.accentSoft
            )
        }

        return LeagueCard(
            tier: LeagueCard.Tier.from(streak: max(streak.longest, streak.current)),
            userScore: appState.lastEntry?.score ?? 0,
            friends: members,
            onInviteFriends: {
                showInviteFriends = true
            }
        )
    }

    // MARK: - Hero card (varies by mode)

    @ViewBuilder
    private var heroCard: some View {
        switch mode {
        case .firstNight:
            firstNightHero
        case .evening:
            eveningHero
        case .morning(let entry):
            morningHero(entry, isRecovery: false)
        case .recovery(let entry):
            morningHero(entry, isRecovery: true)
        }
    }

    private func heroMood(_ r: Int) -> Pet.Mood {
        switch r {
        case 85...:   return .energized
        case 70..<85: return .rested
        case 55..<70: return .calm
        case 40..<55: return .groggy
        default:      return .tired
        }
    }

    // MARK: - Celebration triggers

    /// Streak milestones we celebrate with a full-screen toast. Picked from
    /// the Duolingo / habit-tracker playbook — early hits (3, 7) build the
    /// habit, then we ramp the cadence so it doesn't feel spammy.
    private static let streakMilestones: Set<Int> = [3, 7, 14, 30, 60, 100, 200, 365]

    /// Inspect current streak + level and fire a `CelebrationToast` if a
    /// milestone hasn't been celebrated yet. Guards against re-firing using
    /// the AppStorage trackers so a backgrounded app doesn't replay the toast.
    private func maybeFireCelebration() {
        // Don't stack celebrations — if one's on screen, wait.
        guard celebration == nil else { return }

        // Level-up takes priority over streak (rarer, more rewarding).
        let level = appState.pet.level
        if level > lastCelebratedLevel && level > 1 {
            celebration = .init(
                kind: .levelUp(newLevel: level, title: appState.pet.levelTitle),
                // No "See unlocks" CTA — the unlocks/Pet screen is hidden in
                // this slim build, so the button would dangle. The toast's
                // primary button only ever dismisses, so keep the copy honest.
                title: "Level \(level)!",
                subtitle: "You reached \(appState.pet.levelTitle), and a fresh streak freeze is ready.",
                ctaTitle: "Nice!",
                pet: appState.pet
            )
            lastCelebratedLevel = level
            return
        }

        let s = streak.current
        if Self.streakMilestones.contains(s) && s > lastCelebratedStreak {
            celebration = .init(
                kind: .streakMilestone(days: s),
                title: streakHeadline(for: s),
                subtitle: streakSubtitle(for: s, petName: appState.pet.name),
                ctaTitle: "Keep going",
                pet: appState.pet
            )
            lastCelebratedStreak = s
        }
    }

    private func streakHeadline(for days: Int) -> String {
        switch days {
        case 3:   return "3-day streak!"
        case 7:   return "One week strong"
        case 14:  return "Two weeks in"
        case 30:  return "30-day streak!"
        case 60:  return "60 nights — wow"
        case 100: return "Triple digits"
        case 200: return "200-day legend"
        case 365: return "A FULL YEAR"
        default:  return "\(days)-day streak"
        }
    }

    private func streakSubtitle(for days: Int, petName: String) -> String {
        switch days {
        case 3:   return "Three nights in a row. The habit is forming."
        case 7:   return "A full week of consistent sleep. \(petName) is glowing."
        case 14:  return "Two weeks. Your body clock is locking in."
        case 30:  return "A month of consistency. This is real."
        case 60:  return "60 nights. \(petName) couldn't be prouder."
        case 100: return "100 nights of resting well. Top 1% territory."
        case 200: return "Half a year, doubled. Unreal."
        case 365: return "A year of nightly wins. Hall of Fame."
        default:  return "Another milestone. Keep showing up."
        }
    }

    /// Tap reaction: register the interaction, pick a contextual line, show a
    /// bubble for ~2.4s. If the user hasn't tapped the owl in >24h we lead
    /// with a "missed you" message before falling back to the regular pool.
    private func handleOwlTap() {
        let log = PetInteractionLog.shared
        let line: String
        if log.owlMissedYou() {
            line = PetReactionPool.missedYou(for: appState.pet)
        } else {
            line = PetReactionPool.random(
                for: appState.pet,
                interactionsToday: log.interactionsToday
            )
        }
        log.registerTap()

        let token = UUID()
        heroSpeechToken = token
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            heroSpeech = line
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            // Only clear if no newer tap has taken over.
            if heroSpeechToken == token {
                withAnimation(.easeOut(duration: 0.3)) { heroSpeech = nil }
            }
        }
    }

    private func morningHero(_ entry: SleepEntry, isRecovery: Bool) -> some View {
        let r = entry.readinessScore ?? entry.score
        return MooniCard(padding: 24, cornerRadius: 32) {
            VStack(spacing: 18) {
                // Score (left) · pet mood (right)
                HStack(spacing: 8) {
                    SleepScoreRing(score: entry.score, size: 158, lineWidth: 13)

                    Spacer(minLength: 0)

                    VStack(spacing: 8) {
                        DreamSpiritView(
                            pet: petForMood(heroMood(r)),
                            size: 104,
                            interactive: true,
                            onTap: { handleOwlTap() }
                        )
                            .shadow(color: MooniColor.petGlow.opacity(0.3),
                                    radius: 18, y: 8)
                        Text(scoreStatus(entry.score))
                            .font(MooniFont.title(13))
                            .foregroundColor(scoreColor(entry.score))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(scoreColor(entry.score).opacity(0.16))
                            .clipShape(Capsule())
                    }
                    .frame(width: 128)
                }
                // Speech bubble overlays the full score+owl row (the whole card
                // width) rather than just the 104pt owl, so a long line wraps
                // and stays inside the card. Pinned .topTrailing so its right
                // edge hugs the owl side and it grows leftward into the card
                // interior — never clipping off the right card edge.
                .overlay(alignment: .topTrailing) {
                    if let line = heroSpeech {
                        PetSpeechBubble(text: line, maxWidth: 200)
                            .offset(y: -8)
                            .transition(.opacity.combined(with: .scale(scale: 0.7, anchor: .bottomTrailing)))
                    }
                }

                // Timing (bottom)
                HStack(spacing: 8) {
                    heroChip(icon: "bed.double.fill",
                             value: entry.bedtime.hourMinuteString,
                             label: "Bed", color: MooniColor.accent)
                    heroChip(icon: "moon.zzz.fill",
                             value: entry.formattedDuration,
                             label: "Asleep", color: MooniColor.accent)
                    heroChip(icon: "sunrise.fill",
                             value: entry.wakeTime.hourMinuteString,
                             label: "Wake", color: MooniColor.accent)
                }

                Button {
                    if subscriptionManager.isPro {
                        showSleepStory = true
                    } else {
                        showPaywall = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text("See your sleep story")
                            .font(MooniFont.title(15))
                        if !subscriptionManager.isPro {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11, weight: .bold))
                        }
                    }
                    .foregroundColor(MooniColor.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(MooniColor.accent)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var firstNightHero: some View {
        MooniCard(padding: 26, cornerRadius: 32) {
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [MooniColor.accent.opacity(0.30), .clear],
                                center: .center, startRadius: 4, endRadius: 160
                            )
                        )
                        .frame(width: 280, height: 280)
                        .blur(radius: 6)

                    DreamSpiritView(
                        pet: petForMood(.cozy),
                        size: 170,
                        interactive: true,
                        onTap: { handleOwlTap() }
                    )
                        .shadow(color: MooniColor.petGlow.opacity(0.4), radius: 26, y: 12)
                        .overlay(alignment: .top) {
                            if let line = heroSpeech {
                                PetSpeechBubble(text: line, maxWidth: 240)
                                    .offset(y: -28)
                                    .transition(.opacity.combined(with: .scale(scale: 0.7, anchor: .bottom)))
                            }
                        }
                }
                .frame(height: 200)

                VStack(spacing: 6) {
                    trackingStatusPill
                    Text("Your first night")
                        .font(MooniFont.display(28))
                        .foregroundColor(MooniColor.textPrimary)
                    Text(subscriptionManager.isPro
                         ? "Just sleep — \(appState.pet.name) will track everything automatically. Your score appears in the morning."
                         : "Set your bedtime, then log it in the morning and \(appState.pet.name) scores your night. Auto-tracking comes with Pro.")
                        .font(MooniFont.body(14))
                        .foregroundColor(MooniColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 12)
                }

                HStack(spacing: 8) {
                    heroChip(icon: "moon.zzz.fill", value: windDownTime.hourMinuteString, label: "Wind down", color: MooniColor.success)
                    heroChip(icon: "bed.double.fill", value: appState.targetBedtime.hourMinuteString, label: "Bed", color: MooniColor.accent)
                    heroChip(icon: "sunrise.fill", value: appState.targetWakeTime.hourMinuteString, label: "Wake", color: MooniColor.warning)
                }
            }
        }
    }

    private var eveningHero: some View {
        MooniCard(padding: 26, cornerRadius: 32) {
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [MooniColor.accent.opacity(0.32), .clear],
                                center: .center, startRadius: 4, endRadius: 150
                            )
                        )
                        .frame(width: 260, height: 260)
                        .blur(radius: 5)

                    DreamSpiritView(
                        pet: petForMood(.sleepy),
                        size: 150,
                        interactive: true,
                        onTap: { handleOwlTap() }
                    )
                        .shadow(color: MooniColor.petGlow.opacity(0.35), radius: 22, y: 10)
                        .overlay(alignment: .top) {
                            if let line = heroSpeech {
                                PetSpeechBubble(text: line, maxWidth: 240)
                                    .offset(y: -28)
                                    .transition(.opacity.combined(with: .scale(scale: 0.7, anchor: .bottom)))
                            }
                        }
                }
                .frame(height: 180)

                VStack(spacing: 6) {
                    trackingStatusPill
                    Text("\(appState.pet.name) is getting sleepy")
                        .font(MooniFont.display(24))
                        .foregroundColor(MooniColor.textPrimary)
                        .multilineTextAlignment(.center)
                    Text(eveningSubline)
                        .font(MooniFont.body(13))
                        .foregroundColor(MooniColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)
                }

            }
        }
    }

    /// Tracking-status pill shown at the top of the first-night and evening
    /// heroes. Auto-tracking is Pro-only, so for free users we show an honest,
    /// muted "manual logging" pill that taps through to the paywall rather
    /// than a false green "auto-tracking on" claim.
    @ViewBuilder
    private var trackingStatusPill: some View {
        if subscriptionManager.isPro {
            HStack(spacing: 6) {
                Circle()
                    .fill(MooniColor.success)
                    .frame(width: 6, height: 6)
                Text("AUTO-TRACKING ON")
                    .font(MooniFont.caption(10))
                    .foregroundColor(MooniColor.success)
                    .tracking(1.2)
            }
        } else {
            Button {
                Haptics.tap()
                showPaywall = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(MooniColor.accentSoft)
                    Text("UNLOCK AUTO-TRACKING")
                        .font(MooniFont.caption(10))
                        .foregroundColor(MooniColor.accentSoft)
                        .tracking(1.2)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(MooniColor.accentSoft.opacity(0.12))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func heroChip(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.16))
                .clipShape(Circle())
            Text(value)
                .font(MooniFont.title(15))
                .foregroundColor(MooniColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(MooniFont.caption(10))
                .foregroundColor(MooniColor.textMuted)
                .textCase(.uppercase)
                .tracking(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Tonight plan (automation-first)

    private var tonightPlanCard: some View {
        MooniCard(padding: 18, cornerRadius: 26) {
            VStack(alignment: .leading, spacing: 14) {
                // Tracking status header. Auto-tracking is Pro-only, so free
                // users get an honest "log in the morning" header that taps
                // through to the paywall instead of a false "active" claim.
                if subscriptionManager.isPro {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(MooniColor.success.opacity(0.18))
                                .frame(width: 36, height: 36)
                            Image(systemName: "waveform.path.ecg")
                                .foregroundColor(MooniColor.success)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(MooniColor.success)
                                    .frame(width: 6, height: 6)
                                Text("AUTO-TRACKING ACTIVE")
                                    .font(MooniFont.caption(10))
                                    .foregroundColor(MooniColor.success)
                                    .tracking(1.2)
                            }
                            Text("Sleep detection starts automatically tonight")
                                .font(MooniFont.caption(12))
                                .foregroundColor(MooniColor.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(MooniColor.success.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(MooniColor.success.opacity(0.22), lineWidth: 1)
                    )
                } else {
                    Button {
                        Haptics.tap()
                        showPaywall = true
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(MooniColor.accentSoft.opacity(0.18))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "bed.double.fill")
                                    .foregroundColor(MooniColor.accentSoft)
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text("MANUAL LOGGING")
                                        .font(MooniFont.caption(10))
                                        .foregroundColor(MooniColor.textMuted)
                                        .tracking(1.2)
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(MooniColor.textMuted)
                                }
                                Text("Log your night in the morning · Unlock auto-tracking")
                                    .font(MooniFont.caption(12))
                                    .foregroundColor(MooniColor.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Schedule at a glance
                HStack(spacing: 8) {
                    scheduleChip(icon: "bed.double.fill", label: "Target bed", value: appState.targetBedtime.hourMinuteString, color: MooniColor.accent)
                    scheduleChip(icon: "sunrise.fill", label: "Wake goal", value: appState.targetWakeTime.hourMinuteString, color: MooniColor.warning)
                    scheduleChip(icon: "moon.zzz.fill", label: "Wind-down", value: windDownTime.hourMinuteString, color: MooniColor.success)
                }

                // Optional actions (collapsed by default)
                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                        showManualOptions.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showManualOptions ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                        Text(showManualOptions ? "Hide sleep tools" : "Sleep tools")
                            .font(MooniFont.caption(12))
                    }
                    .foregroundColor(MooniColor.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.05))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                if showManualOptions {
                    VStack(spacing: 8) {
                        PrimaryButton(title: "Start wind-down ritual", icon: "moon.zzz.fill") {
                            showWindDown = true
                        }
                        SecondaryButton(title: "Log bedtime manually", icon: "bed.double.fill") {
                            showStartSleep = true
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if !isHealthConnected {
                    Button {
                        // Apple Health import is Pro-only — connectAppleHealth()
                        // silently no-ops for free users, so don't request
                        // sensitive health permission for nothing. Route free
                        // users to the paywall instead (mirrors ProfileView).
                        if subscriptionManager.isPro {
                            connectAppleHealth()
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: subscriptionManager.isPro ? "heart.text.square.fill" : "lock.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text(subscriptionManager.isPro
                                 ? "Connect Apple Health for richer data"
                                 : "Connect Apple Health — Pro feature")
                                .font(MooniFont.caption(12))
                        }
                        .foregroundColor(MooniColor.accentSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func scheduleChip(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
            Text(value)
                .font(MooniFont.title(14))
                .foregroundColor(MooniColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(MooniFont.caption(9))
                .foregroundColor(MooniColor.textMuted)
                .tracking(0.3)
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Week strip

    private var weekStripSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("This week")
                    .font(MooniFont.title(17))
                    .foregroundColor(MooniColor.textPrimary)
                Spacer()
                if let entry = displayEntry {
                    Text(formattedSelectedDate(entry))
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textMuted)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(last7Days, id: \.self) { day in
                        weekDayChip(day)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private func weekDayChip(_ day: Date) -> some View {
        let key = day.dayKey
        let entry = appState.entries.first(where: { $0.dayKey == key })
        let isSelected = (selectedDayKey ?? appState.lastEntry?.dayKey) == key
        let isToday = Calendar.current.isDateInToday(day)
        let scoreTint: Color = entry.map { scoreColor($0.score) } ?? Color.white.opacity(0.18)

        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                if entry != nil {
                    selectedDayKey = key
                }
            }
        } label: {
            VStack(spacing: 6) {
                Text(weekdayLetter(day))
                    .font(MooniFont.caption(10))
                    .foregroundColor(isSelected ? MooniColor.background : MooniColor.textMuted)
                    .tracking(0.7)

                Text("\(Calendar.current.component(.day, from: day))")
                    .font(MooniFont.title(16))
                    .foregroundColor(isSelected ? MooniColor.background : MooniColor.textPrimary)

                if let entry {
                    Text("\(entry.score)")
                        .font(MooniFont.caption(10))
                        .foregroundColor(isSelected ? MooniColor.background.opacity(0.8) : scoreTint)
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 4, height: 4)
                }
            }
            .frame(width: 44, height: 70)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? scoreTint : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isToday && !isSelected ? MooniColor.accentSoft.opacity(0.5) : Color.clear, lineWidth: 1.2)
            )
            .opacity(entry == nil ? 0.6 : 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Day detail

    /// True when this night's numbers are NOT measured — they're a fallback
    /// estimate from the user's target schedule because the app was never
    /// opened and no morning notification was tapped that day.
    private func isUnconfirmedScheduleEstimate(_ entry: SleepEntry) -> Bool {
        entry.isEstimated
            && entry.resolvedSource == .appActivityEstimate
            && !entry.didCompleteMorningCheckIn
            && MorningCheckInStore.checkIn(for: entry.dayKey) == nil
    }

    /// Deliberately tiny + muted. The info still matters, but it should
    /// whisper, not shout a big golden warning box across the card.
    private func missedDayExplanation(_ entry: SleepEntry) -> some View {
        Button {
            Haptics.tap()
            editingEntry = entry
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(MooniColor.textMuted)
                Text("Estimated from your schedule")
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textMuted)
                Text("·  Set real times")
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.accentSoft)
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
    }

    private func dayDetailCard(_ entry: SleepEntry) -> some View {
        MooniCard(padding: 18, cornerRadius: 26) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.formattedDuration)
                            .font(MooniFont.display(26))
                            .foregroundColor(MooniColor.textPrimary)
                        Button {
                            Haptics.tap()
                            editingEntry = entry
                        } label: {
                            Text("\(entry.bedtime.hourMinuteString) → \(entry.wakeTime.hourMinuteString)")
                                .font(MooniFont.caption(12))
                                .foregroundColor(MooniColor.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Edit bedtime and wake time")
                    }
                    Spacer()
                    scoreBadge(entry.score)
                }

                if isUnconfirmedScheduleEstimate(entry) {
                    missedDayExplanation(entry)
                }

                Divider().background(Color.white.opacity(0.06))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    detailMetric(icon: "bolt.heart.fill",
                                 title: "Readiness",
                                 value: "\(entry.readinessScore ?? entry.score)",
                                 tint: scoreColor(entry.readinessScore ?? entry.score))
                    detailMetric(icon: "battery.100.bolt",
                                 title: "Energy",
                                 value: entry.energyLevel ?? "Steady",
                                 tint: MooniColor.warning)
                    detailMetric(icon: "sparkles",
                                 title: "Quality",
                                 value: entry.quality.label,
                                 tint: MooniColor.accent)
                    detailMetric(icon: "checkmark.circle.fill",
                                 title: "Routine",
                                 value: entry.routineCompleted ? "Done" : "Skipped",
                                 tint: entry.routineCompleted ? MooniColor.success : MooniColor.textMuted)
                }
            }
        }
    }

    private func detailMetric(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(MooniFont.title(14))
                    .foregroundColor(MooniColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(title)
                    .font(MooniFont.caption(10))
                    .foregroundColor(MooniColor.textMuted)
                    .tracking(0.5)
                    .textCase(.uppercase)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func scoreBadge(_ score: Int) -> some View {
        let tint = scoreColor(score)
        return Text("\(score)")
            .font(MooniFont.title(18))
            .foregroundColor(tint)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(tint.opacity(0.18))
            )
            .overlay(
                Capsule().stroke(tint.opacity(0.4), lineWidth: 1)
            )
    }

    // MARK: - Insight card

    private func insightCard(_ entry: SleepEntry) -> some View {
        let copy = entry.insight ?? insightText(for: entry)
        return MooniCard(padding: 16, cornerRadius: 22) {
            HStack(spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(MooniColor.warning)
                    .frame(width: 36, height: 36)
                    .background(MooniColor.warning.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Insight")
                        .font(MooniFont.caption(10))
                        .foregroundColor(MooniColor.warning)
                        .tracking(0.6)
                        .textCase(.uppercase)
                    Text(copy)
                        .font(MooniFont.body(14))
                        .foregroundColor(MooniColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - History

    private var historySection: some View {
        let recent = Array(appState.entries
            .sorted(by: { $0.wakeTime > $1.wakeTime })
            .prefix(8))

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent nights")
                    .font(MooniFont.title(17))
                    .foregroundColor(MooniColor.textPrimary)
                Spacer()
                Text("\(appState.entries.count) tracked")
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textMuted)
            }

            VStack(spacing: 8) {
                ForEach(recent) { entry in
                    historyRow(entry)
                }
            }
        }
    }

    private func historyRow(_ entry: SleepEntry) -> some View {
        let tint = scoreColor(entry.score)
        let isSelected = displayEntry?.id == entry.id

        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                selectedDayKey = entry.dayKey
            }
        } label: {
            HStack(spacing: 14) {
                // Mini score indicator
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: CGFloat(min(max(entry.score, 0), 100)) / 100)
                        .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(entry.score)")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textPrimary)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(historyDateLabel(entry.wakeTime))
                        .font(MooniFont.title(14))
                        .foregroundColor(MooniColor.textPrimary)
                    Text("\(entry.formattedDuration) · \(entry.bedtime.hourMinuteString)–\(entry.wakeTime.hourMinuteString)")
                        .font(MooniFont.caption(11))
                        .foregroundColor(MooniColor.textMuted)
                        .lineLimit(1)
                }

                Spacer()

                Text(scoreLabel(entry.score))
                    .font(MooniFont.caption(11))
                    .foregroundColor(tint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(tint.opacity(0.16)))

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(MooniColor.textMuted)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(isSelected ? 0.10 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? tint.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Growth footer

    private var growthFooter: some View {
        MooniCard(padding: 16, cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Growth")
                            .font(MooniFont.caption(10))
                            .foregroundColor(MooniColor.accentSoft)
                            .tracking(0.6)
                            .textCase(.uppercase)
                        Text("Next: \(appState.pet.name) becomes \(nextStageName)")
                            .font(MooniFont.title(16))
                            .foregroundColor(MooniColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(growthCopy)
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(MooniColor.warning)
                        .frame(width: 36, height: 36)
                        .background(MooniColor.warning.opacity(0.16))
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                }

                MooniProgressBar(value: appState.growthProgress, height: 9)

                HStack {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(MooniColor.warning)
                    Text("\(appState.dreamStars) dream stars")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                    Spacer()
                    if !subscriptionManager.isPro {
                        Button { showPaywall = true } label: {
                            Text("See full path")
                                .font(MooniFont.caption(12))
                                .foregroundColor(MooniColor.accentSoft)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Computed data

    private var last7Days: [Date] {
        let cal = Calendar.current
        return (0..<7).reversed().compactMap {
            cal.date(byAdding: .day, value: -$0, to: Date())
        }
    }

    private var displayEntry: SleepEntry? {
        if let key = selectedDayKey,
           let match = appState.entries.first(where: { $0.dayKey == key }) {
            return match
        }
        return appState.lastEntry
    }

    private func petForMood(_ mood: Pet.Mood) -> Pet {
        var p = appState.pet
        p.mood = mood
        return p
    }

    // MARK: - Copy

    private func heroHeadline(_ entry: SleepEntry, isRecovery: Bool) -> String {
        if isRecovery {
            return "Gentle recovery tonight will help \(appState.pet.name) bounce back."
        }
        if let briefing = morningBriefing {
            return briefing.heroSubline
        }
        switch entry.score {
        case 85...:    return "Great rhythm — \(appState.pet.name) feels fully charged."
        case 70..<85:  return "Solid night. Today is a good day for focused work."
        case 60..<70:  return "An okay night. A steadier bedtime tonight will help."
        default:       return "Rough night. Keep things light and gentle today."
        }
    }

    private var eveningSubline: String {
        HomeIntelligence.eveningAnticipation(
            bedtimeConsistencyDays: appState.bedtimeConsistencyDays,
            targetBedtime: appState.targetBedtime,
            petName: appState.pet.name
        )
    }

    private var growthCopy: String {
        guard let next = appState.nextEvolutionStage else {
            return "\(appState.pet.name) is fully grown"
        }
        let nights = appState.nightsUntilNextEvolution
        if nights == 0 {
            return "\(appState.pet.name) is ready to grow into \(next.label)"
        }
        return "\(nights) calm night\(nights == 1 ? "" : "s") to go"
    }

    private var nextStageName: String {
        appState.nextEvolutionStage?.label ?? "Dream form"
    }

    private var greeting: String {
        switch TimeOfDay.current {
        case .morning: return "Good morning"
        case .day: return "Good afternoon"
        case .evening: return "Good evening"
        case .night: return "Good evening"
        }
    }

    private func scoreLabel(_ score: Int) -> String {
        switch score {
        case 85...:    return "Great"
        case 70..<85:  return "Good"
        case 50..<70:  return "Okay"
        default:       return "Low"
        }
    }

    private func weekdayLetter(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date).uppercased()
    }

    private func formattedSelectedDate(_ entry: SleepEntry) -> String {
        let f = DateFormatter()
        let cal = Calendar.current
        if cal.isDateInToday(entry.wakeTime) { return "Last night" }
        if cal.isDateInYesterday(entry.wakeTime) { return "Yesterday" }
        f.dateFormat = "EEE, MMM d"
        return f.string(from: entry.wakeTime)
    }

    private func historyDateLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Last night" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: date)
    }

    // MARK: - Auto wake-up detection

    private func checkAutoWakeUp() {
        let hour = Calendar.current.component(.hour, from: Date())
        guard hour >= 5 && hour < 13 else { return }
        let todayKey = Date().dayKey
        guard UserDefaults.standard.string(forKey: "mooni.autoWakeShownDay") != todayKey else { return }
        guard let entry = appState.lastEntry, Calendar.current.isDateInToday(entry.wakeTime) else { return }
        guard !appState.isSleeping else { return }
        UserDefaults.standard.set(todayKey, forKey: "mooni.autoWakeShownDay")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            showAutoWakeUp = true
        }
    }

    // MARK: - Helpers

    private var windDownTime: Date {
        Calendar.current.date(byAdding: .minute, value: -30, to: appState.targetBedtime) ?? appState.targetBedtime
    }

    private var questDone: Int {
        min(appState.routine.completedToday.intersection(Set(["breathing", "journal", "no_phone"])).count, 3)
    }

    private var isHealthConnected: Bool { healthKit.isConnected }

    private func connectAppleHealth() {
        Task {
            _ = await healthKit.requestAuthorization()
            await appState.importHealthKitSleep()
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 85...:    return MooniColor.success
        case 70..<85:  return MooniColor.accent
        case 50..<70:  return MooniColor.warning
        default:       return MooniColor.danger
        }
    }

    private func scoreStatus(_ score: Int) -> String {
        switch score {
        case 85...:    return "Great night"
        case 70..<85:  return "Solid night"
        case 50..<70:  return "So-so night"
        default:       return "Rough night"
        }
    }

    private func insightText(for entry: SleepEntry) -> String {
        if appState.bedtimeConsistencyDays > 0 {
            return "You sleep better when bedtime stays within 30 minutes of \(appState.targetBedtime.hourMinuteString)."
        }
        if entry.score < 60 {
            return "A shorter recovery quest tonight can help \(appState.pet.name) bounce back without pressure."
        }
        return "Keeping bedtime close to \(appState.targetBedtime.hourMinuteString) helps \(appState.pet.name) wake up cozier."
    }
}

// MARK: - Sheets

private struct WindDownSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var systemTask: WindDownSystemTask?

    private var questHabits: [RoutineHabit] {
        ["breathing", "journal", "no_phone"].compactMap { id in
            RoutineHabit.library.first { $0.id == id }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MooniGradient.night.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        LunaMoodHero(
                            pet: appState.pet,
                            mood: .sleepy,
                            size: 150,
                            caption: "Screen is dimmed. \(appState.pet.name) is settling in with you."
                        )
                        .padding(.top, 8)

                        if let task = systemTask {
                            WindDownSystemTaskCard(task: task)
                        }

                        MooniCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Tonight's Quest")
                                    .font(MooniFont.title(18))
                                    .foregroundColor(MooniColor.textPrimary)

                                ForEach(Array(questHabits.enumerated()), id: \.element.id) { index, habit in
                                    HabitRow(habit: habit, index: index)
                                }
                            }
                        }

                        PrimaryButton(title: "I'm ready for sleep", icon: "moon.fill") {
                            appState.enterSleepMode()
                            dismiss()
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Wind-down")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(MooniColor.accent)
                }
            }
            .onAppear {
                if systemTask == nil, let task = WindDownSystemTaskStore.shared.taskForTonight {
                    systemTask = task
                    WindDownSystemTaskStore.shared.markShown(task)
                }
            }
        }
    }
}

private struct HabitRow: View {
    @EnvironmentObject var appState: AppState
    let habit: RoutineHabit
    let index: Int

    private var isDone: Bool {
        appState.routine.completedToday.contains(habit.id)
    }

    var body: some View {
        Button {
            let wasDone = isDone
            withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) {
                appState.toggleHabitCompletion(habit)
            }
            if !wasDone {
                appState.awardDreamStarsForQuestStep(habit, amount: index == 2 ? 10 : 5)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } else {
                UISelectionFeedbackGenerator().selectionChanged()
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "\(index + 1).circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(isDone ? MooniColor.success : MooniColor.accent)

                VStack(alignment: .leading, spacing: 3) {
                    Text(habit.title)
                        .font(MooniFont.title(15))
                        .foregroundColor(MooniColor.textPrimary)
                    Text(isDone ? lunaMicrocopy(index: index) : stepHint(index: index))
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(14)
            .background(Color.white.opacity(isDone ? 0.11 : 0.055))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func stepHint(index: Int) -> String {
        switch index {
        case 0: return "A few slow breaths soften bedtime."
        case 1: return "Clear one thought before sleep."
        default: return "Phone away — last step before bed."
        }
    }

    private func lunaMicrocopy(index: Int) -> String {
        switch index {
        case 0: return "Almost ready for sleep."
        case 1: return "That helped me feel calmer."
        default: return "I feel cozy now."
        }
    }
}

private struct StartSleepSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var bedtime: Date = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                MooniGradient.night.ignoresSafeArea()
                VStack(spacing: 24) {
                    LunaMoodHero(
                        pet: appState.pet,
                        mood: .sleepy,
                        size: 150,
                        caption: "Sleep well. \(appState.pet.name) is settling in with you."
                    )

                    MooniCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tonight's bedtime")
                                .font(MooniFont.caption(13))
                                .foregroundColor(MooniColor.textSecondary)
                            DatePicker("", selection: $bedtime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .colorScheme(.dark)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 4)

                    PrimaryButton(title: "Good night", icon: "moon.stars.fill") {
                        ActivitySleepEstimator.shared.recordSleepStart(at: normalizedBedtime)
                        appState.enterSleepMode(startedAt: normalizedBedtime)
                        dismiss()
                    }

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Going to bed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(MooniColor.accent)
                }
            }
        }
    }

    private var normalizedBedtime: Date {
        let now = Date()
        let calendar = Calendar.current
        let picked = calendar.dateComponents([.hour, .minute], from: bedtime)
        var today = calendar.dateComponents([.year, .month, .day], from: now)
        today.hour = picked.hour
        today.minute = picked.minute

        guard let selectedToday = calendar.date(from: today) else { return now }
        if selectedToday > now.addingTimeInterval(30 * 60) {
            return calendar.date(byAdding: .day, value: -1, to: selectedToday) ?? now
        }
        return min(selectedToday, now)
    }
}

private struct MorningWhySheet: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    let entry: SleepEntry
    @Binding var showPaywall: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                MooniGradient.night.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        LunaMoodHero(
                            pet: appState.pet,
                            mood: Pet.Mood.from(score: entry.score),
                            size: 140,
                            caption: "Here is the simple version."
                        )
                        .padding(.top, 4)

                        MooniCard(padding: 18, cornerRadius: 22) {
                            VStack(alignment: .leading, spacing: 14) {
                                Text(explanation)
                                    .font(MooniFont.body(16))
                                    .foregroundColor(MooniColor.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)

                                MooniInfoRow(icon: "bed.double.fill", title: "Bedtime", value: bedtimeDetail)
                                MooniInfoRow(icon: "sunrise.fill", title: "Wake time", value: wakeDetail, color: MooniColor.warning)
                                MooniInfoRow(icon: "moon.zzz.fill", title: "Wind-down", value: entry.routineCompleted ? "Completed" : "Try tonight", color: MooniColor.success)
                            }
                        }

                        if !subscriptionManager.isPro && !appState.entries.isEmpty {
                            MooniPremiumLockCard(
                                icon: "sparkles",
                                title: "Deeper sleep insight",
                                subtitle: "Unlock sleep debt, best sleep window, and recovery prediction.",
                                actionTitle: "See your full pattern"
                            ) {
                                showPaywall = true
                                dismiss()
                            }
                            .padding(.top, 2)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Why")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(MooniColor.accent)
                }
            }
        }
    }

    private var explanation: String {
        let name = appState.pet.name
        if entry.score >= 80 {
            return "\(name) woke up cozy because your sleep duration and timing were close to your goal."
        }
        if entry.score >= 60 {
            return "\(name) had an okay night. A steadier bedtime tonight should make tomorrow feel softer."
        }
        return "Rough night. A small recovery quest tonight is enough to help \(name) start bouncing back."
    }

    private var bedtimeDetail: String {
        "\(entry.bedtime.hourMinuteString) target \(appState.targetBedtime.hourMinuteString)"
    }

    private var wakeDetail: String {
        "\(entry.wakeTime.hourMinuteString) target \(appState.targetWakeTime.hourMinuteString)"
    }
}

private struct RecoveryPlanSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Binding var showPaywall: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                MooniGradient.night.ignoresSafeArea()

                VStack(spacing: 18) {
                    LunaMoodHero(
                        pet: appState.pet,
                        mood: .recovering,
                        size: 150,
                        caption: "Tonight is a fresh start."
                    )

                    MooniCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Gentle recovery")
                                .font(MooniFont.title(18))
                                .foregroundColor(MooniColor.textPrimary)

                            MooniInfoRow(icon: "iphone.slash", title: "Phone away", value: "10 min earlier")
                            MooniInfoRow(icon: "wind", title: "Breathing", value: "2 minutes", color: MooniColor.success)
                            MooniInfoRow(icon: "moon.fill", title: "Bedtime", value: appState.targetBedtime.hourMinuteString)
                        }
                    }

                    MooniPremiumLockCard(
                        icon: "heart.text.square.fill",
                        title: "Personal recovery plan",
                        subtitle: "Premium adapts recovery nights to sleep debt, schedule, and wake-up patterns."
                    ) {
                        showPaywall = true
                    }

                    PrimaryButton(title: "Start wind-down", icon: "moon.zzz.fill") {
                        dismiss()
                    }

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Recovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(MooniColor.accent)
                }
            }
        }
    }
}

// MARK: - Auto Wake-Up Sheet

// MARK: - Wake-up stats

/// Derived stats for the morning sheet — deltas, percentile, records,
/// newly unlocked badges. Pure value type; no side effects.
fileprivate struct WakeUpStats {
    let entry: SleepEntry
    let goalHours: Double
    let pet: Pet
    let leveledUpTo: Int?
    let newlyUnlockedBadges: [UnlockableItem]
    let currentStreak: Int
    let longestStreak: Int
    let newLongestStreak: Bool
    let freezesRemaining: Int
    let scoreDelta: Int?
    let percentile: Int?
    /// If today's score is a record, the number of nights it took to beat.
    let bestInDays: Int?
    let goalDeltaMinutes: Int
    let consistencyDays: Int
    let energyEarned: Int
    let xpToNextLevel: Int
    let levelProgress: Double
    let totalPastEntries: Int

    init(entry: SleepEntry,
         history: [SleepEntry],
         goalHours: Double,
         pet: Pet,
         lastLevelUp: Int?,
         currentStreak: Int,
         longestStreak: Int,
         freezesRemaining: Int,
         consistencyDays: Int) {
        self.entry = entry
        self.goalHours = goalHours
        self.pet = pet
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.freezesRemaining = freezesRemaining
        self.consistencyDays = consistencyDays
        self.energyEarned = entry.energyEarned

        let past = history
            .filter { $0.dayKey != entry.dayKey }
            .sorted { $0.wakeTime > $1.wakeTime }
        self.totalPastEntries = past.count

        if let prev = past.first {
            self.scoreDelta = entry.score - prev.score
        } else {
            self.scoreDelta = nil
        }

        if past.count >= 4 {
            let beat = past.filter { entry.score > $0.score }.count
            self.percentile = Int((Double(beat) / Double(past.count) * 100).rounded())
        } else {
            self.percentile = nil
        }

        if past.count >= 5 {
            if let idx = past.firstIndex(where: { $0.score >= entry.score }) {
                self.bestInDays = idx >= 5 ? idx : nil
            } else {
                self.bestInDays = past.count
            }
        } else {
            self.bestInDays = nil
        }

        if let level = lastLevelUp {
            self.leveledUpTo = level
            self.newlyUnlockedBadges = UnlockableItem.catalog.filter { $0.requiredLevel == level }
        } else {
            self.leveledUpTo = nil
            self.newlyUnlockedBadges = []
        }

        self.newLongestStreak = (currentStreak > 0 && currentStreak == longestStreak && longestStreak >= 3)

        let goalSec = goalHours * 3600
        self.goalDeltaMinutes = Int(((entry.totalSleepDuration - goalSec) / 60).rounded())

        self.xpToNextLevel = max(0, pet.energyForNextLevel - pet.dreamEnergy)
        self.levelProgress = pet.levelProgress
    }

    /// Up to three "wow" chips shown right under the score ring.
    /// Picked dynamically so each morning surfaces the strongest signal.
    var highlightChips: [WakeHighlightChip] {
        var chips: [WakeHighlightChip] = []
        if let n = bestInDays, n >= 6 {
            chips.append(.init(icon: "trophy.fill",
                               value: "Best in \(n)",
                               label: "nights",
                               tint: MooniColor.warning))
        }
        if let d = scoreDelta, abs(d) >= 3 {
            let up = d > 0
            chips.append(.init(icon: up ? "arrow.up.right" : "arrow.down.right",
                               value: "\(up ? "+" : "")\(d)",
                               label: "vs last night",
                               tint: up ? MooniColor.success : MooniColor.danger))
        }
        if let p = percentile, p >= 60 {
            chips.append(.init(icon: "chart.line.uptrend.xyaxis",
                               value: "Top \(max(1, 100 - p))%",
                               label: "of your nights",
                               tint: MooniColor.accent))
        }
        if chips.count < 3, let p = percentile, p < 60 {
            chips.append(.init(icon: "chart.bar.fill",
                               value: "\(p)\u{00A0}pct",
                               label: "of your nights",
                               tint: MooniColor.accentSoft))
        }
        if chips.count < 3 {
            // Goal delta chip
            let mins = goalDeltaMinutes
            let absMins = abs(mins)
            let h = absMins / 60
            let m = absMins % 60
            let value = h > 0 ? "\(mins >= 0 ? "+" : "-")\(h)h \(m)m" : "\(mins >= 0 ? "+" : "-")\(m)m"
            chips.append(.init(icon: mins >= 0 ? "target" : "hourglass",
                               value: value,
                               label: mins >= -10 ? "of goal" : "short of goal",
                               tint: mins >= -10 ? MooniColor.success : MooniColor.warning))
        }
        if chips.count < 3 {
            chips.append(.init(icon: "bed.double.fill",
                               value: entry.formattedDuration,
                               label: "total sleep",
                               tint: MooniColor.accentSoft))
        }
        return Array(chips.prefix(3))
    }

    /// Headline shown above the score ring — picks the most exciting fact.
    func heroHeadline(petName: String) -> String {
        if leveledUpTo != nil {
            return "\(petName) leveled up!"
        }
        if newLongestStreak {
            return "New longest streak!"
        }
        if let n = bestInDays, n >= 7 {
            return "Your best night in \(n) days"
        }
        if let p = percentile, p >= 85 {
            return "Top \(max(1, 100 - p))% night ever"
        }
        if let d = scoreDelta, d >= 8 {
            return "+\(d) better than yesterday"
        }
        if entry.score >= 85 {
            return "\(petName) feels recharged"
        }
        if entry.score >= 70 {
            return "Solid night for \(petName)"
        }
        return "\(petName) tracked your night"
    }

    /// Pet's spoken message at the bottom — dynamic, never repeats the headline verbatim.
    func petMessage(petName: String) -> String {
        if let level = leveledUpTo {
            return "I leveled up to \(level)! Keep this rhythm and we'll unlock even more."
        }
        if newLongestStreak {
            return "\(currentStreak) days in a row — that's our longest ever. Don't break it tonight!"
        }
        if let n = bestInDays, n >= 7 {
            return "I haven't felt this rested in \(n) nights. Whatever you did last night — do it again."
        }
        if let p = percentile, p >= 75 {
            return "This was a top \(max(1, 100 - p))% night for us. Going to coast on that all day."
        }
        if let d = scoreDelta, d >= 8 {
            return "We jumped \(d) points from yesterday. Small wins compound."
        }
        if entry.score >= 85 {
            return "Fully charged. Today's going to feel light."
        }
        if entry.score >= 70 {
            return "Solid recovery. A consistent bedtime tonight pushes us into top territory."
        }
        if entry.score >= 50 {
            return "Mid night. A gentler wind-down can sharpen tomorrow."
        }
        return "Rough one. Let's go easier on screens tonight — I'll bounce back."
    }
}

fileprivate struct WakeHighlightChip: Identifiable {
    let id = UUID()
    let icon: String
    let value: String
    let label: String
    let tint: Color
}

// MARK: - Sheet

private struct AutoWakeUpSheet: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var streak = StreakManager.shared
    @Environment(\.dismiss) private var dismiss
    let entry: SleepEntry
    let petName: String
    @Binding var showPaywall: Bool

    // Phase: accuracy gate → summary. The gate is the first thing the user
    // sees on waking — it asks "did we get this right?" and offers a quick
    // edit. Only after they confirm (or save edits) does the rich morning
    // summary play its animations.
    private enum WakePhase { case accuracy, story, summary }
    @State private var phase: WakePhase = .accuracy

    // Editable copies of the tracked times, surfaced when the user taps Edit.
    @State private var editing: Bool = false
    @State private var editedBedtime: Date = .now
    @State private var editedWakeTime: Date = .now
    @State private var accuracyChipsIn: Bool = false
    @State private var accuracyHeroIn: Bool = false

    @State private var heroVisible = false
    @State private var ringVisible = false
    @State private var rowVisible = false
    @State private var cardsVisible = false
    @State private var levelUpPulse = false

    private var stats: WakeUpStats {
        WakeUpStats(
            entry: entry,
            history: appState.entries,
            goalHours: appState.goalHours,
            pet: appState.pet,
            lastLevelUp: appState.lastLevelUp,
            currentStreak: streak.current,
            longestStreak: streak.longest,
            freezesRemaining: streak.freezesRemaining,
            consistencyDays: appState.bedtimeConsistencyDays
        )
    }

    private var storyContext: SleepStoryContext {
        SleepStoryContext(
            entry: entry,
            pet: appState.pet,
            petName: petName,
            history: appState.entries,
            goalHours: appState.goalHours,
            currentStreak: streak.current,
            longestStreak: streak.longest,
            consistencyDays: appState.bedtimeConsistencyDays,
            leveledUpTo: appState.lastLevelUp
        )
    }

    private var scoreTint: Color {
        switch entry.score {
        case 85...: return MooniColor.success
        case 70..<85: return MooniColor.accent
        case 50..<70: return MooniColor.warning
        default: return MooniColor.danger
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MooniGradient.night.ignoresSafeArea()
                StarsBackground(count: 60)

                Group {
                    if phase == .accuracy {
                        accuracyGateView
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                    } else if phase == .story {
                        SleepStoryView(
                            context: storyContext,
                            onFinished: { advanceToSummary() }
                        )
                        .transition(.opacity)
                    } else {
                        summaryScrollView
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }
                }
                .animation(.easeInOut(duration: 0.4), value: phase)
            }
            .navigationTitle(phase == .accuracy ? "Good morning" : "This morning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(phase == .story ? .hidden : .visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    // Only show Done once the user is past the story.
                    if phase == .summary {
                        Button("Done") { dismiss() }
                            .foregroundColor(MooniColor.accent)
                    }
                }
            }
            .onAppear {
                editedBedtime = entry.bedtime
                editedWakeTime = entry.wakeTime
                runAccuracyAnimation()
            }
        }
    }

    // MARK: - Accuracy gate

    private var accuracyGateView: some View {
        ScrollView {
            VStack(spacing: 22) {
                // Chip + headline
                VStack(spacing: 10) {
                    Text.iconHeader("🦉", "WE TRACKED YOUR NIGHT")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(MooniColor.accentSoft)
                        .tracking(2)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(MooniColor.accent.opacity(0.16))
                        .clipShape(Capsule())

                    Text(editing ? "Adjust the times\nbelow." : "Did we get\nthis right?")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(MooniColor.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
                .opacity(accuracyHeroIn ? 1 : 0)
                .offset(y: accuracyHeroIn ? 0 : 8)

                // Bedtime / Wake big time cards
                HStack(spacing: 12) {
                    accuracyTimeCard(
                        emoji: "🌙",
                        label: "BEDTIME",
                        tint: MooniColor.accent,
                        date: editing ? $editedBedtime : .constant(entry.bedtime),
                        editing: editing
                    )
                    accuracyTimeCard(
                        emoji: "☀️",
                        label: "WAKE",
                        tint: MooniColor.warning,
                        date: editing ? $editedWakeTime : .constant(entry.wakeTime),
                        editing: editing
                    )
                }
                .opacity(accuracyHeroIn ? 1 : 0)
                .offset(y: accuracyHeroIn ? 0 : 10)

                // Duration callout (recomputed live when editing)
                let durationHours = (editing ? editedWakeTime : entry.wakeTime)
                    .timeIntervalSince(editing ? editedBedtime : entry.bedtime) / 3600.0
                HStack(spacing: 8) {
                    EmojiIcon(emoji: "⏱", size: 14, tint: MooniColor.textPrimary)
                    Text(durationLabel(durationHours))
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(MooniColor.textPrimary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())
                .opacity(accuracyHeroIn ? 1 : 0)

                if editing {
                    // Save / Cancel pair
                    VStack(spacing: 10) {
                        Button(action: saveEdits) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark")
                                Text("Save my times")
                            }
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundColor(MooniColor.background)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .background(MooniColor.success)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .disabled(editedWakeTime <= editedBedtime)
                        .opacity(editedWakeTime <= editedBedtime ? 0.5 : 1)

                        Button(action: cancelEdits) {
                            Text("Cancel")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(MooniColor.textSecondary)
                                .padding(.vertical, 6)
                        }
                    }
                    .padding(.horizontal, 12)
                    .opacity(accuracyChipsIn ? 1 : 0)
                    .offset(y: accuracyChipsIn ? 0 : 10)
                } else {
                    // Feedback question + 3 big buttons
                    Text("How close did we get?")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(MooniColor.textSecondary)
                        .padding(.top, 4)
                        .opacity(accuracyChipsIn ? 1 : 0)

                    VStack(spacing: 10) {
                        accuracyChoice(emoji: "👍", label: "Accurate",
                                       sub: "Times match what I remember",
                                       tint: MooniColor.success,
                                       action: { record("accurate"); advanceToStory() })
                        accuracyChoice(emoji: "🤏", label: "Somewhat accurate",
                                       sub: "Close but off by a few minutes",
                                       tint: MooniColor.warning,
                                       action: { record("somewhat"); advanceToStory() })
                        accuracyChoice(emoji: "👎", label: "Not accurate",
                                       sub: "Pretty off — let me edit",
                                       tint: MooniColor.danger,
                                       action: { record("inaccurate"); startEditing() })
                    }
                    .opacity(accuracyChipsIn ? 1 : 0)
                    .offset(y: accuracyChipsIn ? 0 : 10)

                    Button(action: startEditing) {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil")
                                .font(.system(size: 12, weight: .bold))
                            Text("Edit times")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                        }
                        .foregroundColor(MooniColor.accentSoft)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(MooniColor.accent.opacity(0.14))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(MooniColor.accent.opacity(0.3), lineWidth: 1))
                    }
                    .opacity(accuracyChipsIn ? 1 : 0)
                    .padding(.top, 4)

                    Button(action: { record("skipped"); advanceToStory() }) {
                        Text("Skip — show my morning")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(MooniColor.textMuted.opacity(0.7))
                            .padding(.top, 6)
                    }
                    .opacity(accuracyChipsIn ? 1 : 0)
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }

    private var summaryScrollView: some View {
        ScrollView {
            VStack(spacing: 18) {
                heroSection
                    .opacity(heroVisible ? 1 : 0)

                highlightRow
                    .opacity(rowVisible ? 1 : 0)
                    .offset(y: rowVisible ? 0 : 10)

                if let level = stats.leveledUpTo {
                    levelUpCard(level: level)
                        .opacity(cardsVisible ? 1 : 0)
                        .offset(y: cardsVisible ? 0 : 12)
                }

                if stats.currentStreak > 0 || stats.newLongestStreak {
                    streakCard
                        .opacity(cardsVisible ? 1 : 0)
                        .offset(y: cardsVisible ? 0 : 12)
                }

                xpCard
                    .opacity(cardsVisible ? 1 : 0)
                    .offset(y: cardsVisible ? 0 : 12)

                if let s = entry.stages, s.totalSleep > 0 {
                    stagesCard(s)
                        .opacity(cardsVisible ? 1 : 0)
                        .offset(y: cardsVisible ? 0 : 12)
                }

                coreStatsCard
                    .opacity(cardsVisible ? 1 : 0)
                    .offset(y: cardsVisible ? 0 : 12)

                sparklineCard
                    .opacity(cardsVisible ? 1 : 0)
                    .offset(y: cardsVisible ? 0 : 12)

                petMessageCard
                    .opacity(cardsVisible ? 1 : 0)
                    .offset(y: cardsVisible ? 0 : 12)

                ctaButton
                    .opacity(cardsVisible ? 1 : 0)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 32)
        }
        .onAppear { runEntryAnimation() }
    }

    // MARK: Accuracy helpers

    private func accuracyTimeCard(emoji: String, label: String, tint: Color,
                                  date: Binding<Date>, editing: Bool) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                EmojiIcon(emoji: emoji, size: 14, tint: tint)
                Text(label)
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundColor(tint)
                    .tracking(1.4)
            }

            if editing {
                DatePicker("", selection: date, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .frame(height: 110)
                    .clipped()
                    .colorScheme(.dark)
            } else {
                Text(date.wrappedValue.hourMinuteString)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(MooniColor.textPrimary)
                    .frame(height: 60)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 10)
        .background(tint.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.32), lineWidth: 1)
        )
    }

    private func accuracyChoice(emoji: String, label: String, sub: String,
                                tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                EmojiIcon(emoji: emoji, size: 24, tint: tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(MooniColor.textPrimary)
                    Text(sub)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(MooniColor.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(tint)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(tint.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(tint.opacity(0.32), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func durationLabel(_ hours: Double) -> String {
        guard hours.isFinite, hours > 0 else { return "—" }
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return "\(h)h \(m)m of sleep"
    }

    // MARK: Animations / actions

    private func runAccuracyAnimation() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        withAnimation(.easeOut(duration: 0.45).delay(0.08)) { accuracyHeroIn = true }
        withAnimation(.easeOut(duration: 0.45).delay(0.28)) { accuracyChipsIn = true }
    }

    private func record(_ rating: String) {
        // Lightweight telemetry — survives app launches but never blocks user.
        let key = "wakeAccuracyFeedback"
        var log = (UserDefaults.standard.array(forKey: key) as? [[String: String]]) ?? []
        log.append([
            "date": ISO8601DateFormatter().string(from: Date()),
            "rating": rating,
            "bed": ISO8601DateFormatter().string(from: entry.bedtime),
            "wake": ISO8601DateFormatter().string(from: entry.wakeTime)
        ])
        // Cap to last 60 entries — no need for unbounded growth.
        if log.count > 60 { log = Array(log.suffix(60)) }
        UserDefaults.standard.set(log, forKey: key)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func startEditing() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        editedBedtime = entry.bedtime
        editedWakeTime = entry.wakeTime
        withAnimation(.easeInOut(duration: 0.3)) { editing = true }
    }

    private func cancelEdits() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        editedBedtime = entry.bedtime
        editedWakeTime = entry.wakeTime
        withAnimation(.easeInOut(duration: 0.3)) { editing = false }
    }

    private func saveEdits() {
        guard editedWakeTime > editedBedtime else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        _ = appState.logSleep(
            bedtime: editedBedtime,
            wakeTime: editedWakeTime,
            quality: entry.quality,
            mood: entry.mood,
            notes: entry.notes,
            routineCompleted: entry.routineCompleted
        )
        record("edited")
        advanceToStory()
    }

    private func advanceToStory() {
        withAnimation(.easeInOut(duration: 0.4)) { phase = .story }
    }

    private func advanceToSummary() {
        withAnimation(.easeInOut(duration: 0.4)) { phase = .summary }
    }

    private func runEntryAnimation() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        withAnimation(.easeOut(duration: 0.4)) { heroVisible = true }
        withAnimation(.spring(response: 1.0, dampingFraction: 0.78).delay(0.15)) {
            ringVisible = true
        }
        withAnimation(.easeOut(duration: 0.45).delay(0.30)) { rowVisible = true }
        withAnimation(.easeOut(duration: 0.5).delay(0.50)) { cardsVisible = true }

        // Always start the halo + spirit pulse — it's a gentle ambient breath,
        // not just a level-up celebration. Bigger wins still get the success
        // haptic on top.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            levelUpPulse = true
        }
        if stats.leveledUpTo != nil || stats.newLongestStreak || (stats.bestInDays ?? 0) >= 7 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    // MARK: Hero

    private var heroSection: some View {
        VStack(spacing: 12) {
            // Auto-tracked chip — kept; this is the user's first proof we measured.
            HStack(spacing: 6) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 10, weight: .bold))
                Text("AUTO-TRACKED · \(entry.wakeTime.hourMinuteString)")
                    .font(MooniFont.caption(10))
                    .tracking(1.5)
            }
            .foregroundColor(MooniColor.success)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(MooniColor.success.opacity(0.14))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(MooniColor.success.opacity(0.3), lineWidth: 1))

            // ☀️ + GOOD MORNING — small emoji adds warmth without bloating the
            // header. The eyebrow is uppercased on purpose so the headline beneath
            // gets the eye.
            HStack(spacing: 6) {
                EmojiIcon(emoji: "☀", size: 13, tint: MooniColor.warning)
                Text("GOOD MORNING")
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.accentSoft)
                    .tracking(2)
            }

            Text(stats.heroHeadline(petName: petName))
                .font(MooniFont.display(26))
                .foregroundColor(MooniColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)

            ZStack {
                // Soft sunrise halo — pulses gently so the screen feels alive
                // without being distracting. Tint follows the score colour so
                // good nights glow warm/green and rough nights glow cool/red.
                Circle()
                    .fill(RadialGradient(
                        colors: [scoreTint.opacity(levelUpPulse ? 0.42 : 0.30), .clear],
                        center: .center, startRadius: 4, endRadius: 170))
                    .frame(width: 340, height: 340)
                    .blur(radius: 10)
                    .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                               value: levelUpPulse)

                DreamSpiritView(pet: appState.pet, size: 64)
                    .offset(y: -112)
                    .scaleEffect(levelUpPulse ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                               value: levelUpPulse)

                SleepScoreRing(score: ringVisible ? entry.score : 0, size: 188, lineWidth: 14)
                    .animation(.spring(response: 1.0, dampingFraction: 0.78).delay(0.15),
                               value: ringVisible)
            }
            .frame(height: 220)
        }
    }

    // MARK: Highlight row

    private var highlightRow: some View {
        HStack(spacing: 10) {
            ForEach(stats.highlightChips) { chip in
                highlightChipView(chip)
            }
        }
    }

    private func highlightChipView(_ chip: WakeHighlightChip) -> some View {
        VStack(spacing: 6) {
            Image(systemName: chip.icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(chip.tint)
            Text(chip.value)
                .font(MooniFont.title(17))
                .foregroundColor(MooniColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(chip.label)
                .font(MooniFont.caption(10))
                .foregroundColor(MooniColor.textMuted)
                .tracking(0.4)
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(chip.tint.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(chip.tint.opacity(0.32), lineWidth: 1)
                )
        )
    }

    // MARK: Level-up card

    private func levelUpCard(level: Int) -> some View {
        let badges = stats.newlyUnlockedBadges
        return MooniCard(padding: 18, cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(MooniColor.warning.opacity(0.22))
                            .frame(width: 44, height: 44)
                            .scaleEffect(levelUpPulse ? 1.15 : 1.0)
                            .blur(radius: levelUpPulse ? 1.5 : 0)
                        Image(systemName: "sparkles")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(MooniColor.warning)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("LEVEL UP")
                            .font(MooniFont.caption(11))
                            .foregroundColor(MooniColor.warning)
                            .tracking(2)
                        Text("Level \(level) · \(appState.pet.levelTitle)")
                            .font(MooniFont.title(18))
                            .foregroundColor(MooniColor.textPrimary)
                    }
                    Spacer()
                }

                HStack(spacing: 8) {
                    Image(systemName: "snowflake")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(MooniColor.accentSoft)
                    Text("+1 streak freeze unlocked")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())

                if !badges.isEmpty {
                    Divider().background(Color.white.opacity(0.08))
                    Text("Just unlocked")
                        .font(MooniFont.caption(11))
                        .foregroundColor(MooniColor.textMuted)
                        .tracking(1)
                    HStack(spacing: 10) {
                        ForEach(badges.prefix(3), id: \.id) { item in
                            newBadgeTile(item)
                        }
                        if badges.count > 3 {
                            Text("+\(badges.count - 3)")
                                .font(MooniFont.caption(12))
                                .foregroundColor(MooniColor.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.06))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(MooniColor.warning.opacity(0.35), lineWidth: 1)
        )
    }

    private func newBadgeTile(_ item: UnlockableItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: item.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(MooniColor.warning)
            Text(item.name)
                .font(MooniFont.caption(12))
                .foregroundColor(MooniColor.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(MooniColor.warning.opacity(0.14))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(MooniColor.warning.opacity(0.3), lineWidth: 1))
    }

    // MARK: Streak card

    private var streakCard: some View {
        MooniCard(padding: 16, cornerRadius: 22) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(MooniColor.warning.opacity(0.18))
                        .frame(width: 50, height: 50)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(MooniColor.warning)
                        .scaleEffect(stats.newLongestStreak && levelUpPulse ? 1.1 : 1.0)
                }
                VStack(alignment: .leading, spacing: 3) {
                    if stats.newLongestStreak {
                        Text("NEW LONGEST · \(stats.currentStreak) DAYS")
                            .font(MooniFont.caption(11))
                            .foregroundColor(MooniColor.warning)
                            .tracking(1.5)
                    } else {
                        Text("STREAK")
                            .font(MooniFont.caption(11))
                            .foregroundColor(MooniColor.textMuted)
                            .tracking(2)
                    }
                    Text("\(stats.currentStreak) day\(stats.currentStreak == 1 ? "" : "s") in a row")
                        .font(MooniFont.title(18))
                        .foregroundColor(MooniColor.textPrimary)
                    HStack(spacing: 6) {
                        if stats.currentStreak < stats.longestStreak {
                            Text("Personal best: \(stats.longestStreak)")
                                .font(MooniFont.caption(11))
                                .foregroundColor(MooniColor.textSecondary)
                        } else if !stats.newLongestStreak {
                            Text("Keep going to beat your best")
                                .font(MooniFont.caption(11))
                                .foregroundColor(MooniColor.textSecondary)
                        }
                        if stats.freezesRemaining > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "snowflake")
                                    .font(.system(size: 9, weight: .bold))
                                Text("\(stats.freezesRemaining)")
                                    .font(MooniFont.caption(11))
                            }
                            .foregroundColor(MooniColor.accentSoft)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(MooniColor.accent.opacity(0.14))
                            .clipShape(Capsule())
                        }
                    }
                }
                Spacer()
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(stats.newLongestStreak ? MooniColor.warning.opacity(0.35) : Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: XP card

    private var xpCard: some View {
        MooniCard(padding: 16, cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("DREAM ENERGY EARNED")
                            .font(MooniFont.caption(10))
                            .foregroundColor(MooniColor.textMuted)
                            .tracking(1.5)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("+\(stats.energyEarned)")
                                .font(MooniFont.display(28))
                                .foregroundColor(MooniColor.accent)
                            Text("XP")
                                .font(MooniFont.caption(12))
                                .foregroundColor(MooniColor.textSecondary)
                                .offset(y: -4)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("LEVEL \(appState.pet.level)")
                            .font(MooniFont.caption(10))
                            .foregroundColor(MooniColor.textMuted)
                            .tracking(1.5)
                        Text(appState.pet.levelTitle)
                            .font(MooniFont.title(14))
                            .foregroundColor(MooniColor.accentSoft)
                    }
                }

                MooniProgressBar(value: stats.levelProgress, height: 8)

                HStack {
                    Text("\(appState.pet.dreamEnergy) / \(appState.pet.energyForNextLevel)")
                        .font(MooniFont.caption(11))
                        .foregroundColor(MooniColor.textSecondary)
                    Spacer()
                    Text("\(stats.xpToNextLevel) XP to level \(appState.pet.level + 1)")
                        .font(MooniFont.caption(11))
                        .foregroundColor(MooniColor.textMuted)
                }
            }
        }
    }

    // MARK: Stages

    private func stagesCard(_ s: SleepStagesEstimate) -> some View {
        let total = max(s.totalSleep + s.awakeTime, 1)
        let segments: [(String, TimeInterval, Color)] = [
            ("Deep", s.deepSleep, MooniColor.success),
            ("Light", s.lightSleep, MooniColor.accentSoft),
            ("REM", s.remSleep, MooniColor.accent),
            ("Awake", s.awakeTime, MooniColor.warning)
        ]
        return MooniCard(padding: 16, cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("SLEEP STAGES")
                        .font(MooniFont.caption(10))
                        .foregroundColor(MooniColor.textMuted)
                        .tracking(1.5)
                    Spacer()
                    if s.isEstimated {
                        Text("Estimated")
                            .font(MooniFont.caption(10))
                            .foregroundColor(MooniColor.textMuted)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Capsule())
                    }
                }

                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(segments.indices, id: \.self) { idx in
                            let (_, sec, color) = segments[idx]
                            let w = max(2, geo.size.width * CGFloat(sec / total))
                            Rectangle()
                                .fill(color)
                                .frame(width: w)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .frame(height: 12)

                HStack(spacing: 10) {
                    ForEach(segments.indices, id: \.self) { idx in
                        let (label, sec, color) = segments[idx]
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 5) {
                                Circle().fill(color).frame(width: 6, height: 6)
                                Text(label)
                                    .font(MooniFont.caption(10))
                                    .foregroundColor(MooniColor.textMuted)
                                    .lineLimit(1)
                            }
                            Text(formatStage(sec))
                                .font(MooniFont.title(13))
                                .foregroundColor(MooniColor.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private func formatStage(_ sec: TimeInterval) -> String {
        let mins = Int(sec / 60)
        let h = mins / 60
        let m = mins % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    // MARK: Core stats

    private var coreStatsCard: some View {
        MooniCard(padding: 18, cornerRadius: 24) {
            VStack(spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.formattedDuration)
                        .font(MooniFont.display(30))
                        .foregroundColor(MooniColor.textPrimary)
                    Spacer()
                    Text("\(entry.score)")
                        .font(MooniFont.title(20))
                        .foregroundColor(scoreTint)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(scoreTint.opacity(0.16)))
                        .overlay(Capsule().stroke(scoreTint.opacity(0.4), lineWidth: 1))
                }

                Divider().background(Color.white.opacity(0.06))

                HStack(spacing: 0) {
                    wakeStatItem(icon: "moon.fill", label: "Went to bed", value: entry.bedtime.hourMinuteString, color: MooniColor.accent)
                    Divider().background(Color.white.opacity(0.08)).frame(width: 1, height: 40)
                    wakeStatItem(icon: "sun.max.fill", label: "Woke up", value: entry.wakeTime.hourMinuteString, color: MooniColor.warning)
                    Divider().background(Color.white.opacity(0.08)).frame(width: 1, height: 40)
                    wakeStatItem(icon: "bolt.heart.fill", label: "Readiness", value: "\(entry.readinessScore ?? entry.score)", color: scoreTint)
                }
            }
        }
    }

    private func wakeStatItem(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
            Text(value)
                .font(MooniFont.title(15))
                .foregroundColor(MooniColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(MooniFont.caption(9))
                .foregroundColor(MooniColor.textMuted)
                .tracking(0.3)
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Sparkline of recent scores

    private var sparklineCard: some View {
        let recent = Array(appState.entries
            .sorted { $0.wakeTime < $1.wakeTime }
            .suffix(7))
        return Group {
            if recent.count >= 2 {
                MooniCard(padding: 16, cornerRadius: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("LAST 7 NIGHTS")
                                .font(MooniFont.caption(10))
                                .foregroundColor(MooniColor.textMuted)
                                .tracking(1.5)
                            Spacer()
                            let avg = recent.map(\.score).reduce(0, +) / max(1, recent.count)
                            Text("Avg \(avg)")
                                .font(MooniFont.caption(11))
                                .foregroundColor(MooniColor.textSecondary)
                        }
                        sparkline(recent: recent)
                            .frame(height: 56)
                    }
                }
            }
        }
    }

    private func sparkline(recent: [SleepEntry]) -> some View {
        let scores = recent.map { Double($0.score) }
        let minS = max(0, (scores.min() ?? 0) - 5)
        let maxS = min(100, (scores.max() ?? 100) + 5)
        let range = max(1, maxS - minS)
        let todayKey = entry.dayKey
        return GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let step = scores.count > 1 ? w / CGFloat(scores.count - 1) : w
            ZStack(alignment: .topLeading) {
                Path { path in
                    for (i, s) in scores.enumerated() {
                        let x = CGFloat(i) * step
                        let y = h - CGFloat((s - minS) / range) * h
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(MooniColor.accent.opacity(0.85), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))

                ForEach(recent.indices, id: \.self) { i in
                    let s = scores[i]
                    let x = CGFloat(i) * step
                    let y = h - CGFloat((s - minS) / range) * h
                    let isToday = recent[i].dayKey == todayKey
                    Circle()
                        .fill(isToday ? scoreTint : MooniColor.accentSoft.opacity(0.7))
                        .frame(width: isToday ? 10 : 6, height: isToday ? 10 : 6)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(isToday ? 0.6 : 0), lineWidth: 1.5)
                        )
                        .position(x: x, y: y)
                }
            }
        }
    }

    // MARK: Pet message

    private var petMessageCard: some View {
        MooniCard(padding: 14, cornerRadius: 18) {
            HStack(alignment: .top, spacing: 12) {
                DreamSpiritView(pet: appState.pet, size: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text(petName)
                        .font(MooniFont.caption(11))
                        .foregroundColor(MooniColor.accentSoft)
                        .tracking(1.2)
                    Text(stats.petMessage(petName: petName))
                        .font(MooniFont.body(14))
                        .foregroundColor(MooniColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: CTA

    private var ctaButton: some View {
        PrimaryButton(title: "See full analysis", icon: "sparkles") {
            dismiss()
        }
    }
}

#Preview {
    HomeView(showPaywall: .constant(false))
        .environmentObject(AppState.preview)
        .environmentObject(SubscriptionManager.shared)
}
