import SwiftUI

/// Duolingo-style celebration sheet. Slides up from the bottom over a dimmed
/// backdrop, animates the mascot inside, optionally throws confetti, and
/// resolves with a single primary tap.
///
/// Driven by `CelebrationToast.Payload` — pass `nil` to dismiss. Designed to
/// live on the Home view's ZStack root via `.celebrationToast(payload:)`.
struct CelebrationToast: View {
    struct Payload: Equatable, Identifiable {
        enum Kind: Equatable {
            case streakMilestone(days: Int)
            case levelUp(newLevel: Int)
            case questComplete(rewardStars: Int)
            case custom
        }
        let id = UUID()
        let kind: Kind
        let title: String
        let subtitle: String
        var ctaTitle: String = "Nice!"
        var pet: Pet? = nil
        var confetti: Bool = true

        static func == (lhs: Payload, rhs: Payload) -> Bool { lhs.id == rhs.id }
    }

    let payload: Payload
    let onDismiss: () -> Void

    @State private var appeared = false
    @State private var confettiTrigger = 0
    @State private var iconPulse: CGFloat = 0.85

    init(payload: Payload, onDismiss: @escaping () -> Void) {
        self.payload = payload
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            Color.black
                .opacity(appeared ? 0.55 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            ConfettiView(trigger: $confettiTrigger)
                .ignoresSafeArea()

            VStack {
                Spacer()
                card
                    .padding(.horizontal, 22)
                    .padding(.bottom, 28)
                    .offset(y: appeared ? 0 : 60)
                    .opacity(appeared ? 1 : 0)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: appeared)
        .onAppear {
            appeared = true
            Haptics.celebrate()
            if payload.confetti { confettiTrigger += 1 }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                iconPulse = 1.05
            }
        }
    }

    @ViewBuilder
    private var card: some View {
        VStack(spacing: 18) {
            heroIcon
                .padding(.top, 22)

            VStack(spacing: 8) {
                Text(payload.title)
                    .font(MooniFont.display(26))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text(payload.subtitle)
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
            }

            kindAccent
                .padding(.top, 4)

            PrimaryButton(title: payload.ctaTitle, icon: nil) {
                dismiss()
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(MooniColor.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 30, y: 18)
    }

    @ViewBuilder
    private var heroIcon: some View {
        switch payload.kind {
        case .streakMilestone(let days):
            VStack(spacing: 6) {
                StreakFireBadge(count: days, state: .active, size: .large)
                    .scaleEffect(iconPulse)
            }
        case .levelUp(let newLevel):
            ZStack {
                Circle()
                    .fill(LinearGradient.xpFill)
                    .frame(width: 96, height: 96)
                    .shadow(color: MooniColor.xpGreen.opacity(0.6), radius: 16)
                VStack(spacing: -2) {
                    Text("LVL").font(MooniFont.caption(11)).foregroundColor(.black.opacity(0.6))
                    Text("\(newLevel)").font(MooniFont.display(34)).foregroundColor(.black)
                }
            }
            .scaleEffect(iconPulse)
        case .questComplete(let stars):
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: i < starFillCount(stars) ? "star.fill" : "star")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundColor(i < starFillCount(stars) ? MooniColor.warning : MooniColor.textMuted)
                        .scaleEffect(iconPulse)
                }
            }
        case .custom:
            if let pet = payload.pet {
                PetIllustration(pet: pet, size: 100)
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundColor(MooniColor.accentText)
                    .scaleEffect(iconPulse)
            }
        }
    }

    @ViewBuilder
    private var kindAccent: some View {
        switch payload.kind {
        case .questComplete(let stars):
            HStack(spacing: 4) {
                Image(systemName: "moon.stars.fill")
                    .foregroundColor(MooniColor.accentText)
                Text("+\(stars) Dream Stars")
                    .font(MooniFont.title(15))
                    .foregroundColor(MooniColor.textPrimary)
            }
        case .levelUp:
            Text("LEVEL UP")
                .font(MooniFont.caption(12))
                .tracking(1.2)
                .foregroundColor(MooniColor.xpGreenSoft)
        case .streakMilestone(let days):
            Text(milestoneTagline(days: days))
                .font(MooniFont.caption(12))
                .tracking(1.0)
                .foregroundColor(MooniColor.streakFire)
                .textCase(.uppercase)
        case .custom:
            EmptyView()
        }
    }

    private func starFillCount(_ stars: Int) -> Int {
        // 3-star scale: rewardStars 0…30 → 0…3 visible stars.
        switch stars {
        case ..<10: return 1
        case ..<20: return 2
        default:    return 3
        }
    }

    private func milestoneTagline(days: Int) -> String {
        switch days {
        case 1...2:   return "First sparks"
        case 3...6:   return "It's catching"
        case 7...13:  return "Week of rest"
        case 14...29: return "Real momentum"
        case 30...99: return "Sleep mastery"
        default:      return "Legendary"
        }
    }

    private func dismiss() {
        Haptics.tap()
        withAnimation(.easeInOut(duration: 0.25)) { appeared = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { onDismiss() }
    }
}

// MARK: - View modifier

extension View {
    /// Overlays a celebration toast when `payload` is non-nil. Set the binding
    /// to nil from inside the toast's dismiss callback (handled automatically
    /// in the binding flavor below).
    func celebrationToast(payload: Binding<CelebrationToast.Payload?>) -> some View {
        ZStack {
            self
            if let value = payload.wrappedValue {
                CelebrationToast(payload: value) {
                    payload.wrappedValue = nil
                }
                .transition(.opacity)
                .zIndex(50)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: payload.wrappedValue)
    }
}

#Preview {
    struct Demo: View {
        @State var payload: CelebrationToast.Payload? = nil
        var body: some View {
            ZStack {
                MooniGradient.night.ignoresSafeArea()
                VStack(spacing: 16) {
                    PrimaryButton(title: "Streak 7") {
                        payload = .init(
                            kind: .streakMilestone(days: 7),
                            title: "7-day streak!",
                            subtitle: "A full week of consistent bedtimes. Your owl is glowing.",
                            ctaTitle: "Keep it going"
                        )
                    }
                    PrimaryButton(title: "Level up") {
                        payload = .init(
                            kind: .levelUp(newLevel: 5),
                            title: "Level up!",
                            subtitle: "You've reached level 5. New colors unlocked.",
                            ctaTitle: "See unlocks"
                        )
                    }
                    PrimaryButton(title: "Quest done") {
                        payload = .init(
                            kind: .questComplete(rewardStars: 22),
                            title: "Quest complete!",
                            subtitle: "Tonight's bedtime quest finished. Off to dreamland.",
                            ctaTitle: "Sweet dreams"
                        )
                    }
                }
                .padding(28)
            }
            .celebrationToast(payload: $payload)
        }
    }
    return Demo()
}
