import SwiftUI

enum MooniColor {
    static let background = Color(red: 0.06, green: 0.07, blue: 0.16)
    static let surface = Color(red: 0.11, green: 0.12, blue: 0.24)
    static let surfaceElevated = Color(red: 0.16, green: 0.17, blue: 0.32)

    static let accent = Color(red: 0.65, green: 0.62, blue: 1.0)
    static let accentSoft = Color(red: 0.85, green: 0.83, blue: 1.0)

    static let success = Color(red: 0.55, green: 0.85, blue: 0.7)
    static let warning = Color(red: 1.0, green: 0.78, blue: 0.55)
    static let danger = Color(red: 1.0, green: 0.6, blue: 0.7)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textMuted = Color.white.opacity(0.45)

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
    static let night = LinearGradient(
        colors: [
            Color(red: 0.05, green: 0.06, blue: 0.18),
            Color(red: 0.10, green: 0.08, blue: 0.28),
            Color(red: 0.18, green: 0.12, blue: 0.32)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

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

    static let card = LinearGradient(
        colors: [
            Color.white.opacity(0.10),
            Color.white.opacity(0.04)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Background gradient that adapts to time of day.
    static var adaptive: LinearGradient {
        switch TimeOfDay.current {
        case .morning, .day: return day
        case .evening, .night: return night
        }
    }
}
