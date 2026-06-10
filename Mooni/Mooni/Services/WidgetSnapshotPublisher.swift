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

    /// Locale-aware clock formatter (e.g. "11:42 PM" in 12-hour locales,
    /// "23:42" in 24-hour locales).
    ///
    /// The widget renders these strings verbatim. `timeStyle = .short` honors
    /// the user's locale (12/24-hour) and produces output identical to the
    /// app-wide `Date.hourMinuteString` (which is also locale-aware), so the
    /// app and widget stay consistent. This formatter lives here only to keep
    /// the widget data layer self-contained (no dependency on the app target's
    /// Date extension).
    private static let clockFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    /// Encode + write the entry to the shared store, then nudge WidgetKit
    /// to refresh all timelines.
    static func publish(_ entry: SleepEntry) {
        let snapshot = Snapshot(
            score: entry.score,
            quality: qualityLabel(for: entry.score),
            sleepDuration: entry.formattedDuration,
            sleepStart: clockFormatter.string(from: entry.bedtime),
            wakeTime: clockFormatter.string(from: entry.wakeTime),
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
