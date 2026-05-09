import Foundation
import SwiftUI

/// V1 ships with a single species — the owl. The enum is kept (rather
/// than stripped) so existing persisted Pet records keep decoding and
/// future seasonal/rare species can be added without a migration.
enum PetSpecies: String, Codable, CaseIterable, Identifiable {
    case owl

    var id: String { rawValue }

    var defaultName: String { "SleepOwl" }
    var displayName: String { "Owl" }
    var tagline: String { "Wise, quiet, loves moonlight." }

    /// Tint used by the legacy halo around the pet image.
    var tint: Color {
        Color(red: 0.78, green: 0.70, blue: 1.00)
    }

    /// SF Symbol used as a placeholder badge icon (still referenced by
    /// some legacy onboarding components).
    var icon: String { "moon.stars.fill" }
}
