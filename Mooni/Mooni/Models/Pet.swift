import Foundation
import SwiftUI

struct Pet: Codable {
    enum Mood: String, Codable {
        case rested, good, tired, low

        var label: String {
            switch self {
            case .rested: return "Rested"
            case .good:   return "Calm"
            case .tired:  return "Sleepy"
            case .low:    return "Low energy"
            }
        }

        var message: String {
            switch self {
            case .rested: return "feels fully recharged."
            case .good:   return "had a good night."
            case .tired:  return "is a little tired today. Let's recover tonight."
            case .low:    return "needs a gentle night. Try a calmer bedtime routine."
            }
        }

        static func from(score: Int) -> Mood {
            switch score {
            case 85...:  return .rested
            case 70..<85: return .good
            case 50..<70: return .tired
            default:     return .low
            }
        }
    }

    var name: String = "Lumi"
    var level: Int = 1
    var dreamEnergy: Int = 0
    var mood: Mood = .good
    var lastSleepScore: Int? = nil
    var unlockedItems: Set<String> = ["default_color", "hat_nightcap"]
    var equippedHat: String? = "hat_nightcap"
    var equippedColor: String = "default_color"
    var equippedBackground: String? = nil

    var energyForNextLevel: Int {
        100 + (level - 1) * 50
    }

    var levelProgress: Double {
        min(1.0, Double(dreamEnergy) / Double(energyForNextLevel))
    }
}

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
        // Hats
        .init(id: "hat_nightcap",    name: "Starry Nightcap", kind: .hat, requiredLevel: 1, icon: "moon.zzz.fill"),
        .init(id: "hat_crown",       name: "Dream Crown",     kind: .hat, requiredLevel: 4, icon: "crown.fill"),
        .init(id: "hat_beanie",      name: "Cozy Beanie",     kind: .hat, requiredLevel: 5, icon: "snowflake"),
        .init(id: "hat_halo",        name: "Moon Halo",       kind: .hat, requiredLevel: 7, icon: "circle.dashed"),
        .init(id: "hat_bow",         name: "Cloud Bow",       kind: .hat, requiredLevel: 9, icon: "cloud.fill"),
        // Colors
        .init(id: "default_color",   name: "Moonlight",       kind: .color, requiredLevel: 1, icon: "circle.fill"),
        .init(id: "color_lavender",  name: "Lavender",        kind: .color, requiredLevel: 3, icon: "circle.fill"),
        .init(id: "color_mint",      name: "Mint",            kind: .color, requiredLevel: 4, icon: "circle.fill"),
        .init(id: "color_rose",      name: "Rose",            kind: .color, requiredLevel: 6, icon: "circle.fill"),
        .init(id: "color_gold",      name: "Stardust",        kind: .color, requiredLevel: 8, icon: "circle.fill"),
        // Backgrounds
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
