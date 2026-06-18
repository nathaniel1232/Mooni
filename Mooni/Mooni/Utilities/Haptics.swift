import UIKit
import AudioToolbox

/// Centralized tactile + sound feedback. Haptics are pervasive (every tap,
/// selection, slider snap, screen advance) because that constant, subtle
/// physical response is a big part of what makes a native app feel alive.
/// Sound is reserved for meaningful payoffs only (check-in done, score
/// reveal, level-up) so it never feels noisy. Both respect a user toggle,
/// and sound additionally respects the hardware silent switch.
///
/// Usage:
///   Haptics.tap()        // selection / chip / option
///   Haptics.soft()       // Continue / primary button
///   Haptics.tick()       // slider value snapped
///   Haptics.success()    // a step completed
///   Haptics.celebrate()  // big payoff: reveal / level-up (haptic + sound)
enum Haptics {

    // MARK: - User preferences (Settings toggles)

    static let hapticsKey = "mooni.hapticsEnabled"
    static let soundKey = "mooni.soundEnabled"

    static var hapticsEnabled: Bool {
        UserDefaults.standard.object(forKey: hapticsKey) as? Bool ?? true
    }
    static var soundEnabled: Bool {
        UserDefaults.standard.object(forKey: soundKey) as? Bool ?? true
    }

    // MARK: - Haptics (pervasive)

    /// Light selection click — tapping an answer chip / option / card.
    static func tap() {
        guard hapticsEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// Soft impact — a Continue / primary button press.
    static func soft() {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    /// Medium impact — an animation finishing or a fact card landing.
    static func medium() {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Rigid tick — wheel slice ticks, slider value snaps, bucket fills.
    static func tick() {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.7)
    }

    static func success() {
        guard hapticsEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        guard hapticsEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func error() {
        guard hapticsEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    // MARK: - Key-moment payoff (haptic + sparing sound)

    /// Big positive payoff — morning check-in complete, score reveal,
    /// level-up, streak milestone. Strong haptic plus a short, pleasant
    /// system sound (only if sound is enabled and the phone isn't silenced).
    static func celebrate() {
        success()
        playKeyMomentSound(1025) // short, soft positive chime
    }

    /// Level-up / unlock — a punchy, haptics-only payoff. No system sound: the
    /// old "pupupu" (`AudioServicesPlaySystemSound(1025)`) was replaced by the
    /// full-screen `LevelUpCelebrationView`, which carries its own build-up
    /// ticks + success haptic.
    static func levelUp() {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// System UI sounds respect the hardware silent switch by design, so
    /// we only need to gate on the in-app preference here.
    private static func playKeyMomentSound(_ id: SystemSoundID) {
        guard soundEnabled else { return }
        AudioServicesPlaySystemSound(id)
    }
}
