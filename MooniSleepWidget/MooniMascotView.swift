import SwiftUI

/// SleepOwl mascot rendered the same way as the in-app `PetIllustration`:
/// a soft accent halo behind the owl image. No hard bubble, no border —
/// the widget should look like it was lifted out of the app's home screen.
struct MooniMascotView: View {
    var assetName: String = "owl_base"
    /// Glow color around the owl. Defaults to the in-app accent so the
    /// mascot reads as SleepOwl regardless of which size widget renders it.
    var glow: Color = Color(red: 0.78, green: 0.74, blue: 1.0)

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [glow.opacity(0.55), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: side * 0.7
                        )
                    )
                    .blur(radius: 6)

                mascot(side: side)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    @ViewBuilder
    private func mascot(side: CGFloat) -> some View {
        if UIImage(named: assetName) != nil {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(width: side * 0.85, height: side * 0.85)
                .shadow(color: glow.opacity(0.45), radius: 6, y: 2)
        } else {
            ShapeOwl()
                .frame(width: side * 0.85, height: side * 0.85)
        }
    }
}

private struct ShapeOwl: View {
    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let bodyColor = Color(red: 0.74, green: 0.66, blue: 0.96)
            let bellyColor = Color(red: 0.95, green: 0.92, blue: 1.00)

            ZStack {
                Ellipse()
                    .fill(bodyColor)
                    .frame(width: size * 0.86, height: size * 0.92)

                Ellipse()
                    .fill(bellyColor)
                    .frame(width: size * 0.55, height: size * 0.65)
                    .offset(y: size * 0.06)

                HStack(spacing: size * 0.10) {
                    eye(size: size * 0.22)
                    eye(size: size * 0.22)
                }
                .offset(y: -size * 0.10)

                Triangle()
                    .fill(Color(red: 1.0, green: 0.82, blue: 0.55))
                    .frame(width: size * 0.10, height: size * 0.08)
                    .offset(y: size * 0.04)

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
