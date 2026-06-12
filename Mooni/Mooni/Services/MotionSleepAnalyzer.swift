import Foundation
import CoreMotion

/// Retrospective motion-history analysis for sleep detection.
///
/// iOS keeps roughly the last 7 days of motion-activity and pedometer history
/// on-device. Nothing has to run overnight — we query that history in the
/// morning and look for the night's signature:
///
///   • the longest "stationary" block overlapping the sleep window
///     → bed / wake bounds,
///   • the first sustained steps after that block ends
///     → a hard "definitely up and moving" timestamp,
///   • short movement blips inside the block
///     → restlessness / night pickups.
///
/// Requires the Motion & Fitness permission (`NSMotionUsageDescription`);
/// the first query triggers the system prompt. Every entry point degrades to
/// nil when the data is unavailable or denied, so callers can treat motion
/// as an optional signal.
final class MotionSleepAnalyzer {
    static let shared = MotionSleepAnalyzer()

    private let activityManager = CMMotionActivityManager()
    private let pedometer = CMPedometer()

    private init() {}

    struct NightAnalysis {
        /// Start of the longest stationary block in the window (bed candidate).
        var stationaryStart: Date
        /// End of the longest stationary block (wake candidate).
        var stationaryEnd: Date
        /// First 15-minute bin with sustained steps after the block, if any.
        var firstSteps: Date?
        /// Tolerated movement blips inside the block (restlessness signal).
        var interruptions: Int
    }

    var isAvailable: Bool { CMMotionActivityManager.isActivityAvailable() }

    /// True when the user has explicitly denied or the device restricts
    /// Motion & Fitness — querying would fail, so don't bother.
    var isBlocked: Bool {
        switch CMMotionActivityManager.authorizationStatus() {
        case .denied, .restricted: return true
        default: return false
        }
    }

    /// Triggers the system Motion & Fitness prompt (when not yet determined)
    /// by running a minimal history query, then reports whether access is
    /// granted. Safe to call repeatedly — resolved states return immediately.
    /// Used by the onboarding motion-access screen.
    @discardableResult
    func requestAccess() async -> Bool {
        guard isAvailable else { return false }
        switch CMMotionActivityManager.authorizationStatus() {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        default:
            break
        }
        let now = Date()
        _ = await queryActivities(from: now.addingTimeInterval(-60), to: now)
        return CMMotionActivityManager.authorizationStatus() == .authorized
    }

    /// Analyzes the night inside `window` (typically yesterday 19:00 → now).
    /// Returns nil when motion data is unavailable, denied, or shows no
    /// plausible sleep block (≥ 2 h of stillness).
    func analyzeNight(window: DateInterval) async -> NightAnalysis? {
        guard isAvailable, !isBlocked else { return nil }
        let activities = await queryActivities(from: window.start, to: window.end)
        guard activities.count >= 2 else { return nil }

        guard let block = longestStationaryBlock(in: activities, windowEnd: window.end),
              block.interval.duration >= 2 * 3600 else { return nil }

        let start = max(block.interval.start, window.start)
        let steps = await firstSustainedSteps(after: block.interval.end,
                                              before: window.end)

        return NightAnalysis(
            stationaryStart: start,
            stationaryEnd: block.interval.end,
            firstSteps: steps,
            interruptions: block.interruptions
        )
    }

    // MARK: - Activity timeline

    private func queryActivities(from: Date, to: Date) async -> [CMMotionActivity] {
        await withCheckedContinuation { continuation in
            activityManager.queryActivityStarting(from: from, to: to, to: .main) { activities, _ in
                continuation.resume(returning: activities ?? [])
            }
        }
    }

    private struct StationaryBlock {
        var interval: DateInterval
        var interruptions: Int
    }

    /// Walks the activity timeline and merges stationary stretches, tolerating
    /// short movement gaps (≤ `maxGap`) — rolling over in bed or a quick
    /// bathroom trip shouldn't split the night in two. A longer gap closes
    /// the block: that was a real get-up.
    private func longestStationaryBlock(
        in activities: [CMMotionActivity],
        windowEnd: Date,
        maxGap: TimeInterval = 15 * 60
    ) -> StationaryBlock? {
        var best: StationaryBlock?
        var blockStart: Date?
        var blockEnd: Date?
        var interruptions = 0
        var gapStart: Date?

        func closeBlock() {
            if let s = blockStart, let e = blockEnd, e > s {
                let candidate = StationaryBlock(
                    interval: DateInterval(start: s, end: e),
                    interruptions: interruptions
                )
                if candidate.interval.duration > (best?.interval.duration ?? 0) {
                    best = candidate
                }
            }
            blockStart = nil
            blockEnd = nil
            interruptions = 0
            gapStart = nil
        }

        for (idx, activity) in activities.enumerated() {
            // Each sample is in effect until the next sample begins.
            let segmentEnd = idx + 1 < activities.count
                ? activities[idx + 1].startDate
                : windowEnd
            let isStill = activity.stationary
                && !activity.walking && !activity.running
                && !activity.cycling && !activity.automotive

            if isStill {
                if blockStart == nil {
                    blockStart = activity.startDate
                } else if let gap = gapStart {
                    if activity.startDate.timeIntervalSince(gap) > maxGap {
                        closeBlock()
                        blockStart = activity.startDate
                    } else {
                        interruptions += 1
                    }
                }
                gapStart = nil
                blockEnd = segmentEnd
            } else if blockStart != nil, gapStart == nil {
                gapStart = activity.startDate
            }
        }
        closeBlock()
        return best
    }

    // MARK: - Steps

    /// First 15-minute bin with ≥ `threshold` steps — proof the user is up
    /// and moving, not just reaching for the phone on the nightstand.
    private func firstSustainedSteps(
        after start: Date,
        before end: Date,
        threshold: Int = 20
    ) async -> Date? {
        guard CMPedometer.isStepCountingAvailable(), start < end else { return nil }
        var cursor = start
        var bins = 0
        while cursor < end, bins < 96 {
            let binEnd = min(cursor.addingTimeInterval(15 * 60), end)
            if await stepCount(from: cursor, to: binEnd) >= threshold {
                return cursor
            }
            cursor = binEnd
            bins += 1
        }
        return nil
    }

    private func stepCount(from: Date, to: Date) async -> Int {
        await withCheckedContinuation { continuation in
            pedometer.queryPedometerData(from: from, to: to) { data, _ in
                continuation.resume(returning: data?.numberOfSteps.intValue ?? 0)
            }
        }
    }
}
