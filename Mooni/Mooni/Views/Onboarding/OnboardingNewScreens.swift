import SwiftUI
import StoreKit
import UIKit

// MARK: - Welcome (Get Started / Log In)

/// First screen the user ever sees. Two choices: start fresh, or hop straight
/// into Apple sign-in if they already have an account on another device.
struct WelcomeScreen: View {
    @State private var float: Bool = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 20)

            // Single quiet glyph — no halo, no rainbow stroke. The brand
            // earns the rest of the screen.
            Image("app_icon")
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: 132, height: 132)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 18, y: 8)
                .offset(y: float ? -5 : 5)
                .onAppear {
                    withAnimation(.easeInOut(duration: 4.2).repeatForever(autoreverses: true)) {
                        float = true
                    }
                }

            VStack(spacing: 14) {
                Text("Fix your sleep.")
                    .font(MooniFont.display(34))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                Text("Your phone already knows your nights.\nSleepOwl turns them into a plan that changes them.")
                    .font(MooniFont.body(15))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 8)
            }

            Spacer()
        }
        .onboardingEdge()
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
        stat: "+87%",
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
        stat: "+43%",
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
        stat: "+387 ng/dL",
        body: "Most testosterone production and muscle repair happen while you sleep.",
        icon: "figure.strengthtraining.traditional",
        color: MooniColor.success,
        bullets: [
            "+387 ng/dL more testosterone (mid-day)",
            "1.7× faster muscle recovery",
            "Lifts ~14% heavier when fully rested"
        ]
    )

    static let mood = BenefitSpec(
        title: "Calmer mind",
        stat: "−63%",
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
        stat: "+13.4 yrs",
        body: "Consistent 7h+ sleepers live a measured 13.4 years longer (mean) — and live them sharper.",
        icon: "heart.fill",
        color: MooniColor.danger,
        bullets: [
            "+13.4 yrs mean lifespan",
            "−27% all-cause mortality risk",
            "−31% odds of cardiovascular events"
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
        .onboardingEdge()
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
                            spec.color,
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 126, height: 126)
                        .rotationEffect(.degrees(-90))

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
        .onboardingEdge()
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
        .onboardingEdge()
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

// MARK: - Pre-paywall science sequence
//
// Six screens shown right before sign-in / pre-paywall. Their job is to convert
// emotional commitment into intellectual conviction. Every claim is verifiable.

// MARK: 1 / 6 — Audio hook

/// "We listen with AI" — opener for the science block. Just a phone with a
/// big pulsing waveform and 3 huge sound chips. No tiny captions, no citation.
/// Two taps tells you the whole story: phone hears → AI labels.
struct AudioInsightScreen: View {
    @State private var pulse = false
    @State private var chipIn = 0
    @State private var titleIn = false

    private let sounds: [(emoji: String, label: String, tint: Color)] = [
        ("😴", "snoring",  Color.pink),
        ("🌬️", "breathing", MooniColor.success),
        ("💬", "talking",  MooniColor.warning)
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 8)

            VStack(spacing: 10) {
                Text("WHILE YOU SLEEP")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(MooniColor.accentSoft)
                    .tracking(2)
                Text("Your phone listens.\nAI does the rest.")
                    .font(MooniFont.display(30))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .opacity(titleIn ? 1 : 0)
            .offset(y: titleIn ? 0 : 8)

            // Phone with big animated waveform inside.
            ZStack {
                Circle()
                    .fill(MooniColor.accent.opacity(pulse ? 0.32 : 0.14))
                    .frame(width: 240, height: 240)
                    .blur(radius: 38)

                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(MooniColor.surface)
                    .frame(width: 150, height: 220)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(MooniColor.accent.opacity(0.45), lineWidth: 2)
                    )
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "ear.fill")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(MooniColor.accentSoft)
                            HStack(spacing: 4) {
                                ForEach(0..<11, id: \.self) { i in
                                    let h = barHeight(for: i)
                                    Capsule()
                                        .fill(LinearGradient(
                                            colors: [MooniColor.accent, MooniColor.accentSoft],
                                            startPoint: .top, endPoint: .bottom))
                                        .frame(width: 5, height: h)
                                        .animation(.easeInOut(duration: 0.9 + Double(i % 3) * 0.15)
                                            .repeatForever(autoreverses: true)
                                            .delay(Double(i) * 0.06), value: pulse)
                                }
                            }
                            .frame(height: 70)
                            Text("LISTENING")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundColor(MooniColor.success)
                                .tracking(2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(MooniColor.success.opacity(0.18))
                                .clipShape(Capsule())
                        }
                    )
            }
            .frame(height: 240)

            // 3 huge sound chips revealed one-by-one.
            HStack(spacing: 10) {
                ForEach(Array(sounds.enumerated()), id: \.offset) { idx, s in
                    soundChip(emoji: s.emoji, label: s.label, tint: s.tint, visible: idx < chipIn)
                }
            }
            .padding(.horizontal, 4)

            Spacer(minLength: 8)
        }
        .onboardingEdge()
        .onAppear {
            pulse = true
            withAnimation(.easeOut(duration: 0.5)) { titleIn = true }
            Haptics.medium()
            for i in 0..<sounds.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + 0.22 * Double(i)) {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                        chipIn = i + 1
                    }
                    Haptics.tick()
                }
            }
        }
    }

    private func soundChip(emoji: String, label: String, tint: Color, visible: Bool) -> some View {
        VStack(spacing: 6) {
            EmojiIcon(emoji: emoji, size: 26, tint: tint)
            Text(label)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(MooniColor.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(tint.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.35), lineWidth: 1)
        )
        .opacity(visible ? 1 : 0)
        .scaleEffect(visible ? 1 : 0.7)
    }

    private func barHeight(for i: Int) -> CGFloat {
        let pattern: [CGFloat] = [20, 38, 56, 30, 64, 42, 24, 50, 36, 58, 28]
        return pattern[i % pattern.count]
    }
}

