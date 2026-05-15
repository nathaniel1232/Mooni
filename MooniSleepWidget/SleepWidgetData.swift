import Foundation
import SwiftUI

// MARK: - Data Model

/// Snapshot of the user's most recent sleep night, formatted for the widget.
/// All fields are pre-formatted strings (or simple Ints) so the widget never
/// has to do locale/timezone math on a tight render budget.
struct SleepWidgetData: Codable, Hashable {
    let score: Int
    let quality: String          // "Excellent" | "Good" | "Okay" | "Bad"
    let sleepDuration: String    // "7h 36m"
    let sleepStart: String       // "11:42 PM"
    let wakeTime: String         // "7:18 AM"
    let energyScore: Int         // 0–100
    let updatedAt: Date

    static let sample = SleepWidgetData(
        score: 76,
        quality: "Good",
        sleepDuration: "7h 36m",
        sleepStart: "11:42 PM",
        wakeTime: "7:18 AM",
        energyScore: 72,
        updatedAt: Date()
    )

    static let placeholder = SleepWidgetData(
        score: 82,
        quality: "Good",
        sleepDuration: "7h 36m",
        sleepStart: "11:42 PM",
        wakeTime: "7:18 AM",
        energyScore: 74,
        updatedAt: Date()
    )

    /// Derived progress value (0…1) used to drive the ring.
    var ringProgress: Double {
        max(0, min(1, Double(score) / 100.0))
    }

    /// Color band for the ring + score number.
    /// 85+ green/blue · 70–84 lavender · 50–69 amber · <50 pink/red
    var scoreTint: Color {
        switch score {
        case 85...:  return Color(red: 0.55, green: 0.85, blue: 0.78)   // mint/teal
        case 70..<85: return Color(red: 0.72, green: 0.62, blue: 1.00)  // lavender
        case 50..<70: return Color(red: 1.00, green: 0.78, blue: 0.55)  // soft amber
        default:      return Color(red: 1.00, green: 0.60, blue: 0.72)  // soft rose
        }
    }
}

// MARK: - Shared Storage

/// Reads/writes the latest sleep snapshot in a way that works **today** with
/// mock data and **tomorrow** with real app data via App Groups — without the
/// widget target needing code changes.
///
/// To wire up real data later:
///   1. In Xcode → Signing & Capabilities, add the **App Groups** capability
///      to BOTH the `SleepOwl` app target and the `MooniSleepWidget` target.
///   2. Use the same group id for both, e.g. `group.com.sabaiduka.mooni`.
///   3. Set `WidgetDataStore.appGroupIdentifier` below to that id.
///   4. From the app, after each new sleep night, call:
///         WidgetDataStore.shared.write(SleepWidgetData(...))
///         WidgetCenter.shared.reloadAllTimelines()
///   5. The widget will read from the shared `UserDefaults(suiteName:)`
///      automatically — no other widget code changes are needed.
enum WidgetDataStore {
    /// App Group id shared between host app and widget extension.
    /// The "App Groups" capability must be enabled on BOTH targets in
    /// Xcode with this identifier for the snapshot to cross the process
    /// boundary; otherwise we fall back to the bundled sample.
    static let appGroupIdentifier: String = "group.com.nathanielfiskaa.sleepowl"

    private static let storageKey = "mooni.widget.latestSleep"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    /// Read the latest snapshot. Falls back to the bundled sample so the
    /// widget always has something nice to render before the first night.
    static func read() -> SleepWidgetData {
        guard
            let data = defaults.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode(SleepWidgetData.self, from: data)
        else {
            return .sample
        }
        return decoded
    }

    /// Called from the **main app** (not the widget) when a new night lands.
    static func write(_ snapshot: SleepWidgetData) {
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: storageKey)
        }
    }
}
