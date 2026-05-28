import SwiftUI

/// Single-species V1 illustration: renders `owl_base` with mood-driven
/// halo, scale, sparkle/Z overlays, and optional hat. Designed so we
/// can ship one asset now and swap in mood-specific art later without
/// touching call sites.
struct PetIllustration: View {
    let pet: Pet
    var size: CGFloat = 200

    /// Closed eyes are a no-op while the art is a single static image —
    /// kept for source compatibility with older callers.
    var forceClosedEyes: Bool = false

    /// When true, the owl gains a tap gesture: bounce, heart emit, haptic,
    /// and a callback. Default false so all existing call sites stay
    /// non-interactive.
    var interactive: Bool = false

    /// Called once per tap when `interactive` is true. Use this to show a
    /// speech bubble, register the interaction, etc. Heart/bounce animation
    /// happens regardless.
    var onTap: (() -> Void)? = nil

    @State private var bob: Bool = false
    @State private var pulse: Bool = false
    @State private var blinkSquish: Bool = false
    @State private var tapBounce: Bool = false
    @State private var hearts: [HeartBurst] = []

    init(
        pet: Pet,
        size: CGFloat = 200,
        forceClosedEyes: Bool = false,
        interactive: Bool = false,
        onTap: (() -> Void)? = nil
    ) {
        self.pet = pet
        self.size = size
        self.forceClosedEyes = forceClosedEyes
        self.interactive = interactive
        self.onTap = onTap
    }

    private var tint: Color {
        if pet.equippedColor == "default_color" {
            return pet.species.tint
        }
        return UnlockableItem.color(for: pet.equippedColor)
    }

    private var glowIntensity: Double {
        switch pet.mood.legacyBucket {
        case .rested: return 1.0
        case .good:   return 0.78
        case .tired:  return 0.5
        case .low:    return 0.3
        default:      return 0.78
        }
    }

    /// Slight visual cue for sleepy/groggy moods so the user can see the
    /// mood shift even though the artwork itself is static.
    private var moodSaturation: Double {
        switch pet.mood {
        case .energized, .excited, .proud, .rested: return 1.10
        case .cozy, .calm, .recovering, .good:      return 1.0
        case .sleepy, .tired:                        return 0.85
        case .groggy, .restless, .low:               return 0.70
        }
    }

    private var owlImageName: String {
        switch pet.mood.legacyBucket {
        case .rested: return "spirit_dream"   // great sleep
        case .good:   return "spirit_awake"   // normal / awake
        case .tired:  return "spirit_sleep"   // sleeping / slight tired
        case .low:    return "spirit_tired"   // lack sleep / very tired
        default:      return "spirit_awake"
        }
    }

    var body: some View {
        ZStack {
            haloLayer

            Image(owlImageName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                // Combined transforms: idle breath (`pulse`) × tap bounce ×
                // blink squish. Multiplicative so each can animate without
                // stomping the others.
                .scaleEffect(
                    x: (pulse ? 1.02 : 0.98) * (tapBounce ? 1.10 : 1.0),
                    y: (pulse ? 1.02 : 0.98) * (tapBounce ? 1.10 : 1.0) * (blinkSquish ? 0.92 : 1.0)
                )
                .offset(y: bob ? -6 : 6)
                .shadow(color: tint.opacity(0.55), radius: 22, y: 6)

            moodAddOns

            // Heart particle layer — visible only after a tap, auto-cleans.
            ForEach(hearts) { burst in
                Image(systemName: "heart.fill")
                    .font(.system(size: burst.size, weight: .bold))
                    .foregroundColor(burst.color)
                    .shadow(color: burst.color.opacity(0.5), radius: 6)
                    .offset(x: burst.xOffset, y: burst.yOffset)
                    .opacity(burst.opacity)
            }
        }
        .frame(width: size * 1.7, height: size * 1.7)
        .contentShape(Rectangle())
        .onTapGesture {
            guard interactive else { return }
            handleTap()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { bob = true }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { pulse = true }
            scheduleNextBlink()
        }
    }

    // MARK: - Interaction
    private func handleTap() {
        Haptics.soft()

        // Bounce (one-shot)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.45)) { tapBounce = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) { tapBounce = false }
        }

        // Emit a small burst of 3 hearts at slightly different offsets.
        for i in 0..<3 {
            let burst = HeartBurst.spawn(index: i, owlSize: size, tint: tint)
            hearts.append(burst)
            withAnimation(.easeOut(duration: 1.1)) {
                if let idx = hearts.firstIndex(where: { $0.id == burst.id }) {
                    hearts[idx].yOffset = burst.endY
                    hearts[idx].xOffset = burst.endX
                    hearts[idx].opacity = 0
                }
            }
            // Schedule removal after the animation completes.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                hearts.removeAll { $0.id == burst.id }
            }
        }

