import SwiftUI

/// A calm, premium night sky.
///
/// The old version flipped a single shared `twinkle` flag, so every star
/// brightened and dimmed in perfect unison — that synchronised pulsing is
/// what read as "cheap". Here each star owns its size, brightness, twinkle
/// rate and phase, plus a slow independent drift, so the field shimmers
/// organically and never beats together. A few brighter stars carry a soft
/// bloom for depth. Everything is drawn in a single `Canvas` pass driven by
/// one `TimelineView`, so it's actually *lighter* than the old approach
/// (which spun up one `repeatForever` animation per star).
struct StarsBackground: View {
    let count: Int

    init(count: Int = 60) {
        self.count = count
        self.stars = Self.makeStars(count: count)
    }

    private let stars: [Star]

    private struct Star {
        let x: CGFloat            // unit position 0...1
        let y: CGFloat
        let radius: CGFloat       // points
        let baseOpacity: Double
        let twinkleAmp: Double
        let speed: Double         // twinkle cycles / second
        let phase: Double         // 0...2π
        let drift: CGFloat        // points of slow vertical drift
        let bloom: Bool           // soft glow halo
        let warm: Bool            // faint lavender tint vs pure white
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for s in stars {
                    let twinkle = sin(t * s.speed * 2 * .pi + s.phase)      // -1...1
                    let op = min(1, max(0, s.baseOpacity + twinkle * s.twinkleAmp))
                    guard op > 0.01 else { continue }

                    let dy = CGFloat(sin(t * 0.06 + s.phase)) * s.drift
                    let cx = s.x * size.width
                    let cy = s.y * size.height + dy
                    let tint = s.warm
                        ? Color(red: 0.87, green: 0.85, blue: 1.0)
                        : Color.white

                    if s.bloom {
                        let glowR = s.radius * 5
                        let rect = CGRect(x: cx - glowR, y: cy - glowR,
                                          width: glowR * 2, height: glowR * 2)
                        ctx.fill(
                            Path(ellipseIn: rect),
                            with: .radialGradient(
                                Gradient(colors: [tint.opacity(op * 0.45), .clear]),
                                center: CGPoint(x: cx, y: cy),
                                startRadius: 0, endRadius: glowR))
                    }

                    let dot = CGRect(x: cx - s.radius, y: cy - s.radius,
                                     width: s.radius * 2, height: s.radius * 2)
                    ctx.fill(Path(ellipseIn: dot), with: .color(tint.opacity(op)))
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// Deterministic field — same sky every launch, so it never reshuffles
    /// across redraws or screen transitions.
    private static func makeStars(count: Int) -> [Star] {
        var rng = SplitMix64(seed: 0x5EED_0_C0FFEE)
        return (0..<count).map { _ in
            let big = rng.nextDouble() > 0.88
            return Star(
                x: CGFloat(rng.nextDouble()),
                y: CGFloat(rng.nextDouble()),
                radius: big ? CGFloat(1.6 + rng.nextDouble() * 1.5)
                            : CGFloat(0.5 + rng.nextDouble() * 1.0),
                baseOpacity: 0.20 + rng.nextDouble() * 0.50,
                twinkleAmp: 0.22 + rng.nextDouble() * 0.42,
                speed: 0.06 + rng.nextDouble() * 0.20,
                phase: rng.nextDouble() * .pi * 2,
                drift: CGFloat(5 + rng.nextDouble() * 13),
                bloom: big && rng.nextDouble() > 0.4,
                warm: rng.nextDouble() > 0.62
            )
        }
    }
}

/// Tiny, fast, deterministic PRNG (SplitMix64) — keeps the starfield stable
/// without pulling in any dependency or touching the system RNG.
private struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

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

#Preview {
    ZStack {
        MooniGradient.night.ignoresSafeArea()
        StarsBackground(count: 90)
    }
}
