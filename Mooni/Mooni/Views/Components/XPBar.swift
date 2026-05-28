import SwiftUI

/// Slim animated XP / progress bar shaped to sit at the top of the Home view
/// next to the streak badge. Set `value` to a 0…1 fraction; the bar animates
/// from its previous value to the new one, and a floating "+12 XP" chip
/// appears for ~1.4s whenever `recentDelta` flips to a positive number.
///
/// Caller-side pattern (see HomeView in Phase 3):
///   XPBar(
///       value: pet.levelProgress,
///       level: pet.level,
///       title: pet.levelTitle,
///       recentDelta: appState.lastEarnedEnergy
///   )
///
/// `recentDelta` reads `AppState.lastEarnedEnergy` which is already published
/// from the scoring pipeline. Clear it after consumption so the chip can re-fire
/// the next time a night is scored.
struct XPBar: View {
    let value: Double
    var level: Int = 1
    var title: String = ""
    var recentDelta: Int? = nil
    var height: CGFloat = 14

    @State private var animatedValue: Double = 0
    @State private var showDelta: Bool = false
    @State private var deltaAmount: Int = 0

    init(value: Double, level: Int = 1, title: String = "", recentDelta: Int? = nil, height: CGFloat = 14) {
        self.value = value
        self.level = level
        self.title = title
        self.recentDelta = recentDelta
        self.height = height
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                levelChip
                Spacer(minLength: 8)
                if showDelta {
                    deltaChip
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }

            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )

                    // Fill
                    Capsule()
                        .fill(LinearGradient.xpFill)
                        .frame(width: max(8, width * clamped(animatedValue)))
                        .shadow(color: MooniColor.xpGreen.opacity(0.55), radius: 6, y: 0)

                    // Glossy highlight on top half of the fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.35), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .frame(width: max(8, width * clamped(animatedValue)), height: height * 0.55)
                        .offset(y: -height * 0.225)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: height)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { animatedValue = value }
        }
        .onChange(of: value) { _, new in
            withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) {
                animatedValue = new
            }
        }
        .onChange(of: recentDelta) { _, new in
            guard let new, new > 0 else { return }
            deltaAmount = new
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                showDelta = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(.easeOut(duration: 0.35)) { showDelta = false }
            }
        }
    }

    private var levelChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkle")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(MooniColor.xpGreenSoft)
            Text("Lvl \(level)")
                .font(MooniFont.caption(12))
                .foregroundColor(MooniColor.textPrimary)
            if !title.isEmpty {
                Text("·")
                    .foregroundColor(MooniColor.textMuted)
                Text(title)
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textSecondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(Color.white.opacity(0.08))
        )
        .overlay(
            Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
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
        .background(
            Capsule().fill(MooniColor.xpGreen.opacity(0.12))
        )
        .overlay(
            Capsule().stroke(MooniColor.xpGreen.opacity(0.45), lineWidth: 1)
        )
    }

    private func clamped(_ v: Double) -> CGFloat { CGFloat(max(0, min(1, v))) }
}

#Preview {
    ZStack {
        MooniGradient.night.ignoresSafeArea()
        VStack(spacing: 28) {
            XPBar(value: 0.35, level: 3, title: "Restful", recentDelta: nil)
            XPBar(value: 0.78, level: 7, title: "Dreamer", recentDelta: 42)
            XPBar(value: 1.0,  level: 12, title: "Night Owl")
        }
        .padding(24)
    }
}
