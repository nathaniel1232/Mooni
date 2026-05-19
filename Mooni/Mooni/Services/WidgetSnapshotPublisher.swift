import Foundation
import WidgetKit

/// Writes the latest sleep snapshot into the shared App Group container so
/// `MooniSleepWidget` can render real numbers instead of the bundled sample.
///
/// The widget extension and host app both reach into
/// `UserDefaults(suiteName: "group.com.nathanielfiskaa.sleepowl")` using the
/// same key and JSON shape. This MUST match the App Group declared in both
/// `Mooni.entitlements` and `MooniSleepWidget.entitlements` and the id read by
/// `WidgetDataStore` in the widget target — otherwise `UserDefaults(suiteName:)`
/// returns nil, every publish is silently dropped, and the widget is stuck on
/// the bundled sample (always score 76 / placeholder "…").
enum WidgetSnapshotPublisher {
    private static let appGroupIdentifier = "group.com.nathanielfiskaa.sleepowl"
    private static let storageKey = "mooni.widget.latestSleep"

    private struct Snapshot: Codable {
        let score: Int
        let quality: String
        let sleepDuration: String
        let sleepStart: String
        let wakeTime: String
        let energyScore: Int
        let updatedAt: Date
    }

    /// Encode + write the entry to the shared store, then nudge WidgetKit
    /// to refresh all timelines.
    static func publish(_ entry: SleepEntry) {
        let snapshot = Snapshot(
            score: entry.score,
            quality: qualityLabel(for: entry.score),
            sleepDuration: entry.formattedDuration,
            sleepStart: entry.bedtime.hourMinuteString,
            wakeTime: entry.wakeTime.hourMinuteString,
            energyScore: entry.readinessScore ?? entry.score,
            updatedAt: Date()
        )
        guard
            let defaults = UserDefaults(suiteName: appGroupIdentifier),
            let data = try? JSONEncoder().encode(snapshot)
        else { return }
        defaults.set(data, forKey: storageKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func qualityLabel(for score: Int) -> String {
        switch score {
        case 85...:    return "Excellent"
        case 70..<85:  return "Good"
        case 50..<70:  return "Okay"
        default:       return "Bad"
        }
    }
}
