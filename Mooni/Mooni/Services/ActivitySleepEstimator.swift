import Foundation
import Combine
import SwiftUI

/// Fallback sleep estimator that observes scenePhase to infer when the user
/// likely went to bed and woke up — used only when HealthKit data is missing
/// or denied.
///
/// Heuristics (scoped to keep numbers sane):
/// - "Sleep start": app moved to .background/.inactive between 20:00 and 04:00.
/// - "Wake":        app became .active between 04:00 and 12:00.
/// - Within a wake-window we only honour the *first* activation, ignoring
///   later opens the same morning so duration doesn't shrink each time the
///   user re-opens the app.
/// - Durations under 2h or over 14h are discarded.
///
/// Outputs `SleepInterval`s (same shape as HealthKitManager) so the rest of
/// the pipeline doesn't need to care where the data came from.
@MainActor
final class ActivitySleepEstimator: ObservableObject {
    static let shared = ActivitySleepEstimator()

    private enum Key {
        static let lastBackground = "mooni.estimator.lastBackground"
        static let lastWakeDay    = "mooni.estimator.lastWakeDay"
        static let intervals      = "mooni.estimator.intervals"
    }

    private let minDuration: TimeInterval = 2 * 3600
    private let maxDuration: TimeInterval = 14 * 3600

    private init() {}

    // MARK: - Lifecycle entry points

    /// Records an explicit bedtime from the "Going to bed" flow. Unlike the
    /// passive scenePhase heuristic, this trusts the user's intent even if the
    /// app has not entered the background yet.
    func recordSleepStart(at date: Date = Date()) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: Key.lastBackground)
    }

    /// Called by RootView when scenePhase changes. We only care about
    /// active/background transitions; .inactive is treated like background
    /// (Apple sends inactive briefly during phone-call / control-center swipes,
    /// so we still record but the wake-time recovery filters out noise).
    func handleScenePhaseChange(_ phase: ScenePhase, at date: Date = Date()) {
        switch phase {
        case .background, .inactive:
            recordPossibleSleepStart(at: date)
        case .active:
            recordPossibleWake(at: date)
        @unknown default:
            break
        }
    }

    // MARK: - Recording

    private func recordPossibleSleepStart(at date: Date) {
        guard isInSleepStartWindow(date) else { return }
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: Key.lastBackground)
    }

    private func recordPossibleWake(at date: Date) {
        guard isInWakeWindow(date) else { return }

        // First activation of the day wins — later opens shouldn't shrink duration.
        if UserDefaults.standard.string(forKey: Key.lastWakeDay) == date.dayKey { return }

        guard let bgTimestamp = UserDefaults.standard.object(forKey: Key.lastBackground) as? Double else {
            UserDefaults.standard.set(date.dayKey, forKey: Key.lastWakeDay)
            return
        }
        let start = Date(timeIntervalSince1970: bgTimestamp)
        let duration = date.timeIntervalSince(start)

        guard duration >= minDuration, duration <= maxDuration else {
            // Junk window — drop it but still claim the wake-day so we don't
            // keep recomputing later this morning.
            UserDefaults.standard.set(date.dayKey, forKey: Key.lastWakeDay)
            UserDefaults.standard.removeObject(forKey: Key.lastBackground)
            return
        }

        var intervals = persistedIntervals
        // Skip if we already have an estimated entry for this wake-day.
        if !intervals.contains(where: { $0.end.dayKey == date.dayKey }) {
            intervals.append(SleepInterval(start: start, end: date))
            persist(intervals)
        }

        UserDefaults.standard.set(date.dayKey, forKey: Key.lastWakeDay)
        UserDefaults.standard.removeObject(forKey: Key.lastBackground)
    }

    // MARK: - Public read

    /// Returns the most recent estimated nightly intervals, in chronological order.
    /// Limited to roughly the last `days` days.
    func recentIntervals(days: Int = 14) -> [SleepInterval] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return persistedIntervals
            .filter { $0.end >= cutoff }
            .sorted { $0.start < $1.start }
    }

    // MARK: - Windows

    private func isInSleepStartWindow(_ date: Date) -> Bool {
        let h = Calendar.current.component(.hour, from: date)
        // 20:00–23:59 OR 00:00–03:59
        return h >= 20 || h < 4
    }

    private func isInWakeWindow(_ date: Date) -> Bool {
        let h = Calendar.current.component(.hour, from: date)
        return h >= 4 && h < 12
    }

    // MARK: - Persistence

    private struct StoredInterval: Codable {
        let start: Double
        let end: Double
    }

    private var persistedIntervals: [SleepInterval] {
        guard let data = UserDefaults.standard.data(forKey: Key.intervals),
              let decoded = try? JSONDecoder().decode([StoredInterval].self, from: data) else {
            return []
        }
        return decoded.map {
            SleepInterval(
                start: Date(timeIntervalSince1970: $0.start),
                end:   Date(timeIntervalSince1970: $0.end)
            )
        }
    }

    private func persist(_ intervals: [SleepInterval]) {
        let stored = intervals.map { StoredInterval(start: $0.start.timeIntervalSince1970,
                                                    end: $0.end.timeIntervalSince1970) }
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: Key.intervals)
        }
    }
}