        onTap?()
    }

    // MARK: - Blink scheduling
    /// Fires a quick vertical squish every 4–7 seconds at random. The owl's
    /// art doesn't have an actual closed-eye variant, but the squish + short
    /// shadow contraction reads as a blink from arm's length.
    private func scheduleNextBlink() {
        let delay = Double.random(in: 4.0...7.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeInOut(duration: 0.12)) { blinkSquish = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                withAnimation(.easeInOut(duration: 0.12)) { blinkSquish = false }
                scheduleNextBlink()
            }
        }
    }

    @ViewBuilder
    private var haloLayer: some View {
        Circle()
            .fill(RadialGradient(colors: [tint.opacity(0.55), .clear],
                                 center: .center, startRadius: 0, endRadius: size * 0.8))
            .frame(width: size * 1.7, height: size * 1.7)
            .blur(radius: 28)
            .opacity(glowIntensity)

        Circle()
            .fill(tint.opacity(0.30))
            .frame(width: size * 0.95, height: size * 0.95)
            .blur(radius: 18)
            .opacity(glowIntensity * 0.85)
    }

    @ViewBuilder
    private var moodAddOns: some View {
        switch pet.mood {
        case .energized, .excited, .proud, .rested:
            sparkleField
        case .sleepy, .tired:
            sleepyZs
        case .groggy, .restless, .low:
            droopyAura
        default: EmptyView()
        }
    }

    private var sparkleField: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                Image(systemName: i % 2 == 0 ? "sparkle" : "star.fill")
                    .font(.system(size: 9 + CGFloat(i % 3) * 4))
                    .foregroundColor(.white.opacity(i % 2 == 0 ? 0.95 : 0.65))
                    .offset(
                        x: [-size * 0.55, size * 0.50, -size * 0.45, size * 0.46, -size * 0.20, size * 0.22][i],
                        y: [-size * 0.45, -size * 0.38, size * 0.10, size * 0.24, -size * 0.62, -size * 0.55][i]
                    )
                    .opacity(pulse ? 1 : 0.25)
                    .scaleEffect(pulse ? 1.0 : 0.6)
            }
        }
    }

    private var sleepyZs: some View {
        ZStack {
            Text("z")
                .font(.system(size: size * 0.10, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
                .offset(x: size * 0.42, y: -size * 0.42)
                .scaleEffect(pulse ? 1.1 : 0.9)
            Text("Z")
                .font(.system(size: size * 0.16, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.95))
                .offset(x: size * 0.55, y: -size * 0.55)
                .scaleEffect(pulse ? 0.95 : 1.05)
        }
    }

    private var droopyAura: some View {
        Circle()
            .stroke(Color.white.opacity(0.06), lineWidth: 4)
            .frame(width: size * 1.15, height: size * 1.15)
            .blur(radius: 1)
    }

    // MARK: - Heart burst model
    struct HeartBurst: Identifiable {
        let id = UUID()
        var xOffset: CGFloat
        var yOffset: CGFloat
        let endX: CGFloat
        let endY: CGFloat
        let size: CGFloat
        let color: Color
        var opacity: Double = 1.0

        static func spawn(index: Int, owlSize: CGFloat, tint: Color) -> HeartBurst {
            // Stagger the 3 hearts across the upper hemisphere of the owl.
            let xs: [CGFloat] = [-owlSize * 0.12, owlSize * 0.18, -owlSize * 0.03]
            let ys: [CGFloat] = [-owlSize * 0.05, -owlSize * 0.02, -owlSize * 0.10]
            let xStart = xs[index % xs.count]
            let yStart = ys[index % ys.count]
            return HeartBurst(
                xOffset: xStart,
                yOffset: yStart,
                endX: xStart + CGFloat.random(in: -owlSize * 0.12 ... owlSize * 0.12),
                endY: yStart - owlSize * 0.85,
                size: owlSize * (index == 0 ? 0.16 : 0.12),
                color: index == 1 ? tint : MooniColor.danger
            )
        }
    }

}

#Preview {
    ZStack {
        MooniGradient.night.ignoresSafeArea()
        VStack(spacing: 16) {
            ForEach(Pet.Mood.allCases.prefix(6), id: \.self) { m in
                HStack {
                    PetIllustration(pet: { var p = Pet(); p.mood = m; return p }(), size: 90)
                    Text(m.label).foregroundColor(.white)
                }
            }
        }
    }
}
