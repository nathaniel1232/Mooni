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
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(subscriptionManager)
                .preferredColorScheme(.dark)
        }
    }

    /// Registers Outfit .ttf files bundled under Mooni/Resources/Fonts at runtime,
    /// so MooniFont can use Outfit-* postscript names without needing Info.plist
    /// UIAppFonts entries (which Xcode's auto-generated Info.plist doesn't honor).
    private static func registerCustomFonts() {
        let names = ["Outfit-Regular", "Outfit-Medium", "Outfit-SemiBold", "Outfit-Bold"]
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
