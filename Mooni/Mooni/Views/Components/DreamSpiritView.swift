import SwiftUI

struct DreamSpiritView: View {
    let pet: Pet
    var size: CGFloat = 200

    @State private var floating = false
    @State private var sparkle = false

    private var bodyColor: Color { UnlockableItem.color(for: pet.equippedColor) }

    private var spiritImageName: String {
        switch pet.mood {
        case .rested: return "spirit_dream"
        case .good:   return "spirit_awake"
        case .tired:  return "spirit_tired"
        case .low:    return "spirit_sleep"
        }
    }

    // Per-mood image scale to compensate for asset size differences.
    private var imageScale: CGFloat {
        switch pet.mood {
        case .low: return 1.70   // spirit_sleep renders smaller — boost it
        default:   return 1.30
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
            // Outer halo — large, blurred
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
                .frame(width: size * 0.92, height: size * 0.92)
                .blur(radius: 18)
                .opacity(glowIntensity * 0.85)

            // Inner white bloom
            Circle()
                .fill(Color.white.opacity(0.22))
                .frame(width: size * 0.55, height: size * 0.55)
                .blur(radius: 10)

            if pet.mood == .rested {
                sparkles
            }

            // Spirit illustration
            Image(spiritImageName)
                .resizable()
                .scaledToFit()
                .frame(width: size * imageScale, height: size * imageScale)
                .shadow(color: bodyColor.opacity(0.55), radius: 22, y: 4)
        }
        .frame(width: size * 1.7, height: size * 1.7)
        .offset(y: floating ? -6 : 6)
        .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true), value: floating)
        .onAppear {
            floating = true
            sparkle = true
        }
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

}

#Preview {
    ZStack {
        MooniGradient.night.ignoresSafeArea()
        VStack(spacing: 20) {
            HStack(spacing: 10) {
                DreamSpiritView(pet: { var p = Pet(); p.mood = .rested; return p }(), size: 130)
                DreamSpiritView(pet: { var p = Pet(); p.mood = .good; return p }(), size: 130)
            }
            HStack(spacing: 10) {
                DreamSpiritView(pet: { var p = Pet(); p.mood = .tired; return p }(), size: 130)
                DreamSpiritView(pet: { var p = Pet(); p.mood = .low; return p }(), size: 130)
            }
        }
    }
}
