import SwiftUI

/// Occasional comet streak across the night sky.
///
/// Used in onboarding to keep the background visually quiet (very few static
/// stars) while still feeling alive. One streak fires every 12–18 seconds at
/// a random angle and screen position; the rest of the time the layer is
/// blank. A single `TimelineView` drives a single `Canvas` — cheap.
struct ShootingStarsOverlay: View {
    /// Mean seconds between streaks. Real interval jitters ±35% per streak.
    var meanInterval: Double = 15

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 45.0)) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                guard let streak = currentStreak(now: t, in: size) else { return }
                draw(streak, in: ctx)
            }
        }
        .allowsHitTesting(false)
    }

    private struct Streak {
        let head: CGPoint
        let tail: CGPoint
        let opacity: Double
    }

    /// Returns the streak to render this frame, or nil if we're in a gap.
    private func currentStreak(now: Double, in size: CGSize) -> Streak? {
        // Quantize "now" into 30s slots so each slot gets one stable streak
        // (or none) — keeps the streak's geometry deterministic frame-to-frame
        // without storing state.
        let slot = Int(now / 30)
        let local = now - Double(slot) * 30           // 0..<30
        var rng = SplitMix(seed: UInt64(bitPattern: Int64(slot &* 0x9E37_79B9)))

        let jitter = (rng.nextDouble() - 0.5) * 0.7    // -0.35..0.35
        let interval = meanInterval * (1 + jitter)
        // Where in this 30s slot the streak fires.
        let startAt = rng.nextDouble() * (30 - interval).clamped(min: 0)
        let duration = 0.85 + rng.nextDouble() * 0.25  // ~0.85–1.10s
        let progress = (local - startAt) / duration
        guard progress >= 0, progress <= 1 else { return nil }

        // Random origin in the upper third, random angle 200°–245° (down-left).
        let origin = CGPoint(
            x: CGFloat(0.55 + rng.nextDouble() * 0.4) * size.width,
            y: CGFloat(rng.nextDouble() * 0.35) * size.height
        )
        let angle = (200.0 + rng.nextDouble() * 45.0) * .pi / 180
        let travel = size.width * CGFloat(0.55 + rng.nextDouble() * 0.25)

        // Head leads the tail along the trajectory.
        let headOffset = travel * CGFloat(progress)
        let tailOffset = max(0, headOffset - travel * 0.22)
        let head = CGPoint(
            x: origin.x + cos(angle) * headOffset,
            y: origin.y + sin(angle) * headOffset
        )
        let tail = CGPoint(
            x: origin.x + cos(angle) * tailOffset,
            y: origin.y + sin(angle) * tailOffset
        )

        // Fade in fast, hold, fade out.
        let opacity: Double = {
            if progress < 0.12 { return progress / 0.12 }
            if progress > 0.78 { return (1.0 - progress) / 0.22 }
            return 1
        }()
        return Streak(head: head, tail: tail, opacity: opacity)
    }

    private func draw(_ s: Streak, in ctx: GraphicsContext) {
        // Tail gradient line.
        var path = Path()
        path.move(to: s.tail)
        path.addLine(to: s.head)
        let gradient = Gradient(stops: [
            .init(color: Color.white.opacity(0), location: 0),
            .init(color: Color.white.opacity(0.85 * s.opacity), location: 1)
        ])
        ctx.stroke(
            path,
            with: .linearGradient(
                gradient,
                startPoint: s.tail,
                endPoint: s.head),
            style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
        )
        // Bright head dot.
        let r: CGFloat = 1.8
        ctx.fill(
            Path(ellipseIn: CGRect(x: s.head.x - r, y: s.head.y - r,
                                   width: r * 2, height: r * 2)),
            with: .color(Color.white.opacity(s.opacity))
        )
    }
}

private struct SplitMix {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0xDEAD_BEEF_F00D : seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func nextDouble() -> Double {
        Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }
}

private extension Double {
    func clamped(min lower: Double) -> Double { Swift.max(self, lower) }
}
