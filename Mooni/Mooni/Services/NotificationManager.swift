import Foundation
import UserNotifications
import Combine

/// Thin wrapper around UNUserNotificationCenter so onboarding can show its
/// own pre-permission screen and only trigger the system prompt on opt-in.
@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    enum AuthState {
        case notDetermined, authorized, denied
    }

    @Published private(set) var authState: AuthState = .notDetermined

    private init() {
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
}