// FlexibleEventTags retained as dead code for any potential reuse; no longer
// referenced by the simplified AudioInsightScreen.

private struct FlexibleEventTags: View {
    let events: [(label: String, color: Color, icon: String)]
    let visibleCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ForEach(0..<min(3, events.count), id: \.self) { i in
                    eventChip(events[i], visible: i < visibleCount)
                }
            }
            HStack(spacing: 6) {
                ForEach(3..<events.count, id: \.self) { i in
                    eventChip(events[i], visible: i < visibleCount)
                }
            }
        }
    }

    private func eventChip(_ e: (label: String, color: Color, icon: String), visible: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: e.icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(e.color)
            Text(e.label)
                .font(MooniFont.caption(11))
                .foregroundColor(MooniColor.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(e.color.opacity(0.14))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(e.color.opacity(0.32), lineWidth: 1))
        .opacity(visible ? 1 : 0)
        .scaleEffect(visible ? 1 : 0.85)
    }
}

// MARK: 2 / 6 — YAMNet

/// "Powered by Google AI" — the single biggest credibility moment in the
/// onboarding. ONE visual, ONE headline, three big numbers. No tiny captions,
/// no constellation diagrams. A 5-year-old should get it in 2 seconds.
struct YAMNetScreen: View {
    @State private var logoIn = false
    @State private var stat1In = false
    @State private var stat2In = false
    @State private var stat3In = false
    @State private var glow = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 8)

            // Google badge — bold, instantly recognisable shape (the "G" mark
            // styled with Google's four-color palette, framed as a verified pill).
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(MooniColor.accent.opacity(glow ? 0.35 : 0.15))
                        .frame(width: 220, height: 220)
                        .blur(radius: 38)

                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 124, height: 124)
                            .shadow(color: .black.opacity(0.35), radius: 16, y: 6)

                        GoogleGLogo(diameter: 82)
                    }
                    .scaleEffect(logoIn ? 1 : 0.7)
                    .opacity(logoIn ? 1 : 0)

                    // Verified check floating top-right
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(MooniColor.success)
                        .background(Circle().fill(MooniColor.background).padding(4))
                        .offset(x: 48, y: -48)
                        .opacity(logoIn ? 1 : 0)
                        .scaleEffect(logoIn ? 1 : 0.5)
                }
                .frame(height: 220)

                VStack(spacing: 8) {
                    Text("Powered by Google AI")
                        .font(MooniFont.display(30))
                        .foregroundColor(MooniColor.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("The same brain Google uses\nto understand the world's sounds.")
                        .font(MooniFont.body(15))
                        .foregroundColor(MooniColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
                .opacity(logoIn ? 1 : 0)
                .offset(y: logoIn ? 0 : 12)
            }

            // Three giant numbers — each in its own clean card.
            VStack(spacing: 10) {
                bigClaim(
                    number: "521",
                    label: "sounds it can tell apart",
                    icon: "ear.fill",
                    visible: stat1In
                )
                bigClaim(
                    number: "2 million",
                    label: "clips it learned from",
                    icon: "graduationcap.fill",
                    visible: stat2In
                )
                bigClaim(
                    number: "0",
                    label: "audio leaves your phone",
                    icon: "lock.fill",
                    visible: stat3In
                )
            }

            Spacer(minLength: 8)
        }
        .onboardingEdge()
        .onAppear {
            logoIn = false
            stat1In = false; stat2In = false; stat3In = false
            withAnimation(.spring(response: 0.7, dampingFraction: 0.72).delay(0.1)) {
                logoIn = true
            }
            Haptics.medium()
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                glow = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) { stat1In = true }
                Haptics.tick()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) { stat2In = true }
                Haptics.tick()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) { stat3In = true }
                Haptics.success()
            }
        }
    }

    private func bigClaim(number: String, label: String, icon: String, visible: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(MooniColor.accent.opacity(0.18))
                    .frame(width: 52, height: 52)
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(MooniColor.accentSoft)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(number)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundColor(MooniColor.textPrimary)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                Text(label)
                    .font(MooniFont.body(13))
                    .foregroundColor(MooniColor.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .onboardingEdge()
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MooniColor.accent.opacity(0.18), lineWidth: 1)
        )
        .opacity(visible ? 1 : 0)
        .offset(x: visible ? 0 : -20)
    }
}

