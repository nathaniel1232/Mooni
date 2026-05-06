import SwiftUI

/// Mood-driven facial expression buckets for the pet illustrations.
fileprivate enum MoodFace { case happy, content, sleepy, down }

/// Vector-drawn pet illustrations. Each species has a distinct silhouette that
/// adapts to mood (eyes open/closed, blush, sleepy "Z"s, energy bursts).
/// Rendered with SwiftUI shapes so we don't need bitmap assets.
struct PetIllustration: View {
    let pet: Pet
    var size: CGFloat = 200

    /// When true, eyes are closed regardless of mood (used for the bedtime states).
    var forceClosedEyes: Bool = false

    @State private var bob: Bool = false
    @State private var pulse: Bool = false
    @State private var blink: Bool = false

    private var bodyColor: Color {
        if pet.equippedColor == "default_color" {
            return pet.species.tint
        }
        return UnlockableItem.color(for: pet.equippedColor)
    }

    private var eyesClosed: Bool {
        forceClosedEyes || pet.mood.legacyBucket == .low || pet.mood == .sleepy || pet.mood == .restless
    }

    fileprivate var moodFace: MoodFace {
        switch pet.mood {
        case .energized, .excited, .proud, .rested: return .happy
        case .cozy, .calm, .recovering, .good:      return .content
        case .sleepy, .tired:                        return .sleepy
        case .groggy, .restless, .low:               return .down
        }
    }

