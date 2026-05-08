import Foundation
import UIKit
import Combine

/// Controls in-app screen dimming and red-tint overlay during wind-down.
///
/// Apple does not allow third-party apps to toggle Night Shift, the
/// system Color Filter, or change brightness while backgrounded. So this
/// controller does what we *can* do: lower `UIScreen.main.brightness` and
/// publish a flag that views observe to render a warm red overlay. The
/// effect lasts only while Mooni is foreground; the user gets a separate
/// rotating tip card teaching them how to flip the system-level toggles.
@MainActor
final class WindDownDimController: ObservableObject {
    static let shared = WindDownDimController()

    /// Published so any SwiftUI view in the hierarchy can layer a red tint.
    @Published private(set) var isActive: Bool = false

    /// Target brightness while wind-down is active.
    private let dimmedBrightness: CGFloat = 0.1

    private var savedBrightness: CGFloat?
    private var phaseObserver: NSObjectProtocol?
    private var resignObserver: NSObjectProtocol?

    private init() {
        // Re-apply the dim if user backgrounds and returns while in wind-down.
        phaseObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isActive else { return }
                self.applyDim()
            }
        }
        // Restore brightness when leaving so we don't dim other apps.
        resignObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.restoreBrightness()
            }
        }
    }

    deinit {
        if let phaseObserver { NotificationCenter.default.removeObserver(phaseObserver) }
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
    }

    /// Begin wind-down effects: red tint flag + dim brightness.
    func begin() {
        guard !isActive else { return }
        isActive = true
        applyDim()
    }

    /// End wind-down effects and restore the user's brightness.
    func end() {
        guard isActive else { return }
        isActive = false
        restoreBrightness()
    }

    private func applyDim() {
        if savedBrightness == nil {
            savedBrightness = UIScreen.main.brightness
        }
        UIScreen.main.brightness = dimmedBrightness
    }

    private func restoreBrightness() {
        if let saved = savedBrightness {
            UIScreen.main.brightness = saved
            savedBrightness = nil
        }
    }
}
