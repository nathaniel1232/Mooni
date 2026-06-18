import SwiftUI

/// Slim level / XP progress bar shown at the top of Home. A rounded level badge
/// + "LEVEL n" label sit above a clean gradient progress track; a floating
/// "+12 XP" chip pops for ~1.4s whenever `recentDelta` flips positive.
///
/// Level *names* were removed deliberately — a higher number already reads as
/// "better", so the extra "Restful / Dreamer" labels were just noise.
///
///   XPBar(
///       value: pet.levelProgress,
///       level: pet.level,
///       recentDelta: appState.lastEarnedEnergy
///   )
struct XPBar: View {
    let value: Double
    var level: Int = 1
    var recentDelta: Int? = nil
    var height: CGFloat = 12

    @State private var animatedValue: Double = 0
    @State private var showDelta: Bool = false
    @State private var deltaAmount: Int = 0

    init(value: Double, level: Int = 1, recentDelta: Int? = nil, height: CGFloat = 12) {
        self.value = value
        self.level = level
        self.recentDelta = recentDelta
        self.height = height
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                levelBadge
                Text("LEVEL \(level)")
                    .font(MooniFont.caption(12))
                    .tracking(1.4)
                    .foregroundColor(MooniColor.textSecondary)

                Spacer(minLength: 8)

                if showDelta {
                    deltaChip
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                } else {
                    Text("\(Int((animatedValue * 100).rounded()))%")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textMuted)
                        .contentTransition(.numericText())
                }
            }

            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(MooniColor.hairline)

                    Capsule()
                        .fill(LinearGradient.xpFill)
                        .frame(width: max(height, width * clamped(animatedValue)))
                        .shadow(color: MooniColor.xpGreen.opacity(0.45), radius: 5, y: 0)
                }
            }
            .frame(height: height)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { animatedValue = value }
        }
        .onChange(of: value) { _, new in
            withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) { animatedValue = new }
        }
        .onChange(of: recentDelta) { _, new in
            guard let new, new > 0 else { return }
            deltaAmount = new
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { showDelta = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(.easeOut(duration: 0.35)) { showDelta = false }
            }
        }
    }

    /// Rounded badge carrying the level number — the visual anchor of the row.
    private var levelBadge: some View {
        Text("\(level)")
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .foregroundColor(MooniColor.background)
            .frame(width: 26, height: 26)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient.xpFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
            )
            .shadow(color: MooniColor.xpGreen.opacity(0.4), radius: 4, y: 1)
    }

    private var deltaChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "plus.circle.fill")
                .foregroundColor(MooniColor.xpGreen)
                .font(.system(size: 12, weight: .bold))
            Text("\(deltaAmount) XP")
                .font(MooniFont.title(12))
                .foregroundColor(MooniColor.xpGreenSoft)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(MooniColor.xpGreen.opacity(0.14)))
        .overlay(Capsule().stroke(MooniColor.xpGreen.opacity(0.45), lineWidth: 1))
    }

    private func clamped(_ v: Double) -> CGFloat { CGFloat(max(0, min(1, v))) }
}

#Preview {
    ZStack {
        MooniGradient.night.ignoresSafeArea()
        VStack(spacing: 28) {
            XPBar(value: 0.35, level: 3, recentDelta: nil)
            XPBar(value: 0.78, level: 7, recentDelta: 42)
            XPBar(value: 1.0,  level: 12)
        }
        .padding(24)
    }
}
