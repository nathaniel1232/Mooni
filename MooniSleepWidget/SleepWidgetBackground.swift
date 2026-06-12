import SwiftUI

// MARK: - Adaptive Background

/// Widget background that mirrors the in-app `MooniGradient.night` so the
/// home-screen widget reads as part of SleepOwl, not a separate product.
/// Light mode is a soft moonlit cream variant — same color DNA, less contrast.
struct SleepWidgetBackground: View {
    @Environment(\.colorScheme) private var scheme
    /// Score tint piped in by each widget — used to colour the corner glow so
    /// the whole widget reads as "good night" / "rough night" at a glance.
    /// nil falls back to the brand accent.
    var tint: Color? = nil

    var body: some View {
        ZStack {
            // Base gradient — slightly richer than the previous flat-navy
            // version. Bottom is a deep midnight, top picks up a hint of the
            // tint so the widget feels lit from above by the score.
            LinearGradient(
                colors: scheme == .dark ? darkColors : lightColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // One quiet tint wash from the top-left corner so the score colour
            // owns the surface without reading as a glow effect.
            RadialGradient(
                colors: [
                    haloColor.opacity(scheme == .dark ? 0.20 : 0.12),
                    .clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 260
            )

            if scheme == .dark {
                StarSpeckles().opacity(0.55)
            }

            // Subtle inner border so the widget reads as a single piece of
            // glass rather than a flat coloured tile.
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(scheme == .dark ? 0.18 : 0.5),
                            Color.white.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.6
                )
        }
    }

    private var haloColor: Color { tint ?? accentGlow }

    /// In-app `MooniColor.background` is a near-black deep navy. New gradient
    /// has a slightly bluer mid-tone for more depth.
    private var darkColors: [Color] {
        [
            Color(red: 0.05, green: 0.05, blue: 0.13),
            Color(red: 0.08, green: 0.07, blue: 0.20),
            Color(red: 0.04, green: 0.04, blue: 0.10)
        ]
    }

    private var lightColors: [Color] {
        [
            Color(red: 0.98, green: 0.96, blue: 1.00),
            Color(red: 0.93, green: 0.91, blue: 1.00),
            Color(red: 0.88, green: 0.86, blue: 0.99)
        ]
    }

    private var accentGlow: Color {
        Color(red: 0.55, green: 0.50, blue: 0.95) // matches MooniColor.accent
    }
}

private struct StarSpeckles: View {
    // Hand-placed for hierarchy: a few "anchor" bright stars + many faint
    // background pinpricks. Read like a real sky, not a regular pattern.
    private let bright: [(CGPoint, CGFloat)] = [
        (CGPoint(x: 0.18, y: 0.22), 2.4),
        (CGPoint(x: 0.88, y: 0.14), 1.8),
        (CGPoint(x: 0.74, y: 0.82), 2.6),
        (CGPoint(x: 0.92, y: 0.55), 2.0)
    ]
    private let faint: [(CGPoint, CGFloat)] = [
        (CGPoint(x: 0.30, y: 0.78), 1.2),
        (CGPoint(x: 0.55, y: 0.10), 1.0),
        (CGPoint(x: 0.10, y: 0.55), 1.0),
        (CGPoint(x: 0.42, y: 0.34), 0.9),
        (CGPoint(x: 0.66, y: 0.46), 1.1),
        (CGPoint(x: 0.22, y: 0.92), 0.8),
        (CGPoint(x: 0.50, y: 0.68), 0.9),
        (CGPoint(x: 0.80, y: 0.30), 1.0)
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<bright.count, id: \.self) { i in
                    star(at: bright[i].0, size: bright[i].1, bright: true, in: proxy.size)
                }
                ForEach(0..<faint.count, id: \.self) { i in
                    star(at: faint[i].0, size: faint[i].1, bright: false, in: proxy.size)
                }
            }
        }
    }

    private func star(at point: CGPoint, size: CGFloat, bright: Bool, in container: CGSize) -> some View {
        Circle()
            .fill(Color.white.opacity(bright ? 0.92 : 0.55))
            .frame(width: size, height: size)
            .position(x: point.x * container.width, y: point.y * container.height)
            .shadow(
                color: Color(red: 0.78, green: 0.74, blue: 1.0).opacity(bright ? 0.85 : 0.4),
                radius: bright ? 3 : 1.5
            )
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
