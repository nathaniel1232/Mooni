import Foundation

// MARK: - Lock-state samples

/// One sparse sample of the device's lock state, recorded whenever a
/// background-refresh task happens to fire. `locked == true` means the device
/// was passcode-locked at that moment (`isProtectedDataAvailable == false`) —
/// a strong "not in use" signal that corroborates sleep without any sensors.
struct LockStateSample: Codable {
    let time: Date
    let locked: Bool
}

enum LockStateSampleStore {
    private static let key = "mooni.lockStateSamples"
    private static let maxAge: TimeInterval = 48 * 3600
    private static let maxCount = 200

    static func record(locked: Bool, at time: Date = Date()) {
        var all = load()
        all.append(LockStateSample(time: time, locked: locked))
        let cutoff = Date().addingTimeInterval(-maxAge)
        all = Array(all.filter { $0.time >= cutoff }.suffix(maxCount))
        if let data = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func samples(in window: DateInterval) -> [LockStateSample] {
        load().filter { window.contains($0.time) }
    }

    private static func load() -> [LockStateSample] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([LockStateSample].self, from: data)
        else { return [] }
        return decoded
    }
}

// MARK: - Estimate

struct SleepSessionEstimate {
    let bedtime: Date
    let wakeTime: Date
    /// 0–1 — grows with the number of independent signal families that agree.
    let confidence: Double
    /// Human-readable signal names, for the entry's notes and the log.
    let sources: [String]

    var sourceSummary: String { sources.joined(separator: ", ") }
    var duration: TimeInterval { wakeTime.timeIntervalSince(bedtime) }
}

// MARK: - Engine

/// The sleep brain. Fuses every passive signal the phone has about last
/// night into a single bed/wake estimate with a confidence score:
///
///   screen — last phone-down / first phone-use (`ActivitySleepEstimator`)
///   motion — longest stationary block + first steps (`MotionSleepAnalyzer`)
///   taps   — armed bedtime, "still awake" and "I'm awake" probe responses
///   lock   — overnight locked-device samples from background refresh
///
/// Bedtime is the LATEST bed-side signal (sleep starts only once the phone is
/// down AND the body is still AND after the last "still awake" tap); wake is
/// the EARLIEST hard awake signal. The target schedule is deliberately NOT a
/// source — it can never invent a night on its own.
@MainActor
final class SleepSessionEngine {
    static let shared = SleepSessionEngine()
    private init() {}

    /// Estimates the night that ends on `now`'s day. Returns nil when there
    /// aren't enough real signals to bound both ends of the night.
    func estimateNight(
        now: Date,
        armedSleepStart: Date?,
        stillAwakeAt: Date?,
        wakeTappedAt: Date?
    ) async -> SleepSessionEstimate? {
        let cal = Calendar.current
        // Window: 19:00 yesterday → now. Wide enough for early sleepers.
        let startOfToday = cal.startOfDay(for: now)
        guard let windowStart = cal.date(byAdding: .hour, value: -5, to: startOfToday),
              windowStart < now else { return nil }
        let window = DateInterval(start: windowStart, end: now)

        var bedCandidates: [(date: Date, label: String)] = []
        var wakeCandidates: [(date: Date, label: String)] = []
        var families: Set<String> = []

        // 1. Screen activity — the estimator's finished interval for today,
        //    or just the pending "phone went down" timestamp.
        let estimator = ActivitySleepEstimator.shared
        if let interval = estimator.recentIntervals(days: 2)
            .last(where: { $0.end.dayKey == now.dayKey }) {
            bedCandidates.append((interval.start, "screen"))
            wakeCandidates.append((interval.end, "screen"))
            families.insert("screen")
        } else if let down = estimator.pendingEstimatedSleepStart,
                  window.contains(down) {
            bedCandidates.append((down, "screen"))
            families.insert("screen")
        }

        // 2. Explicit taps.
        if let armed = armedSleepStart, window.contains(armed) {
            bedCandidates.append((armed, "bedtime tap"))
            families.insert("taps")
        }
        if let still = stillAwakeAt, window.contains(still) {
            // Provably awake at that moment; add the ~8 min mean onset latency.
            bedCandidates.append((still.addingTimeInterval(8 * 60), "still-awake tap"))
            families.insert("taps")
        }
        if let tap = wakeTappedAt, window.contains(tap) {
            wakeCandidates.append((tap, "wake tap"))
            families.insert("taps")
        }

        // 3. Motion history.
        let motion = await MotionSleepAnalyzer.shared.analyzeNight(window: window)
        if let m = motion {
            bedCandidates.append((m.stationaryStart, "motion"))
            wakeCandidates.append((m.stationaryEnd, "motion"))
            if let steps = m.firstSteps {
                wakeCandidates.append((steps, "steps"))
            }
            families.insert("motion")
        }

        // 4. Lock-state samples. "Unlocked" is only meaningful as a wake
        //    signal on devices that actually lock — without a passcode,
        //    protected data is always available and every sample reads
        //    unlocked, so require at least one locked sample that night.
        let lockSamples = LockStateSampleStore.samples(in: window)
        let lockedOvernight = lockSamples.contains { $0.locked }
        if lockedOvernight {
            families.insert("lock")
            if let firstUnlocked = lockSamples
                .filter({ !$0.locked && cal.component(.hour, from: $0.time) >= 4 })
                .map(\.time)
                .min() {
                wakeCandidates.append((firstUnlocked, "device unlock"))
            }
        }

        guard !bedCandidates.isEmpty, !wakeCandidates.isEmpty else { return nil }

        let bed = bedCandidates.map(\.date).max()!
        let wake = wakeCandidates.map(\.date).min()!

        let duration = wake.timeIntervalSince(bed)
        guard duration >= 2 * 3600, duration <= 14 * 3600 else { return nil }

        var confidence: Double
        switch families.count {
        case 1:  confidence = 0.45
        case 2:  confidence = 0.65
        case 3:  confidence = 0.80
        default: confidence = 0.90
        }
        // Agreement bonus: screen and motion independently landing on the
        // same bedtime is the strongest corroboration we can get.
        if let m = motion,
           let screenBed = bedCandidates.first(where: { $0.label == "screen" })?.date,
           abs(m.stationaryStart.timeIntervalSince(screenBed)) <= 30 * 60 {
            confidence = min(0.95, confidence + 0.05)
        }
        if lockedOvernight {
            confidence = min(0.95, confidence + 0.03)
        }

        let sources = Set(bedCandidates.map(\.label) + wakeCandidates.map(\.label))
        return SleepSessionEstimate(
            bedtime: bed,
            wakeTime: wake,
            confidence: confidence,
            sources: sources.sorted()
        )
    }
}
