import SwiftUI
import Combine

/// Day vs night appearance for the MAIN app (not onboarding/paywall, which
/// stay dark by design). Driven by time of day, not the system light/dark
/// setting — mornings/days read light & airy, evenings/nights read dark.
enum MooniThemeMode {
    case light   // morning + day
    case dark    // evening + night
}

/// Single source of truth for the current app appearance. `MooniColor`'s
/// adaptive tokens and `MooniGradient.night` read `ThemeManager.currentMode`.
/// Views re-render on a flip because `RootView` observes this object and
/// re-ids its content (flips happen ~twice a day, so the rebuild is cheap).
@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    /// Nonisolated mirror of `mode` so the `MooniColor` tokens (called from
    /// any context) can read it without an actor hop. Kept in sync from `mode`.
    nonisolated(unsafe) static var currentMode: MooniThemeMode = ThemeManager.modeForNow()

    @Published var mode: MooniThemeMode {
        didSet { ThemeManager.currentMode = mode }
    }

    private init() {
        let m = ThemeManager.modeForNow()
        mode = m
        ThemeManager.currentMode = m
    }

    nonisolated static func modeForNow() -> MooniThemeMode {
        #if DEBUG
        // Debug override (screenshot tooling / dev menu): force a theme via the
        // "debug.themeMode" UserDefaults key ("light"/"dark"). No effect in
        // release, and ignored unless the key is set.
        if let forced = UserDefaults.standard.string(forKey: "debug.themeMode") {
            if forced == "light" { return .light }
            if forced == "dark" { return .dark }
        }
        #endif
        switch TimeOfDay.current {
        case .morning, .day:    return .light
        case .evening, .night:  return .dark
        }
    }

    /// Recompute from the clock. Call on launch / foreground / scene-active.
    func refresh() {
        let next = Self.modeForNow()
        if next != mode { mode = next }
    }

    /// Resolve the mode for what's on screen. The light/day theme only applies
    /// to the MAIN app — onboarding and the paywall are always dark by design
    /// (they share `MooniColor` tokens, so they'd render dark-on-dark in the
    /// morning otherwise). Call from `RootView` whenever the visible branch or
    /// scene phase changes.
    func apply(forMainApp: Bool) {
        let next: MooniThemeMode = forMainApp ? Self.modeForNow() : .dark
        if next != mode { mode = next }
    }
}
