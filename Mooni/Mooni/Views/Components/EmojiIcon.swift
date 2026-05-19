import SwiftUI

/// Renders an emoji-shaped slot as an SF Symbol instead of an actual emoji
/// glyph. We hit a rendering bug where SwiftUI Text using the bundled Outfit
/// font would fall through to a missing-glyph "?" box for certain emoji
/// codepoints — particularly compound ZWJ sequences and variation selectors
/// — on some iOS versions. SF Symbols ship with the OS and always render.
///
/// Existing code stores emojis as data (e.g. `[(emoji: "🌙", label: ...)]`).
/// Rather than rip out every model and call site, this view keeps the emoji
/// string as the *identifier* and maps it to a symbol at render time. New
/// code can pass the emoji it would have used and get a consistent icon.
struct EmojiIcon: View {
    let emoji: String
    var size: CGFloat = 22
    var tint: Color? = nil

    var body: some View {
        if Self.isOwl(emoji) {
            // The owl is the brand mascot — never the Apple owl emoji or a
            // generic SF Symbol. Always render the bundled artwork.
            Image("owl_base")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: size * 1.15, height: size * 1.15)
        } else {
            Image(systemName: Self.symbolName(for: emoji))
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(tint ?? MooniColor.textPrimary)
                .symbolRenderingMode(.hierarchical)
                .frame(minWidth: size, minHeight: size)
        }
    }

    /// True for the owl mascot glyph (with or without variation selectors).
    static func isOwl(_ emoji: String) -> Bool {
        emoji.unicodeScalars.contains { $0.value == 0x1F989 }
    }

    /// Maps a known emoji to its closest SF Symbol. Unknown emoji fall through
    /// to a generic sparkle so the layout never collapses or shows a "?" box.
    /// Variation selectors (FE0F / FE0E) and ZWJ are stripped so "🌬️" matches
    /// "🌬" and so on.
    static func symbolName(for emoji: String) -> String {
        let cleaned = emoji.unicodeScalars
            .filter { $0.value != 0xFE0F && $0.value != 0xFE0E && $0.value != 0x200D }
            .reduce(into: "") { $0.unicodeScalars.append($1) }

        switch cleaned {
        // Sleep / night
        case "🦉":  return "moon.stars.fill"
        case "🌙", "🌚", "🌛", "🌜": return "moon.fill"
        case "💭", "☁", "🌤":  return "cloud.fill"
        case "🛌", "🛏":  return "bed.double.fill"
        case "😴", "😪", "💤": return "zzz"

        // Day / sun
        case "☀":  return "sun.max.fill"
        case "🌅":  return "sunrise.fill"
        case "🌄", "🌆":  return "sunset.fill"

        // Faces / mood
        case "🙂", "😊":  return "face.smiling"
        case "😐":  return "minus.circle.fill"
        case "🤔":  return "questionmark.bubble.fill"
        case "🤷":  return "questionmark.circle.fill"
        case "😩", "😫": return "face.dashed.fill"
        case "😤", "😠": return "exclamationmark.triangle.fill"
        case "😬":  return "face.dashed"
        case "😵‍💫", "😵": return "face.dashed"

        // Hands
        case "👍":  return "hand.thumbsup.fill"
        case "👎":  return "hand.thumbsdown.fill"
        case "🤏":  return "hand.point.up.left.fill"
        case "👑":  return "crown.fill"

        // People / body
        case "🧑", "👴", "👵", "👤": return "person.fill"
        case "👯", "👫", "👭", "👬": return "person.2.fill"
        case "🧠":  return "brain.head.profile"
        case "💪":  return "figure.strengthtraining.traditional"
        case "🧘":  return "figure.mind.and.body"
        case "🏃":  return "figure.run"
        case "🗣":  return "person.wave.2.fill"
        case "🩸":  return "drop.fill"

        // Activity / objects
        case "✈":  return "airplane"
        case "🎬":  return "film.fill"
        case "🎮":  return "gamecontroller.fill"
        case "📚", "📓": return "book.fill"
        case "🎸":  return "guitars.fill"
        case "📝":  return "pencil.and.outline"
        case "📋":  return "list.bullet.clipboard.fill"
        case "📅":  return "calendar"
        case "📱":  return "iphone"
        case "📲":  return "iphone.radiowaves.left.and.right"
        case "📊":  return "chart.bar.fill"
        case "📈":  return "chart.line.uptrend.xyaxis"
        case "💸", "💵": return "dollarsign.circle.fill"
        case "💡":  return "lightbulb.fill"
        case "🔋":  return "battery.25"
        case "⚡":  return "bolt.fill"
        case "🎯":  return "target"
        case "🏆":  return "trophy.fill"
        case "🪞":  return "rectangle.portrait.on.rectangle.portrait.fill"
        case "🎧":  return "headphones"
        case "☕", "🍵": return "cup.and.saucer.fill"
        case "🍔":  return "fork.knife"
        case "🚫":  return "nosign"
        case "🔒":  return "lock.fill"
        case "🗑":  return "trash.fill"
        case "💬":  return "message.fill"
        case "🌬":  return "wind"
        case "🔬", "🧬":  return "atom"
        case "🤖":  return "cpu.fill"
        case "🍎":  return "apple.logo"
        case "🏥":  return "cross.case.fill"
        case "🔍":  return "magnifyingglass"
        case "⏱":  return "clock.fill"
        case "⏰":  return "alarm.fill"
        case "⚠":  return "exclamationmark.triangle.fill"
        case "🔥":  return "flame.fill"
        case "📿":  return "circle.hexagonpath.fill"

        // Status dots
        case "🟢":  return "circle.fill"
        case "🔴":  return "circle.fill"

        // Stars / sparkle
        case "🌟", "⭐": return "star.fill"
        case "✨":  return "sparkles"
        case "🎉", "🎊": return "party.popper.fill"

        // Hearts
        case "❤", "💙", "💚", "💛", "💜": return "heart.fill"

        default:
            return "sparkles"
        }
    }
}

extension Text {
    /// Drop-in for headers that used to read `Text("🦉 LABEL")`. Returns an
    /// HStack with the icon followed by the text. Standard view modifiers
    /// (`.font`, `.foregroundColor`, `.tracking`, `.textCase`) chain through.
    static func iconHeader(_ emoji: String, _ label: String,
                           size: CGFloat = 12,
                           tint: Color = MooniColor.accentSoft) -> some View {
        HStack(spacing: 6) {
            EmojiIcon(emoji: emoji, size: size, tint: tint)
            Text(label)
        }
    }
}
