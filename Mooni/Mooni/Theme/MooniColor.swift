import SwiftUI

enum MooniColor {
    // MARK: - Adaptive helper
    /// Picks a value for the current app appearance (time-of-day driven).
    /// Used by every token that should flip between the light morning theme
    /// and the dark night theme. `ThemeManager.shared.mode` is the source.
    static func dyn(light: Color, dark: Color) -> Color {
        ThemeManager.currentMode == .light ? light : dark
    }

    /// The dark deep-navy used as INK on accent/warning fills and the tab bar.
    /// Stays dark in BOTH modes on purpose — it's the "contrast color" laid on
    /// top of the bright accent pills, never a surface, so it must not flip.
    static let background = Color(red: 0.06, green: 0.07, blue: 0.16)

    static var surface: Color {
        dyn(light: Color(red: 1.0, green: 1.0, blue: 1.0),
            dark: Color(red: 0.11, green: 0.12, blue: 0.24))
    }
    static var surfaceElevated: Color {
        dyn(light: Color(red: 0.95, green: 0.94, blue: 1.0),
            dark: Color(red: 0.16, green: 0.17, blue: 0.32))
    }

    // MARK: - App-wide base background
    // The onboarding flow and the main app share ONE dark background so there's
    // no colour jump at the hand-off. These stay dark (onboarding is always
    // night); the MAIN app's background flips via `MooniGradient.night`.
    static let bgTop = Color(red: 0.045, green: 0.05, blue: 0.12)
    static let bgBottom = Color(red: 0.02, green: 0.025, blue: 0.065)

    // App accent — shifted from the old lavender to the redesign's blue so the
    // whole app matches the new Home. (Light-theme values are dormant: the
    // theme is forced dark during the redesign.)
    static let accent = Color(red: 0.23, green: 0.56, blue: 1.0)
    static let accentSoft = Color(red: 0.58, green: 0.80, blue: 1.0)

    /// Accent used as TEXT or icon ink on the screen/card background.
    /// The plain `accent`/`accentSoft` are light lavenders tuned to read on the
    /// dark night theme and to sit *under* dark ink on accent-filled buttons —
    /// but as foreground text on the bright morning theme they wash out and
    /// fail contrast. This token keeps the exact night-theme accent at night
    /// and swaps to a deeper, AA-readable violet in the light theme. Use it for
    /// `.foregroundColor` / `.foregroundStyle`, never for fills (fills should
    /// stay `accent` so their dark ink keeps its contrast).
    static var accentText: Color {
        dyn(light: Color(red: 0.16, green: 0.42, blue: 0.86), dark: Color(red: 0.50, green: 0.76, blue: 1.0))
    }

    /// Accent for bare FILLS that must read against the screen/card background —
    /// progress-bar fills, indicators, meters. Button fills keep the light
    /// `accent` (their dark ink needs that contrast), but a bare lavender bar
    /// disappears on the bright morning theme, leaving "barely-there" progress
    /// bars. This keeps the night accent at night and deepens to a visible
    /// violet in the light theme.
    static var accentFill: Color {
        dyn(light: Color(red: 0.20, green: 0.50, blue: 0.95), dark: accent)
    }

    static let success = Color(red: 0.55, green: 0.85, blue: 0.7)
    static let warning = Color(red: 1.0, green: 0.78, blue: 0.55)
    static let danger = Color(red: 1.0, green: 0.6, blue: 0.7)

    // MARK: - Adaptive text
    static var textPrimary: Color {
        dyn(light: Color(red: 0.13, green: 0.12, blue: 0.26), dark: .white)
    }
    static var textSecondary: Color {
        dyn(light: Color(red: 0.34, green: 0.30, blue: 0.50), dark: .white.opacity(0.7))
    }
    static var textMuted: Color {
        dyn(light: Color(red: 0.50, green: 0.46, blue: 0.64), dark: .white.opacity(0.45))
    }

