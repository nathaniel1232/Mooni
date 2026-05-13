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

// MARK: - Pre-paywall science sequence
//
// Six screens shown right before sign-in / pre-paywall. Their job is to convert
// emotional commitment into intellectual conviction. Every claim is verifiable.

// MARK: 1 / 6 — Audio hook

struct AudioInsightScreen: View {
    @State private var pulse = false
    @State private var eventsIn = 0
    @State private var waveAmp: CGFloat = 0

    private let events: [(label: String, color: Color, icon: String)] = [
        ("snore",    Color.pink,                  "wind"),
        ("speech",   MooniColor.warning,          "bubble.left.fill"),
        ("breath",   MooniColor.success,          "lungs.fill"),
        ("movement", MooniColor.accent,           "arrow.left.and.right"),
        ("silence",  MooniColor.accentSoft,       "moon.stars.fill")
    ]

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 4)

            VStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(LinearGradient(
                        colors: [MooniColor.accent, MooniColor.accentSoft],
                        startPoint: .leading, endPoint: .trailing))
                Text("THE SCIENCE")
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.accentSoft)
                    .tracking(2)
                Text("Your phone hears more\nthan you think.")
                    .font(MooniFont.display(26))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
            }

            // Animated waveform
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(MooniColor.accent.opacity(0.18), lineWidth: 1)
                    )

                HStack(spacing: 3) {
                    ForEach(0..<32, id: \.self) { i in
                        let h = barHeight(for: i)
                        Capsule()
                            .fill(LinearGradient(
                                colors: [MooniColor.accent.opacity(0.8), MooniColor.accentSoft],
                                startPoint: .top, endPoint: .bottom))
                            .frame(width: 4, height: h)
                            .animation(.easeInOut(duration: 0.9 + Double(i % 5) * 0.1)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.04),
                                       value: pulse)
                    }
                }
                .frame(height: 80)
            }
            .frame(height: 110)
            .padding(.horizontal, 4)

            // Event chips floating up from waveform
            VStack(alignment: .leading, spacing: 8) {
                Text("EACH SOUND IS CLASSIFIED")
                    .font(MooniFont.caption(10))
                    .foregroundColor(MooniColor.textMuted)
                    .tracking(1.5)

                FlexibleEventTags(events: events, visibleCount: eventsIn)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Playable demo — 3 emoji buttons for real recognized sounds
            VStack(alignment: .leading, spacing: 8) {
                Text("HEAR THREE OF THEM")
                    .font(MooniFont.caption(10))
                    .foregroundColor(MooniColor.textMuted)
                    .tracking(1.5)
                HStack(spacing: 8) {
                    AudioSampleButton(emoji: "😴", label: "Snore",      resource: "sample_snore",     tint: Color.pink)
                    AudioSampleButton(emoji: "💬", label: "Sleep talk", resource: "sample_sleeptalk", tint: MooniColor.warning)
                    AudioSampleButton(emoji: "🌬️", label: "Breath",     resource: "sample_breath",    tint: MooniColor.success)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("Source: CDC, Sleep & Sleep Disorders, 2023")
                .font(MooniFont.caption(9))
                .foregroundColor(MooniColor.textMuted)

            Spacer(minLength: 4)
        }
        .padding(.horizontal, 22)
        .onAppear {
            pulse = true
            Haptics.medium()
            for i in 0..<events.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 + 0.18 * Double(i)) {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                        eventsIn = i + 1
                    }
                    Haptics.tick()
                }
            }
        }
    }

    private func barHeight(for i: Int) -> CGFloat {
        let pattern: [CGFloat] = [12, 28, 44, 70, 52, 30, 22, 38, 60, 40, 24, 18, 32, 50, 76, 58, 36, 20]
        return pattern[i % pattern.count]
    }
}

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

struct YAMNetScreen: View {
    @State private var dotsIn = 0
    @State private var statsIn = false

