import SwiftUI

struct DreamSpiritView: View {
    let pet: Pet
    var size: CGFloat = 200

    @State private var floating = false
    @State private var blinkClosed = false
    @State private var sparkle = false

    private var bodyColor: Color { UnlockableItem.color(for: pet.equippedColor) }

    private var hatTilt: Double {
        pet.mood == .tired || pet.mood == .low ? -22 : -12
    }

    private var eyeArcHeight: CGFloat {
        switch pet.mood {
        case .rested: return 1.0
        case .good:   return 0.72
        case .tired:  return 0.38
        case .low:    return 0.18
        }
    }

    private var smileCurve: CGFloat {
        switch pet.mood {
        case .rested: return 1.0
        case .good:   return 0.70
        case .tired:  return 0.25
        case .low:    return 0.0
        }
    }

    private var glowIntensity: Double {
        switch pet.mood {
        case .rested: return 1.0
        case .good:   return 0.75
        case .tired:  return 0.50
        case .low:    return 0.30
        }
    }

    var body: some View {
        ZStack {
            // Outer halo — very large, blurred
            Circle()
                .fill(
                    RadialGradient(
                        colors: [bodyColor.opacity(0.60), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.82
                    )
                )
                .frame(width: size * 1.65, height: size * 1.65)
                .blur(radius: 32)
                .opacity(glowIntensity)

            // Mid glow ring
            Circle()
                .fill(bodyColor.opacity(0.40))
                .frame(width: size * 0.88, height: size * 0.88)
                .blur(radius: 18)
                .opacity(glowIntensity * 0.85)

            // Inner white bloom
            Circle()
                .fill(Color.white.opacity(0.28))
                .frame(width: size * 0.52, height: size * 0.52)
                .blur(radius: 10)

            if pet.mood == .rested {
                sparkles
            }

            if pet.mood == .low || pet.mood == .tired {
                blanket
            }

            spiritBody

            if let hatId = pet.equippedHat {
                hatView(for: hatId)
                    .rotationEffect(.degrees(hatTilt), anchor: .bottom)
                    .offset(y: -size * 0.50)
            }
        }
        .frame(width: size * 1.7, height: size * 1.7)
        .offset(y: floating ? -6 : 6)
        .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true), value: floating)
        .onAppear {
            floating = true
            sparkle = true
            startBlinking()
        }
    }

    // MARK: - Spirit Body

    private var spiritBody: some View {
        ZStack {
            // Ghost silhouette — primary fill
            GhostBodyShape()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.96, green: 0.94, blue: 1.0),
                            bodyColor
                        ],
                        center: UnitPoint(x: 0.40, y: 0.24),
                        startRadius: 2,
                        endRadius: size * 0.58
                    )
                )
                .frame(width: size * 0.80, height: size * 1.0)
                .shadow(color: bodyColor.opacity(0.65), radius: 22, y: 4)

            // Glossy highlight (upper-left sheen)
            GhostBodyShape()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.55), Color.clear],
                        center: UnitPoint(x: 0.32, y: 0.16),
                        startRadius: 0,
                        endRadius: size * 0.30
                    )
                )
                .frame(width: size * 0.80, height: size * 1.0)

            // Cheeks
            HStack(spacing: size * 0.30) {
                cheek
                cheek
            }
            .offset(y: -size * 0.12)

            // Eyes
            HStack(spacing: size * 0.19) {
                eyeArc
                eyeArc
            }
            .offset(y: -size * 0.23)
            .scaleEffect(y: blinkClosed ? 0.05 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: blinkClosed)

            // Mouth
            mouth
                .offset(y: -size * 0.06)
        }
    }

    // MARK: - Face elements

    private var cheek: some View {
        Ellipse()
            .fill(Color(red: 1.0, green: 0.60, blue: 0.72).opacity(0.58))
            .frame(width: size * 0.11, height: size * 0.08)
            .blur(radius: 3)
    }

    private var eyeArc: some View {
        ArcEyeShape(height: eyeArcHeight)
            .stroke(
                MooniColor.background,
                style: StrokeStyle(lineWidth: 2.8, lineCap: .round)
            )
            .frame(width: size * 0.088, height: size * 0.054)
    }

    private var mouth: some View {
        MouthShape(curve: smileCurve)
            .stroke(
                MooniColor.background.opacity(0.85),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
            )
            .frame(width: size * 0.13, height: size * 0.055)
    }

    // MARK: - Sparkles

    private var sparkles: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                Image(systemName: i % 2 == 0 ? "sparkle" : "star.fill")
                    .font(.system(size: 9 + CGFloat(i % 3) * 5))
                    .foregroundColor(.white.opacity(i % 2 == 0 ? 0.90 : 0.60))
                    .offset(
                        x: [-size * 0.54, size * 0.50, -size * 0.42, size * 0.44, -size * 0.18, size * 0.20][i],
                        y: [-size * 0.44, -size * 0.36, size * 0.08, size * 0.22, -size * 0.60, -size * 0.54][i]
                    )
                    .opacity(sparkle ? 1 : 0.2)
                    .scaleEffect(sparkle ? 1.0 : 0.6)
                    .animation(
                        .easeInOut(duration: 1.3 + Double(i) * 0.28)
                            .repeatForever(autoreverses: true),
                        value: sparkle
                    )
            }
        }
    }

    // MARK: - Blanket

    private var blanket: some View {
        BlanketShape()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.28, green: 0.32, blue: 0.60),
                        Color(red: 0.18, green: 0.20, blue: 0.44)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: size * 0.90, height: size * 0.50)
            .offset(y: size * 0.28)
            .overlay(
                Text("z z z")
                    .font(MooniFont.caption(12))
                    .foregroundColor(.white.opacity(0.65))
                    .offset(x: size * 0.30, y: -size * 0.18)
            )
    }

    // MARK: - Hat

    @ViewBuilder
    private func hatView(for id: String) -> some View {
        switch id {
        case "hat_nightcap":
            ZStack {
                NightcapShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.28, green: 0.22, blue: 0.56),
                                Color(red: 0.15, green: 0.11, blue: 0.38)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size * 0.44, height: size * 0.40)
                // Stars on cap
                Image(systemName: "sparkle")
                    .font(.system(size: size * 0.07))
                    .foregroundColor(.white.opacity(0.80))
                    .offset(x: size * 0.03, y: size * 0.02)
                Image(systemName: "sparkle")
                    .font(.system(size: size * 0.045))
                    .foregroundColor(.white.opacity(0.55))
                    .offset(x: size * 0.12, y: size * 0.09)
                // Pom-pom at tip
                Circle()
                    .fill(Color.white)
                    .frame(width: size * 0.10, height: size * 0.10)
                    .shadow(color: .white.opacity(0.8), radius: 6)
                    .offset(x: size * 0.16, y: -size * 0.12)
            }
        case "hat_crown":
            CrownShape()
                .fill(LinearGradient(colors: [Color.yellow, Color(red: 1.0, green: 0.65, blue: 0.0)], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.46, height: size * 0.24)
        case "hat_beanie":
            BeanieShape()
                .fill(Color(red: 0.85, green: 0.50, blue: 0.58))
                .frame(width: size * 0.46, height: size * 0.28)
        case "hat_halo":
            Ellipse()
                .stroke(Color.yellow.opacity(0.90), lineWidth: 3.5)
                .frame(width: size * 0.48, height: size * 0.12)
                .shadow(color: Color.yellow.opacity(0.7), radius: 8)
        case "hat_bow":
            BowShape()
                .fill(Color(red: 1.0, green: 0.72, blue: 0.86))
                .frame(width: size * 0.38, height: size * 0.17)
        default:
            EmptyView()
        }
    }

    private func startBlinking() {
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64.random(in: 2_800_000_000...5_200_000_000))
                blinkClosed = true
                try? await Task.sleep(nanoseconds: 130_000_000)
                blinkClosed = false
            }
        }
    }
}

