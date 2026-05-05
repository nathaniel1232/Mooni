import SwiftUI

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

    enum Tab: Hashable {
        case home, log, pet, routine
    }

    var body: some View {
        TabView(selection: $selection) {
            HomeView(showPaywall: $showPaywall)
                .tabItem { Label("Home", systemImage: "moon.stars.fill") }
                .tag(Tab.home)

            SleepLogView()
                .tabItem { Label("Sleep", systemImage: "bed.double.fill") }
                .tag(Tab.log)

            PetScreenView(showPaywall: $showPaywall)
                .tabItem { Label("Spirit", systemImage: "sparkles") }
                .tag(Tab.pet)

            RoutineView()
                .tabItem { Label("Routine", systemImage: "checklist") }
                .tag(Tab.routine)
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
}

#Preview {
    RootView()
        .environmentObject(AppState.preview)
        .environmentObject(SubscriptionManager.shared)
}
