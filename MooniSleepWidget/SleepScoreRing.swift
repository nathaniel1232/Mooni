import SwiftUI

/// Circular progress ring around the Mooni mascot.
/// Track adapts to light/dark; progress arc uses an angular gradient + glow.
struct SleepScoreRing<Center: View>: View {
    let progress: Double
    let tint: Color
    let lineWidth: CGFloat
    @ViewBuilder var center: () -> Center

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(
                    SleepWidgetPalette.ringTrack,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )

            // Progress arc — angular gradient with a glow halo
            Circle()
                .trim(from: 0, to: max(0.001, progress))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            tint.opacity(0.45),
                            tint,
                            Color.white.opacity(0.85),
                            tint,
                            tint.opacity(0.45)
                        ]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.55), radius: 6, x: 0, y: 0)

            center()
                .padding(lineWidth + 4)
        }
    }
}
