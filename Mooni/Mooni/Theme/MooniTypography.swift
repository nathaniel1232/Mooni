import SwiftUI
import UIKit

enum MooniFont {
    /// Outfit is a geometric sans bundled with the app. Falls back to the
    /// system rounded design if the family hasn't been registered yet
    /// (first launch in some simulators, missing Info.plist registration, etc).
    private static let isOutfitAvailable: Bool = {
        UIFont.familyNames.contains("Outfit")
            || UIFont(name: "Outfit-Regular", size: 12) != nil
    }()

    /// Cached cascaded fonts per (name, size). Without a cascade list to
    /// AppleColorEmoji, SwiftUI Text using .custom(...) renders emoji as the
    /// missing-glyph "?" box — so every emoji in the app must go through a
    /// font that explicitly cascades to the colour-emoji family.
    private static var cache: [String: Font] = [:]

    private static func outfit(_ size: CGFloat, weight: Font.Weight) -> Font {
        guard isOutfitAvailable else {
            return .system(size: size, weight: weight, design: .rounded)
        }
        let name: String
        switch weight {
        case .bold, .heavy, .black: name = "Outfit-Bold"
        case .semibold:             name = "Outfit-SemiBold"
        case .medium:               name = "Outfit-Medium"
        default:                    name = "Outfit-Regular"
        }

        let key = "\(name)-\(size)"
        if let cached = cache[key] { return cached }

        guard let base = UIFont(name: name, size: size),
              let emoji = UIFont(name: "AppleColorEmoji", size: size) else {
            let fallback = Font.custom(name, size: size)
            cache[key] = fallback
            return fallback
        }

        let descriptor = base.fontDescriptor.addingAttributes([
            .cascadeList: [emoji.fontDescriptor]
        ])
        let composed = UIFont(descriptor: descriptor, size: size)
        let font = Font(composed)
        cache[key] = font
        return font
    }

    static func display(_ size: CGFloat = 34) -> Font {
        outfit(size, weight: .bold)
    }

    static func title(_ size: CGFloat = 22) -> Font {
        outfit(size, weight: .semibold)
    }

    static func body(_ size: CGFloat = 16) -> Font {
        outfit(size, weight: .regular)
    }

    static func caption(_ size: CGFloat = 13) -> Font {
        outfit(size, weight: .medium)
    }

    static func mono(_ size: CGFloat = 14) -> Font {
        // Keep mono for numerics — Outfit is proportional.
        .system(size: size, weight: .medium, design: .monospaced)
    }
}
