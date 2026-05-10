import SwiftUI
import StoreKit
import UIKit

// MARK: - Welcome (Get Started / Log In)

/// First screen the user ever sees. Two choices: start fresh, or hop straight
/// into Apple sign-in if they already have an account on another device.
struct WelcomeScreen: View {
    @State private var glow: Bool = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 24)

            ZStack {
                Circle()
                    .fill(MooniColor.accent.opacity(glow ? 0.40 : 0.22))
                    .frame(width: 240, height: 240)
                    .blur(radius: 36)

                Image("owl_base")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 170, height: 170)
                    .shadow(color: MooniColor.accent.opacity(0.55), radius: 20)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                    glow = true
                }
            }

            VStack(spacing: 10) {
                Text("SleepOwl")
                    .font(MooniFont.display(40))
                    .foregroundColor(MooniColor.textPrimary)
                    .tracking(0.5)
                Text("Sleep better. Grow stronger.")
                    .font(MooniFont.body(16))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(.horizontal, 28)
    }
}

// MARK: - Benefit reel

struct BenefitSpec {
    let title: String
    let stat: String
    let body: String
    let icon: String
    let color: Color
    let bullets: [String]

    static let energy = BenefitSpec(
        title: "All-day energy",
        stat: "+92%",
        body: "Sleep is the cleanest way to feel awake. Members report it in their first week.",
        icon: "bolt.fill",
        color: MooniColor.warning,
        bullets: [
            "Wake up without the snooze loop",
            "No more 3pm crash",
            "Real energy without caffeine"
        ]
    )

    static let focus = BenefitSpec(
        title: "Sharper focus",
        stat: "+40%",
        body: "Deep sleep is when memories consolidate and your brain clears the noise.",
        icon: "brain.head.profile",
        color: MooniColor.accent,
        bullets: [
            "Faster thinking",
            "Better memory recall",
            "Stay locked in longer"
        ]
    )

    static let body = BenefitSpec(
        title: "Stronger body",
        stat: "+30%",
        body: "Most testosterone production and muscle repair happen while you sleep.",
        icon: "figure.strengthtraining.traditional",
        color: MooniColor.success,
        bullets: [
            "Higher testosterone",
            "Faster muscle recovery",
            "Better gym performance"
        ]
    )

    static let mood = BenefitSpec(
        title: "Calmer mind",
        stat: "−65%",
        body: "Sleep regulates the brain's emotional thermostat. Less anxiety, fewer spirals.",
        icon: "face.smiling.fill",
        color: .pink,
        bullets: [
            "Steadier mood",
            "Lower anxiety & stress",
            "More motivation, more discipline"
        ]
    )

    static let looks = BenefitSpec(
        title: "Better looking",
        stat: "Visible",
        body: "Your face shows your sleep first. Skin repairs, eye bags fade, you look fresh.",
        icon: "sparkles",
        color: MooniColor.accentSoft,
        bullets: [
            "Brighter skin",
            "Less puffy eyes",
            "Easier fat loss & appetite control"
        ]
    )

    static let longevity = BenefitSpec(
        title: "A longer life",
        stat: "Years",
        body: "Consistent sleep is one of the strongest predictors of lifespan and disease risk.",
        icon: "heart.fill",
        color: MooniColor.danger,
        bullets: [
            "Stronger immune system",
            "Lower disease risk",
            "More years, lived better"
        ]
    )
}

struct BenefitScreen: View {
    let spec: BenefitSpec
    @State private var heroIn = false
    @State private var copyIn = false
    @State private var rowsVisible = 0

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 8)

            BenefitHeroCard(spec: spec, isVisible: heroIn)
                .frame(height: 228)
                .padding(.horizontal, 2)

            VStack(spacing: 8) {
                Text("Better sleep =")
                    .font(MooniFont.caption(13))
                    .foregroundColor(MooniColor.accentSoft)
                    .tracking(2)
                    .textCase(.uppercase)

                Text(spec.title)
                    .font(MooniFont.display(30))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)

                Text(spec.body)
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
            }
            .opacity(copyIn ? 1 : 0)
            .offset(y: copyIn ? 0 : 10)

            VStack(spacing: 9) {
                ForEach(Array(spec.bullets.enumerated()), id: \.offset) { index, line in
                    BenefitProofRow(
                        text: line,
                        icon: index == 0 ? spec.icon : "checkmark.circle.fill",
                        color: spec.color,
                        progress: rowProgress(index),
                        isVisible: index < rowsVisible
                    )
                }
            }
            .padding(.horizontal, 2)

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 24)
        .onAppear {
            heroIn = false
            copyIn = false
            rowsVisible = 0
            withAnimation(.spring(response: 0.85, dampingFraction: 0.82).delay(0.05)) {
                heroIn = true
            }
            withAnimation(.easeOut(duration: 0.7).delay(0.35)) {
                copyIn = true
            }
            for i in 0..<spec.bullets.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.68 + Double(i) * 0.18) {
                    withAnimation(.spring(response: 0.56, dampingFraction: 0.84)) {
                        rowsVisible = i + 1
                    }
                }
            }
        }
    }

    private func rowProgress(_ index: Int) -> CGFloat {
        let values: [CGFloat] = [0.96, 0.78, 0.62]
        return values[min(index, values.count - 1)]
    }
}

