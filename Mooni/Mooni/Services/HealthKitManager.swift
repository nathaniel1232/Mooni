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

    private init() {
        refreshAuthState()
    }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func refreshAuthState() {
        guard isAvailable, let type = sleepType else {
            authState = .unavailable
            return
        }
        switch store.authorizationStatus(for: type) {
        case .notDetermined: authState = .notDetermined
        case .sharingAuthorized: authState = .authorized
        case .sharingDenied: authState = .denied
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
            refreshAuthState()
            // We can't introspect read-permission directly; assume success unless explicitly denied.
            return authState != .denied
        } catch {
            lastImportError = error.localizedDescription
            return false
        }
    }

    /// Pulls sleep samples from the last `days` days and groups them into per-night bedtime/wakeTime ranges.
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
        // Only count "asleep"-state samples, ignore "inBed".
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ]
        let asleep = samples.filter { asleepValues.contains($0.value) }
            .sorted { $0.startDate < $1.startDate }
        guard !asleep.isEmpty else { return [] }

        var intervals: [SleepInterval] = []
        var currentStart = asleep[0].startDate
        var currentEnd = asleep[0].endDate

        for s in asleep.dropFirst() {
            // Gap of <60min → same night, extend
            if s.startDate.timeIntervalSince(currentEnd) < 60 * 60 {
                currentEnd = max(currentEnd, s.endDate)
            } else {
                intervals.append(SleepInterval(start: currentStart, end: currentEnd))
                currentStart = s.startDate
                currentEnd = s.endDate
            }
        }
        intervals.append(SleepInterval(start: currentStart, end: currentEnd))

        // Filter out naps shorter than 1 hour
        return intervals.filter { $0.end.timeIntervalSince($0.start) >= 60 * 60 }
    }
}

struct SleepInterval: Equatable {
    let start: Date
    let end: Date
    var duration: TimeInterval { end.timeIntervalSince(start) }
}