    var body: some View {
        ZStack {
            // Glow halos
            haloLayer

            // The pet itself, by species
            Group {
                switch pet.species {
                case .fox:   FoxArt(bodyColor: bodyColor, accentColor: foxAccent, eyesClosed: eyesClosed, mood: moodFace, blink: blink)
                case .panda: PandaArt(bodyColor: pandaBodyColor, eyesClosed: eyesClosed, mood: moodFace, blink: blink)
                case .owl:   OwlArt(bodyColor: bodyColor, accentColor: owlAccent, eyesClosed: eyesClosed, mood: moodFace, blink: blink)
                }
            }
            .frame(width: size, height: size)
            .scaleEffect(pulse ? 1.02 : 0.98)
            .offset(y: bob ? -6 : 6)
            .shadow(color: bodyColor.opacity(0.55), radius: 22, y: 6)

            // Hat overlay
            if let hat = pet.equippedHat {
                hatOverlay(hat)
            }

            // Mood add-ons
            moodAddOns
        }
        .frame(width: size * 1.7, height: size * 1.7)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { bob = true }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { pulse = true }
            // Blink loop
            startBlinking()
        }
    }

    private var foxAccent: Color   { Color(red: 1.00, green: 0.92, blue: 0.82) }
    private var owlAccent: Color   { Color(red: 0.62, green: 0.55, blue: 0.95) }
    private var pandaBodyColor: Color {
        // Panda is always the cool white-blue cream regardless of equipped color
        if pet.equippedColor == "default_color" { return Color(red: 0.96, green: 0.97, blue: 1.00) }
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

    @ViewBuilder
    private var haloLayer: some View {
        Circle()
            .fill(RadialGradient(colors: [bodyColor.opacity(0.55), .clear],
                                 center: .center, startRadius: 0, endRadius: size * 0.8))
            .frame(width: size * 1.7, height: size * 1.7)
            .blur(radius: 28)
            .opacity(glowIntensity)

        Circle()
            .fill(bodyColor.opacity(0.30))
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

    private func startBlinking() {
        Task { @MainActor in
            while true {
                try? await Task.sleep(nanoseconds: UInt64.random(in: 2_500_000_000...5_000_000_000))
                withAnimation(.easeOut(duration: 0.08)) { blink = true }
                try? await Task.sleep(nanoseconds: 130_000_000)
                withAnimation(.easeIn(duration: 0.10)) { blink = false }
            }
        }
    }
}

// MARK: - Fox

private struct FoxArt: View {
    let bodyColor: Color
    let accentColor: Color
    let eyesClosed: Bool
    let mood: MoodFace
    let blink: Bool

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                // Body — round chest
                Ellipse()
                    .fill(LinearGradient(colors: [bodyColor, bodyColor.opacity(0.78)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: s * 0.78, height: s * 0.66)
                    .offset(y: s * 0.10)
                // Belly
                Ellipse()
                    .fill(accentColor)
                    .frame(width: s * 0.46, height: s * 0.34)
                    .offset(y: s * 0.18)
                // Tail
                FoxTail()
                    .fill(LinearGradient(colors: [bodyColor, accentColor],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: s * 0.42, height: s * 0.36)
                    .offset(x: -s * 0.32, y: -s * 0.05)

                // Head
                Ellipse()
                    .fill(LinearGradient(colors: [bodyColor.opacity(0.95), bodyColor],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: s * 0.74, height: s * 0.66)
                    .offset(y: -s * 0.18)

                // Cheeks
                Ellipse()
                    .fill(accentColor)
                    .frame(width: s * 0.42, height: s * 0.30)
                    .offset(y: -s * 0.08)

                // Ears
                EarTriangle()
                    .fill(bodyColor)
                    .frame(width: s * 0.20, height: s * 0.24)
                    .offset(x: -s * 0.24, y: -s * 0.42)
                EarTriangle()
                    .fill(bodyColor)
                    .frame(width: s * 0.20, height: s * 0.24)
                    .offset(x: s * 0.24, y: -s * 0.42)
                // Inner ears
                EarTriangle()
                    .fill(accentColor.opacity(0.8))
                    .frame(width: s * 0.10, height: s * 0.13)
                    .offset(x: -s * 0.24, y: -s * 0.40)
                EarTriangle()
                    .fill(accentColor.opacity(0.8))
                    .frame(width: s * 0.10, height: s * 0.13)
                    .offset(x: s * 0.24, y: -s * 0.40)

                // Face
                petFace(s: s, eyesClosed: eyesClosed, mood: mood, blink: blink, accent: bodyColor.darker(by: 0.35))

                // Nose
                Ellipse()
                    .fill(Color.black.opacity(0.7))
                    .frame(width: s * 0.06, height: s * 0.045)
                    .offset(y: -s * 0.06)

                // Blush for happy/content moods
                if mood == .happy || mood == .content {
                    Ellipse()
                        .fill(Color.pink.opacity(0.35))
                        .frame(width: s * 0.10, height: s * 0.06)
                        .offset(x: -s * 0.20, y: -s * 0.04)
                    Ellipse()
                        .fill(Color.pink.opacity(0.35))
                        .frame(width: s * 0.10, height: s * 0.06)
                        .offset(x: s * 0.20, y: -s * 0.04)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

// MARK: - Panda

private struct PandaArt: View {
    let bodyColor: Color
    let eyesClosed: Bool
    let mood: MoodFace
    let blink: Bool

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let dark = Color(red: 0.10, green: 0.10, blue: 0.18)
            ZStack {
                // Body
                Ellipse()
                    .fill(LinearGradient(colors: [bodyColor, bodyColor.opacity(0.86)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: s * 0.80, height: s * 0.68)
                    .offset(y: s * 0.10)

                // Arms (dark)
                Ellipse()
                    .fill(dark)
                    .frame(width: s * 0.18, height: s * 0.28)
                    .offset(x: -s * 0.34, y: s * 0.18)
                Ellipse()
                    .fill(dark)
                    .frame(width: s * 0.18, height: s * 0.28)
                    .offset(x: s * 0.34, y: s * 0.18)

                // Head
                Circle()
                    .fill(LinearGradient(colors: [bodyColor, bodyColor.opacity(0.93)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: s * 0.72, height: s * 0.72)
                    .offset(y: -s * 0.16)

                // Ears
                Circle()
                    .fill(dark)
                    .frame(width: s * 0.22, height: s * 0.22)
                    .offset(x: -s * 0.28, y: -s * 0.45)
                Circle()
                    .fill(dark)
                    .frame(width: s * 0.22, height: s * 0.22)
                    .offset(x: s * 0.28, y: -s * 0.45)

                // Eye patches
                Ellipse()
                    .fill(dark)
                    .frame(width: s * 0.20, height: s * 0.26)
                    .rotationEffect(.degrees(-12))
                    .offset(x: -s * 0.16, y: -s * 0.16)
                Ellipse()
                    .fill(dark)
                    .frame(width: s * 0.20, height: s * 0.26)
                    .rotationEffect(.degrees(12))
                    .offset(x: s * 0.16, y: -s * 0.16)

                // Eyes (white shine inside dark patch)
                Group {
                    if eyesClosed || blink {
                        Capsule()
                            .fill(Color.white)
                            .frame(width: s * 0.06, height: s * 0.012)
                            .offset(x: -s * 0.16, y: -s * 0.16)
                        Capsule()
                            .fill(Color.white)
                            .frame(width: s * 0.06, height: s * 0.012)
                            .offset(x: s * 0.16, y: -s * 0.16)
                    } else {
                        Circle()
                            .fill(Color.white)
                            .frame(width: s * 0.05, height: s * 0.05)
                            .offset(x: -s * 0.15, y: -s * 0.18)
                        Circle()
                            .fill(Color.white)
                            .frame(width: s * 0.05, height: s * 0.05)
                            .offset(x: s * 0.17, y: -s * 0.18)
                    }
                }

                // Nose
                Ellipse()
                    .fill(dark)
                    .frame(width: s * 0.07, height: s * 0.05)
                    .offset(y: -s * 0.05)

                // Mouth
                MouthShape(mood: mood)
                    .stroke(dark.opacity(0.85), lineWidth: max(2, s * 0.012))
                    .frame(width: s * 0.18, height: s * 0.09)
                    .offset(y: s * 0.01)

                // Blush
                if mood == .happy || mood == .content {
                    Ellipse()
                        .fill(Color.pink.opacity(0.40))
                        .frame(width: s * 0.10, height: s * 0.06)
                        .offset(x: -s * 0.26, y: -s * 0.03)
                    Ellipse()
                        .fill(Color.pink.opacity(0.40))
                        .frame(width: s * 0.10, height: s * 0.06)
                        .offset(x: s * 0.26, y: -s * 0.03)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

// MARK: - Owl

private struct OwlArt: View {
    let bodyColor: Color
    let accentColor: Color
    let eyesClosed: Bool
    let mood: MoodFace
    let blink: Bool

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                // Body
                RoundedRectangle(cornerRadius: s * 0.28)
                    .fill(LinearGradient(colors: [bodyColor, bodyColor.opacity(0.82)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: s * 0.74, height: s * 0.78)
                    .offset(y: s * 0.04)

                // Belly feathers
                Ellipse()
                    .fill(Color.white.opacity(0.70))
                    .frame(width: s * 0.46, height: s * 0.50)
                    .offset(y: s * 0.08)

                // Wings
                WingShape()
                    .fill(accentColor.opacity(0.85))
                    .frame(width: s * 0.20, height: s * 0.40)
                    .offset(x: -s * 0.32, y: s * 0.08)
                WingShape()
                    .fill(accentColor.opacity(0.85))
                    .frame(width: s * 0.20, height: s * 0.40)
                    .scaleEffect(x: -1)
                    .offset(x: s * 0.32, y: s * 0.08)

                // Head merges with body — ear tufts
                EarTriangle()
                    .fill(bodyColor.darker(by: 0.20))
                    .frame(width: s * 0.16, height: s * 0.22)
                    .offset(x: -s * 0.24, y: -s * 0.34)
                EarTriangle()
                    .fill(bodyColor.darker(by: 0.20))
                    .frame(width: s * 0.16, height: s * 0.22)
                    .offset(x: s * 0.24, y: -s * 0.34)

                // Big eye sockets
                Circle()
                    .fill(Color.white)
                    .frame(width: s * 0.30, height: s * 0.30)
                    .offset(x: -s * 0.16, y: -s * 0.18)
                Circle()
                    .fill(Color.white)
                    .frame(width: s * 0.30, height: s * 0.30)
                    .offset(x: s * 0.16, y: -s * 0.18)

                // Pupils / closed eyes
                Group {
                    if eyesClosed || blink {
                        Capsule()
                            .fill(Color.black.opacity(0.85))
                            .frame(width: s * 0.16, height: s * 0.022)
                            .offset(x: -s * 0.16, y: -s * 0.18)
                        Capsule()
                            .fill(Color.black.opacity(0.85))
                            .frame(width: s * 0.16, height: s * 0.022)
                            .offset(x: s * 0.16, y: -s * 0.18)
                    } else {
                        Circle()
                            .fill(Color.black)
                            .frame(width: s * 0.13, height: s * 0.13)
                            .offset(x: -s * 0.16, y: -s * 0.18)
                        Circle()
                            .fill(Color.white)
                            .frame(width: s * 0.04, height: s * 0.04)
                            .offset(x: -s * 0.13, y: -s * 0.20)
                        Circle()
                            .fill(Color.black)
                            .frame(width: s * 0.13, height: s * 0.13)
                            .offset(x: s * 0.16, y: -s * 0.18)
                        Circle()
                            .fill(Color.white)
                            .frame(width: s * 0.04, height: s * 0.04)
                            .offset(x: s * 0.19, y: -s * 0.20)
                    }
                }

                // Beak
                BeakShape()
                    .fill(Color(red: 1.0, green: 0.78, blue: 0.50))
                    .frame(width: s * 0.10, height: s * 0.10)
                    .offset(y: -s * 0.05)

                // Cute moon mark on belly
                Image(systemName: "moon.fill")
                    .font(.system(size: s * 0.10))
                    .foregroundColor(accentColor.opacity(0.55))
                    .offset(y: s * 0.16)

                // Blush
                if mood == .happy || mood == .content {
                    Ellipse()
                        .fill(Color.pink.opacity(0.45))
                        .frame(width: s * 0.08, height: s * 0.05)
                        .offset(x: -s * 0.30, y: -s * 0.10)
                    Ellipse()
                        .fill(Color.pink.opacity(0.45))
                        .frame(width: s * 0.08, height: s * 0.05)
                        .offset(x: s * 0.30, y: -s * 0.10)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

// MARK: - Shared face renderer

private extension View {
    @ViewBuilder
    func petFace(
        s: CGFloat, eyesClosed: Bool, mood: MoodFace, blink: Bool, accent: Color
    ) -> some View {
        ZStack {
            // Eyes
            if eyesClosed || blink {
                Capsule()
                    .fill(accent)
                    .frame(width: s * 0.10, height: s * 0.018)
                    .offset(x: -s * 0.15, y: -s * 0.18)
                Capsule()
                    .fill(accent)
                    .frame(width: s * 0.10, height: s * 0.018)
                    .offset(x: s * 0.15, y: -s * 0.18)
            } else {
                Circle()
                    .fill(accent)
                    .frame(width: s * 0.07, height: s * 0.07)
                    .offset(x: -s * 0.15, y: -s * 0.18)
                Circle()
                    .fill(.white)
                    .frame(width: s * 0.022, height: s * 0.022)
                    .offset(x: -s * 0.135, y: -s * 0.20)
                Circle()
                    .fill(accent)
                    .frame(width: s * 0.07, height: s * 0.07)
                    .offset(x: s * 0.15, y: -s * 0.18)
                Circle()
                    .fill(.white)
                    .frame(width: s * 0.022, height: s * 0.022)
                    .offset(x: s * 0.165, y: -s * 0.20)
            }

            // Mouth
            MouthShape(mood: mood)
                .stroke(accent.opacity(0.8), lineWidth: max(1.6, s * 0.010))
                .frame(width: s * 0.16, height: s * 0.08)
                .offset(y: -s * 0.005)
        }
    }
}

// MARK: - Shapes

private struct FoxTail: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addQuadCurve(to: CGPoint(x: rect.minX + rect.width * 0.20, y: rect.minY + rect.height * 0.10),
                       control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.20))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.midY),
                       control: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.minX + rect.width * 0.30, y: rect.maxY),
                       control: CGPoint(x: rect.minX + rect.width * 0.10, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY),
                       control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.10))
        return p
    }
}

private struct EarTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY),
                       control: CGPoint(x: rect.maxX + 4, y: rect.midY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY),
                       control: CGPoint(x: rect.midX, y: rect.maxY + 4))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY),
                       control: CGPoint(x: rect.minX - 4, y: rect.midY))
        return p
    }
}

private struct WingShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.midY),
                       control: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY),
                       control: CGPoint(x: rect.minX + rect.width * 0.5, y: rect.maxY + 6))
        p.closeSubpath()
        return p
    }
}

