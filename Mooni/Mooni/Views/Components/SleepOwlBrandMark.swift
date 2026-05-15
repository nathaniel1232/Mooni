import SwiftUI

/// Small, unobtrusive "SleepOwl" lockup placed at the top of every main screen.
/// Exists so screenshots and screen recordings always carry the app's name —
/// useful for influencer/UGC sharing without forcing a giant watermark.
struct SleepOwlBrandMark: View {
    enum Size {
        case compact   // toolbar / inline
        case standard  // top of a screen
        case prominent // main home header — reads as the app's wordmark
    }

    var size: Size = .standard

    private var logoSide: CGFloat {
        switch size {
        case .compact:   return 16
        case .standard:  return 20
        case .prominent: return 32
        }
    }
    private var fontSize: CGFloat {
        switch size {
        case .compact:   return 12
        case .standard:  return 13
        case .prominent: return 22
        }
    }
    private var horizontalPadding: CGFloat {
        switch size {
        case .compact:   return 8
        case .standard:  return 10
        case .prominent: return 0
        }
    }
    private var verticalPadding: CGFloat {
        switch size {
        case .compact:   return 4
        case .standard:  return 5
        case .prominent: return 0
        }
    }
    private var spacing: CGFloat { size == .prominent ? 10 : 6 }
    private var tracking: CGFloat { size == .prominent ? -0.4 : 0.5 }
    private var hasCapsule: Bool { size != .prominent }

    var body: some View {
        HStack(spacing: spacing) {
            Image("spirit_awake")
                .resizable()
                .scaledToFit()
                .frame(width: logoSide, height: logoSide)
                .shadow(color: MooniColor.accent.opacity(size == .prominent ? 0.6 : 0.4),
                        radius: size == .prominent ? 8 : 4)
            Text("SleepOwl")
                .font(.system(size: fontSize,
                              weight: size == .prominent ? .heavy : .semibold,
                              design: .rounded))
                .foregroundStyle(size == .prominent
                                 ? AnyShapeStyle(LinearGradient(
                                     colors: [MooniColor.textPrimary, MooniColor.accentSoft],
                                     startPoint: .leading,
                                     endPoint: .trailing))
                                 : AnyShapeStyle(MooniColor.textPrimary.opacity(0.92)))
                .tracking(tracking)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(
            Group {
                if hasCapsule {
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 0.5))
                }
            }
        )
        .accessibilityLabel("SleepOwl")
    }
}

#Preview {
    ZStack {
        MooniGradient.night.ignoresSafeArea()
        VStack(spacing: 12) {
            SleepOwlBrandMark(size: .standard)
            SleepOwlBrandMark(size: .compact)
        }
    }
}