    private let highlights: [(angle: Double, label: String, color: Color)] = [
        (0,    "snore",    Color.pink),
        (60,   "speech",   MooniColor.warning),
        (120,  "breath",   MooniColor.success),
        (180,  "movement", MooniColor.accent),
        (240,  "cough",    MooniColor.accentSoft),
        (300,  "silence",  MooniColor.warning)
    ]

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 4)

            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("GOOGLE RESEARCH · 2018")
                        .font(MooniFont.caption(10))
                        .tracking(1.6)
                }
                .foregroundColor(MooniColor.success)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(MooniColor.success.opacity(0.14))
                .clipShape(Capsule())

                Text("Powered by YAMNet")
                    .font(MooniFont.display(28))
                    .foregroundColor(MooniColor.textPrimary)
                Text("the AI that\nrecognizes your night.")
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Constellation visual
            ZStack {
                Circle()
                    .stroke(MooniColor.accent.opacity(0.18), lineWidth: 1)
                    .frame(width: 200, height: 200)
                Circle()
                    .stroke(MooniColor.accent.opacity(0.12), lineWidth: 1)
                    .frame(width: 140, height: 140)

                // Background constellation dots (representing 521 classes)
                ForEach(0..<48, id: \.self) { i in
                    let angle = Double(i) * (360.0 / 48.0)
                    let radius: CGFloat = (i % 3 == 0) ? 100 : (i % 2 == 0 ? 75 : 55)
                    Circle()
                        .fill(MooniColor.accentSoft.opacity(0.35))
                        .frame(width: 3, height: 3)
                        .offset(x: radius * cos(angle * .pi / 180),
                                y: radius * sin(angle * .pi / 180))
                        .opacity(i < dotsIn * 4 ? 1 : 0)
                }

                // Highlighted sleep-relevant labels
                ForEach(Array(highlights.enumerated()), id: \.offset) { idx, h in
                    let r: CGFloat = 110
                    HStack(spacing: 4) {
                        Circle().fill(h.color).frame(width: 6, height: 6)
                        Text(h.label)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(MooniColor.textPrimary)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(h.color.opacity(0.18))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(h.color.opacity(0.4), lineWidth: 1))
                    .offset(x: r * cos(h.angle * .pi / 180),
                            y: r * sin(h.angle * .pi / 180))
                    .opacity(idx < dotsIn ? 1 : 0)
                    .scaleEffect(idx < dotsIn ? 1 : 0.8)
                }

                // Center node
                ZStack {
                    Circle().fill(MooniColor.accent.opacity(0.22)).frame(width: 64, height: 64)
                    Circle().stroke(MooniColor.accent.opacity(0.6), lineWidth: 1.5).frame(width: 64, height: 64)
                    VStack(spacing: 1) {
                        Text("521")
                            .font(.system(size: 19, weight: .heavy, design: .rounded))
                            .foregroundColor(MooniColor.textPrimary)
                        Text("classes")
                            .font(.system(size: 8, weight: .semibold, design: .rounded))
                            .foregroundColor(MooniColor.textMuted)
                            .tracking(0.5)
                    }
                }
            }
            .frame(width: 240, height: 240)

            // Big stats
            HStack(spacing: 8) {
                yamStat("521", "sound classes")
                yamStat("8M", "clips trained")
                yamStat("100%", "on-device")
            }
            .opacity(statsIn ? 1 : 0)
            .offset(y: statsIn ? 0 : 12)

            Text("Gemmeke et al., AudioSet, ICASSP 2017 · TensorFlow Hub")
                .font(MooniFont.caption(9))
                .foregroundColor(MooniColor.textMuted)
                .multilineTextAlignment(.center)

            Spacer(minLength: 4)
        }
        .padding(.horizontal, 22)
        .onAppear {
            Haptics.soft()
            for i in 0..<highlights.count + 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 + Double(i) * 0.18) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                        dotsIn = i + 1
                    }
                    Haptics.tick()
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeOut(duration: 0.5)) { statsIn = true }
                Haptics.success()
            }
        }
    }

    private func yamStat(_ number: String, _ caption: String) -> some View {
        VStack(spacing: 4) {
            Text(number)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(LinearGradient(
                    colors: [MooniColor.success, MooniColor.accentSoft],
                    startPoint: .top, endPoint: .bottom))
            Text(caption)
                .font(MooniFont.caption(10))
                .foregroundColor(MooniColor.textMuted)
                .tracking(0.4)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(MooniColor.success.opacity(0.18), lineWidth: 1)
        )
    }
}

// MARK: 3 / 6 — Sleep Efficiency

