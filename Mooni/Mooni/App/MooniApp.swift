import SwiftUI
import CoreText
import RevenueCat

@main
struct MooniApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    init() {
        Self.registerCustomFonts()
        SubscriptionManager.shared.configure()
        // Force-init so the UNUserNotificationCenter delegate is set
        // before any wake-probe notification can be tapped.
        _ = NotificationManager.shared
        // SAFETY NET (mechanism 8): register the background refresh task
        // before launch completes. No-op/logs if the capability isn't set.
        BackgroundRefreshManager.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(subscriptionManager)
        }
    }

    /// Registers Outfit .ttf files bundled under SleepOwl/Fonts at runtime, so
    /// MooniFont can use Outfit-* postscript names without needing Info.plist
    /// UIAppFonts entries (Xcode's auto-generated Info.plist drops array values).
    private static func registerCustomFonts() {
        let names = [
            "Outfit-Thin", "Outfit-ExtraLight", "Outfit-Light", "Outfit-Regular",
            "Outfit-Medium", "Outfit-SemiBold", "Outfit-Bold", "Outfit-ExtraBold",
            "Outfit-Black",
            "Poppins-Regular", "Poppins-Medium", "Poppins-SemiBold", "Poppins-Bold"
        ]
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
