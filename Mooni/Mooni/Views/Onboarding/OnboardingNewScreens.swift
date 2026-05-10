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
    @State private var animateIn = false

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 16)

            ZStack {
                Circle()
                    .fill(spec.color.opacity(animateIn ? 0.38 : 0.18))
                    .frame(width: 200, height: 200)
                    .blur(radius: 32)

                Image(systemName: spec.icon)
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(LinearGradient(
                        colors: [.white, spec.color],
                        startPoint: .top, endPoint: .bottom))
                    .shadow(color: spec.color.opacity(0.6), radius: 16)
                    .scaleEffect(animateIn ? 1 : 0.6)
            }
            .onAppear {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) {
                    animateIn = true
                }
            }

            VStack(spacing: 8) {
                Text("Better sleep =")
                    .font(MooniFont.caption(13))
                    .foregroundColor(MooniColor.accentSoft)
                    .tracking(2)
                    .textCase(.uppercase)

                Text(spec.title)
                    .font(MooniFont.display(34))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)

                Text(spec.stat)
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundStyle(LinearGradient(
                        colors: [spec.color.opacity(0.85), spec.color],
                        startPoint: .leading, endPoint: .trailing))
                    .padding(.top, 4)

                Text(spec.body)
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
            }

            VStack(spacing: 10) {
                ForEach(Array(spec.bullets.enumerated()), id: \.offset) { _, line in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(spec.color)
                        Text(line)
                            .font(MooniFont.title(14))
                            .foregroundColor(MooniColor.textPrimary)
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 24)
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
