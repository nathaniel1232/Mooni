import Foundation
import SwiftUI

struct Pet: Codable {
    // MARK: - Mood
    /// Expanded mood set used by the new pet system. The legacy 4-state cases
    /// (rested/good/tired/low) are kept as aliases via `legacyBucket` so existing
    /// view code keeps working until it's migrated.
    enum Mood: String, Codable, CaseIterable {
        case energized
        case cozy
        case calm
        case sleepy
        case groggy
        case restless
        case recovering
        case excited
        case proud

        // Legacy aliases — older code referenced these directly.
        case rested
        case good
        case tired
        case low

        var label: String {
            switch self {
            case .energized:  return "Energized"
            case .cozy:       return "Cozy"
            case .calm:       return "Calm"
            case .sleepy:     return "Sleepy"
            case .groggy:     return "Groggy"
            case .restless:   return "Restless"
            case .recovering: return "Recovering"
            case .excited:    return "Excited"
            case .proud:      return "Proud"
            case .rested:     return "Rested"
            case .good:       return "Calm"
            case .tired:      return "Sleepy"
            case .low:        return "Low energy"
            }
        }

        var message: String {
            switch self {
            case .energized:  return "is bouncing with energy."
            case .cozy:       return "feels warm and cozy."
            case .calm:       return "had a peaceful night."
            case .sleepy:     return "is a little sleepy today."
            case .groggy:     return "is groggy and needs a kinder night — let's wind down earlier."
            case .restless:   return "had a restless night and is leaning on you tonight."
            case .recovering: return "is worn down by sleep debt and needs you to rest tonight."
            case .excited:    return "is excited for tonight!"
            case .proud:      return "is proud of your streak."
            case .rested:     return "feels fully recharged."
            case .good:       return "had a good night."
            case .tired:      return "is a little tired and is counting on you tonight."
            case .low:        return "is running on empty and really needs you to rest tonight."
            }
        }

        /// Bucket used by the legacy DreamSpiritView image picker.
        var legacyBucket: Mood {
            switch self {
            case .energized, .excited, .proud, .rested:
                return .rested
            case .cozy, .calm, .recovering, .good:
                return .good
            case .sleepy, .tired:
                return .tired
            case .groggy, .restless, .low:
                return .low
            }
        }

        static func from(score: Int) -> Mood {
            switch score {
            case 85...:    return .energized
            case 70..<85:  return .calm
            case 50..<70:  return .sleepy
            default:       return .restless
            }
        }
    }

    // MARK: - Evolution stage
    enum EvolutionStage: String, Codable, CaseIterable {
        case egg
        case baby
        case young
        case adult
        case dream
        case legendary

        var label: String {
            switch self {
            case .egg:       return "Egg"
            case .baby:      return "Baby"
            case .young:     return "Young"
            case .adult:     return "Adult"
            case .dream:     return "Dream form"
            case .legendary: return "Legendary"
            }
        }

        /// Consistent days needed to reach this stage.
        var consistencyRequired: Int {
            switch self {
            case .egg:       return 0
            case .baby:      return 0
            case .young:     return 3
            case .adult:     return 10
            case .dream:     return 25
            case .legendary: return 60
            }
        }
    }

    // MARK: - Stored
    var name: String = "SleepOwl"
    var species: PetSpecies = .owl
    var room: PetRoom = .moonBedroom
    var stage: EvolutionStage = .baby

    var level: Int = 1
    var dreamEnergy: Int = 0
    var mood: Mood = .calm
    var lastSleepScore: Int? = nil

    var unlockedItems: Set<String> = ["default_color"]
    var equippedHat: String? = nil // deprecated; retained for backward-compatible decoding
    var equippedColor: String = "default_color"
    var equippedBackground: String? = nil

    // MARK: - Codable
    init() {}

    enum CodingKeys: String, CodingKey {
        case name, species, room, stage
        case level, dreamEnergy, mood, lastSleepScore
        case unlockedItems, equippedHat, equippedColor, equippedBackground
    }

