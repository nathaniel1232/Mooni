import SwiftUI

/// The "SleepOwl" lockup placed at the top of every main screen so screenshots
/// and screen recordings always carry the app's identity.
///
/// The glyph is now the real App Store icon (`app_icon`) — the same artwork
/// users tap on their home screen — clipped to an iOS-style squircle with a
/// hairline edge and a soft accent bloom, instead of a bare cut-out owl.
struct SleepOwlBrandMark: View {
    enum Size {
        case compact   // toolbar / inline
        case standard  // top of a screen
        case prominent // main home header — reads as the app's wordmark
    }

    var size: Size = .standard

    private var iconSide: CGFloat {
        switch size {
        case .compact:   return 18
        case .standard:  return 24
        case .prominent: return 36
        }
    }
    private var fontSize: CGFloat {
        switch size {
        case .compact:   return 13
        case .standard:  return 15
        case .prominent: return 24
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
        case .compact:   return 5
        case .standard:  return 6
        case .prominent: return 0
        }
    }
    private var spacing: CGFloat { size == .prominent ? 11 : 7 }
    private var tracking: CGFloat { size == .prominent ? -0.4 : 0.3 }
    private var hasCapsule: Bool { size != .prominent }

    var body: some View {
        HStack(spacing: spacing) {
            appIcon
            Text("SleepOwl")
                .font(.system(size: fontSize,
                              weight: size == .prominent ? .heavy : .semibold,
                              design: .rounded))
                .foregroundColor(size == .prominent
                                 ? MooniColor.textPrimary
                                 : MooniColor.textPrimary.opacity(0.92))
                .tracking(tracking)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(
            Group {
                if hasCapsule {
                    Capsule()
                        .fill(MooniColor.hairline)
                        .overlay(Capsule().stroke(MooniColor.hairline, lineWidth: 0.5))
                }
            }
        )
        .accessibilityElement()
        .accessibilityLabel("SleepOwl")
    }

    private var appIcon: some View {
        let corner = iconSide * 0.235
        return Image("app_icon")
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .frame(width: iconSide, height: iconSide)
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(MooniColor.hairline, lineWidth: 0.5)
            )
            .shadow(color: MooniColor.accent.opacity(size == .prominent ? 0.55 : 0.35),
                    radius: size == .prominent ? 9 : 5, y: 1)
    }
}

#Preview {
    ZStack {
        MooniGradient.night.ignoresSafeArea()
        VStack(spacing: 22) {
            SleepOwlBrandMark(size: .prominent)
            SleepOwlBrandMark(size: .standard)
            SleepOwlBrandMark(size: .compact)
        }
    }
}
