import Foundation
import Combine
import WidgetKit

/// Local-first friends layer. Generates the user's 6-char code on first use,
/// keeps a persisted list of added friends, and projects everything into the
/// shape the `FriendsSleepWidget` expects (matched by JSON shape, not by a
/// shared Swift type — same pattern as `WidgetSnapshotPublisher`).
///
/// **Why local-first**: the viral loop (invite via iMessage → friend types
/// code in → both sides see each other) doesn't require any backend. When
/// real per-friend sleep sync ships, only `syncToWidget(...)` and a future
/// `refreshSnapshots(...)` need to change — call sites stay identical.
///
/// Persistence is split:
///   • `myCode` and the friends list live in the App Group so the widget
///     and a future widget-side action can read them.
///   • Each add / remove / sleep-log triggers a widget timeline reload so
///     the change shows within seconds, not at next-hour refresh.
@MainActor
final class FriendsManager: ObservableObject {

    static let shared = FriendsManager()

    private enum Key {
        static let myCode = "mooni.friends.myCode"
        static let friends = "mooni.friends.list"
        /// Matches `FriendsWidgetStore.storageKey` in
        /// `MooniSleepWidget/FriendsSleepData.swift`. If the widget side
        /// changes that key, this one must change in lockstep.
        static let widgetFriendsPayload = "mooni.widget.friends"
    }

    /// Shared App Group suite. Must match the widget's `appGroupIdentifier`
    /// — if these drift, the widget falls back to mock data.
    private static let appGroupID = "group.com.nathanielfiskaa.sleepowl"

    private var defaults: UserDefaults {
        UserDefaults(suiteName: Self.appGroupID) ?? .standard
    }

    @Published private(set) var myCode: String
    @Published private(set) var friends: [FriendCode]

    private init() {
        let d = UserDefaults(suiteName: Self.appGroupID) ?? .standard
        if let existing = d.string(forKey: Key.myCode), !existing.isEmpty {
            self.myCode = existing
        } else {
            let fresh = FriendCodeGenerator.generate()
            d.set(fresh, forKey: Key.myCode)
            self.myCode = fresh
        }

        if let data = d.data(forKey: Key.friends),
           let decoded = try? JSONDecoder().decode([FriendCode].self, from: data) {
            self.friends = decoded
        } else {
            self.friends = []
        }
    }

    // MARK: - Mutations

    /// Adds a friend by code. Returns `.added` when the code is fresh,
    /// `.exists` when this friend is already in the list, `.invalid` when the
    /// code can't be parsed, and `.selfCode` when the user tries to add their
    /// own code.
    enum AddResult: Equatable {
        case added(FriendCode)
        case exists
        case invalid
        case selfCode
    }

    @discardableResult
    func addFriend(rawCode: String, displayName: String? = nil) -> AddResult {
        guard let normalized = FriendCodeGenerator.sanitize(rawCode) else {
            return .invalid
        }
        if normalized == myCode { return .selfCode }
        if friends.contains(where: { $0.code == normalized }) { return .exists }

        let trimmedName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = FriendCode(
            code: normalized,
            displayName: (trimmedName?.isEmpty == false) ? trimmedName : nil,
            addedAt: Date()
        )
        friends.insert(entry, at: 0)
        persistFriends()
        Haptics.success()
        return .added(entry)
    }

    func removeFriend(code: String) {
        friends.removeAll { $0.code == code }
        persistFriends()
    }

    func rename(code: String, to displayName: String?) {
        guard let idx = friends.firstIndex(where: { $0.code == code }) else { return }
        let trimmed = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        friends[idx].displayName = (trimmed?.isEmpty == false) ? trimmed : nil
        persistFriends()
    }

    // MARK: - Invite copy

    /// Prefilled iMessage text. The 6-char code is what actually matters — the
    /// URL is a soft handshake that we can light up later via universal links
    /// without changing this call site.
    func inviteShareText(petName: String) -> String {
        """
        Sleep with me on Sleepowl 🌙
        My code: \(myCode)
        \(Self.appShareURL)
        """
    }

    /// App Store URL placeholder. Replace with the real link once the app is
    /// approved — until then, friends type the 6-char code into the app.
    static let appShareURL = "https://apps.apple.com/app/sleepowl"

    // MARK: - Widget projection

    /// Project the current friends list + my latest sleep into the JSON shape
    /// the FriendsSleepWidget expects. Friends' scores are 0 with a "Pending"
    /// label until backend sync lands — the avatar and name still render so
    /// the widget reads as populated, not empty.
    func syncToWidget(myLatest: SleepEntry?, petName: String) {
        let me = WidgetFriendSnapshot(
            id: "me",
            name: "You",
            avatarEmoji: "🦉",
            score: myLatest?.score ?? 0,
            quality: myLatest?.quality.label ?? "—",
            sleepDuration: myLatest?.formattedDuration ?? "—",
            sleepStart: myLatest?.bedtime.hourMinuteString ?? "—",
            wakeTime: myLatest?.wakeTime.hourMinuteString ?? "—"
        )

        let friendSnaps = friends.prefix(2).map { f in
            WidgetFriendSnapshot(
                id: f.code,
                name: f.resolvedName,
                avatarEmoji: Self.avatarEmoji(for: f),
                score: 0,
                quality: "Pending",
                sleepDuration: "—",
                sleepStart: "—",
                wakeTime: "—"
            )
        }

        let payload = WidgetFriendsPayload(me: me, friends: Array(friendSnaps))
        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults.set(data, forKey: Key.widgetFriendsPayload)
        WidgetCenter.shared.reloadTimelines(ofKind: "MooniFriendsSleepWidget")
    }

    private static func avatarEmoji(for friend: FriendCode) -> String {
        // Stable pseudo-random pick so the same friend always shows the same
        // emoji until they get a real avatar.
        let pool = ["🦉", "🌙", "⭐", "🌟", "🌜", "✨", "🐻", "🐰"]
        let idx = abs(friend.code.hashValue) % pool.count
        return pool[idx]
    }

    // MARK: - Persistence

    private func persistFriends() {
        if let data = try? JSONEncoder().encode(friends) {
            defaults.set(data, forKey: Key.friends)
        }
    }
}

// MARK: - Widget payload (JSON-shape mirror)

/// JSON-shape mirror of `FriendSleepSnapshot` in
/// `MooniSleepWidget/FriendsSleepData.swift`. Field names and types MUST
/// stay identical so the widget can decode what the app writes. Same pattern
/// as `WidgetSnapshotPublisher.Snapshot`.
private struct WidgetFriendSnapshot: Codable {
    let id: String
    let name: String
    let avatarEmoji: String
    let score: Int
    let quality: String
    let sleepDuration: String
    let sleepStart: String
    let wakeTime: String
}

private struct WidgetFriendsPayload: Codable {
    let me: WidgetFriendSnapshot
    let friends: [WidgetFriendSnapshot]
}
