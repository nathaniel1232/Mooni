import SwiftUI

/// Big streak indicator modeled on Duolingo's flame. Three visual states cover
/// the lifecycle:
///   • `.active` — bright orange flame, gentle flicker animation
///   • `.frozen` — cold blue flame, used when a Streak Freeze item is consumed
///   • `.lost`   — desaturated grey, slight downward droop, count reset to 0
///
/// Two sizes: `.large` for the Home top bar / celebration modals, `.compact`
/// for inline use in cards.
struct StreakFireBadge: View {
    enum Status: Equatable {
        case active
        case frozen
        case lost
    }

    enum Size {
        case large
        case compact

        var flameSize: CGFloat {
            switch self {
            case .large:   return 44
            case .compact: return 22
            }
        }

        var numberSize: CGFloat {
            switch self {
            case .large:   return 34
            case .compact: return 17
            }
        }

        var labelSize: CGFloat {
            switch self {
            case .large:   return 11
            case .compact: return 10
            }
        }
    }

    let count: Int
    var state: Status = .active
    var size: Size = .large
    /// When true, tapping the badge animates a small pulse (used on Home).
    var tappable: Bool = false

    @State private var flicker: Bool = false
    @State private var tapPulse: Bool = false

    init(count: Int, state: Status = .active, size: Size = .large, tappable: Bool = false) {
        self.count = count
        self.state = state
        self.size = size
        self.tappable = tappable
    }

    var body: some View {
        HStack(spacing: size == .large ? 12 : 8) {
            flame

            VStack(alignment: .leading, spacing: -2) {
                Text("\(count)")
                    .font(MooniFont.display(size.numberSize))
                    .foregroundColor(numberColor)
                    .contentTransition(.numericText())
                Text(label)
                    .font(MooniFont.caption(size.labelSize))
                    .foregroundColor(MooniColor.textMuted)
                    .textCase(.uppercase)
                    .tracking(0.6)
            }
        }
        .scaleEffect(tapPulse ? 1.08 : 1.0)
        .animation(.spring(response: 0.32, dampingFraction: 0.55), value: tapPulse)
        .onTapGesture {
            guard tappable else { return }
            Haptics.tap()
            tapPulse = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { tapPulse = false }
        }
        .onAppear {
            // Flicker is only meaningful when the flame is alive.
            if state == .active {
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    flicker = true
                }
            }
        }
        .onChange(of: state) { _, new in
            flicker = (new == .active)
        }
    }

    // MARK: - Flame
    @ViewBuilder
    private var flame: some View {
        ZStack {
            // Glow halo behind the flame so the icon reads at small sizes.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [glowColor.opacity(state == .lost ? 0.0 : 0.45), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size.flameSize * 0.9
                    )
                )
                .frame(width: size.flameSize * 1.8, height: size.flameSize * 1.8)
                .blur(radius: 6)

            Image(systemName: "flame.fill")
                .resizable()
                .scaledToFit()
                .frame(width: size.flameSize, height: size.flameSize)
                .symbolRenderingMode(.palette)
                .foregroundStyle(flameTopColor, flameBottomColor)
                .scaleEffect(y: flicker ? 1.04 : 0.96, anchor: .bottom)
                .rotationEffect(.degrees(state == .lost ? 8 : 0))
                .opacity(state == .lost ? 0.5 : 1)
                .shadow(color: glowColor.opacity(state == .lost ? 0 : 0.6), radius: 12, y: 2)
        }
    }

    // MARK: - State-driven palette
    private var flameTopColor: Color {
        switch state {
        case .active: return MooniColor.streakFire
        case .frozen: return MooniColor.streakFrozen
        case .lost:   return Color.white.opacity(0.35)
        }
    }

    private var flameBottomColor: Color {
        switch state {
        case .active: return MooniColor.streakEmber
        case .frozen: return MooniColor.streakFrozen.opacity(0.7)
        case .lost:   return Color.white.opacity(0.18)
        }
    }

    private var glowColor: Color {
        switch state {
        case .active: return MooniColor.streakFire
        case .frozen: return MooniColor.streakFrozen
        case .lost:   return .clear
        }
    }

    private var numberColor: Color {
        switch state {
        case .active: return MooniColor.textPrimary
        case .frozen: return MooniColor.streakFrozen
        case .lost:   return MooniColor.textMuted
        }
    }

    private var label: String {
        switch state {
        case .active: return count == 1 ? "Day streak" : "Day streak"
        case .frozen: return "Frozen"
        case .lost:   return "Streak lost"
        }
    }
}

#Preview {
    ZStack {
        MooniGradient.night.ignoresSafeArea()
        VStack(spacing: 28) {
            StreakFireBadge(count: 12, state: .active, size: .large, tappable: true)
            StreakFireBadge(count: 7,  state: .frozen, size: .large)
            StreakFireBadge(count: 0,  state: .lost,   size: .large)
            HStack(spacing: 18) {
                StreakFireBadge(count: 3, state: .active, size: .compact)
                StreakFireBadge(count: 9, state: .frozen, size: .compact)
            }
        }
    }
}
