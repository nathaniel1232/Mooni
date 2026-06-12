import SwiftUI

/// Circular progress ring around the SleepOwl mascot.
/// Track adapts to light/dark; progress arc is a flat solid stroke.
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

            // Progress arc
            Circle()
                .trim(from: 0, to: max(0.001, progress))
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            center()
                .padding(lineWidth + 4)
        }
    }
}
