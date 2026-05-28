import SwiftUI

/// Visual theme for a Sleepowl Reveal card. Picking a template only swaps the
/// background gradient + accent colors — the layout and copy stay identical so
/// the user can post 4 different-looking videos of the same week and the brand
/// reads consistently.
enum RevealTemplate: String, CaseIterable, Identifiable {
    case night
    case aurora
    case dream
    case galaxy

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .night:  return "Night"
        case .aurora: return "Aurora"
        case .dream:  return "Dream"
        case .galaxy: return "Galaxy"
        }
    }

    /// Background gradient that fills the entire portrait card. High enough
    /// contrast to keep white text readable everywhere on the card.
    var background: LinearGradient {
        switch self {
        case .night:
            return LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.05, blue: 0.16),
                    Color(red: 0.09, green: 0.07, blue: 0.26),
                    Color(red: 0.18, green: 0.10, blue: 0.32)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .aurora:
            return LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.12, blue: 0.22),
                    Color(red: 0.10, green: 0.32, blue: 0.40),
                    Color(red: 0.20, green: 0.55, blue: 0.55),
                    Color(red: 0.42, green: 0.74, blue: 0.62)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .dream:
            return LinearGradient(
                colors: [
                    Color(red: 0.16, green: 0.10, blue: 0.30),
                    Color(red: 0.45, green: 0.22, blue: 0.50),
                    Color(red: 0.86, green: 0.50, blue: 0.62),
                    Color(red: 1.00, green: 0.78, blue: 0.62)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .galaxy:
            return LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.02, blue: 0.08),
                    Color(red: 0.10, green: 0.04, blue: 0.22),
                    Color(red: 0.20, green: 0.08, blue: 0.38),
                    Color(red: 0.04, green: 0.04, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    /// Primary accent — used on the score numbers, divider line, and "AFTER"
    /// chip. Chosen to harmonize with the gradient.
    var accent: Color {
        switch self {
        case .night:  return Color(red: 0.78, green: 0.72, blue: 1.0)
        case .aurora: return Color(red: 0.78, green: 1.0,  blue: 0.86)
        case .dream:  return Color(red: 1.0,  green: 0.88, blue: 0.78)
        case .galaxy: return Color(red: 0.86, green: 0.78, blue: 1.0)
        }
    }

    /// Secondary accent used on small chips & icons.
    var secondaryAccent: Color {
        switch self {
        case .night:  return Color(red: 1.0, green: 0.85, blue: 0.55) // golden moon
        case .aurora: return Color(red: 0.55, green: 0.88, blue: 1.0)  // pale teal
        case .dream:  return Color(red: 1.0, green: 0.70, blue: 0.85)  // pink
        case .galaxy: return Color(red: 0.65, green: 0.55, blue: 1.0)  // purple
        }
    }

    /// True when the gradient is light enough that the watermark needs darker
    /// text. Currently only `.aurora` qualifies.
    var prefersDarkText: Bool {
        self == .aurora
    }

    /// Whether to render a starfield overlay on top of the gradient.
    var hasStars: Bool {
        switch self {
        case .night, .galaxy: return true
        case .aurora, .dream: return false
        }
    }
}
