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
            Color(red: 0.20, green: 0.18, blue: 0.40),
            Color(red: 0.45, green: 0.30, blue: 0.55),
            Color(red: 0.85, green: 0.55, blue: 0.55)
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
}
