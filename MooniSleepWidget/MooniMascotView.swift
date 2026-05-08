import SwiftUI

/// Mooni owl mascot inside a soft circular bubble.
///
/// If you've added the existing `owl_base` asset to the widget target's
/// asset catalog (or a shared catalog), it will render that. Otherwise
/// it falls back to a cute SwiftUI-shape owl so the widget is never blank.
struct MooniMascotView: View {
    /// Bundle that owns the asset catalog containing `owl_base`.
    /// The widget needs its own copy of the image — either drag the asset
    /// into the widget's asset catalog, or set up a shared asset catalog
    /// that's a member of both targets.
    var assetName: String = "owl_base"

    var body: some View {
        ZStack {
            // Soft adaptive bubble behind the mascot
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            SleepWidgetPalette.mascotBubbleInner,
                            SleepWidgetPalette.mascotBubbleOuter
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 60
                    )
                )
                .overlay(
                    Circle().stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: Color.purple.opacity(0.25), radius: 6, x: 0, y: 2)

            mascot
                .padding(6)
        }
    }

    @ViewBuilder
    private var mascot: some View {
        if UIImage(named: assetName) != nil {
            Image(assetName)
                .resizable()
                .scaledToFit()
        } else {
            ShapeOwl()
        }
    }
}

/// Fallback owl drawn from SwiftUI shapes — used when the asset isn't
/// available to the widget target yet.
private struct ShapeOwl: View {
    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let bodyColor = Color(red: 0.74, green: 0.66, blue: 0.96)
            let bellyColor = Color(red: 0.95, green: 0.92, blue: 1.00)

            ZStack {
                // Body
                Ellipse()
                    .fill(bodyColor)
                    .frame(width: size * 0.86, height: size * 0.92)

                // Belly
                Ellipse()
                    .fill(bellyColor)
                    .frame(width: size * 0.55, height: size * 0.65)
                    .offset(y: size * 0.06)

                // Eyes
                HStack(spacing: size * 0.10) {
                    eye(size: size * 0.22)
                    eye(size: size * 0.22)
                }
                .offset(y: -size * 0.10)

                // Beak
                Triangle()
                    .fill(Color(red: 1.0, green: 0.82, blue: 0.55))
                    .frame(width: size * 0.10, height: size * 0.08)
                    .offset(y: size * 0.04)

                // Ear tufts
                HStack(spacing: size * 0.42) {
                    Triangle()
                        .fill(bodyColor)
                        .frame(width: size * 0.16, height: size * 0.18)
                        .rotationEffect(.degrees(-12))
                    Triangle()
                        .fill(bodyColor)
                        .frame(width: size * 0.16, height: size * 0.18)
                        .rotationEffect(.degrees(12))
                }
                .offset(y: -size * 0.36)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func eye(size: CGFloat) -> some View {
        ZStack {
            Circle().fill(Color.white)
            Circle()
                .fill(Color(red: 0.18, green: 0.14, blue: 0.32))
                .frame(width: size * 0.55, height: size * 0.55)
            Circle()
                .fill(Color.white)
                .frame(width: size * 0.18, height: size * 0.18)
                .offset(x: size * 0.10, y: -size * 0.10)
        }
        .frame(width: size, height: size)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
