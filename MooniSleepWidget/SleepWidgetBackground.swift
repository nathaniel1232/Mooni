import SwiftUI

// MARK: - Adaptive Background

/// Soft pastel gradient in light mode; deep aurora-purple gradient in dark
/// mode. Both share the same brand DNA so the widget feels consistent.
struct SleepWidgetBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: scheme == .dark ? darkColors : lightColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Soft top-left highlight for that "premium" feel
            RadialGradient(
                colors: [
                    (scheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.55)),
                    Color.white.opacity(0.0)
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 200
            )
            .blendMode(.plusLighter)

            // Subtle stars in dark mode for that night-sky feel
            if scheme == .dark {
                StarSpeckles()
                    .opacity(0.55)
            }
        }
    }

    private var lightColors: [Color] {
        [
            Color(red: 0.96, green: 0.93, blue: 1.00),  // pale lavender
            Color(red: 0.91, green: 0.87, blue: 1.00),  // lavender
            Color(red: 1.00, green: 0.91, blue: 0.96)   // soft cream-pink
        ]
    }

    private var darkColors: [Color] {
        [
            Color(red: 0.07, green: 0.06, blue: 0.18),  // deep midnight
            Color(red: 0.13, green: 0.10, blue: 0.30),  // plum
            Color(red: 0.20, green: 0.13, blue: 0.34)   // warm aurora
        ]
    }
}

/// Tiny static "stars" scattered in the dark-mode background.
private struct StarSpeckles: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                star(at: CGPoint(x: 0.18, y: 0.22), size: 2, in: proxy.size)
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

/// Single source of truth for widget text/chrome colors. Built on `UIColor`
/// dynamic providers so SwiftUI re-renders correctly when the system theme
/// flips and previews stay accurate.
enum SleepWidgetPalette {
    static let textPrimary = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.97, green: 0.95, blue: 1.00, alpha: 1)   // soft cream
            : UIColor(red: 0.18, green: 0.14, blue: 0.32, alpha: 1)   // deep plum
    })

    static let textSecondary = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.85, green: 0.82, blue: 0.95, alpha: 1)
            : UIColor(red: 0.36, green: 0.30, blue: 0.52, alpha: 1)
    })

    static let textTertiary = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.70, green: 0.66, blue: 0.85, alpha: 1)
            : UIColor(red: 0.54, green: 0.48, blue: 0.66, alpha: 1)
    })

    static let chipBackground = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.10)
            : UIColor.white.withAlphaComponent(0.55)
    })

    static let ringTrack = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.14)
            : UIColor.white.withAlphaComponent(0.30)
    })

    static let mascotBubbleInner = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.30, green: 0.24, blue: 0.50, alpha: 1)
            : UIColor(red: 1.00, green: 0.96, blue: 1.00, alpha: 1)
    })

    static let mascotBubbleOuter = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.18, green: 0.14, blue: 0.36, alpha: 1)
            : UIColor(red: 0.92, green: 0.88, blue: 1.00, alpha: 1)
    })
}
