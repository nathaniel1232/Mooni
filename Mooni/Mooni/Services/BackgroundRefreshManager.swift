import Foundation
import BackgroundTasks
import UIKit

/// SAFETY NET (mechanism 8). Opportunistic background refresh: even if the
/// user never opens the app, iOS periodically wakes us to re-reconcile the
/// notification safety net (in case it pruned pending requests) and chain the
/// next refresh. iOS does NOT guarantee timing — this is a backstop on top of
/// the always-scheduled notifications, not a replacement for them.
///
/// Fail-safe by design: if the `BGTaskSchedulerPermittedIdentifiers` Info.plist
/// key / Background Modes capability has not been added yet, `register`
/// returns false and `submit` throws — both are handled, so the app never
/// crashes and every other safety net still works.
enum BackgroundRefreshManager {

    /// Must be listed verbatim in `BGTaskSchedulerPermittedIdentifiers`.
    static let taskIdentifier = "com.nathanielfiskaa.sleepowl.refresh"

    /// Call once, before the app finishes launching (MooniApp.init).
    static func register() {
        let ok = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            handle(task: task as! BGAppRefreshTask)
        }
        SleepAutomationLog.shared.log(
            ok ? "BGTask registered"
               : "BGTask NOT registered (add BGTaskSchedulerPermittedIdentifiers + Background Modes)"
        )
    }

    /// Ask iOS to wake us again later. Safe to call repeatedly.
    static func scheduleNext() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date().addingTimeInterval(4 * 3600)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            SleepAutomationLog.shared.log("BGTask submit failed: \(error.localizedDescription)")
        }
    }

    private static func handle(task: BGAppRefreshTask) {
        scheduleNext() // always chain the next refresh first
        SleepAutomationLog.shared.log("BGTask fired — reconciling notification safety net")
        let work = Task { @MainActor in
            // Sample the lock state while iOS has us awake in the background —
            // a passcode-locked device in the middle of the night is a strong
            // "asleep" corroboration for the sleep brain (SleepSessionEngine).
            LockStateSampleStore.record(
                locked: !UIApplication.shared.isProtectedDataAvailable
            )
            NotificationManager.shared.reconcileFromStoredSchedule()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = {
            work.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}
