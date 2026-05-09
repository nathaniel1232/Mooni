import Foundation
import Combine

/// Tasks SleepOwl surfaces during wind-down to nudge the user into using
/// system features Apple won't let us toggle for them (Night Shift, the
/// red Color Filter, low brightness, focus modes). One task is shown
/// every few days, rotating through the catalog.
struct WindDownSystemTask: Identifiable, Hashable {
    let id: String
    let title: String
    let body: String
    /// Step-by-step instructions the user follows in the system Settings app.
    let steps: [String]
    let icon: String
    /// Optional URL to deep-link the user into Settings.
    let settingsURL: URL?
}

extension WindDownSystemTask {
    static let catalog: [WindDownSystemTask] = [
        .init(
            id: "night_shift",
            title: "Turn on Night Shift",
            body: "Warm-tinted screens cut blue light and help your body wind down.",
            steps: [
                "Open Settings → Display & Brightness",
                "Tap Night Shift",
                "Turn on Manually Enable Until Tomorrow",
                "Slide colour temperature to More Warm"
            ],
            icon: "moon.fill",
            settingsURL: URL(string: "App-prefs:DISPLAY")
        ),
        .init(
            id: "color_filter_red",
            title: "Switch to a red Colour Filter",
            body: "A red tint is even calmer than Night Shift — perfect right before bed.",
            steps: [
                "Open Settings → Accessibility → Display & Text Size",
                "Tap Colour Filters and turn it on",
                "Pick Colour Tint",
                "Drag Hue all the way to the right and Intensity to max"
            ],
            icon: "drop.halffull",
            settingsURL: URL(string: "App-prefs:ACCESSIBILITY")
        ),
        .init(
            id: "accessibility_shortcut",
            title: "Triple-click to flip the red filter",
            body: "Set up a shortcut so you can toggle the red filter from anywhere with three home/side-button presses.",
            steps: [
                "Open Settings → Accessibility → Accessibility Shortcut",
                "Select Colour Filters",
                "Test by triple-clicking the side or home button"
            ],
            icon: "bolt.circle.fill",
            settingsURL: URL(string: "App-prefs:ACCESSIBILITY")
        ),
        .init(
            id: "low_brightness",
            title: "Lower brightness all the way",
            body: "Even Night Shift screens are bright. Drop brightness to ~10% for the next hour.",
            steps: [
                "Swipe down from the top-right to open Control Centre",
                "Drag the brightness slider almost to the bottom",
                "Lock your phone if you don't need it"
            ],
            icon: "sun.min.fill",
            settingsURL: nil
        ),
        .init(
            id: "sleep_focus",
            title: "Switch on Sleep Focus",
            body: "Silences notifications and dims the lock screen automatically.",
            steps: [
                "Open Control Centre",
                "Tap Focus",
                "Pick Sleep"
            ],
            icon: "bed.double.fill",
            settingsURL: nil
        )
    ]
}

@MainActor
final class WindDownSystemTaskStore: ObservableObject {
    static let shared = WindDownSystemTaskStore()

    private let lastShownKey = "mooni.lastSystemTaskShownAt"
    private let lastIndexKey = "mooni.lastSystemTaskIndex"

    /// Minimum days between two system-task suggestions.
    private let cadenceDays: Int = 3

    /// The task to surface tonight, or nil if it's too soon since the last one.
    var taskForTonight: WindDownSystemTask? {
        let defaults = UserDefaults.standard
        let last = defaults.object(forKey: lastShownKey) as? Date
        if let last,
           let cutoff = Calendar.current.date(byAdding: .day, value: cadenceDays, to: last),
           Date() < cutoff {
            return nil
        }
        let nextIndex = (defaults.integer(forKey: lastIndexKey) + 1) % WindDownSystemTask.catalog.count
        return WindDownSystemTask.catalog[nextIndex]
    }

    /// Mark the surfaced task as shown. Call when the user actually sees the card.
    func markShown(_ task: WindDownSystemTask) {
        guard let idx = WindDownSystemTask.catalog.firstIndex(of: task) else { return }
        UserDefaults.standard.set(Date(), forKey: lastShownKey)
        UserDefaults.standard.set(idx, forKey: lastIndexKey)
    }
}