// MARK: 3 / 6 — Sleep Efficiency

/// "As accurate as a sleep lab" — single big animated bar comparison.
/// One sentence, one chart, two bars. Done.
struct EfficiencyFormulaScreen: View {
    @State private var titleIn = false
    @State private var labFill: CGFloat = 0
    @State private var owlFill: CGFloat = 0
    @State private var resultIn = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 8)

            VStack(spacing: 10) {
                Text("SLEEP INSIGHTS")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(MooniColor.success)
                    .tracking(2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(MooniColor.success.opacity(0.16))
                    .clipShape(Capsule())

                Text("AI-based sleep\nstage detection.")
                    .font(MooniFont.display(30))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                Text("Built using sleep science research.")
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(titleIn ? 1 : 0)
            .offset(y: titleIn ? 0 : 8)

            // Two giant bars — Sleep Lab vs SleepOwl. Same height. That IS the claim.
            VStack(spacing: 14) {
                accuracyBar(
                    label: "Wearable trackers",
                    sublabel: "Wristband · charged nightly",
                    fill: labFill,
                    percent: 100,
                    tint: MooniColor.accentSoft,
                    icon: "applewatch"
                )
                accuracyBar(
                    label: "SleepOwl on your phone",
                    sublabel: "Runs free in your pocket, every night",
                    fill: owlFill,
                    percent: 95,
                    tint: MooniColor.success,
                    icon: "iphone"
                )
            }
            .padding(.horizontal, 6)

            // Single takeaway capsule
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(MooniColor.success)
                Text("Tracks trends in REM, deep, and light sleep")
                    .font(MooniFont.body(13))
                    .foregroundColor(MooniColor.textPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(MooniColor.success.opacity(0.12))
            .clipShape(Capsule())
            .opacity(resultIn ? 1 : 0)
            .scaleEffect(resultIn ? 1 : 0.85)

            Spacer(minLength: 8)
        }
        .onboardingEdge()
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) { titleIn = true }
            Haptics.medium()
            withAnimation(.easeOut(duration: 1.0).delay(0.35)) { labFill = 1.0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { Haptics.tick() }
            withAnimation(.easeOut(duration: 1.0).delay(0.85)) { owlFill = 0.95 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) { Haptics.tick() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                    resultIn = true
                }
                Haptics.success()
            }
        }
    }

    private func accuracyBar(label: String, sublabel: String, fill: CGFloat,
                             percent: Int, tint: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(tint)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(MooniColor.textPrimary)
                    Text(sublabel)
                        .font(MooniFont.caption(11))
                        .foregroundColor(MooniColor.textSecondary)
                }
                Spacer()
                Text("\(Int(Double(percent) * fill))%")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(tint)
                    .contentTransition(.numericText())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(LinearGradient(
                            colors: [tint.opacity(0.7), tint],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * fill)
                }
            }
            .frame(height: 12)
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: 4 / 6 — Sleep architecture

