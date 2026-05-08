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

    @State private var bob: Bool = false
    @State private var pulse: Bool = false

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

    var body: some View {
        ZStack {
            haloLayer

            Image("owl_base")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .saturation(moodSaturation)
                .scaleEffect(pulse ? 1.02 : 0.98)
                .offset(y: bob ? -6 : 6)
                .shadow(color: tint.opacity(0.55), radius: 22, y: 6)

            if let hat = pet.equippedHat {
                hatOverlay(hat)
            }

            moodAddOns
        }
        .frame(width: size * 1.7, height: size * 1.7)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { bob = true }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { pulse = true }
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

    @ViewBuilder
    private func hatOverlay(_ hat: String) -> some View {
        switch hat {
        case "hat_nightcap": NightcapShape().offset(y: -size * 0.42)
        case "hat_crown":    CrownShape().offset(y: -size * 0.42)
        case "hat_beanie":   BeanieShape().offset(y: -size * 0.42)
        case "hat_halo":     HaloShape().offset(y: -size * 0.42)
        case "hat_bow":      BowShape().offset(x: size * 0.20, y: -size * 0.32)
        default: EmptyView()
        }
    }
}

// MARK: - Hat overlays

private struct NightcapShape: View {
    var body: some View {
        ZStack {
            HatBody()
                .fill(LinearGradient(
                    colors: [Color(red: 0.55, green: 0.50, blue: 0.95),
                             Color(red: 0.78, green: 0.74, blue: 1.0)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 92, height: 60)
            Circle()
                .fill(Color.white.opacity(0.95))
                .frame(width: 18, height: 18)
                .offset(x: 28, y: -22)
            Image(systemName: "star.fill")
                .foregroundColor(.white.opacity(0.9))
                .font(.system(size: 9))
                .offset(x: -12, y: 6)
            Image(systemName: "moon.fill")
                .foregroundColor(.white.opacity(0.9))
                .font(.system(size: 9))
                .offset(x: 8, y: -2)
        }
    }
}

private struct CrownShape: View {
    var body: some View {
        Image(systemName: "crown.fill")
            .font(.system(size: 56))
            .foregroundStyle(LinearGradient(
                colors: [Color.yellow, Color.orange],
                startPoint: .top, endPoint: .bottom))
            .shadow(color: Color.yellow.opacity(0.6), radius: 6)
    }
}

private struct BeanieShape: View {
    var body: some View {
        ZStack {
            HatBody()
                .fill(LinearGradient(
                    colors: [Color(red: 0.45, green: 0.65, blue: 0.95),
                             Color(red: 0.65, green: 0.85, blue: 1.0)],
                    startPoint: .top, endPoint: .bottom))
                .frame(width: 84, height: 50)
            Image(systemName: "snowflake")
                .foregroundColor(.white.opacity(0.9))
                .font(.system(size: 14))
                .offset(y: 6)
        }
    }
}

private struct HaloShape: View {
    var body: some View {
        Ellipse()
            .stroke(LinearGradient(
                colors: [Color.yellow.opacity(0.9), Color.orange.opacity(0.85)],
                startPoint: .leading, endPoint: .trailing), lineWidth: 5)
            .frame(width: 90, height: 18)
            .shadow(color: Color.yellow.opacity(0.6), radius: 8)
    }
}

private struct BowShape: View {
    var body: some View {
        ZStack {
            Capsule()
                .fill(Color(red: 1.0, green: 0.55, blue: 0.75))
                .frame(width: 22, height: 14)
                .rotationEffect(.degrees(-15))
                .offset(x: -8)
            Capsule()
                .fill(Color(red: 1.0, green: 0.55, blue: 0.75))
                .frame(width: 22, height: 14)
                .rotationEffect(.degrees(15))
                .offset(x: 8)
            Circle()
                .fill(Color(red: 1.0, green: 0.45, blue: 0.65))
                .frame(width: 8, height: 8)
        }
    }
}

private struct HatBody: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY - 6))
        p.addLine(to: CGPoint(x: rect.midX + rect.width * 0.05, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY - 4),
                       control: CGPoint(x: rect.maxX, y: rect.midY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - 6),
                       control: CGPoint(x: rect.midX, y: rect.maxY + 6))
        p.closeSubpath()
        return p
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
