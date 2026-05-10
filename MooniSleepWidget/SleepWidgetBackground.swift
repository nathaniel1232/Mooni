import SwiftUI

// MARK: - Adaptive Background

/// Widget background that mirrors the in-app `MooniGradient.night` so the
/// home-screen widget reads as part of SleepOwl, not a separate product.
/// Light mode is a soft moonlit cream variant — same color DNA, less contrast.
struct SleepWidgetBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: scheme == .dark ? darkColors : lightColors,
                startPoint: .top,
                endPoint: .bottom
            )

            // Soft accent glow from the top — matches the in-app card halo.
            RadialGradient(
                colors: [
                    accentGlow.opacity(scheme == .dark ? 0.30 : 0.20),
                    .clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 220
            )
            .blendMode(.plusLighter)

            if scheme == .dark {
                StarSpeckles().opacity(0.45)
            }
        }
    }

    /// In-app `MooniColor.background` is a near-black deep navy. Use the same
    /// base + a touch of accent for depth.
    private var darkColors: [Color] {
        [
            Color(red: 0.04, green: 0.04, blue: 0.10),
            Color(red: 0.07, green: 0.06, blue: 0.16),
            Color(red: 0.10, green: 0.08, blue: 0.22)
        ]
    }

    private var lightColors: [Color] {
        [
            Color(red: 0.97, green: 0.95, blue: 1.00),
            Color(red: 0.92, green: 0.90, blue: 1.00)
        ]
    }

    private var accentGlow: Color {
        Color(red: 0.55, green: 0.50, blue: 0.95) // matches MooniColor.accent
    }
}

private struct StarSpeckles: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                star(at: CGPoint(x: 0.18, y: 0.22), size: 2,   in: proxy.size)
                star(at: CGPoint(x: 0.88, y: 0.14), size: 1.5, in: proxy.size)
                star(at: CGPoint(x: 0.74, y: 0.82), size: 2.5, in: proxy.size)
                star(at: CGPoint(x: 0.30, y: 0.78), size: 1.5, in: proxy.size)
                star(at: CGPoint(x: 0.55, y: 0.10), size: 1.2, in: proxy.size)
                star(at: CGPoint(x: 0.10, y: 0.55), size: 1.2, in: proxy.size)
                star(at: CGPoint(x: 0.92, y: 0.55), size: 1.8, in: proxy.size)
            }
        }
    }

    private func star(at point: CGPoint, size: CGFloat, in container: CGSize) -> some View {
        Circle()
            .fill(Color.white.opacity(0.85))
            .frame(width: size, height: size)
            .position(x: point.x * container.width, y: point.y * container.height)
            .shadow(color: Color(red: 0.78, green: 0.74, blue: 1.0).opacity(0.7), radius: 3)
    }
}

// MARK: - Adaptive Palette

enum SleepWidgetPalette {
    static let textPrimary = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.97, green: 0.95, blue: 1.00, alpha: 1)
            : UIColor(red: 0.18, green: 0.14, blue: 0.32, alpha: 1)
    })

    static let textSecondary = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.78, green: 0.76, blue: 0.92, alpha: 1)
            : UIColor(red: 0.36, green: 0.30, blue: 0.52, alpha: 1)
    })

    static let textTertiary = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.62, green: 0.60, blue: 0.78, alpha: 1)
            : UIColor(red: 0.54, green: 0.48, blue: 0.66, alpha: 1)
    })

    static let chipBackground = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.08)
            : UIColor.white.withAlphaComponent(0.55)
    })

    static let ringTrack = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.10)
            : UIColor.white.withAlphaComponent(0.30)
    })

    /// Kept for source compatibility with MooniMascotView, no longer used as
    /// a hard bubble — the mascot now reads like the in-app owl (halo only).
    static let mascotBubbleInner = Color.clear
    static let mascotBubbleOuter = Color.clear
}