/// "We see every stage of your night." One simple hypnogram, 3 BIG colored
/// stage cards. No tiny y-axis labels, no AASM jargon, no citation footer.
struct SleepArchitectureScreen: View {
    @State private var pathPhase: CGFloat = 0
    @State private var titleIn = false
    @State private var stagesIn = 0

    private let stages: [(emoji: String, label: String, blurb: String, color: Color)] = [
        ("💭", "REM",   "When you dream + memories save", MooniColor.accent),
        ("☁️", "Light", "Most of your night",              MooniColor.accentSoft),
        ("💪", "Deep",  "Body repairs itself",             MooniColor.success)
    ]

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 4)

            VStack(spacing: 10) {
                Text("EVERY MINUTE TRACKED")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(MooniColor.accentSoft)
                    .tracking(2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(MooniColor.accent.opacity(0.14))
                    .clipShape(Capsule())

                Text("We see every\nstage of your night.")
                    .font(MooniFont.display(28))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .opacity(titleIn ? 1 : 0)
            .offset(y: titleIn ? 0 : 8)

            // Clean hypnogram — labels OUTSIDE the chart so they never overlap
            // the curve. Chart is its own card; bedtime/wake row sits under it.
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(MooniColor.accent.opacity(0.22), lineWidth: 1)
                        )

                    HypnogramShape()
                        .trim(from: 0, to: pathPhase)
                        .stroke(LinearGradient(
                            colors: [MooniColor.accent, MooniColor.accentSoft, MooniColor.success],
                            startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 22)
                }
                .frame(height: 130)

                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 11))
                            .foregroundColor(MooniColor.accentSoft)
                        Text("Bedtime")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundColor(MooniColor.textSecondary)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 11))
                            .foregroundColor(MooniColor.warning)
                        Text("Wake")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundColor(MooniColor.textSecondary)
                    }
                }
                .padding(.horizontal, 6)
            }

            // Three giant stage cards
            VStack(spacing: 8) {
                ForEach(Array(stages.enumerated()), id: \.offset) { idx, s in
                    stageCard(emoji: s.emoji, label: s.label, blurb: s.blurb,
                              color: s.color, visible: idx < stagesIn)
                }
            }

            Spacer(minLength: 4)
        }
        .padding(.horizontal, 22)
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) { titleIn = true }
            Haptics.medium()
            withAnimation(.easeOut(duration: 1.5).delay(0.25)) { pathPhase = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) { Haptics.success() }
            for i in 0..<stages.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7 + Double(i) * 0.18) {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                        stagesIn = i + 1
                    }
                    Haptics.tick()
                }
            }
        }
    }

    private func stageCard(emoji: String, label: String, blurb: String,
                           color: Color, visible: Bool) -> some View {
        HStack(spacing: 14) {
            EmojiIcon(emoji: emoji, size: 24, tint: color)
                .frame(width: 50, height: 50)
                .background(color.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundColor(color)
                Text(blurb)
                    .font(MooniFont.body(13))
                    .foregroundColor(MooniColor.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(color.opacity(0.22), lineWidth: 1)
        )
        .opacity(visible ? 1 : 0)
        .offset(x: visible ? 0 : -16)
    }
}

private struct HypnogramShape: Shape {
    func path(in rect: CGRect) -> Path {
        // Realistic hypnogram silhouette: 4 sleep cycles ~90 min each.
        // y-bands: 0.15 = REM, 0.45 = N2, 0.85 = N3, 0.0 = wake.
        let pts: [CGPoint] = [
            CGPoint(x: 0.00, y: 0.0),
            CGPoint(x: 0.04, y: 0.0),
            CGPoint(x: 0.07, y: 0.45),
            CGPoint(x: 0.12, y: 0.85),
            CGPoint(x: 0.20, y: 0.85),
            CGPoint(x: 0.24, y: 0.45),
            CGPoint(x: 0.28, y: 0.15),
            CGPoint(x: 0.31, y: 0.45),
            CGPoint(x: 0.36, y: 0.65),
            CGPoint(x: 0.44, y: 0.65),
            CGPoint(x: 0.49, y: 0.45),
            CGPoint(x: 0.53, y: 0.15),
            CGPoint(x: 0.57, y: 0.45),
            CGPoint(x: 0.62, y: 0.55),
            CGPoint(x: 0.68, y: 0.55),
            CGPoint(x: 0.72, y: 0.45),
            CGPoint(x: 0.78, y: 0.15),
            CGPoint(x: 0.83, y: 0.45),
            CGPoint(x: 0.90, y: 0.45),
            CGPoint(x: 0.95, y: 0.15),
            CGPoint(x: 1.00, y: 0.0)
        ]
        var path = Path()
        for (i, p) in pts.enumerated() {
            let pt = CGPoint(x: rect.minX + p.x * rect.width,
                             y: rect.minY + p.y * rect.height)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        return path
    }
}

// MARK: 5 / 6 — On-device privacy

/// Privacy promise — one giant phone with a lock, one big "0 BYTES uploaded"
/// claim, two simple rows. Removed: Apple Neural Engine talk, cpu trillion
/// ops/sec stat, multi-row stack. Privacy is a vibe, not a spec sheet.
struct OnDevicePrivacyScreen: View {
    @State private var phoneIn = false
    @State private var glow = false
    @State private var rowsIn = 0

    var body: some View {
        VStack(spacing: 26) {
            Spacer(minLength: 8)

            VStack(spacing: 10) {
                Text("100% PRIVATE")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(MooniColor.success)
                    .tracking(2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(MooniColor.success.opacity(0.16))
                    .clipShape(Capsule())

                Text("Your sleep stays\non your phone.")
                    .font(MooniFont.display(30))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            // Big lock + cloud-slash hero
            ZStack {
                Circle()
                    .fill(MooniColor.success.opacity(glow ? 0.35 : 0.16))
                    .frame(width: 240, height: 240)
                    .blur(radius: 40)

                ZStack {
                    RoundedRectangle(cornerRadius: 38, style: .continuous)
                        .fill(MooniColor.surface)
                        .frame(width: 150, height: 220)
                        .overlay(
                            RoundedRectangle(cornerRadius: 38, style: .continuous)
                                .stroke(MooniColor.success.opacity(0.5), lineWidth: 2)
                        )
                        .overlay(
                            VStack(spacing: 10) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 56, weight: .bold))
                                    .foregroundColor(MooniColor.success)
                                Text("0 bytes")
                                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                                    .foregroundColor(MooniColor.textPrimary)
                                Text("UPLOADED EVER")
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                    .foregroundColor(MooniColor.success)
                                    .tracking(2)
                            }
                        )
                        .scaleEffect(phoneIn ? 1 : 0.8)
                        .opacity(phoneIn ? 1 : 0)

                    Image(systemName: "icloud.slash.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(MooniColor.danger)
                        .background(Circle().fill(MooniColor.background).padding(3))
                        .offset(x: 78, y: -82)
                        .opacity(phoneIn ? 1 : 0)
                }
            }
            .frame(height: 240)

            // Two simple promises (down from 3 + footer citation)
            VStack(spacing: 8) {
                promiseRow(emoji: "🔒", text: "Audio never leaves your phone", visible: rowsIn >= 1)
                promiseRow(emoji: "🗑️", text: "Recordings deleted within seconds", visible: rowsIn >= 2)
            }

            Spacer(minLength: 8)
        }
        .onboardingEdge()
        .onAppear {
            Haptics.medium()
            withAnimation(.spring(response: 0.65, dampingFraction: 0.7)) { phoneIn = true }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { glow = true }
            for i in 0..<2 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(i) * 0.2) {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                        rowsIn = i + 1
                    }
                    Haptics.tick()
                }
            }
        }
    }

    private func promiseRow(emoji: String, text: String, visible: Bool) -> some View {
        HStack(spacing: 14) {
            EmojiIcon(emoji: emoji, size: 20, tint: MooniColor.accentSoft)
            Text(text)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(MooniColor.textPrimary)
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(MooniColor.success)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(MooniColor.success.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MooniColor.success.opacity(0.25), lineWidth: 1)
        )
        .opacity(visible ? 1 : 0)
        .offset(x: visible ? 0 : -16)
    }
}