// MARK: - Ghost Shapes

private struct GhostBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height

        // Ghost silhouette:
        //   Large round dome on top (bezier control points above frame)
        //   Arm nubs on each side (control points extending beyond frame width)
        //   Three downward bumps at base

        p.move(to: CGPoint(x: 0, y: h * 0.44))

        // ── Top dome ──────────────────────────────────────────────────────────
        // Cubic bezier from left shoulder to right shoulder, arching high above frame
        p.addCurve(
            to: CGPoint(x: w, y: h * 0.44),
            control1: CGPoint(x: 0, y: -h * 0.48),
            control2: CGPoint(x: w, y: -h * 0.48)
        )

        // ── Right arm nub ─────────────────────────────────────────────────────
        p.addCurve(
            to: CGPoint(x: w, y: h * 0.60),
            control1: CGPoint(x: w * 1.16, y: h * 0.45),
            control2: CGPoint(x: w * 1.16, y: h * 0.59)
        )

        // Right side down to bump line
        p.addLine(to: CGPoint(x: w, y: h * 0.72))

        // ── Three downward bumps (right → left) ───────────────────────────────
        p.addQuadCurve(
            to: CGPoint(x: w * 0.67, y: h * 0.72),
            control: CGPoint(x: w * 0.835, y: h * 0.97)
        )
        p.addQuadCurve(
            to: CGPoint(x: w * 0.33, y: h * 0.72),
            control: CGPoint(x: w * 0.500, y: h * 0.97)
        )
        p.addQuadCurve(
            to: CGPoint(x: 0, y: h * 0.72),
            control: CGPoint(x: w * 0.165, y: h * 0.97)
        )

        // Left side up from bump line
        p.addLine(to: CGPoint(x: 0, y: h * 0.60))

        // ── Left arm nub ──────────────────────────────────────────────────────
        p.addCurve(
            to: CGPoint(x: 0, y: h * 0.44),
            control1: CGPoint(x: -w * 0.16, y: h * 0.59),
            control2: CGPoint(x: -w * 0.16, y: h * 0.45)
        )

        p.closeSubpath()
        return p
    }
}

