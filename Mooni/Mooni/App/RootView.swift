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
/// sleeping. The only escape is "Wake up", which kicks them into the morning
/// check-in. This is the in-app version of a screen-time block.
struct SleepingOverlay: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            MooniGradient.night.ignoresSafeArea()
            StarsBackground(count: 70)

            VStack(spacing: 22) {
                Spacer()

                LunaMoodHero(
                    pet: appState.pet,
                    mood: .sleepy,
                    size: 200,
                    caption: nil
                )

                VStack(spacing: 10) {
                    Text("\(appState.pet.name) is sleeping")
                        .font(MooniFont.display(28))
                        .foregroundColor(MooniColor.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("The app is resting too. Tap wake up when you're up — Luna will ask you a couple of questions before unlocking the day.")
                        .font(MooniFont.body(14))
                        .foregroundColor(MooniColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }

                if let started = appState.sleepStartedAt {
                    Text("Sleep started at \(started.hourMinuteString)")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textMuted)
                }

                Spacer()

                PrimaryButton(title: "Wake up", icon: "sun.max.fill") {
                    appState.wakeUpFromSleepMode()
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 32)
            }
        }
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
        case home, sleep, quest, luna, me
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

            PetScreenView(showPaywall: $showPaywall)
                .tabItem { Label("Luna", systemImage: "sparkles") }
                .tag(Tab.luna)

            ProfileView(showPaywall: $showPaywall)
                .tabItem { Label("Me", systemImage: "person.crop.circle.fill") }
                .tag(Tab.me)
        }
        .tint(MooniColor.accent)
        .sheet(isPresented: $appState.showMorningCheckIn) {
            MorningCheckInView()
        }
        .mooniPaywall(isPresented: $showPaywall)
        .task { await appState.importHealthKitSleep() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await appState.importHealthKitSleep() }
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