private struct BeakShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.18, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

private struct MouthShape: Shape {
    let mood: MoodFace
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let mid = CGPoint(x: rect.midX, y: rect.midY)
        switch mood {
        case .happy:
            p.move(to: CGPoint(x: rect.minX, y: rect.midY - 1))
            p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY - 1),
                           control: CGPoint(x: mid.x, y: rect.maxY + 4))
        case .content:
            p.move(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY),
                           control: CGPoint(x: mid.x, y: rect.midY + rect.height * 0.5))
        case .sleepy:
            p.move(to: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.2, y: rect.midY))
        case .down:
            p.move(to: CGPoint(x: rect.minX, y: rect.midY + 2))
            p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY + 2),
                           control: CGPoint(x: mid.x, y: rect.minY - 2))
        }
        return p
    }
}

// MARK: - Hat overlays

private struct NightcapShape: View {
    var body: some View {
        ZStack {
            // Cap body
            HatBody()
                .fill(LinearGradient(
                    colors: [Color(red: 0.55, green: 0.50, blue: 0.95),
                             Color(red: 0.78, green: 0.74, blue: 1.0)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 92, height: 60)
            // Pom-pom
            Circle()
                .fill(Color.white.opacity(0.95))
                .frame(width: 18, height: 18)
                .offset(x: 28, y: -22)
            // Stars on cap
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

// MARK: - Color helpers

private extension Color {
    func darker(by amount: Double) -> Color {
        let uiColor = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        b = max(0, b - CGFloat(amount))
        return Color(UIColor(hue: h, saturation: s, brightness: b, alpha: a))
    }
}

#Preview {
    ZStack {
        MooniGradient.night.ignoresSafeArea()
        ScrollView {
            VStack(spacing: 12) {
                ForEach(PetSpecies.allCases) { sp in
                    HStack(spacing: 10) {
                        ForEach(Pet.Mood.allCases.prefix(4), id: \.self) { mood in
                            VStack {
                                PetIllustration(pet: { var p = Pet(); p.species = sp; p.mood = mood; p.equippedHat = nil; return p }(), size: 90)
                                Text("\(sp.displayName)\n\(mood.label)")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                }
            }
        }
    }
}
