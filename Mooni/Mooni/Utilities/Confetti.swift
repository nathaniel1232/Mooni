import SwiftUI

/// Pure-SwiftUI confetti emitter. No CAEmitterLayer / no UIKit bridging — keeps
/// it cheap and avoids freezes on older devices.
///
/// Usage:
///   ZStack {
///       myContent
///       ConfettiView(trigger: $celebrationCount)
///   }
///
/// Bumping `trigger` (or calling `.emit()` on the view) fires a fresh burst.
/// `ConfettiView` self-cleans pieces once they fall off the bottom edge.
struct ConfettiView: View {
    @Binding var trigger: Int
    var count: Int = 36
    var duration: Double = 2.4

    @State private var pieces: [Piece] = []
    @State private var lastTrigger: Int = 0

    init(trigger: Binding<Int>, count: Int = 36, duration: Double = 2.4) {
        self._trigger = trigger
        self.count = count
        self.duration = duration
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    PieceView(piece: piece, size: geo.size, duration: duration)
                }
            }
            .allowsHitTesting(false)
            .onChange(of: trigger) { _, new in
                guard new != lastTrigger else { return }
                lastTrigger = new
                spawnBurst()
            }
        }
    }

    private func spawnBurst() {
        // Drop the oldest burst if we're stacking many in a row.
        if pieces.count > count * 3 {
            pieces.removeFirst(count)
        }
        let burst = (0..<count).map { _ in Piece.random() }
        pieces.append(contentsOf: burst)

        // Cleanup so the array doesn't grow forever — pieces are finished
        // animating by `duration + 0.4`, after which we drop them.
        let toRemove = burst.map(\.id)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.4) {
            pieces.removeAll { toRemove.contains($0.id) }
        }
    }

    // MARK: - Model
    struct Piece: Identifiable {
        let id = UUID()
        let xStart: CGFloat        // 0…1
        let xDriftAngle: CGFloat   // radians for sway
        let rotationStart: Double
        let rotationEnd: Double
        let shape: Shape
        let color: Color
        let size: CGFloat
        let delay: Double

        enum Shape: CaseIterable { case circle, rect, sparkle, star, heart }

        static func random() -> Piece {
            Piece(
                xStart: CGFloat.random(in: 0.1...0.9),
                xDriftAngle: CGFloat.random(in: -0.35...0.35),
                rotationStart: Double.random(in: 0...360),
                rotationEnd: Double.random(in: 360...1080) * (Bool.random() ? 1 : -1),
                shape: Shape.allCases.randomElement()!,
                color: palette.randomElement()!,
                size: CGFloat.random(in: 6...11),
                delay: Double.random(in: 0...0.18)
            )
        }

        static let palette: [Color] = [
            MooniColor.streakFire,
            MooniColor.streakEmber,
            MooniColor.xpGreen,
            MooniColor.xpGreenSoft,
            MooniColor.accent,
            MooniColor.accentSoft,
            MooniColor.petGlow,
            Color(red: 1.0, green: 0.92, blue: 0.55)
        ]
    }

    private struct PieceView: View {
        let piece: Piece
        let size: CGSize
        let duration: Double

        @State private var animated = false

        var body: some View {
            shapeView
                .frame(width: piece.size, height: piece.size)
                .foregroundColor(piece.color)
                .shadow(color: piece.color.opacity(0.5), radius: 3)
                .rotationEffect(.degrees(animated ? piece.rotationEnd : piece.rotationStart))
                .position(
                    x: animated
                        ? size.width * piece.xStart + sin(piece.xDriftAngle * 5) * 36
                        : size.width * piece.xStart,
                    y: animated ? size.height + 40 : -40
                )
                .opacity(animated ? 0.0 : 1.0)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + piece.delay) {
                        withAnimation(.easeIn(duration: duration)) { animated = true }
                    }
                }
        }

        @ViewBuilder
        private var shapeView: some View {
            switch piece.shape {
            case .circle:  Circle()
            case .rect:    RoundedRectangle(cornerRadius: 2, style: .continuous)
            case .sparkle: Image(systemName: "sparkle").resizable().scaledToFit()
            case .star:    Image(systemName: "star.fill").resizable().scaledToFit()
            case .heart:   Image(systemName: "heart.fill").resizable().scaledToFit()
            }
        }
    }
}

#Preview {
    struct Demo: View {
        @State var trigger = 0
        var body: some View {
            ZStack {
                MooniGradient.night.ignoresSafeArea()
                VStack(spacing: 40) {
                    Text("Confetti demo")
                        .font(MooniFont.display(28))
                        .foregroundColor(MooniColor.textPrimary)
                    PrimaryButton(title: "Pop") { trigger += 1 }
                }
                .padding(40)

                ConfettiView(trigger: $trigger)
            }
        }
    }
    return Demo()
}