struct EfficiencyFormulaScreen: View {
    @State private var numIn = false
    @State private var denomIn = false
    @State private var resultIn = false
    @State private var bedFill: CGFloat = 0

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 4)

            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "function")
                        .font(.system(size: 11, weight: .bold))
                    Text("CLINICAL STANDARD · SINCE 1972")
                        .font(MooniFont.caption(10))
                        .tracking(1.5)
                }
                .foregroundColor(MooniColor.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(MooniColor.accent.opacity(0.14))
                .clipShape(Capsule())

                Text("Sleep Efficiency")
                    .font(MooniFont.display(28))
                    .foregroundColor(MooniColor.textPrimary)
                Text("the formula every sleep lab\nin the world uses.")
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Animated formula
            VStack(spacing: 14) {
                HStack(alignment: .center, spacing: 10) {
                    Text("SE")
                        .font(.system(size: 28, weight: .heavy, design: .serif))
                        .foregroundColor(MooniColor.accentSoft)
                    Text("=")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(MooniColor.textMuted)
                    VStack(spacing: 4) {
                        Text("Time Asleep")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(MooniColor.success)
                            .opacity(numIn ? 1 : 0)
                        Rectangle()
                            .fill(Color.white.opacity(0.4))
                            .frame(height: 1)
                            .frame(width: 120)
                        Text("Time in Bed")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(MooniColor.accent)
                            .opacity(denomIn ? 1 : 0)
                    }
                    Text("× 100")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(MooniColor.textSecondary)
                        .opacity(resultIn ? 1 : 0)
                }

                // Bed visual showing fill
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(MooniColor.accent.opacity(0.25), lineWidth: 1)
                        )
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LinearGradient(
                                colors: [MooniColor.success.opacity(0.7), MooniColor.success],
                                startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * bedFill, height: 40)
                    }
                    .frame(height: 40)
                    HStack {
                        Text("Asleep · 7h 32m")
                            .font(MooniFont.caption(11))
                            .foregroundColor(MooniColor.textPrimary)
                            .padding(.leading, 12)
                            .opacity(resultIn ? 1 : 0)
                        Spacer()
                        Text("\(Int(bedFill * 100))%")
                            .font(MooniFont.title(15))
                            .foregroundColor(MooniColor.textPrimary)
                            .padding(.trailing, 12)
                    }
                    .frame(height: 40)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(MooniColor.accent.opacity(0.22), lineWidth: 1)
            )

            // Trust strip
            HStack(spacing: 8) {
                effStat("2,500+", "AASM-accredited\nlabs in the US")
                effStat("AASM", "the global scoring\nstandard")
                effStat("50+", "years of\nclinical use")
            }

            Text("AASM Manual for the Scoring of Sleep, v3.0 · Berry et al., 2023")
                .font(MooniFont.caption(9))
                .foregroundColor(MooniColor.textMuted)

            Spacer(minLength: 4)
        }
        .padding(.horizontal, 22)
        .onAppear {
            Haptics.soft()
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) { numIn = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { Haptics.tick() }
            withAnimation(.easeOut(duration: 0.5).delay(0.55)) { denomIn = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { Haptics.tick() }
            withAnimation(.easeOut(duration: 0.5).delay(0.95)) { resultIn = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) { Haptics.medium() }
            withAnimation(.easeOut(duration: 1.4).delay(1.0)) { bedFill = 0.94 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { Haptics.success() }
        }
    }

    private func effStat(_ number: String, _ caption: String) -> some View {
        VStack(spacing: 4) {
            Text(number)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(MooniColor.textPrimary)
            Text(caption)
                .font(MooniFont.caption(9))
                .foregroundColor(MooniColor.textMuted)
                .tracking(0.3)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: 4 / 6 — Sleep architecture

struct SleepArchitectureScreen: View {
    @State private var pathPhase: CGFloat = 0
    @State private var rowsIn = 0

    private let stages: [(label: String, color: Color, share: String)] = [
        ("REM",        MooniColor.accent,    "20–25%"),
        ("Light · N2", MooniColor.accentSoft,"45–55%"),
        ("Deep · N3",  MooniColor.success,   "13–23%"),
        ("Awake",      MooniColor.warning,   "<5%")
    ]

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 4)

            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "waveform.path")
                        .font(.system(size: 11, weight: .bold))
                    Text("AASM SCORING · PER MINUTE")
                        .font(MooniFont.caption(10))
                        .tracking(1.5)
                }
                .foregroundColor(MooniColor.accentSoft)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(MooniColor.accent.opacity(0.14))
                .clipShape(Capsule())

                Text("We map your night,\nminute by minute.")
                    .font(MooniFont.display(26))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
            }

            // Hypnogram
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(MooniColor.accent.opacity(0.18), lineWidth: 1)
                    )

                HypnogramShape()
                    .trim(from: 0, to: pathPhase)
                    .stroke(LinearGradient(
                        colors: [MooniColor.accent, MooniColor.success, MooniColor.accentSoft],
                        startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 18)

                // Y-axis labels
                VStack(alignment: .leading, spacing: 0) {
                    stageLabel("REM",   tint: MooniColor.accent)
                    Spacer(minLength: 4)
                    stageLabel("Light", tint: MooniColor.accentSoft)
                    Spacer(minLength: 4)
                    stageLabel("Deep",  tint: MooniColor.success)
                }
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)

                // X-axis time labels
                VStack {
                    Spacer()
                    HStack {
                        Text("11pm").font(.system(size: 9)).foregroundColor(MooniColor.textMuted)
                        Spacer()
                        Text("2am").font(.system(size: 9)).foregroundColor(MooniColor.textMuted)
                        Spacer()
                        Text("5am").font(.system(size: 9)).foregroundColor(MooniColor.textMuted)
                        Spacer()
                        Text("7am").font(.system(size: 9)).foregroundColor(MooniColor.textMuted)
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 4)
                }
            }
            .frame(height: 160)

            // Stage breakdown rows
            VStack(spacing: 6) {
                ForEach(Array(stages.enumerated()), id: \.offset) { idx, s in
                    HStack {
                        Circle().fill(s.color).frame(width: 8, height: 8)
                        Text(s.label)
                            .font(MooniFont.body(13))
                            .foregroundColor(MooniColor.textPrimary)
                        Spacer()
                        Text(s.share)
                            .font(MooniFont.caption(11))
                            .foregroundColor(MooniColor.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(s.color.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .padding(.vertical, 2)
                    .opacity(idx < rowsIn ? 1 : 0)
                    .offset(x: idx < rowsIn ? 0 : -8)
                }
            }
            .padding(.horizontal, 4)

            Text("AASM Manual for the Scoring of Sleep, v3.0 · Berry et al., 2023")
                .font(MooniFont.caption(9))
                .foregroundColor(MooniColor.textMuted)

            Spacer(minLength: 4)
        }
        .padding(.horizontal, 22)
        .onAppear {
            Haptics.soft()
            withAnimation(.easeOut(duration: 1.6).delay(0.2)) { pathPhase = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { Haptics.success() }
            for i in 0..<stages.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(i) * 0.12) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        rowsIn = i + 1
                    }
                    Haptics.tick()
                }
            }
        }
    }

    private func stageLabel(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .foregroundColor(tint)
            .tracking(1)
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

struct OnDevicePrivacyScreen: View {
    @State private var phoneIn = false
    @State private var pulse = false
    @State private var rowsIn = 0

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 4)

            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("ON-DEVICE · ALWAYS")
                        .font(MooniFont.caption(10))
                        .tracking(1.6)
                }
                .foregroundColor(MooniColor.success)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(MooniColor.success.opacity(0.14))
                .clipShape(Capsule())

                Text("Nothing leaves your phone.")
                    .font(MooniFont.display(26))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Audio is processed by Apple's Neural Engine and discarded within seconds.")
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }

            // Phone visual
            ZStack {
                Circle()
                    .fill(MooniColor.success.opacity(pulse ? 0.30 : 0.14))
                    .frame(width: 200, height: 200)
                    .blur(radius: 30)

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(MooniColor.surface)
                    .frame(width: 110, height: 165)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(MooniColor.accent.opacity(0.45), lineWidth: 2)
                    )
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(MooniColor.success)
                            Text("0 BYTES")
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundColor(MooniColor.textPrimary)
                                .tracking(1.5)
                            Text("uploaded")
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundColor(MooniColor.textMuted)
                                .tracking(1)
                        }
                    )
                    .scaleEffect(phoneIn ? 1 : 0.85)
                    .opacity(phoneIn ? 1 : 0)

                // No-cloud slash
                Image(systemName: "icloud.slash.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(MooniColor.danger.opacity(0.85))
                    .offset(x: 80, y: -55)
                    .opacity(phoneIn ? 1 : 0)
            }
            .frame(height: 200)

            // Privacy proof rows
            VStack(spacing: 6) {
                privacyRow(idx: 0, icon: "cpu.fill",
                           title: "Apple Neural Engine",
                           sub: "17 trillion operations / sec",
                           color: MooniColor.accent)
                privacyRow(idx: 1, icon: "antenna.radiowaves.left.and.right.slash",
                           title: "Zero network calls",
                           sub: "Audio never touches a server",
                           color: MooniColor.success)
                privacyRow(idx: 2, icon: "trash.fill",
                           title: "Auto-deleted",
                           sub: "Recordings discarded after analysis",
                           color: MooniColor.warning)
            }

            Text("Apple Core ML · processed on-device using A-series Neural Engine")
                .font(MooniFont.caption(9))
                .foregroundColor(MooniColor.textMuted)
                .multilineTextAlignment(.center)

            Spacer(minLength: 4)
        }
        .padding(.horizontal, 22)
        .onAppear {
            Haptics.medium()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { phoneIn = true }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { pulse = true }
            for i in 0..<3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 + Double(i) * 0.14) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        rowsIn = i + 1
                    }
                    Haptics.tick()
                }
            }
        }
    }

    @ViewBuilder
    private func privacyRow(idx: Int, icon: String, title: String, sub: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(MooniFont.title(13))
                    .foregroundColor(MooniColor.textPrimary)
                Text(sub)
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.textSecondary)
            }
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(MooniColor.success.opacity(0.85))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .opacity(idx < rowsIn ? 1 : 0)
        .offset(x: idx < rowsIn ? 0 : -8)
    }
}

