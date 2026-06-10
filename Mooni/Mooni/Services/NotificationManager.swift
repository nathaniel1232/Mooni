import Foundation
import UserNotifications
import Combine

/// Thin wrapper around UNUserNotificationCenter so onboarding can show its
/// own pre-permission screen and only trigger the system prompt on opt-in.
@MainActor
final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    enum AuthState {
        case notDetermined, authorized, denied
    }

    @Published private(set) var authState: AuthState = .notDetermined

    /// Identifier prefix for "are you awake?" probe notifications.
    /// `nonisolated` so the UNUserNotificationCenterDelegate callbacks
    /// (which are non-isolated) can read it without an actor hop.
    nonisolated static let wakeProbePrefix = "mooni.wakeProbe."
    /// Action ID for the "I'm awake" tap on a wake-probe notification.
    nonisolated static let wakeProbeAction = "mooni.wakeProbe.iAmAwake"

    /// SAFETY NET — Identifier prefix for the *daily-repeating* wake probes.
    /// Unlike `wakeProbePrefix` (per-night, only scheduled inside sleep mode),
    /// these are scheduled proactively every day from the user's target wake
    /// time regardless of whether the user ever opened the app or entered
    /// sleep mode. They are NOT cancelled on wake — they must keep firing
    /// every morning so a missed night can never go un-prompted again.
    nonisolated static let dailyWakeProbePrefix = "mooni.dailyWakeProbe."
    /// SAFETY NET — single daily-repeating "we couldn't confirm last night's
    /// sleep, tap to log it" catch-up notification, fired late morning.
    nonisolated static let catchUpIdentifier = "mooni.catchUpLog"
    /// How many daily safety-net probes we schedule per morning.
    static let dailyWakeProbeCount = 5

    /// Sleep-onset probes — silent "still awake?" pings during the first
    /// 45 minutes after sleep mode starts. Each tap proves the user was
    /// still awake at that moment, letting us narrow the real onset
    /// window without asking them to remember in the morning.
    nonisolated static let onsetProbePrefix = "mooni.onsetProbe."
    nonisolated static let onsetProbeAction = "mooni.onsetProbe.stillAwake"
    nonisolated static let onsetProbeCategory = "mooni.onsetProbe"

    /// Posted when the user confirms they're awake — either via a probe
    /// notification or by tapping wake on the sleep-lock overlay.
    static let didConfirmWakeNotification = Notification.Name("mooni.didConfirmWake")
    /// Posted when the user taps "still awake" on an onset probe. The
    /// `userInfo` carries `tappedAt: Date` so the listener can refine
    /// the lower bound on real sleep onset.
    static let didConfirmStillAwakeNotification = Notification.Name("mooni.didConfirmStillAwake")

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        registerCategories()
        Task { await refreshAuthState() }
    }

    func refreshAuthState() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: authState = .notDetermined
        case .denied:        authState = .denied
        case .authorized, .provisional, .ephemeral:
            authState = .authorized
        @unknown default:    authState = .notDetermined
        }
    }

    /// Triggers the real OS prompt. Only call after the user accepts the in-app screen.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthState()
            return granted
        } catch {
            await refreshAuthState()
            return false
        }
    }

    /// Schedules a nightly bedtime nudge in the pet's voice.
    /// Safe to call repeatedly — it replaces the previous nudge.
    func scheduleNightlyBedtimeNudge(petName: String, bedtime: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["mooni.bedtime"])

        let content = UNMutableNotificationContent()
        content.title = "\(petName) is getting sleepy…"
        content.body = "Tuck in soon — your sleep story will be waiting the moment you wake."
        content.sound = .default

        // Fire 30 min before target bedtime
        let nudgeDate = bedtime.addingTimeInterval(-30 * 60)
        let comps = Calendar.current.dateComponents([.hour, .minute], from: nudgeDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)

        let request = UNNotificationRequest(identifier: "mooni.bedtime", content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Safety net (proactive, schedule-independent)

    /// SAFETY NET (mechanisms 1, 6, 7). Idempotently (re)schedules the full
    /// set of notifications the app should ALWAYS have pending, regardless of
    /// whether the user ever taps "going to bed" or opens the app:
    ///
    ///   • the nightly wind-down nudge,
    ///   • daily-repeating "are you awake?" wake probes around wake time,
    ///   • a daily-repeating late-morning "log last night" catch-up.
    ///
    /// Each sub-call removes its own pending requests before re-adding, so
    /// calling this on every launch / foreground / background-refresh
    /// self-heals anything iOS dropped or that was never scheduled because
    /// the user never entered sleep mode. This is the core fix for the
    /// "I didn't touch the app and it did nothing" failure.
    func reconcileSafetyNetNotifications(petName: String, bedtime: Date, wakeTime: Date) {
        // The bedtime wind-down nudge is benign and stays unconditional for
        // everyone — it never asks the user to confirm a night, it just nudges.
        scheduleNightlyBedtimeNudge(petName: petName, bedtime: bedtime)

        // The daily-repeating wake probes + catch-up only make sense for users
        // who can have a night auto-confirmed. Gate them behind Pro to match
        // the auto-tracking gate (HealthKitManager.startSleepObserverIfNeeded).
        // We also suppress them once tonight's night is already logged, and
        // while per-night probes are active (see scheduleWakeProbes) so the
        // user never gets the same morning ping twice. In every suppressed
        // case we CLEAR any previously-scheduled daily probes so a user who
        // lapsed from Pro — or who logged early — stops getting them.
        let suppressDailyProbes = !SubscriptionManager.shared.isPro
            || isTonightAlreadyLogged()
            || perNightProbesActive

        if suppressDailyProbes {
            clearDailyWakeProbes()
            clearCatchUpPrompt()
        } else {
            scheduleDailyWakeProbes(wakeTime: wakeTime, petName: petName)
            scheduleCatchUpPrompt(wakeTime: wakeTime, petName: petName)
        }
        SleepAutomationLog.shared.log("Reconciled safety-net notifications (wake \(wakeTime.hourMinuteString), dailyProbes=\(suppressDailyProbes ? "suppressed" : "scheduled"))")
    }

    /// UserDefaults flag set while per-night wake probes are pending (i.e. the
    /// user is in sleep mode). Used to suppress the overlapping daily-repeating
    /// safety-net probes so the same morning isn't double-pinged.
    private static let perNightProbesActiveKey = "mooni.perNightWakeProbesActive"
    /// Unix time after which the per-night probe window is considered spent,
    /// so a stale `active` flag can't suppress the daily safety net forever.
    private static let perNightProbesEndKey = "mooni.perNightWakeProbesEnd"

    /// True while per-night wake probes are scheduled for the upcoming wake
    /// window. Read in `reconcileSafetyNetNotifications` to de-duplicate.
    /// Self-expires: the per-night probes are one-shot, so once their window
    /// (incl. the late catch-up) has passed they're spent — even if the user
    /// never tapped a probe or relaunched the app to clear the flag. Without
    /// this, an un-tapped night would leave the flag stuck `true` and mask the
    /// daily safety-net probes indefinitely, defeating their whole purpose.
    private var perNightProbesActive: Bool {
        guard UserDefaults.standard.bool(forKey: Self.perNightProbesActiveKey) else { return false }
        let end = UserDefaults.standard.double(forKey: Self.perNightProbesEndKey)
        if end > 0, Date().timeIntervalSince1970 > end { return false }
        return true
    }

    /// Whether an entry for tonight (keyed by today's wake date) already exists.
    /// Decoded directly from the persisted entry store so this works even in the
    /// background-refresh path, which has no `AppState` instance. Mirrors the
    /// `entries.contains { $0.dayKey == Date().dayKey }` check AppState uses.
    private func isTonightAlreadyLogged() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: "mooni.entries"),
              let entries = try? JSONDecoder().decode([SleepEntry].self, from: data)
        else { return false }
        let today = Date().dayKey
        return entries.contains { $0.dayKey == today }
    }

    /// Removes any pending daily-repeating wake probes without re-adding them.
    private func clearDailyWakeProbes() {
        let ids = (0..<Self.dailyWakeProbeCount).map { "\(Self.dailyWakeProbePrefix)\($0)" }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    /// Removes the pending daily catch-up prompt without re-adding it.
    private func clearCatchUpPrompt() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.catchUpIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.catchUpIdentifier])
    }

    /// SAFETY NET (mechanism 8 companion). Rebuilds bedtime/wake from the
    /// persisted target schedule and reconciles — used by the background
    /// refresh task, which has no `AppState` instance to read from.
    func reconcileFromStoredSchedule() {
        let d = UserDefaults.standard
        let bH = d.object(forKey: "mooni.targetBedHour") as? Int ?? 22
        let bM = d.object(forKey: "mooni.targetBedMinute") as? Int ?? 30
        let wH = d.object(forKey: "mooni.targetWakeHour") as? Int ?? 7
        let wM = d.object(forKey: "mooni.targetWakeMinute") as? Int ?? 0
        let cal = Calendar.current
        let now = Date()
        let bed = cal.date(bySettingHour: bH, minute: bM, second: 0, of: now) ?? now
        let wake = cal.date(bySettingHour: wH, minute: wM, second: 0, of: now) ?? now
        var name = "SleepOwl"
        if let data = d.data(forKey: "mooni.pet"),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let n = obj["name"] as? String, !n.isEmpty {
            name = n
        }
        reconcileSafetyNetNotifications(petName: name, bedtime: bed, wakeTime: wake)
    }

    /// Daily-repeating "are you awake?" probes at wake −60/−30/0/+30/+60 min.
    /// Uses repeating clock-time calendar triggers so they fire every single
    /// morning even with zero interaction. Safe to call repeatedly.
    func scheduleDailyWakeProbes(wakeTime: Date, petName: String) {
        let center = UNUserNotificationCenter.current()
        let ids = (0..<Self.dailyWakeProbeCount).map { "\(Self.dailyWakeProbePrefix)\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)

        let offsets: [Int] = [-60, -30, 0, 30, 60]
        let cal = Calendar.current
        for (idx, minutes) in offsets.enumerated() {
            let fire = wakeTime.addingTimeInterval(TimeInterval(minutes * 60))
            let content = UNMutableNotificationContent()
            if minutes < 0 {
                content.title = "\(petName) is stirring…"
                content.body = "Your night is almost ready. Tap the moment you're up to unlock it."
            } else {
                content.title = "🌙 Your sleep story is ready"
                content.body = "\(petName) watched over you all night. Tap to see what happened while you slept."
            }
            content.sound = .default
            content.categoryIdentifier = "mooni.wakeProbe"
            content.interruptionLevel = .timeSensitive
            content.userInfo = ["safetyNet": true]

            let comps = cal.dateComponents([.hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            center.add(UNNotificationRequest(identifier: ids[idx], content: content, trigger: trigger))
        }
    }

    /// Daily-repeating late-morning catch-up: if the user slept through /
    /// ignored every wake probe, this still pings them once so the night is
    /// never silently lost. Fires ~2h after target wake time.
    func scheduleCatchUpPrompt(wakeTime: Date, petName: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.catchUpIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "🌙 You have an unopened night"
        content.body = "\(petName) is still holding last night's story. Tap to open it and keep your streak alive."
        content.sound = .default
        content.categoryIdentifier = "mooni.wakeProbe"
        content.interruptionLevel = .timeSensitive
        content.userInfo = ["safetyNet": true, "catchUp": true]

        let fire = wakeTime.addingTimeInterval(2 * 3600)
        let comps = Calendar.current.dateComponents([.hour, .minute], from: fire)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        center.add(UNNotificationRequest(identifier: Self.catchUpIdentifier, content: content, trigger: trigger))
    }

    // MARK: - Wake probes

    /// Schedules "are you awake?" probes every 30 minutes starting 1h
    /// before `wakeTime` and continuing 1h after, so we still catch users
    /// who oversleep past their target. Tapping any one (or its action)
    /// records the user's actual wake moment, which feeds back into the
    /// sleep onset / duration estimate for that night.
    func scheduleWakeProbes(wakeTime: Date, petName: String) {
        let center = UNUserNotificationCenter.current()
        cancelWakeProbes()

        // De-duplicate: the per-night probes scheduled here fire at the same
        // clock times as the daily-repeating safety-net probes (and catch-up).
        // Cancel the daily set for this window and flag per-night probes as
        // active so the next safety-net reconcile won't re-add the overlap.
        UserDefaults.standard.set(true, forKey: Self.perNightProbesActiveKey)
        // Window end = past the last probe (+60m) and the daily catch-up (+2h),
        // plus a grace hour. After this the flag self-expires (see getter).
        UserDefaults.standard.set(
            wakeTime.addingTimeInterval(3 * 3600).timeIntervalSince1970,
            forKey: Self.perNightProbesEndKey
        )
        clearDailyWakeProbes()
        clearCatchUpPrompt()

        // -60, -30, 0, +30, +60 (30-minute cadence, 2-hour window).
        let offsets: [Int] = [-60, -30, 0, 30, 60]
        let now = Date()

        for (idx, minutes) in offsets.enumerated() {
            let fireDate = wakeTime.addingTimeInterval(TimeInterval(minutes * 60))
            // Skip any probe that's already in the past.
            guard fireDate > now.addingTimeInterval(5) else { continue }

            let content = UNMutableNotificationContent()
            if minutes < 0 {
                content.title = "\(petName) is stirring…"
                content.body = "Your night is almost ready. Tap the moment you're up to unlock it."
            } else {
                content.title = "🌙 Your sleep story is ready"
                content.body = "\(petName) watched over you all night. Tap to see what happened while you slept."
            }
            content.sound = .default
            content.categoryIdentifier = "mooni.wakeProbe"
            content.interruptionLevel = .timeSensitive
            content.userInfo = ["fireDate": fireDate.timeIntervalSince1970]

            let comps = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

            let id = "\(Self.wakeProbePrefix)\(idx)"
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            center.add(request)
        }
    }

    /// Total number of probes scheduled per night. Drives the cancel
    /// loop; keep in sync with `scheduleWakeProbes` offsets length.
    static let wakeProbeCount = 5

    // MARK: - Sleep onset probes
    //
    // We schedule three "still awake?" pings at +15, +30 and +45 minutes
    // after the user enters sleep mode. Each tap proves they were still
    // awake at that moment — pushing the lower bound on real sleep onset
    // forward. If they don't tap any, the silence itself is signal:
    // they probably fell asleep within the first window.

    /// Schedules onset probes after the user enters sleep mode.
    func scheduleOnsetProbes(sleepStart: Date, petName: String) {
        let center = UNUserNotificationCenter.current()
        cancelOnsetProbes()
        let offsets: [Int] = [15, 30, 45]
        let now = Date()

        for (idx, minutes) in offsets.enumerated() {
            let fireDate = sleepStart.addingTimeInterval(TimeInterval(minutes * 60))
            guard fireDate > now.addingTimeInterval(5) else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Still awake?"
            content.body = "If \(petName) hasn't drifted off yet, tap so we know."
            content.sound = nil
            content.interruptionLevel = .passive
            content.categoryIdentifier = Self.onsetProbeCategory
            content.userInfo = ["fireDate": fireDate.timeIntervalSince1970]

            let interval = max(5, fireDate.timeIntervalSince(now))
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let id = "\(Self.onsetProbePrefix)\(idx)"
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            center.add(request)
        }
    }

    func cancelOnsetProbes() {
        let ids = (0..<3).map { "\(Self.onsetProbePrefix)\($0)" }
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ids)
        UNUserNotificationCenter.current()
            .removeDeliveredNotifications(withIdentifiers: ids)
    }

    /// Removes any pending wake probes — call when the user wakes early
    /// or sleep mode otherwise ends.
    func cancelWakeProbes() {
        let ids = (0..<Self.wakeProbeCount).map { "\(Self.wakeProbePrefix)\($0)" }
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ids)
        UNUserNotificationCenter.current()
            .removeDeliveredNotifications(withIdentifiers: ids)
        // Per-night probes are no longer active; the daily safety-net probes
        // may resume on the next reconcile (gated by Pro / not-yet-logged).
        UserDefaults.standard.set(false, forKey: Self.perNightProbesActiveKey)
        UserDefaults.standard.removeObject(forKey: Self.perNightProbesEndKey)
    }

    private func registerCategories() {
        let wakeAction = UNNotificationAction(
            identifier: Self.wakeProbeAction,
            title: "I'm awake",
            options: [.foreground]
        )
        let wakeCategory = UNNotificationCategory(
            identifier: "mooni.wakeProbe",
            actions: [wakeAction],
            intentIdentifiers: [],
            options: []
        )

        // Onset probes can be answered without launching SleepOwl —
        // background-only action keeps the user from accidentally
        // breaking sleep mode by tapping it.
        let onsetAction = UNNotificationAction(
            identifier: Self.onsetProbeAction,
            title: "Still awake",
            options: []
        )
        let onsetCategory = UNNotificationCategory(
            identifier: Self.onsetProbeCategory,
            actions: [onsetAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([wakeCategory, onsetCategory])
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Show the probe banner even when SleepOwl is foreground so the user
    /// has a one-tap "I'm awake" affordance.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let id = response.notification.request.identifier
        let tapTime = Date()
        if id.hasPrefix(Self.wakeProbePrefix)
            || id.hasPrefix(Self.dailyWakeProbePrefix)
            || id == Self.catchUpIdentifier {
            Task { @MainActor in
                NotificationManager.shared.recordWakeConfirmation(at: tapTime)
            }
        } else if id.hasPrefix(Self.onsetProbePrefix) {
            // "Still awake" tap — record the lower bound on real onset.
            // We deliberately do NOT cancel sleep mode here.
            Task { @MainActor in
                NotificationManager.shared.recordStillAwake(at: tapTime)
            }
        }
        completionHandler()
    }

    /// Persists a wake-tap timestamp and broadcasts so AppState can react.
    func recordWakeConfirmation(at date: Date) {
        if UserDefaults.standard.object(forKey: "mooni.wakeTappedAt") == nil {
            UserDefaults.standard.set(date, forKey: "mooni.wakeTappedAt")
        }
        cancelWakeProbes()
        NotificationCenter.default.post(name: Self.didConfirmWakeNotification, object: nil)
    }

    /// Persists the *latest* "still awake" tap so onset estimation can
    /// push the lower bound forward each time the user confirms they're
    /// still up.
    func recordStillAwake(at date: Date) {
        let key = "mooni.lastStillAwakeAt"
        let prior = UserDefaults.standard.object(forKey: key) as? Date
        if prior == nil || date > prior! {
            UserDefaults.standard.set(date, forKey: key)
        }
        NotificationCenter.default.post(
            name: Self.didConfirmStillAwakeNotification,
            object: nil,
            userInfo: ["tappedAt": date]
        )
    }
}
