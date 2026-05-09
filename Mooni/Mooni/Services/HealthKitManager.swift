import Foundation
import Combine
import HealthKit

@MainActor
final class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()

    enum AuthState {
        case notDetermined, authorized, denied, unavailable
    }

    @Published private(set) var authState: AuthState = .notDetermined
    @Published private(set) var isImporting: Bool = false
    @Published private(set) var lastImportError: String? = nil

    private let store = HKHealthStore()
    private var sleepType: HKCategoryType? {
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
    }

    /// HealthKit never reports read-only permission status, so we persist
    /// a flag once the user has gone through the system sheet — that's
    /// the only reliable way to know we're "connected" from the UI.
    private static let didConnectKey = "mooni.health.didConnect"
    private var didCompleteConnection: Bool {
        get { UserDefaults.standard.bool(forKey: Self.didConnectKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.didConnectKey) }
    }

    private init() {
        refreshAuthState()
    }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// True once the user has tapped through the HealthKit prompt at
    /// least once. HealthKit does not expose read-only authorization status,
    /// so this persisted flag is the closest reliable signal for sleep reads.
    var isConnected: Bool {
        if case .authorized = authState { return true }
        return didCompleteConnection
    }

    func refreshAuthState() {
        guard isAvailable, let type = sleepType else {
            authState = .unavailable
            return
        }
        switch store.authorizationStatus(for: type) {
        case .notDetermined: authState = .notDetermined
        case .sharingAuthorized: authState = .authorized
        case .sharingDenied:
            // `authorizationStatus(for:)` reports write/share permission only.
            // This app requests sleep reads, not writes, so a successful prompt
            // later still appears as `.sharingDenied` here.
            authState = didCompleteConnection ? .authorized : .notDetermined
        @unknown default: authState = .notDetermined
        }
    }

    /// Prompts the system permission sheet. Returns true if the user has granted (or already granted) read access.
    @discardableResult
    func requestAuthorization() async -> Bool {
        guard isAvailable, let type = sleepType else {
            authState = .unavailable
            return false
        }
        do {
            try await store.requestAuthorization(toShare: [], read: [type])
            didCompleteConnection = true
            refreshAuthState()
            objectWillChange.send()
            return true
        } catch {
            lastImportError = error.localizedDescription
            refreshAuthState()
            return false
        }
    }

    /// Pulls sleep samples from the last `days` days and groups them into per-night bedtime/wakeTime ranges.
    /// When HealthKit includes stages, those stage durations are carried through.
    func fetchNightlySleep(days: Int = 14) async -> [SleepInterval] {
        guard isAvailable, let type = sleepType else { return [] }

        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictEndDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let samples: [HKCategorySample] = await withCheckedContinuation { cont in
            let q = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, results, _ in
                cont.resume(returning: (results as? [HKCategorySample]) ?? [])
            }
            store.execute(q)
        }

        return Self.groupIntoNights(samples: samples)
    }

    /// Groups raw samples into single nightly intervals. Samples within 60 minutes of each other are merged.
    static func groupIntoNights(samples: [HKCategorySample]) -> [SleepInterval] {
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ]
        let relevantValues = asleepValues.union([
            HKCategoryValueSleepAnalysis.awake.rawValue,
            HKCategoryValueSleepAnalysis.inBed.rawValue
        ])
        let relevant = samples.filter { relevantValues.contains($0.value) }
            .sorted { $0.startDate < $1.startDate }
        guard !relevant.isEmpty else { return [] }

        var groups: [[HKCategorySample]] = []
        var current: [HKCategorySample] = [relevant[0]]
        var currentEnd = relevant[0].endDate

        for s in relevant.dropFirst() {
            // Gap of <60min → same night, extend
            if s.startDate.timeIntervalSince(currentEnd) < 60 * 60 {
                current.append(s)
                currentEnd = max(currentEnd, s.endDate)
            } else {
                groups.append(current)
                current = [s]
                currentEnd = s.endDate
            }
        }
        groups.append(current)

        // Filter out naps shorter than 1 hour
        return groups.compactMap { samples -> SleepInterval? in
            makeInterval(from: samples)
        }
        .filter { $0.totalSleepDuration >= 60 * 60 }
    }

    private static func makeInterval(from samples: [HKCategorySample]) -> SleepInterval? {
        guard let start = samples.map(\.startDate).min(),
              let end = samples.map(\.endDate).max() else {
            return nil
        }

        var deep: TimeInterval = 0
        var rem: TimeInterval = 0
        var light: TimeInterval = 0
        var awake: TimeInterval = 0
        var inBed: TimeInterval = 0

        for sample in samples {
            let duration = max(0, sample.endDate.timeIntervalSince(sample.startDate))
            switch sample.value {
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                deep += duration
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                rem += duration
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                 HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                light += duration
            case HKCategoryValueSleepAnalysis.awake.rawValue:
                awake += duration
            case HKCategoryValueSleepAnalysis.inBed.rawValue:
                inBed += duration
            default:
                break
            }
        }

        let totalSleep = deep + rem + light
        guard totalSleep > 0 else { return nil }

        let hasStageData = deep > 0 || rem > 0 || samples.contains { $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue || $0.value == HKCategoryValueSleepAnalysis.awake.rawValue }
        let stages = hasStageData
            ? SleepStagesEstimate(
                deepSleep: deep,
                remSleep: rem,
                lightSleep: light,
                awakeTime: awake,
                isEstimated: false
            )
            : nil

        return SleepInterval(
            start: start,
            end: end,
            totalSleep: totalSleep,
            timeInBed: inBed > 0 ? inBed : nil,
            stages: stages
        )
    }
}

struct SleepInterval: Equatable {
    let start: Date
    let end: Date
    var totalSleep: TimeInterval? = nil
    var timeInBed: TimeInterval? = nil
    var stages: SleepStagesEstimate? = nil
    var duration: TimeInterval { end.timeIntervalSince(start) }
    var totalSleepDuration: TimeInterval { totalSleep ?? duration }
}
