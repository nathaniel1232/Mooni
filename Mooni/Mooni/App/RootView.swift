import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var subscription = SubscriptionManager.shared
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.scenePhase) private var scenePhase

    /// The light/day theme only applies once the user is in the actual app.
    private var showingMainApp: Bool {
        appState.hasCompletedOnboarding && subscription.isPro
    }

    var body: some View {
        ZStack {
            // Root backdrop stays dark — onboarding/paywall draw their own dark
            // background over it, and each main-app screen draws the adaptive
            // `MooniGradient.night` (light by day) on top, so this only shows
            // at edges/during transitions.
            LinearGradient(colors: [MooniColor.bgTop, MooniColor.bgBottom],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            if !appState.hasCompletedOnboarding {
                OnboardingView()
                    .transition(.opacity)
            } else if !subscription.isPro {
                // Hard paywall: there is no free tier. Once onboarding is done
                // the app is fully gated behind Pro — no close button, no
                // "continue without subscribing". The only ways past are an
                // actual purchase/restore or the hidden developer unlock.
                PaywallView(hardLock: true)
                    .transition(.opacity)
            } else {
                // `.id(theme.mode)` rebuilds the main app when day↔night flips
                // so the adaptive tokens are re-read. Flips happen ~twice a day.
                MainTabView()
                    .id(theme.mode)
                    .transition(.opacity)
            }

            if appState.isSleeping {
                SleepingOverlay()
                    .transition(.opacity)
                    .zIndex(10)
            }

            // Warm-red tint while wind-down is active. Above all UI but
            // ignores hit-testing so the user can still tap.
            WindDownTintOverlay()
                .zIndex(20)
        }
        // Status bar + system controls follow the theme: dark content in the
        // light morning theme, light content at night / in onboarding.
        .preferredColorScheme(theme.mode == .light ? .light : .dark)
        .animation(.easeInOut(duration: 0.4), value: appState.hasCompletedOnboarding)
        .animation(.easeInOut(duration: 0.4), value: subscription.isPro)
        .animation(.easeInOut(duration: 0.4), value: appState.isSleeping)
        // Full-screen level-up takeover — fires from ANY screen the instant the
        // pet levels up (its own window sits above every sheet/cover), not just
        // when the user lands on Home.
        .onChange(of: appState.levelUpCelebration) { _, newValue in
            guard let level = newValue, level > 1 else { return }
            LevelUpPresenter.shared.present(level: level, petName: appState.pet.name)
            appState.levelUpCelebration = nil
        }
        .onAppear { theme.apply(forMainApp: showingMainApp) }
        .onChange(of: showingMainApp) { _, v in theme.apply(forMainApp: v) }
        // Feed scenePhase to the activity estimator at the root level so we
        // catch background/active transitions even during onboarding.
        .onChange(of: scenePhase) { _, phase in
            ActivitySleepEstimator.shared.handleScenePhaseChange(phase)
            if phase == .active { theme.apply(forMainApp: showingMainApp) }
        }
    }
}

/// Full-screen lock that stays in front of the tab bar while the user is
/// sleeping. The only escape is "I'm awake", which kicks them into the morning
/// check-in. This is the in-app version of a screen-time block.
struct SleepingOverlay: View {
    @EnvironmentObject var appState: AppState
    @State private var auraPulse: CGFloat = 0.85

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            content(now: context.date)
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let wakeAnchor = appState.nextWakeProbeAnchor
        let openSecondsBeforeWake: TimeInterval = 60 * 60        // 1 hour
        let lateOpenAfterStart: TimeInterval = (appState.goalHours + 0.5) * 3600
        let started = appState.sleepStartedAt
        let isLate = started.map { now.timeIntervalSince($0) >= lateOpenAfterStart } ?? false
        let canWake = now.timeIntervalSince(wakeAnchor) >= -openSecondsBeforeWake || isLate

