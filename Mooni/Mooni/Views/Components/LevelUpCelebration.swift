import SwiftUI
import UIKit

// MARK: - Presenter

/// Presents the full-screen level-up takeover in its OWN `UIWindow`, layered
/// above every sheet, cover, and tab — so it fires reliably the instant the pet
/// levels up, no matter what screen the user is on (the old toast only showed
/// up once the user happened to land on Home).
///
/// Driven from `RootView`, which observes `AppState.levelUpCelebration`.
@MainActor
final class LevelUpPresenter {
    static let shared = LevelUpPresenter()
    private init() {}

    private var window: UIWindow?

    /// Show the celebration for the level just reached. No-ops if one is already
    /// on screen (a multi-level jump still lands on the final level).
    func present(level: Int, petName: String) {
        guard window == nil, let scene = activeScene else { return }

        let win = UIWindow(windowScene: scene)
        win.windowLevel = .alert + 1          // above alerts, sheets, covers
        win.backgroundColor = .clear

        let host = UIHostingController(
            rootView: LevelUpCelebrationView(level: level, petName: petName) { [weak self] in
                self?.dismiss()
            }
        )
        host.view.backgroundColor = .clear
        win.rootViewController = host
        win.makeKeyAndVisible()
        window = win
    }

    private func dismiss() {
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
    }

    private var activeScene: UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }
}

// MARK: - Celebration view

/// A bright, app-pausing "you leveled up" moment: a glowing level badge that
/// pops to the new number, an XP bar that sweeps to full, confetti, and a
/// building haptic payoff. Deliberately light/airy — a hard cut away from the
/// dark app so it lands as a genuine dopamine beat.
struct LevelUpCelebrationView: View {
    let level: Int
    var petName: String = "SleepOwl"
    let onDismiss: () -> Void

    // Palette tuned for the bright backdrop (the app's dark tokens would wash
    // out here, so these are local).
    private let ink = Color(red: 0.17, green: 0.14, blue: 0.32)
    private let inkSoft = Color(red: 0.42, green: 0.37, blue: 0.58)
    private let violet = Color(red: 0.48, green: 0.42, blue: 0.96)
    private let violetDeep = Color(red: 0.36, green: 0.30, blue: 0.82)

    @State private var appeared = false
    @State private var barFill: CGFloat = 0
    @State private var displayedLevel: Int
    @State private var badgePulse = false
    @State private var ringSweep: CGFloat = 0
    @State private var showButton = false
    @State private var confettiTrigger = 0

    init(level: Int, petName: String = "SleepOwl", onDismiss: @escaping () -> Void) {
        self.level = level
        self.petName = petName
        self.onDismiss = onDismiss
        _displayedLevel = State(initialValue: max(1, level - 1))
    }

    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            ConfettiView(trigger: $confettiTrigger, count: 60, duration: 2.8)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()

                Text("LEVEL UP")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .tracking(5)
                    .foregroundStyle(violetDeep)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                badge
                    .padding(.top, 22)

                Text("Level \(displayedLevel)")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(ink)
                    .contentTransition(.numericText(value: Double(displayedLevel)))
                    .padding(.top, 22)

                Text("\(petName) is getting stronger every night.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 6)
                    .opacity(appeared ? 1 : 0)

                xpBar
                    .padding(.top, 26)
                    .padding(.horizontal, 44)

                Spacer()

                Button(action: dismiss) {
                    Text("Continue")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule().fill(
                                LinearGradient(colors: [violet, violetDeep],
                                               startPoint: .leading, endPoint: .trailing))
                        )
                        .shadow(color: violet.opacity(0.4), radius: 16, y: 8)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 16)
            }
        }
        .onAppear(perform: runSequence)
    }

    // MARK: Pieces

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 1.0, blue: 1.0),
                    Color(red: 0.95, green: 0.94, blue: 1.0),
                    Color(red: 0.90, green: 0.89, blue: 1.0)
                ],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(
                colors: [violet.opacity(0.28), .clear],
                center: .center, startRadius: 0, endRadius: 360
            )
            .opacity(appeared ? 1 : 0)
        }
    }

    private var badge: some View {
        ZStack {
            // Soft glow
            Circle()
                .fill(violet.opacity(0.35))
                .frame(width: 150, height: 150)
                .blur(radius: 34)
                .scaleEffect(badgePulse ? 1.15 : 0.9)

            // Sweeping ring that fills as the bar fills
            Circle()
                .stroke(violet.opacity(0.16), lineWidth: 10)
                .frame(width: 138, height: 138)
            Circle()
                .trim(from: 0, to: ringSweep)
                .stroke(
                    LinearGradient(colors: [violet, violetDeep],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 138, height: 138)

            // Filled core
            Circle()
                .fill(LinearGradient(colors: [violet, violetDeep],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 104, height: 104)
                .shadow(color: violetDeep.opacity(0.5), radius: 18, y: 8)

            Image(systemName: "moon.stars.fill")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: violetDeep.opacity(0.6), radius: 6)
        }
        .scaleEffect((appeared ? 1 : 0.5) * (badgePulse ? 1.06 : 1.0))
    }

    private var xpBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(violet.opacity(0.14))
                Capsule()
                    .fill(LinearGradient(colors: [MooniColor.xpGreen, MooniColor.xpGreenSoft],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(12, geo.size.width * barFill))
                    .shadow(color: MooniColor.xpGreen.opacity(0.5), radius: 6)
            }
        }
        .frame(height: 14)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: Choreography

    private func runSequence() {
        Haptics.soft()
        withAnimation(.easeOut(duration: 0.4)) { appeared = true }

        // Bar + ring sweep to full together.
        withAnimation(.easeInOut(duration: 1.0).delay(0.25)) {
            barFill = 1
            ringSweep = 1
        }

        // Rising tick haptics as it fills.
        for (i, t) in [0.35, 0.6, 0.85, 1.05].enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + t) {
                _ = i
                Haptics.tick()
            }
        }

        // Payoff: number flips up, badge pops, confetti, success haptic.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.28) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
                displayedLevel = level
                badgePulse = true
            }
            confettiTrigger += 1
            Haptics.success()
            if Haptics.hapticsEnabled {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.55) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { badgePulse = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            withAnimation(.easeOut(duration: 0.35)) { showButton = true }
        }
    }

    private func dismiss() {
        Haptics.tap()
        withAnimation(.easeIn(duration: 0.25)) { appeared = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) { onDismiss() }
    }
}

#Preview {
    LevelUpCelebrationView(level: 5, petName: "SleepOwl", onDismiss: {})
}
