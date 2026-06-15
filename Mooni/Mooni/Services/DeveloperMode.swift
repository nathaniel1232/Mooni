import Foundation
import Combine

/// Tracks whether the hidden developer menu has been unlocked. The unlock
/// gesture is 20 silent taps on the paywall owl (see PaywallView). Persisted so
/// it survives relaunches; can be re-locked from inside the menu.
final class DeveloperMode: ObservableObject {
    static let shared = DeveloperMode()

    private static let key = "mooni.developerModeUnlocked"

    @Published private(set) var isUnlocked: Bool

    private init() {
        isUnlocked = UserDefaults.standard.bool(forKey: Self.key)
    }

    func unlock() { set(true) }
    func lock() { set(false) }

    private func set(_ value: Bool) {
        guard isUnlocked != value else { return }
        isUnlocked = value
        UserDefaults.standard.set(value, forKey: Self.key)
    }
}
