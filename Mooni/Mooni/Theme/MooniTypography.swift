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
        let key = "\(weight)-\(size)"
        if let cached = cache[key] { return cached }

        let psName: String
        let uiWeight: UIFont.Weight
        switch weight {
        case .black:    psName = "Outfit-Bold"; uiWeight = .black
        case .heavy:    psName = "Outfit-Bold"; uiWeight = .heavy
        case .bold:     psName = "Outfit-Bold"; uiWeight = .bold
        case .semibold: psName = "Outfit-SemiBold"; uiWeight = .semibold
        case .medium:   psName = "Outfit-Medium"; uiWeight = .medium
        default:        psName = "Outfit-Regular"; uiWeight = .regular
        }

        // Base = Outfit at this weight when it loaded; otherwise the system
        // font at the matching weight. We NEVER return Font.custom(_:) here:
        // Font.custom ignores cascade lists, which is exactly what made emoji
        // (especially ZWJ sequences like "😵‍💫" and variation-selector forms
        // like "☀️") render as a missing-glyph "?" box. Building the font from
        // a UIFontDescriptor with an explicit AppleColorEmoji cascade — plus a
        // system-font cascade as a final safety net — guarantees every emoji
        // renders in colour no matter the iOS version or which weights loaded.
        let systemFallback: UIFont = {
            let sys = UIFont.systemFont(ofSize: size, weight: uiWeight)
            if let rounded = sys.fontDescriptor.withDesign(.rounded) {
                return UIFont(descriptor: rounded, size: size)
            }
            return sys
        }()
        let base = (isOutfitAvailable ? UIFont(name: psName, size: size) : nil)
            ?? systemFallback

        var cascade: [UIFontDescriptor] = []
        if let emoji = UIFont(name: "AppleColorEmoji", size: size) {
            cascade.append(emoji.fontDescriptor)
        }
        cascade.append(UIFont.systemFont(ofSize: size, weight: uiWeight).fontDescriptor)

        let descriptor = base.fontDescriptor.addingAttributes([
            .cascadeList: cascade
        ])
        let font = Font(UIFont(descriptor: descriptor, size: size))
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
