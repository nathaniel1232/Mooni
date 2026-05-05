import Foundation
import SwiftUI

/// The starter room (background) the user picks during onboarding.
/// Premium rooms are layered on top of these later.
enum PetRoom: String, Codable, CaseIterable, Identifiable {
    case cozyForest
    case moonBedroom
    case cloudNest

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cozyForest:  return "Cozy Forest"
        case .moonBedroom: return "Moon Bedroom"
        case .cloudNest:   return "Cloud Nest"
        }
    }

    var tagline: String {
        switch self {
        case .cozyForest:  return "Mossy, warm, full of fireflies."
        case .moonBedroom: return "Soft sheets under a glowing moon."
        case .cloudNest:   return "Floating high above the world."
        }
    }

    var icon: String {
        switch self {
        case .cozyForest:  return "leaf.fill"
        case .moonBedroom: return "bed.double.fill"
        case .cloudNest:   return "cloud.fill"
        }
    }

    /// Background gradient for the placeholder room preview.
    var gradient: LinearGradient {
        switch self {
        case .cozyForest:
            return LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.18, blue: 0.18),
                    Color(red: 0.14, green: 0.28, blue: 0.22),
                    Color(red: 0.20, green: 0.34, blue: 0.24)
                ],
                startPoint: .top, endPoint: .bottom
            )
        case .moonBedroom:
            return LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.07, blue: 0.20),
                    Color(red: 0.14, green: 0.13, blue: 0.32),
                    Color(red: 0.26, green: 0.20, blue: 0.42)
                ],
                startPoint: .top, endPoint: .bottom
            )
        case .cloudNest:
            return LinearGradient(
                colors: [
                    Color(red: 0.20, green: 0.24, blue: 0.42),
                    Color(red: 0.36, green: 0.40, blue: 0.62),
                    Color(red: 0.62, green: 0.68, blue: 0.86)
                ],
                startPoint: .top, endPoint: .bottom
            )
        }
    }
}
