import Foundation
import SwiftUI

/// The starter species the user picks during onboarding.
/// More species (rare / seasonal) live in the Premium catalog.
enum PetSpecies: String, Codable, CaseIterable, Identifiable {
    case fox
    case panda
    case owl

    var id: String { rawValue }

    var defaultName: String {
        switch self {
        case .fox:   return "Nova"
        case .panda: return "Mochi"
        case .owl:   return "Luna"
        }
    }

    var displayName: String {
        switch self {
        case .fox:   return "Fox"
        case .panda: return "Panda"
        case .owl:   return "Owl"
        }
    }

    var tagline: String {
        switch self {
        case .fox:   return "Playful, curious, loves cozy nights."
        case .panda: return "Gentle, sleepy, loves calm routines."
        case .owl:   return "Wise, quiet, loves moonlight."
        }
    }

    /// Tint used for the placeholder spirit visuals until per-species art ships.
    var tint: Color {
        switch self {
        case .fox:   return Color(red: 1.00, green: 0.72, blue: 0.50)
        case .panda: return Color(red: 0.92, green: 0.94, blue: 1.00)
        case .owl:   return Color(red: 0.78, green: 0.70, blue: 1.00)
        }
    }

    /// SF Symbol used as a placeholder badge icon.
    var icon: String {
        switch self {
        case .fox:   return "pawprint.fill"
        case .panda: return "leaf.fill"
        case .owl:   return "moon.stars.fill"
        }
    }
}