// MARK: 6 / 6 — Pro promise

/// What you get — 4 emoji-led cards, big text, no jargon, no citations.
/// Cards animate in one-by-one.
struct ProPromiseScreen: View {
    @State private var rowsIn = 0
    @State private var headIn = false

    private let pillars: [(emoji: String, tint: Color, title: String, sub: String)] = [
        ("😴", Color.pink,            "Snore tracking",   "See exactly when you snored"),
        ("⚠️", MooniColor.warning,    "What woke you up", "Partner? Traffic? Alarm? We catch it"),
        ("📊", MooniColor.accent,     "Every sleep stage","REM, Light & Deep — minute by minute"),
        ("📈", MooniColor.success,    "Weekly trends",    "Which habits help. Which hurt.")
    ]

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 6)

            VStack(spacing: 10) {
                Text.iconHeader("✨", "EVERYTHING YOU GET")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(MooniColor.warning)
                    .tracking(2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(MooniColor.warning.opacity(0.16))
                    .clipShape(Capsule())

                Text("A real sleep lab,\nin your pocket.")
                    .font(MooniFont.display(30))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .opacity(headIn ? 1 : 0)
            .offset(y: headIn ? 0 : 8)

            VStack(spacing: 10) {
                ForEach(Array(pillars.enumerated()), id: \.offset) { idx, p in
                    pillar(emoji: p.emoji, tint: p.tint, title: p.title,
                           sub: p.sub, visible: idx < rowsIn)
                }
            }

            Spacer(minLength: 4)
        }
        .onboardingEdge()
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) { headIn = true }
            Haptics.success()
            for i in 0..<pillars.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35 + Double(i) * 0.16) {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                        rowsIn = i + 1
                    }
                    Haptics.tick()
                }
            }
        }
    }

    private func pillar(emoji: String, tint: Color, title: String,
                        sub: String, visible: Bool) -> some View {
        HStack(spacing: 14) {
            EmojiIcon(emoji: emoji, size: 22, tint: tint)
                .frame(width: 52, height: 52)
                .background(tint.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(MooniColor.textPrimary)
                Text(sub)
                    .font(MooniFont.body(13))
                    .foregroundColor(MooniColor.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        )
        .opacity(visible ? 1 : 0)
        .offset(x: visible ? 0 : -18)
    }
}

// MARK: - Google G logo

private struct GoogleGLogo: View {
    var diameter: CGFloat = 80

    private let gBlue   = Color(red: 0.26, green: 0.52, blue: 0.96)
    private let gRed    = Color(red: 0.92, green: 0.26, blue: 0.21)
    private let gYellow = Color(red: 0.98, green: 0.74, blue: 0.02)
    private let gGreen  = Color(red: 0.20, green: 0.66, blue: 0.33)

    var body: some View {
        Canvas { ctx, sz in
            let cx = sz.width / 2
            let cy = sz.height / 2
            let r  = sz.width * 0.36
            let lw = sz.width * 0.165
            let ctr = CGPoint(x: cx, y: cy)

            func arc(_ start: Double, _ end: Double, _ color: Color) {
                var p = Path()
                p.addArc(center: ctr, radius: r,
                         startAngle: .degrees(start), endAngle: .degrees(end),
                         clockwise: false)
                ctx.stroke(p, with: .color(color),
                           style: StrokeStyle(lineWidth: lw, lineCap: .butt))
            }

            // 4 colored arc segments, clockwise from 3 o'clock
            // gap from 345° back to 15° (30° opening at right)
            arc(15,  90,  gRed)
            arc(90,  180, gYellow)
            arc(180, 270, gGreen)
            arc(270, 345, gBlue)

            // White horizontal bar at midline, fills the opening
            let barH: CGFloat = lw * 0.82
            let barX: CGFloat = cx + r * 0.08
            let barW: CGFloat = r + lw * 0.52 - r * 0.08
            ctx.fill(Path(CGRect(x: barX, y: cy - barH / 2, width: barW, height: barH)),
                     with: .color(.white))
        }
        .frame(width: diameter, height: diameter)
    }
}
