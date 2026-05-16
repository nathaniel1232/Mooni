import Foundation

/// SAFETY NET (mechanism 10 — diagnostics). A tiny persisted ring buffer of
/// timestamped automation events (notification reconciles, auto sleep-mode
/// entry, missed-night backfills, morning-prompt decisions). When a user
/// reports "the app did nothing last night" we can read exactly which safety
/// nets fired instead of guessing. Surfaced read-only in the profile/debug UI.
final class SleepAutomationLog: @unchecked Sendable {
    static let shared = SleepAutomationLog()

    private let key = "mooni.automationLog"
    private let maxEntries = 120
    private let queue = DispatchQueue(label: "mooni.automationLog")

    private init() {}

    func log(_ message: String) {
        queue.async {
            let stamp = ISO8601DateFormatter().string(from: Date())
            var lines = UserDefaults.standard.stringArray(forKey: self.key) ?? []
            lines.append("\(stamp)  \(message)")
            if lines.count > self.maxEntries {
                lines.removeFirst(lines.count - self.maxEntries)
            }
            UserDefaults.standard.set(lines, forKey: self.key)
        }
        #if DEBUG
        print("[SleepAutomation] \(message)")
        #endif
    }

    var entries: [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
