import UIKit

/// Lightweight wrapper around UIKit's haptic generators. Centralized so we
/// can mute them globally in tests/previews and keep call sites short.
///
/// Usage:
///   Haptics.tap()        // option / tap selection
///   Haptics.success()    // chart finished, animation landed
///   Haptics.warning()    // bad-news fact landed
///   Haptics.spinTick()   // wheel slice ticked past pointer
enum Haptics {
    /// Light selection click, e.g. tapping an answer chip.
    static func tap() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// Soft impact, e.g. a Continue tap or value-snap on a slider.
    static func soft() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    /// Medium impact, e.g. an animation finishing or a fact card landing.
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Rigid tick — used for wheel slice ticks and bucket-fill segments.
    static func tick() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.7)
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
