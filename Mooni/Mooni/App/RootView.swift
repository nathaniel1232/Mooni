import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject var appState: AppState

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
        }
        .animation(.easeInOut(duration: 0.4), value: appState.hasCompletedOnboarding)
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
