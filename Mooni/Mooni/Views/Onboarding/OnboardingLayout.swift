import SwiftUI

/// Single source of truth for the onboarding flow's look.
///
/// Every screen used to hand-roll its own padding, spacing, header chip and
/// a different tint per card (warning / danger / pink / accent …) which made
/// the flow feel inconsistent and noisy. Screens now compose from these
/// shared atoms so the whole flow reads as ONE designed product: identical
/// edge padding, identical vertical rhythm, identical typography, and a
/// single accent colour throughout. Change it here → changes everywhere.
enum OnboardingLayout {
    /// Horizontal screen-edge padding for every onboarding step.
    static let hPad: CGFloat = 24
    /// The one accent. No per-card rainbow.
    static let accent: Color = MooniColor.accent
}

extension View {
    /// Standard onboarding screen edge padding.
    func onboardingEdge() -> some View {
        padding(.horizontal, OnboardingLayout.hPad)
    }
}

// MARK: - Atoms

/// Small uppercase eyebrow chip above a title. Always the single accent.
struct OBEyebrow: View {
    let emoji: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            EmojiIcon(emoji: emoji, size: 12, tint: OnboardingLayout.accent)
            Text(text.uppercased())
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .tracking(2)
                .foregroundColor(OnboardingLayout.accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(OnboardingLayout.accent.opacity(0.16))
        .clipShape(Capsule())
    }
}

struct OBTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(MooniFont.display(30))
            .foregroundColor(MooniColor.textPrimary)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct OBSubtitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(MooniFont.body(15))
            .foregroundColor(MooniColor.textSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Left-aligned title + optional subtitle for *question* screens. The quiz
/// reads top-left (title sits on the same band as the back chevron) instead of
/// the old dead-centre look, which felt floaty and pushed the answer controls
/// too far down the screen. Content screens still use the centred OBTitle.
struct QuestionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(MooniFont.display(30))
                .foregroundColor(MooniColor.textPrimary)
                .multilineTextAlignment(.leading)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The one card used for every list / option / stat row in onboarding.
/// Single accent, optional subtitle, built-in reveal offset.
struct OBCard: View {
    let emoji: String
    let title: String
    var subtitle: String? = nil
    var visible: Bool = true

    var body: some View {
        HStack(spacing: 14) {
            EmojiIcon(emoji: emoji, size: 24, tint: OnboardingLayout.accent)
                .frame(width: 52, height: 52)
                .background(OnboardingLayout.accent.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundColor(MooniColor.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(MooniFont.body(13))
                        .foregroundColor(MooniColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(OnboardingLayout.accent.opacity(0.18), lineWidth: 1)
        )
        .opacity(visible ? 1 : 0)
        .offset(x: visible ? 0 : -16)
    }
}

// MARK: - Scaffold

/// Every "title + content" onboarding screen flows through this so the
/// eyebrow→title→subtitle→content rhythm and edge padding are pixel-identical
/// on every step. Screens with a hero visual on top use `OBTitle`/`OBSubtitle`
/// directly under their visual instead.
struct OnboardingScaffold<Content: View>: View {
    var eyebrow: (emoji: String, text: String)? = nil
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 12) {
                if let eyebrow {
                    OBEyebrow(emoji: eyebrow.emoji, text: eyebrow.text)
                }
                OBTitle(title)
                if let subtitle {
                    OBSubtitle(subtitle)
                }
            }
            content
        }
        .frame(maxWidth: .infinity)
        .onboardingEdge()
    }
}
