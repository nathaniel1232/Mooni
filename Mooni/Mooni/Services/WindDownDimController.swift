import Foundation
import UIKit
import Combine

/// Controls in-app screen dimming and red-tint overlay during wind-down.
///
/// Apple does not allow third-party apps to toggle Night Shift, the
/// system Color Filter, or change brightness while backgrounded. So this
/// controller does what we *can* do: lower `UIScreen.main.brightness` and
/// publish a flag that views observe to render a warm red overlay. The
/// effect lasts only while SleepOwl is foreground; the user gets a separate
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
        // Hop into a MainActor Task and reach the singleton directly to
        // avoid Swift 6 captured-self diagnostics.
        phaseObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                let c = WindDownDimController.shared
                guard c.isActive else { return }
                c.applyDim()
            }
        }
        // Restore brightness when leaving so we don't dim other apps.
        resignObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                WindDownDimController.shared.restoreBrightness()
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

    /// The active screen via the connected window scene — required by
    /// iOS 26+, which deprecated `UIScreen.main`. Returns nil if no
    /// foreground scene exists yet (we simply skip the brightness call).
    private var activeScreen: UIScreen? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen
    }

    fileprivate func applyDim() {
        guard let screen = activeScreen else { return }
        if savedBrightness == nil {
            savedBrightness = screen.brightness
        }
        screen.brightness = dimmedBrightness
    }

    fileprivate func restoreBrightness() {
        guard let screen = activeScreen else { return }
        if let saved = savedBrightness {
            screen.brightness = saved
            savedBrightness = nil
        }
    }
}