        ZStack {
            MooniGradient.night.ignoresSafeArea()
            StarsBackground(count: 90)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [MooniColor.accent.opacity(0.34), .clear],
                        center: .center,
                        startRadius: 6,
                        endRadius: 240
                    )
                )
                .frame(width: 460, height: 460)
                .scaleEffect(auraPulse)
                .opacity(0.85)
                .onAppear {
                    withAnimation(.easeInOut(duration: 4.2).repeatForever(autoreverses: true)) {
                        auraPulse = 1.05
                    }
                }

            VStack(spacing: 26) {
                Spacer()

                LunaMoodHero(
                    pet: appState.pet,
                    mood: .sleepy,
                    size: 210,
                    caption: nil
                )

                VStack(spacing: 12) {
                    Text("\(appState.pet.name) is sleeping")
                        .font(MooniFont.display(30))
                        .foregroundColor(MooniColor.textPrimary)
                        .multilineTextAlignment(.center)

                    if let started {
                        HStack(spacing: 12) {
                            sleepStat(
                                icon: "moon.stars.fill",
                                value: started.hourMinuteString,
                                label: "Asleep at"
                            )
                            sleepStat(
                                icon: "sunrise.fill",
                                value: wakeAnchor.hourMinuteString,
                                label: "Target wake"
                            )
                        }
                        .padding(.top, 4)
                    }

                    Text(canWake
                         ? "Tap when you're awake — \(appState.pet.name) will ask a few quick questions before unlocking the day."
                         : "\(appState.pet.name) will check in around \(wakeAnchor.addingTimeInterval(-openSecondsBeforeWake).hourMinuteString). Sleep tight.")
                        .font(MooniFont.body(14))
                        .foregroundColor(MooniColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .padding(.top, 10)
                }

                Spacer()

                if canWake {
                    PrimaryButton(title: "Are you awake?", icon: "sun.max.fill") {
                        appState.wakeUpFromSleepMode()
                    }
                    .frame(maxWidth: 280)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    VStack(spacing: 14) {
                        HStack(spacing: 8) {
                            Image(systemName: "moon.zzz.fill")
                                .foregroundColor(MooniColor.accentSoft)
                            Text("Sleep mode active")
                                .font(MooniFont.caption(13))
                                .foregroundColor(MooniColor.textMuted)
                                .textCase(.uppercase)
                        }

                        // Always-available escape: arming the night by mistake
                        // (or during the day) must never trap the user behind
                        // the lock until `canWake`. This exits sleep mode
                        // WITHOUT logging anything.
                        Button {
                            appState.cancelSleepMode()
                        } label: {
                            Text("I'm not actually going to bed")
                                .font(MooniFont.caption(13))
                                .foregroundColor(MooniColor.textMuted)
                                .underline()
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 36)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: canWake)
        }
    }

    private func sleepStat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(MooniColor.accentSoft)
                .font(.system(size: 14, weight: .semibold))
            Text(value)
                .font(MooniFont.title(15))
                .foregroundColor(MooniColor.textPrimary)
            Text(label)
                .font(MooniFont.caption(11))
                .foregroundColor(MooniColor.textMuted)
                .textCase(.uppercase)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection: Tab
    @State private var showPaywall = false
    @State private var showDiscountPaywall = false
    @State private var showVoiceTracking = false

    init() {
        // DEBUG: allow screenshot tooling to set the initial tab via a
        // UserDefaults key. No effect in production unless that key is set.
        let raw = UserDefaults.standard.string(forKey: "debug.initialTab") ?? "home"
        let initial: Tab
        switch raw {
        case "sleep", "stats": initial = .stats
        case "sounds":         initial = .sounds
        case "me":             initial = .me
        default:               initial = .home
        }
        self._selection = State(initialValue: initial)
    }

    enum Tab: Hashable {
        case home, stats, sounds, me
    }

    var body: some View {
        Group {
            switch selection {
            case .home:   HomeView(showPaywall: $showPaywall)
            case .stats:  SleepReportView(showPaywall: $showPaywall)
            case .sounds: FallAsleepView()
            case .me:     ProfileView(showPaywall: $showPaywall)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Custom bar with a raised center "Sleep" button that starts voice
        // tracking, instead of being a normal tab destination.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MooniTabBar(selection: $selection) {
                Haptics.tap()
                showVoiceTracking = true
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .fullScreenCover(isPresented: $appState.showMorningCheckIn) {
            MorningCheckInView()
        }
        .mooniPaywall(isPresented: $showPaywall)
        .fullScreenCover(isPresented: $showDiscountPaywall) {
            DiscountPaywallView(
                petName: appState.pet.name,
                onAccept: { showDiscountPaywall = false },
                onDecline: { showDiscountPaywall = false }
            )
        }
        .fullScreenCover(isPresented: $showVoiceTracking) {
            VoiceTrackingView()
        }
        .task {
            await appState.runAutomationMaintenance(reason: "launch task")
            await refreshProAndMaybeOfferDiscount()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task {
                    await appState.runAutomationMaintenance(reason: "foreground")
                    await refreshProAndMaybeOfferDiscount()
                }
            case .background, .inactive:
                // SAFETY NET (mechanism 2): phone put down at night → arm the
                // night automatically so probes fire even with no "going to
                // bed" tap.
                appState.autoArmNightIfDue()
                // SAFETY NET (mechanism 8): queue the next background refresh.
                BackgroundRefreshManager.scheduleNext()
            @unknown default:
                break
            }
        }
    }

    /// Re-confirm entitlement on launch/foreground (belt-and-suspenders on top
    /// of the RevenueCat delegate, so Pro stays correct for the whole paid
    /// period and flips off promptly when it lapses), then decide whether to
    /// surface the one-time win-back discount offer.
    @MainActor
    private func refreshProAndMaybeOfferDiscount() async {
        await subscriptionManager.refreshCustomerInfo()

        // Never stack the win-back offer on another modal or the sleep lock,
        // and only show it when a GENUINE discount package is configured —
        // otherwise we'd be advertising a "special offer" at full price.
        guard !showPaywall, !showDiscountPaywall,
              !appState.isSleeping, !appState.showMorningCheckIn,
              subscriptionManager.discountAnnualPackage != nil,
              appState.shouldPresentDiscountPaywall() else { return }

        appState.markDiscountPaywallShown()
        showDiscountPaywall = true
    }

}

// MARK: - Custom bottom bar

/// Frosted bottom bar that "merges" with the phone (material + hairline,
/// bleeding into the home-indicator area) with a raised center "Sleep" button
/// that starts voice tracking instead of switching tabs.
struct MooniTabBar: View {
    @Binding var selection: MainTabView.Tab
    var onSleep: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            item(.home,   "house.fill",          "Home")
            item(.stats,  "waveform.path.ecg",   "Stats")
            Spacer().frame(width: 70)                // gap for the raised button
            item(.sounds, "music.note",          "Sounds")
            item(.me,     "person.fill",          "Profile")
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(
            Rectangle()
                .fill(Color(red: 0.055, green: 0.075, blue: 0.15))
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            sleepButton.offset(y: -22)
        }
    }

    /// Raised center button — just the moon icon inside the filled circle.
    private var sleepButton: some View {
        Button(action: onSleep) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [NightUI.accentBright, NightUI.accent, NightUI.accentDeep],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 64, height: 64)
                    .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                    .shadow(color: NightUI.accent.opacity(0.55), radius: 12, y: 4)
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start sleep tracking")
    }

    private func item(_ tab: MainTabView.Tab, _ icon: String, _ label: String) -> some View {
        let selected = selection == tab
        return Button {
            selection = tab
            Haptics.tap()
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 22, weight: .semibold))
                Text(label).font(MooniFont.custom(11, weight: .medium))
            }
            .foregroundColor(selected ? NightUI.accentBright : Color.white.opacity(0.42))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RootView()
        .environmentObject(AppState.preview)
        .environmentObject(SubscriptionManager.shared)
}
