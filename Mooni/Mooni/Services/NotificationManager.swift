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
        content.body = "Tap to start tonight's wind-down."
        content.sound = .default

        // Fire 30 min before target bedtime
        let nudgeDate = bedtime.addingTimeInterval(-30 * 60)
        let comps = Calendar.current.dateComponents([.hour, .minute], from: nudgeDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)

        let request = UNNotificationRequest(identifier: "mooni.bedtime", content: content, trigger: trigger)
        center.add(request)
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

        // -60, -30, 0, +30, +60 (30-minute cadence, 2-hour window).
        let offsets: [Int] = [-60, -30, 0, 30, 60]
        let now = Date()

        for (idx, minutes) in offsets.enumerated() {
            let fireDate = wakeTime.addingTimeInterval(TimeInterval(minutes * 60))
            // Skip any probe that's already in the past.
            guard fireDate > now.addingTimeInterval(5) else { continue }

            let content = UNMutableNotificationContent()
            content.title = minutes == 0
                ? "\(petName) is waking up"
                : "\(petName) is checking in"
            content.body = minutes == 0
                ? "Are you awake yet? Tap so we can log it."
                : "If you're up, tap so we can record exactly when you woke."
            content.sound = .default
            content.categoryIdentifier = "mooni.wakeProbe"
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
        if id.hasPrefix(Self.wakeProbePrefix) {
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