private struct BenefitHeroCard: View {
    let spec: BenefitSpec
    let isVisible: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.10),
                            spec.color.opacity(0.10),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(spec.color.opacity(0.20), lineWidth: 1)
                )

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 12)
                        .frame(width: 126, height: 126)
                    Circle()
                        .trim(from: 0, to: isVisible ? 0.78 : 0.08)
                        .stroke(
                            LinearGradient(
                                colors: [spec.color.opacity(0.55), spec.color],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 126, height: 126)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: spec.color.opacity(0.35), radius: 12)

                    Image(systemName: spec.icon)
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(LinearGradient(
                            colors: [.white, spec.color],
                            startPoint: .top,
                            endPoint: .bottom))
                        .scaleEffect(isVisible ? 1 : 0.78)
                }

                VStack(spacing: 2) {
                    Text(spec.stat)
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(LinearGradient(
                            colors: [spec.color.opacity(0.82), spec.color],
                            startPoint: .leading,
                            endPoint: .trailing))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text("key signal")
                        .font(MooniFont.caption(11))
                        .foregroundColor(MooniColor.textMuted)
                        .tracking(1.2)
                        .textCase(.uppercase)
                }
            }
        }
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 18)
        .scaleEffect(isVisible ? 1 : 0.96)
    }
}

private struct BenefitProofRow: View {
    let text: String
    let icon: String
    let color: Color
    let progress: CGFloat
    let isVisible: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(text)
                    .font(MooniFont.title(14))
                    .foregroundColor(MooniColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(LinearGradient(colors: [color.opacity(0.65), color],
                                                 startPoint: .leading,
                                                 endPoint: .trailing))
                            .frame(width: geo.size.width * progress * (isVisible ? 1 : 0.05))
                    }
                }
                .frame(height: 6)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 13)
        .background(Color.white.opacity(0.065))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(color.opacity(0.12), lineWidth: 1)
        )
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 12)
    }
}

// MARK: - Rate App

/// Wraps `SKStoreReviewController.requestReview` so we can call it from a
/// button without UIKit import noise. The system decides whether to show the
/// sheet, but since we only ask once during onboarding it almost always does.
enum OnboardingRatingPrompt {
    @MainActor
    static func request() {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else { return }
        AppStore.requestReview(in: scene)
    }
}

struct RateAppScreen: View {
    @State private var twinkle = false

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 12)

            ZStack {
                Circle()
                    .fill(MooniColor.warning.opacity(twinkle ? 0.45 : 0.22))
                    .frame(width: 220, height: 220)
                    .blur(radius: 36)

                HStack(spacing: 6) {
                    ForEach(0..<5) { i in
                        Image(systemName: "star.fill")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(MooniColor.warning)
                            .scaleEffect(twinkle ? 1.0 : 0.85)
                            .animation(
                                .spring(response: 0.5)
                                    .delay(Double(i) * 0.08),
                                value: twinkle
                            )
                    }
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    twinkle = true
                }
            }

            VStack(spacing: 10) {
                Text("Help SleepOwl grow")
                    .font(MooniFont.display(28))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)

                Text("A 5-star rating is what lets us keep building features for you. It only takes a tap.")
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Sign In with Apple

struct SignInScreen: View {
    let state: OnboardingView.AuthState
    let errorMessage: String?

    @State private var glow = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 16)

            ZStack {
                Circle()
                    .fill(MooniColor.accent.opacity(glow ? 0.40 : 0.20))
                    .frame(width: 200, height: 200)
                    .blur(radius: 32)

                Image(systemName: state == .signedIn ? "checkmark.seal.fill" : "person.crop.circle.badge.checkmark")
                    .font(.system(size: 70, weight: .bold))
                    .foregroundStyle(LinearGradient(
                        colors: [.white, MooniColor.accentSoft],
                        startPoint: .top, endPoint: .bottom))
                    .shadow(color: MooniColor.accent.opacity(0.55), radius: 14)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    glow = true
                }
            }

            VStack(spacing: 10) {
                Text(state == .signedIn ? "You're all set" : "Save your progress")
                    .font(MooniFont.display(28))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)

                Text(state == .signedIn
                     ? "Your sleep history will sync to all your devices."
                     : "Sign in with Apple to back up your sleep data and unlock shared widgets later.")
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }

            VStack(spacing: 10) {
                signInBenefitRow(icon: "icloud.fill",     text: "Backup across devices")
                signInBenefitRow(icon: "person.2.fill",   text: "Share widgets with friends")
                signInBenefitRow(icon: "lock.shield.fill", text: "Private — only your data")
            }
            .padding(.horizontal, 4)

            if let err = errorMessage {
                Text(err)
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.danger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 24)
    }

    private func signInBenefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(MooniColor.accentSoft)
                .frame(width: 30, height: 30)
                .background(MooniColor.accent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(text)
                .font(MooniFont.title(14))
                .foregroundColor(MooniColor.textPrimary)
            Spacer()
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