    // MARK: - Adaptive surfaces (replace inline `Color.white.opacity(...)`)
    /// Standard translucent card fill.
    static var card: Color {
        dyn(light: Color(red: 0.40, green: 0.36, blue: 0.62).opacity(0.07),
            dark: .white.opacity(0.05))
    }
    /// Selected / emphasised card fill.
    static var cardStrong: Color {
        dyn(light: Color(red: 0.40, green: 0.36, blue: 0.62).opacity(0.12),
            dark: .white.opacity(0.12))
    }
    /// Hairline strokes, dividers, progress tracks.
    static var hairline: Color {
        dyn(light: Color(red: 0.20, green: 0.18, blue: 0.40).opacity(0.12),
            dark: .white.opacity(0.10))
    }

    static let petGlow = Color(red: 0.78, green: 0.85, blue: 1.0)

    // MARK: - Gamification tokens
    /// Streak flame core — used by `StreakFireBadge`. The bright tip of the flame.
    static let streakFire = Color(red: 1.0, green: 0.62, blue: 0.18)
    /// Deeper red base of the flame, paired with `streakFire` in a vertical gradient.
    static let streakEmber = Color(red: 1.0, green: 0.35, blue: 0.30)
    /// Cold blue replacement when a streak is frozen (streak-freeze item active).
    static let streakFrozen = Color(red: 0.55, green: 0.82, blue: 1.0)

    /// XP / progress green — high contrast against the dark surface for the XP bar fill.
    static let xpGreen = Color(red: 0.34, green: 0.85, blue: 0.45)
    static let xpGreenSoft = Color(red: 0.65, green: 0.95, blue: 0.65)
}

extension LinearGradient {
    /// Vertical flame gradient (bright top → red base) used inside the streak fire icon.
    static let streakFlame = LinearGradient(
        colors: [MooniColor.streakFire, MooniColor.streakEmber],
        startPoint: .top,
        endPoint: .bottom
    )

    /// XP bar fill: a left-to-right green sweep that reads as "progress".
    static let xpFill = LinearGradient(
        colors: [MooniColor.xpGreen, MooniColor.xpGreenSoft],
        startPoint: .leading,
        endPoint: .trailing
    )
}

enum MooniGradient {
    /// The main app's screen background. Despite the name it now ADAPTS to the
    /// time of day: a light, airy lavender-cream by morning/day, the deep dark
    /// gradient by evening/night. (Onboarding/paywall use their own constant
    /// dark gradient, so they're unaffected.)
    static var night: LinearGradient {
        switch ThemeManager.currentMode {
        case .light:
            return LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.96, blue: 1.0),
                    Color(red: 0.93, green: 0.92, blue: 0.99),
                    Color(red: 0.90, green: 0.89, blue: 0.99)
                ],
                startPoint: .top, endPoint: .bottom)
        case .dark:
            return LinearGradient(
                colors: [
                    MooniColor.bgTop,
                    Color(red: 0.033, green: 0.038, blue: 0.092),
                    MooniColor.bgBottom
                ],
                startPoint: .top, endPoint: .bottom)
        }
    }

    static let dawn = LinearGradient(
        colors: [
            Color(red: 0.06, green: 0.07, blue: 0.18),
            Color(red: 0.16, green: 0.13, blue: 0.32),
            Color(red: 0.32, green: 0.24, blue: 0.48),
            Color(red: 0.55, green: 0.45, blue: 0.78)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Daytime gradient — deep indigo/blue sky feel, dark enough for white text.
    static let day = LinearGradient(
        colors: [
            Color(red: 0.08, green: 0.14, blue: 0.38),
            Color(red: 0.16, green: 0.24, blue: 0.54),
            Color(red: 0.26, green: 0.36, blue: 0.66)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Adaptive card fill. Dark mode: the familiar white glass. Light mode: a
    /// soft lavender-tinted glass so cards lift off the cream background.
    static var card: LinearGradient {
        switch ThemeManager.currentMode {
        case .light:
            return LinearGradient(
                colors: [Color.white.opacity(0.9), Color.white.opacity(0.6)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .dark:
            // Solid navy card to match the redesigned Home's NightCard.
            return LinearGradient(
                colors: [Color(red: 0.085, green: 0.115, blue: 0.22),
                         Color(red: 0.06, green: 0.085, blue: 0.17)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    /// Background gradient that adapts to time of day.
    static var adaptive: LinearGradient {
        switch TimeOfDay.current {
        case .morning, .day: return day
        case .evening, .night: return night
        }
    }
}
