import SwiftUI

/// Animated speech bubble pointing down at the owl. Designed to be overlaid
/// on top of a hero owl view with `.alignmentGuide` or `.overlay(alignment: .top)`.
///
/// Drive it from the parent by passing a non-nil string to `text`. When `text`
/// becomes nil, the bubble fades out and is detached from the layout.
///
/// Pair with `PetReactionPool.random(...)` for one-tap reactions, or pass a
/// longer message string sourced from `PetMessageGenerator`.
struct PetSpeechBubble: View {
    let text: String
    var maxWidth: CGFloat = 240
    /// Side of the bubble where the tail points. Bubble usually sits above the
    /// owl with a downward tail.
    var tailSide: TailSide = .bottom

    enum TailSide { case bottom, top, leading, trailing }

    @State private var appeared = false

    var body: some View {
        Text(text)
            .font(MooniFont.body(14))
            .foregroundColor(MooniColor.textPrimary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: maxWidth)
            .background(
                BubbleShape(tailSide: tailSide)
                    .fill(Color.white.opacity(0.16))
            )
            .background(
                BubbleShape(tailSide: tailSide)
                    .fill(MooniColor.surface.opacity(0.92))
            )
            .overlay(
                BubbleShape(tailSide: tailSide)
                    .stroke(MooniColor.accentSoft.opacity(0.32), lineWidth: 1)
            )
            .compositingGroup()
            .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
            .scaleEffect(appeared ? 1.0 : 0.65, anchor: anchor)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.7)) {
                    appeared = true
                }
            }
            .onDisappear { appeared = false }
    }

    private var anchor: UnitPoint {
        switch tailSide {
        case .bottom: return .bottom
        case .top:    return .top
        case .leading: return .leading
        case .trailing: return .trailing
        }
    }
}

/// Rounded rectangle with a small triangular tail on one side. Single-path so
/// borders render correctly all the way around.
private struct BubbleShape: Shape {
    let tailSide: PetSpeechBubble.TailSide
    let corner: CGFloat = 18
    let tailLength: CGFloat = 10
    let tailWidth: CGFloat = 16

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let bodyRect: CGRect
        switch tailSide {
        case .bottom: bodyRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - tailLength)
        case .top:    bodyRect = CGRect(x: rect.minX, y: rect.minY + tailLength, width: rect.width, height: rect.height - tailLength)
        case .leading: bodyRect = CGRect(x: rect.minX + tailLength, y: rect.minY, width: rect.width - tailLength, height: rect.height)
        case .trailing: bodyRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width - tailLength, height: rect.height)
        }

        // Rounded body
        p.addRoundedRect(in: bodyRect, cornerSize: CGSize(width: corner, height: corner))

        // Tail
        var tail = Path()
        switch tailSide {
        case .bottom:
            let cx = bodyRect.midX
            let yBase = bodyRect.maxY
            tail.move(to: CGPoint(x: cx - tailWidth / 2, y: yBase - 0.5))
            tail.addLine(to: CGPoint(x: cx + tailWidth / 2, y: yBase - 0.5))
            tail.addLine(to: CGPoint(x: cx, y: yBase + tailLength))
            tail.closeSubpath()
        case .top:
            let cx = bodyRect.midX
            let yBase = bodyRect.minY
            tail.move(to: CGPoint(x: cx - tailWidth / 2, y: yBase + 0.5))
            tail.addLine(to: CGPoint(x: cx + tailWidth / 2, y: yBase + 0.5))
            tail.addLine(to: CGPoint(x: cx, y: yBase - tailLength))
            tail.closeSubpath()
        case .leading:
            let cy = bodyRect.midY
            let xBase = bodyRect.minX
            tail.move(to: CGPoint(x: xBase + 0.5, y: cy - tailWidth / 2))
            tail.addLine(to: CGPoint(x: xBase + 0.5, y: cy + tailWidth / 2))
            tail.addLine(to: CGPoint(x: xBase - tailLength, y: cy))
            tail.closeSubpath()
        case .trailing:
            let cy = bodyRect.midY
            let xBase = bodyRect.maxX
            tail.move(to: CGPoint(x: xBase - 0.5, y: cy - tailWidth / 2))
            tail.addLine(to: CGPoint(x: xBase - 0.5, y: cy + tailWidth / 2))
            tail.addLine(to: CGPoint(x: xBase + tailLength, y: cy))
            tail.closeSubpath()
        }
        p.addPath(tail)
        return p
    }
}

// MARK: - Reaction pool for tap-to-react

/// Short, playful one-liners shown briefly when the user taps the owl. Pulled
/// from one of three pools depending on the pet's current mood — sleepy
/// reactions feel different from energized ones, which keeps repeat-tapping
/// from getting boring.
enum PetReactionPool {

    /// Pick a fresh line. `interactionsToday` rotates through the pool so the
    /// same tap-spammer doesn't see "Hi!" six times in a row.
    static func random(for pet: Pet, interactionsToday: Int) -> String {
        let pool = self.pool(for: pet)
        guard !pool.isEmpty else { return "Hi." }
        let idx = abs(interactionsToday + pet.name.hashValue) % pool.count
        return pool[idx]
    }

    /// Special "I missed you" message used on cold-open after >24h absence.
    static func missedYou(for pet: Pet) -> String {
        let pool = [
            "Oh! You're back.",
            "I missed you yesterday.",
            "Where were you? Come closer.",
            "I waited up. Almost."
        ]
        let idx = abs(pet.name.hashValue) % pool.count
        return pool[idx]
    }

    private static func pool(for pet: Pet) -> [String] {
        switch pet.mood.legacyBucket {
        case .rested:
            return [
                "Eee!",
                "I feel so good today.",
                "Look at us — well rested.",
                "Best night ever.",
                "Hoo hoo!",
                "I could fly."
            ]
        case .good:
            return [
                "Hey you.",
                "Steady as ever.",
                "Pleasant night.",
                "Solid sleep.",
                "We did okay."
            ]
        case .tired:
            return [
                "Mmmh... sleepy.",
                "Can we nap?",
                "Let's wind down soon.",
                "Yawn.",
                "Earlier tonight?"
            ]
        default:
            return [
                "Rough one.",
                "Please rest tonight.",
                "I'm wiped.",
                "Be gentle, okay?",
                "Tonight let's catch up."
            ]
        }
    }
}

#Preview {
    ZStack {
        MooniGradient.night.ignoresSafeArea()
        VStack(spacing: 28) {
            PetSpeechBubble(text: "Hey! I feel great today.")
            PetSpeechBubble(text: "Can we wind down a little earlier tonight? My head is heavy.", maxWidth: 280)
            PetSpeechBubble(text: "Hoo!", tailSide: .top)
        }
        .padding(40)
    }
}
