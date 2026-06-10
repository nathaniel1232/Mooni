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
    /// Best-effort signal that a real sample read actually succeeded. Drives the
    /// "connected" UI so a denied read-only authorization can't masquerade as
    /// connected. nil = not probed yet, true = a read returned samples,
    /// false = a probe completed but read access is denied / persistently empty.
    @Published private(set) var readAccessConfirmed: Bool?

    private let store = HKHealthStore()
    private var sleepType: HKCategoryType? {
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
    }

    /// The single live observer query. HealthKit does NOT deduplicate observer
    /// queries, so without this guard every launch/foreground/maintenance pass
    /// would execute another one — leaking queries and firing duplicate imports.
    private var sleepObserverQuery: HKObserverQuery?
    /// Background delivery only needs to be enabled once per type.
    private var backgroundDeliveryEnabled = false

    /// HealthKit never reports read-only permission status, so we persist
    /// a flag once the user has gone through the system sheet — that's
    /// the only reliable way to know we're "connected" from the UI.
    private static let didConnectKey = "mooni.health.didConnect"
    private var didCompleteConnection: Bool {
        get { UserDefaults.standard.bool(forKey: Self.didConnectKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.didConnectKey) }
    }

    /// Persists the fact that we once successfully read sleep samples. Read-only
    /// HealthKit auth is never reported by `authorizationStatus`, so an actual
    /// successful read is the only trustworthy proof of read access. Once true
    /// we stay "connected" even if a later probe comes back empty (e.g. the user
    /// simply hasn't recorded sleep recently).
    private static let didConfirmReadKey = "mooni.health.didConfirmRead"
    private var didConfirmRead: Bool {
        get { UserDefaults.standard.bool(forKey: Self.didConfirmReadKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.didConfirmReadKey) }
    }

    private init() {
        // Trust a previously confirmed read across launches; otherwise leave it
        // unknown until a probe runs.
        readAccessConfirmed = didConfirmRead ? true : nil
        refreshAuthState()
    }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Whether we have real evidence sleep reads work. HealthKit never reports
    /// read-only authorization via `authorizationStatus`, so we cannot trust a
    /// "granted-looking" status alone — a user who DENIED the read would still
    /// look connected. We instead require a successful sample read (now or in
    /// the past). Before any probe has completed we fall back to "tapped through
    /// the sheet" so freshly-onboarded users aren't shown as disconnected, but a
    /// completed probe that finds the read denied/empty wins and reports false.
    var isConnected: Bool {
        switch readAccessConfirmed {
        case .some(true):  return true
        case .some(false): return false
        case .none:        return didCompleteConnection
        }
    }

    func refreshAuthState() {
        guard isAvailable, let type = sleepType else {
            authState = .unavailable
            return
        }
        // A completed probe that found the read denied/empty is the most
        // trustworthy signal — surface it as `.denied` regardless of the
        // (read-blind) write status below.
        if readAccessConfirmed == false {
            authState = .denied
            // Still kick off a re-probe (handled after the switch) in case the
            // user has since granted access in Settings.
        } else {
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
        // Verify the granted-looking status against an actual read, but only
        // once the user has been through the sheet (no point probing before).
        if didCompleteConnection {
            Task { await probeReadAccess() }
        }
    }

    /// Best-effort verification that a real sleep read can succeed. Runs a tiny
    /// (limit 1) sample query over a wide window. A returned sample is proof of
    /// read access → connected. A query error or a persistently empty result is
    /// treated as not-connected, UNLESS we previously confirmed a read (the user
    /// may simply have no recent sleep data), in which case we keep the prior
    /// confirmation rather than flapping the UI.
    func probeReadAccess() async {
        guard isAvailable, let type = sleepType else { return }

        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -365, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])

        let result: (samples: Int, errored: Bool) = await withCheckedContinuation { cont in
            let q = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, results, error in
                cont.resume(returning: (results?.count ?? 0, error != nil))
            }
            store.execute(q)
        }

        if result.samples > 0 {
            didConfirmRead = true
            readAccessConfirmed = true
            // Read works — let the (read-blind) status decide authorized vs not.
            if authState == .denied { authState = .authorized }
        } else if didConfirmRead {
            // Once-confirmed connection survives a temporary empty/error read.
            readAccessConfirmed = true
        } else if result.errored {
            // A genuine query error (not a denial — HealthKit returns an empty
            // result, NOT an error, for denied read access). Don't downgrade to
            // .denied on a transient failure; stay unconfirmed (nil) so we fall
            // back to sheet-completion status and retry on the next probe.
            readAccessConfirmed = nil
        } else {
            // Empty result, no error, never confirmed: either read access was
            // denied, or there's simply no sleep data yet. Either way auto-
            // tracking can't produce anything, so stop masquerading as
            // connected. Self-heals to true the moment any sample appears.
            // Don't re-call refreshAuthState() here or it would re-spawn this probe.
            readAccessConfirmed = false
            authState = .denied
        }
    }

    /// Posted when new sleep data is written to HealthKit (observer fires).
    /// AppState listens to this and re-imports. Works in foreground; with the
    /// healthkit.background-delivery entitlement, iOS may also deliver it in background.
    nonisolated static let sleepDataUpdated = Notification.Name("mooni.healthKit.sleepDataUpdated")

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
            startSleepObserverIfNeeded()
            // Verify the read actually works rather than assuming the sheet =
            // granted (the user may have left the read toggle off).
            await probeReadAccess()
            return true
        } catch {
            lastImportError = error.localizedDescription
            refreshAuthState()
            return false
        }
    }

    /// Sets up an HKObserverQuery so we hear about new sleep samples the moment
    /// they're written — e.g. when the Watch syncs overnight data in the morning.
    /// Idempotent: a query is created at most once for the lifetime of this
    /// manager. HealthKit does not deduplicate observer queries, so calling
    /// `execute` repeatedly would leak queries and fire `sleepDataUpdated`
    /// (and therefore imports) multiple times per update.
    ///
    /// Gated behind a Pro subscription: auto-tracking is the headline paid
    /// feature, so free users only get the manual logging path. We check here
    /// (rather than only at call sites) so a missed call site can't silently
    /// leak the feature to non-Pro users.
    func startSleepObserverIfNeeded() {
        guard isAvailable, let type = sleepType else { return }
        guard SubscriptionManager.shared.isPro else { return }
        guard sleepObserverQuery == nil else { return }

        // Enable background delivery once (hourly cadence; sleep data arrives
        // once per night). Re-enabling on every pass is wasteful and can race.
        if !backgroundDeliveryEnabled {
            backgroundDeliveryEnabled = true
            store.enableBackgroundDelivery(for: type, frequency: .hourly) { _, _ in }
        }

        let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completionHandler, error in
            guard error == nil, self != nil else { completionHandler(); return }
            NotificationCenter.default.post(name: HealthKitManager.sleepDataUpdated, object: nil)
            completionHandler()
        }
        sleepObserverQuery = query
        store.execute(query)
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

        // A non-empty fetch is concrete proof that read access works — record it
        // so the "connected" UI reflects reality even if a probe never ran.
        if !samples.isEmpty {
            didConfirmRead = true
            readAccessConfirmed = true
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
