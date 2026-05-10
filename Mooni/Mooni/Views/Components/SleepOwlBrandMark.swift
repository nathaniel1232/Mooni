import SwiftUI

/// Small, unobtrusive "SleepOwl" lockup placed at the top of every main screen.
/// Exists so screenshots and screen recordings always carry the app's name —
/// useful for influencer/UGC sharing without forcing a giant watermark.
struct SleepOwlBrandMark: View {
    enum Size {
        case compact   // toolbar / inline
        case standard  // top of a screen
    }

    var size: Size = .standard

    private var logoSide: CGFloat { size == .compact ? 16 : 20 }
    private var fontSize: CGFloat { size == .compact ? 12 : 13 }
    private var horizontalPadding: CGFloat { size == .compact ? 8 : 10 }
    private var verticalPadding: CGFloat { size == .compact ? 4 : 5 }

    var body: some View {
        HStack(spacing: 6) {
            Image("owl_base")
                .resizable()
                .scaledToFit()
                .frame(width: logoSide, height: logoSide)
                .shadow(color: MooniColor.accent.opacity(0.4), radius: 4)
            Text("SleepOwl")
                .font(MooniFont.title(fontSize))
                .foregroundColor(MooniColor.textPrimary.opacity(0.92))
                .tracking(0.5)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.06))
                .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 0.5))
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
