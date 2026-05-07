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
        return .custom(name, size: size)
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
