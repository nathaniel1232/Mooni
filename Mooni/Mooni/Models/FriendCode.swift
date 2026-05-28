import Foundation

/// One entry in the user's local friends list. Code-only design means we don't
/// need a backend to "add a friend" — the user shares a 6-char code via
/// iMessage, the recipient types it into Sleepowl, both sides remember each
/// other locally.
///
/// `displayName` is captured at add-time (either typed by the receiver or
/// pulled from a future iMessage-handshake payload). When a real Supabase
/// `friendships` table lands in Phase 5b, the same struct still works: we
/// just enrich it with a server-side `userID` and start pulling snapshot
/// data nightly.
struct FriendCode: Codable, Hashable, Identifiable {
    /// 6-char uppercase alphanumeric code that identifies this friend.
    /// Codes are generated locally and never re-issued for the same user.
    let code: String

    /// Optional friendly name. nil when the receiver added a code without
    /// labeling it — we fall back to "Friend" + a short hash.
    var displayName: String?

    let addedAt: Date

    var id: String { code }

    /// First character used for the small avatar circle. Falls back to the
    /// first code character when no displayName is set.
    var avatarInitial: String {
        if let first = displayName?.trimmingCharacters(in: .whitespaces).first {
            return String(first).uppercased()
        }
        return String(code.prefix(1))
    }

    /// What we render in lists and on the widget.
    var resolvedName: String {
        displayName?.isEmpty == false ? displayName! : "Friend \(code.suffix(3))"
    }
}

/// Generates fresh 6-char codes for new users. Excludes confusable characters
/// (0/O, 1/I) so codes typed back from a screenshot don't get mistaken.
enum FriendCodeGenerator {
    /// 26 letters + 8 numerals, minus 0/O/1/I = 30 chars. With 6 positions:
    /// 30^6 ≈ 729M combinations. More than enough for the foreseeable scale
    /// of a sleep app; collision-handling is not yet required.
    private static let alphabet: [Character] = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    static func generate() -> String {
        String((0..<6).map { _ in alphabet.randomElement()! })
    }

    /// Normalize user input so "abc-123" / "abc 123" / "abc123" all map to
    /// "ABC123". Returns nil when the result isn't exactly 6 valid chars.
    static func sanitize(_ input: String) -> String? {
        let cleaned = input
            .uppercased()
            .filter { alphabet.contains($0) }
        guard cleaned.count == 6 else { return nil }
        return cleaned
    }
}
