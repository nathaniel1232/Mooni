import SwiftUI
import UIKit

enum MooniFont {
    /// The app's type family. We ship Outfit (a geometric sans), but the whole
    /// UI routes through this one enum, so the family can be swapped in a single
    /// place — no call site changes. Override at runtime via the
    /// "mooni.fontStyle" UserDefaults key for A/B-ing looks:
    ///   "poppins" → bundled Poppins (default)
    ///   "outfit"  → bundled Outfit
    ///   "rounded" → SF Rounded   (soft, friendly — system, no bundled file)
    ///   "serif"   → New York     (elegant editorial — system)
    ///   "system"  → SF Pro       (neutral system default)
    enum Family: String { case poppins, outfit, rounded, serif, system }

    static var family: Family {
        Family(rawValue: UserDefaults.standard.string(forKey: "mooni.fontStyle") ?? "") ?? .poppins
    }

    /// Bundled geometric sans families, registered at runtime in `MooniApp`.
    /// Each falls back to the system font if it hasn't registered yet.
    private static let isOutfitAvailable: Bool = {
        UIFont.familyNames.contains("Outfit") || UIFont(name: "Outfit-Regular", size: 12) != nil
    }()
    private static let isPoppinsAvailable: Bool = {
        UIFont.familyNames.contains("Poppins") || UIFont(name: "Poppins-Regular", size: 12) != nil
    }()

    /// Routes to the active family. Bundled families keep a hand-built emoji
    /// cascade; the system designs cascade to colour emoji natively.
    private static func resolved(_ size: CGFloat, weight: Font.Weight) -> Font {
        switch family {
        case .poppins: return bundled("Poppins", available: isPoppinsAvailable, size, weight: weight)
        case .outfit:  return bundled("Outfit", available: isOutfitAvailable, size, weight: weight)
        case .rounded: return .system(size: size, weight: weight, design: .rounded)
        case .serif:   return .system(size: size, weight: weight, design: .serif)
        case .system:  return .system(size: size, weight: weight, design: .default)
        }
    }

    /// Arbitrary size+weight in the active family — for views that need a
    /// specific scale outside the display/title/body/caption ramp.
    static func custom(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        resolved(size, weight: weight)
    }

    /// Cached cascaded fonts per (name, size). Without a cascade list to
    /// AppleColorEmoji, SwiftUI Text using .custom(...) renders emoji as the
    /// missing-glyph "?" box — so every emoji in the app must go through a
    /// font that explicitly cascades to the colour-emoji family.
    private static var cache: [String: Font] = [:]

    private static func bundled(_ prefix: String, available: Bool,
                                _ size: CGFloat, weight: Font.Weight) -> Font {
        let key = "\(prefix)-\(weight)-\(size)"
        if let cached = cache[key] { return cached }

        let psName: String
        let uiWeight: UIFont.Weight
        switch weight {
        case .black:    psName = "\(prefix)-Bold"; uiWeight = .black
        case .heavy:    psName = "\(prefix)-Bold"; uiWeight = .heavy
        case .bold:     psName = "\(prefix)-Bold"; uiWeight = .bold
        case .semibold: psName = "\(prefix)-SemiBold"; uiWeight = .semibold
        case .medium:   psName = "\(prefix)-Medium"; uiWeight = .medium
        default:        psName = "\(prefix)-Regular"; uiWeight = .regular
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
        let base = (available ? UIFont(name: psName, size: size) : nil)
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
        resolved(size, weight: .bold)
    }

    static func title(_ size: CGFloat = 22) -> Font {
        resolved(size, weight: .semibold)
    }

    static func body(_ size: CGFloat = 16) -> Font {
        resolved(size, weight: .regular)
    }

    static func caption(_ size: CGFloat = 13) -> Font {
        resolved(size, weight: .medium)
    }

    static func mono(_ size: CGFloat = 14) -> Font {
        // Keep mono for numerics — Outfit is proportional.
        .system(size: size, weight: .medium, design: .monospaced)
    }
}