// Arc eye — an upward arch (∩ shape) giving the classic kawaii closed-eye look
private struct ArcEyeShape: Shape {
    var height: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let peak = rect.height * height
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.maxY - peak)
        )
        return p
    }
}

private struct MouthShape: Shape {
    var curve: CGFloat
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let depth = rect.height * curve
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control: CGPoint(x: rect.midX, y: rect.midY + depth)
        )
        return path
    }
}

private struct BlanketShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.25))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.25),
            control: CGPoint(x: rect.midX, y: rect.minY)
        )
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct NightcapShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX * 0.82, y: rect.minY + rect.height * 0.18),
            control: CGPoint(x: rect.midX * 0.55, y: rect.minY)
        )
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct CrownShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: 0, y: h))
        p.addLine(to: CGPoint(x: 0, y: h * 0.42))
        p.addLine(to: CGPoint(x: w * 0.20, y: 0))
        p.addLine(to: CGPoint(x: w * 0.35, y: h * 0.50))
        p.addLine(to: CGPoint(x: w * 0.50, y: 0))
        p.addLine(to: CGPoint(x: w * 0.65, y: h * 0.50))
        p.addLine(to: CGPoint(x: w * 0.80, y: 0))
        p.addLine(to: CGPoint(x: w, y: h * 0.42))
        p.addLine(to: CGPoint(x: w, y: h))
        p.closeSubpath()
        return p
    }
}

private struct BeanieShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(
            center: CGPoint(x: rect.midX, y: rect.maxY),
            radius: rect.width / 2,
            startAngle: .degrees(180),
            endAngle: .degrees(360),
            clockwise: false
        )
        p.addRect(CGRect(x: 0, y: rect.maxY - rect.height * 0.22, width: rect.width, height: rect.height * 0.22))
        return p
    }
}

private struct BowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.midY))
        p.addLine(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: 0, y: rect.maxY))
        p.closeSubpath()
        p.move(to: CGPoint(x: rect.midX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: 0))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

#Preview {
    ZStack {
        MooniGradient.night.ignoresSafeArea()
        VStack(spacing: 20) {
            HStack(spacing: 10) {
                DreamSpiritView(pet: { var p = Pet(); p.mood = .rested; p.equippedHat = "hat_nightcap"; return p }(), size: 130)
                DreamSpiritView(pet: { var p = Pet(); p.mood = .good; p.equippedHat = "hat_crown"; return p }(), size: 130)
            }
            HStack(spacing: 10) {
                DreamSpiritView(pet: { var p = Pet(); p.mood = .tired; return p }(), size: 130)
                DreamSpiritView(pet: { var p = Pet(); p.mood = .low; return p }(), size: 130)
            }
        }
    }
}