    /// Tolerant decode so an existing user's previously-saved Pet survives an
    /// upgrade that adds new stored fields. Every property uses
    /// `decodeIfPresent(...) ?? <default>` so missing keys fall back to sensible
    /// defaults instead of failing the whole decode and silently resetting the
    /// pet (name, level, dreamEnergy, unlocked items, equipped cosmetics).
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "SleepOwl"
        species = try container.decodeIfPresent(PetSpecies.self, forKey: .species) ?? .owl
        room = try container.decodeIfPresent(PetRoom.self, forKey: .room) ?? .moonBedroom
        stage = try container.decodeIfPresent(EvolutionStage.self, forKey: .stage) ?? .baby
        level = try container.decodeIfPresent(Int.self, forKey: .level) ?? 1
        dreamEnergy = try container.decodeIfPresent(Int.self, forKey: .dreamEnergy) ?? 0
        mood = try container.decodeIfPresent(Mood.self, forKey: .mood) ?? .calm
        lastSleepScore = try container.decodeIfPresent(Int.self, forKey: .lastSleepScore)
        unlockedItems = try container.decodeIfPresent(Set<String>.self, forKey: .unlockedItems) ?? ["default_color"]
        equippedHat = try container.decodeIfPresent(String.self, forKey: .equippedHat)
        equippedColor = try container.decodeIfPresent(String.self, forKey: .equippedColor) ?? "default_color"
        equippedBackground = try container.decodeIfPresent(String.self, forKey: .equippedBackground)
    }

    // MARK: - Derived
    var energyForNextLevel: Int {
        // Slightly steeper curve so higher levels feel earned.
        100 + (level - 1) * 75
    }

    var levelProgress: Double {
        min(1.0, Double(dreamEnergy) / Double(energyForNextLevel))
    }

    /// Friendly title shown next to level number.
    var levelTitle: String {
        switch level {
        case ..<3:   return "Drowsy"
        case 3..<6:  return "Restful"
        case 6..<10: return "Dreamer"
        case 10..<15: return "Night Owl"
        case 15..<22: return "Sleep Sage"
        default:     return "Moonlit Legend"
        }
    }

    /// Returns the highest stage reached for the given consistency-day count.
    static func stage(forConsistencyDays days: Int) -> EvolutionStage {
        let ordered: [EvolutionStage] = [.egg, .baby, .young, .adult, .dream, .legendary]
        var current: EvolutionStage = .egg
        for stage in ordered where days >= stage.consistencyRequired {
            current = stage
        }
        return current
    }
}

// MARK: - Unlockables (unchanged catalog kept as-is)
struct UnlockableItem: Identifiable, Codable, Hashable {
    enum Kind: String, Codable {
        case hat, color, background, animation
    }

    var id: String
    var name: String
    var kind: Kind
    var requiredLevel: Int
    var icon: String

    static let catalog: [UnlockableItem] = [
        // Colors
        .init(id: "default_color",   name: "Moonlight",       kind: .color, requiredLevel: 1, icon: "circle.fill"),
        .init(id: "color_lavender",  name: "Lavender",        kind: .color, requiredLevel: 3, icon: "circle.fill"),
        .init(id: "color_mint",      name: "Mint",            kind: .color, requiredLevel: 4, icon: "circle.fill"),
        .init(id: "color_rose",      name: "Rose",            kind: .color, requiredLevel: 6, icon: "circle.fill"),
        .init(id: "color_gold",      name: "Stardust",        kind: .color, requiredLevel: 8, icon: "circle.fill"),
        // Backgrounds
        .init(id: "bg_starry_blanket", name: "Starry Blanket", kind: .background, requiredLevel: 2, icon: "sparkle.magnifyingglass"),
        .init(id: "bg_starfield",    name: "Starfield",       kind: .background, requiredLevel: 2, icon: "sparkles"),
        .init(id: "bg_forest",       name: "Quiet Forest",    kind: .background, requiredLevel: 5, icon: "leaf.fill"),
        .init(id: "bg_ocean",        name: "Ocean",           kind: .background, requiredLevel: 6, icon: "water.waves"),
        .init(id: "bg_galaxy",       name: "Galaxy",          kind: .background, requiredLevel: 8, icon: "moon.stars.fill"),
        .init(id: "bg_aurora",       name: "Aurora",          kind: .background, requiredLevel: 10, icon: "sun.haze.fill"),
        // Animations
        .init(id: "anim_float",      name: "Float",           kind: .animation, requiredLevel: 3, icon: "arrow.up.and.down"),
        .init(id: "anim_sparkle",    name: "Sparkle",         kind: .animation, requiredLevel: 5, icon: "sparkle"),
        .init(id: "anim_dance",      name: "Dance",           kind: .animation, requiredLevel: 7, icon: "music.note")
    ]

    static func color(for id: String) -> Color {
        switch id {
        case "color_lavender": return Color(red: 0.78, green: 0.7, blue: 1.0)
        case "color_mint":     return Color(red: 0.7,  green: 1.0, blue: 0.85)
        case "color_rose":     return Color(red: 1.0,  green: 0.75, blue: 0.85)
        case "color_gold":     return Color(red: 1.0,  green: 0.92, blue: 0.7)
        default:               return MooniColor.petGlow
        }
    }
}
