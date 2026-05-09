import Foundation
import SwiftUI

// MARK: - Friend Snapshot

/// Lightweight per-person snapshot used in the Friends widget. Pre-formatted
/// strings only — no locale work on the widget render thread.
struct FriendSleepSnapshot: Codable, Hashable, Identifiable {
    var id: String          // stable id (user id from your backend later)
    var name: String        // "You" / "Sam" / "Maya"
    var avatarEmoji: String // tiny avatar fallback ("🦉", "🌙", "🐻")
    var score: Int
    var quality: String     // "Good" etc.
    var sleepDuration: String
    var sleepStart: String
    var wakeTime: String

    var ringProgress: Double { max(0, min(1, Double(score) / 100.0)) }

    var scoreTint: Color {
        switch score {
        case 85...:   return Color(red: 0.55, green: 0.85, blue: 0.78)
        case 70..<85: return Color(red: 0.72, green: 0.62, blue: 1.00)
        case 50..<70: return Color(red: 1.00, green: 0.78, blue: 0.55)
        default:      return Color(red: 1.00, green: 0.60, blue: 0.72)
        }
    }
}

/// What the Friends widget renders: you on the left, your top friends on
/// the right. Mock data today; backend-driven later.
struct FriendsWidgetData: Codable, Hashable {
    var me: FriendSleepSnapshot
    var friends: [FriendSleepSnapshot]   // 0–2 shown on medium

    static let sample = FriendsWidgetData(
        me: FriendSleepSnapshot(
            id: "me",
            name: "You",
            avatarEmoji: "🦉",
            score: 76,
            quality: "Good",
            sleepDuration: "7h 36m",
            sleepStart: "11:42 PM",
            wakeTime: "7:18 AM"
        ),
        friends: [
            FriendSleepSnapshot(
                id: "f1",
                name: "Sam",
                avatarEmoji: "🌙",
                score: 88,
                quality: "Excellent",
                sleepDuration: "8h 04m",
                sleepStart: "10:55 PM",
                wakeTime: "7:00 AM"
            ),
            FriendSleepSnapshot(
                id: "f2",
                name: "Maya",
                avatarEmoji: "🐻",
                score: 62,
                quality: "Okay",
                sleepDuration: "6h 12m",
                sleepStart: "12:48 AM",
                wakeTime: "7:00 AM"
            )
        ]
    )
}

// MARK: - Storage

/// Same App-Group strategy as `WidgetDataStore` — wired to your backend later.
///
/// **Wire-up plan when friends become real:**
///   1. From the app, after each successful sync from your friends backend
///      (CloudKit, Firebase, custom server, etc.), call:
///         FriendsWidgetStore.write(FriendsWidgetData(me: ..., friends: ...))
///         WidgetCenter.shared.reloadTimelines(ofKind: "MooniFriendsSleepWidget")
///   2. Make sure the `appGroupIdentifier` in `SleepWidgetData.swift` is set
///      and that BOTH targets have the App Groups capability with the same id.
///   3. The widget reads via `FriendsWidgetStore.read()` — no widget code
///      changes needed when you flip from mock to real data.
///   4. Privacy: only show friends who have explicitly opted in to sharing
///      their sleep score with you (handle this on the app/backend side
///      before writing to the App Group).
enum FriendsWidgetStore {
    private static let storageKey = "mooni.widget.friends"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: WidgetDataStore.appGroupIdentifier)
    }

    static func read() -> FriendsWidgetData {
        guard
            let defaults,
            let data = defaults.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode(FriendsWidgetData.self, from: data)
        else {
            return .sample
        }
        return decoded
    }

    static func write(_ snapshot: FriendsWidgetData) {
        guard let defaults else { return }
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: storageKey)
        }
    }
}