// MARK: 6 / 6 — Pro promise

struct ProPromiseScreen: View {
    @State private var rowsIn = 0
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 4)

            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(MooniColor.warning.opacity(pulse ? 0.35 : 0.18))
                        .frame(width: 120, height: 120)
                        .blur(radius: 22)
                    Image(systemName: "sparkles")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(LinearGradient(
                            colors: [MooniColor.warning, MooniColor.accentSoft],
                            startPoint: .top, endPoint: .bottom))
                }

                Text("Clinical-grade detail.\nFrom your phone.")
                    .font(MooniFont.display(26))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Mooni Pro uses every bit of the science you just saw — running for you, every night.")
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            // Pillar rows
            VStack(spacing: 8) {
                pillar(idx: 0,
                       icon: "wind",
                       tint: Color.pink,
                       title: "Snore detection & timing",
                       sub: "YAMNet flags every snore episode and when it spiked")
                pillar(idx: 1,
                       icon: "exclamationmark.triangle.fill",
                       tint: MooniColor.warning,
                       title: "Wake-cause attribution",
                       sub: "Find the noise — partner, traffic, alarm — that broke your night")
                pillar(idx: 2,
                       icon: "waveform.path.ecg",
                       tint: MooniColor.accent,
                       title: "Full sleep architecture",
                       sub: "Minute-by-minute hypnogram with REM, deep, and light stages")
                pillar(idx: 3,
                       icon: "chart.line.uptrend.xyaxis",
                       tint: MooniColor.success,
                       title: "Trends over weeks",
                       sub: "See exactly which habits move your score — and which don't")
            }

            // Bottom value framing
            HStack(spacing: 8) {
                Image(systemName: "stethoscope")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(MooniColor.accentSoft)
                Text("In-lab sleep studies cost **$1,000+**. You get the same metrics for the price of a coffee.")
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(MooniColor.accent.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(MooniColor.accent.opacity(0.25), lineWidth: 1)
            )

            Text("US polysomnography costs: AASM 2022 patient resource")
                .font(MooniFont.caption(9))
                .foregroundColor(MooniColor.textMuted)

            Spacer(minLength: 4)
        }
        .padding(.horizontal, 22)
        .onAppear {
            Haptics.success()
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { pulse = true }
            for i in 0..<4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + Double(i) * 0.13) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        rowsIn = i + 1
                    }
                    Haptics.tick()
                }
            }
        }
    }

    @ViewBuilder
    private func pillar(idx: Int, icon: String, tint: Color, title: String, sub: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(MooniFont.title(14))
                    .foregroundColor(MooniColor.textPrimary)
                Text(sub)
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
        .opacity(idx < rowsIn ? 1 : 0)
        .offset(y: idx < rowsIn ? 0 : 8)
    }
}
