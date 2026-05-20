import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            MooniGradient.night.ignoresSafeArea()

            if !appState.hasCompletedOnboarding {
                OnboardingView()
                    .transition(.opacity)
            } else {
                MainTabView()
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
        .animation(.easeInOut(duration: 0.4), value: appState.hasCompletedOnboarding)
        .animation(.easeInOut(duration: 0.4), value: appState.isSleeping)
        // Feed scenePhase to the activity estimator at the root level so we
        // catch background/active transitions even during onboarding.
        .onChange(of: scenePhase) { _, phase in
            ActivitySleepEstimator.shared.handleScenePhaseChange(phase)
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
    @State private var selection: Tab = .home
    @State private var showPaywall = false

    init() {
        Self.configureTabBarAppearance()
    }

    enum Tab: Hashable {
        case home, sleep, quest, sounds, me
    }

    var body: some View {
        TabView(selection: $selection) {
            HomeView(showPaywall: $showPaywall)
                .tabItem { Label("Home", systemImage: "moon.stars.fill") }
                .tag(Tab.home)

            SleepReportView(showPaywall: $showPaywall)
                .tabItem { Label("Sleep", systemImage: "chart.xyaxis.line") }
                .tag(Tab.sleep)

            BedtimeQuestView(showPaywall: $showPaywall)
                .tabItem { Label("Quest", systemImage: "checklist") }
                .tag(Tab.quest)

            FallAsleepView()
                .tabItem { Label("Sounds", systemImage: "waveform") }
                .tag(Tab.sounds)

            ProfileView(showPaywall: $showPaywall)
                .tabItem { Label("Me", systemImage: "person.crop.circle.fill") }
                .tag(Tab.me)
        }
        .tint(MooniColor.accent)
        .onChange(of: selection) { _, _ in Haptics.tap() }
        .sheet(isPresented: $appState.showMorningCheckIn) {
            MorningCheckInView()
        }
        .mooniPaywall(isPresented: $showPaywall)
        .task {
            await appState.runAutomationMaintenance(reason: "launch task")
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task { await appState.runAutomationMaintenance(reason: "foreground") }
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

    private static func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        appearance.backgroundColor = UIColor(MooniColor.background).withAlphaComponent(0.86)
        appearance.shadowColor = UIColor.white.withAlphaComponent(0.08)

        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: UIColor.white.withAlphaComponent(0.56)
        ]
        itemAppearance.selected.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: UIColor(MooniColor.accentSoft)
        ]
        itemAppearance.normal.iconColor = UIColor.white.withAlphaComponent(0.56)
        itemAppearance.selected.iconColor = UIColor(MooniColor.accentSoft)

        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().isTranslucent = true
    }
}

#Preview {
    RootView()
        .environmentObject(AppState.preview)
        .environmentObject(SubscriptionManager.shared)
}
