import SwiftUI

struct MooniCard<Content: View>: View {
    let content: () -> Content
    var padding: CGFloat = 20
    var cornerRadius: CGFloat = 28

    init(
        padding: CGFloat = 20,
        cornerRadius: CGFloat = 28,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content
    }

    var body: some View {
        // Wrap content() in a VStack so multi-view (TupleView) bodies stack
        // predictably instead of relying on implicit layout behaviour.
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MooniGradient.card)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct LunaMoodHero: View {
    let pet: Pet
    var mood: Pet.Mood
    var size: CGFloat = 210
    var caption: String?

    private var moodPet: Pet {
        var p = pet
        p.mood = mood
        return p
    }

    var body: some View {
        VStack(spacing: 12) {
            DreamSpiritView(pet: moodPet, size: size)
                .padding(.top, 4)
                .shadow(color: MooniColor.petGlow.opacity(0.24), radius: 26, y: 12)

            if let caption {
                Text(caption)
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct LunaSpeechBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(MooniFont.body(15))
            .foregroundColor(MooniColor.textPrimary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.10))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(MooniColor.accentSoft.opacity(0.22), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: MooniColor.petGlow.opacity(0.10), radius: 14, y: 6)
    }
}

struct MooniStatPill: View {
    let icon: String
    let value: String
    let label: String
    var color: Color = MooniColor.accent

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(MooniFont.title(15))
                    .foregroundColor(MooniColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(label)
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.065))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct MooniInfoRow: View {
    let icon: String
    let title: String
    let value: String
    var color: Color = MooniColor.accent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            Text(title)
                .font(MooniFont.body(14))
                .foregroundColor(MooniColor.textSecondary)

            Spacer()

            Text(value)
                .font(MooniFont.title(14))
                .foregroundColor(MooniColor.textPrimary)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.vertical, 4)
    }
}

struct MooniProgressBar: View {
    let value: Double
    var height: CGFloat = 10
    var backgroundOpacity: Double = 0.10
    /// Kept for call-site compatibility; only the first colour is used so
    /// every progress bar in the app renders as one flat fill (no gradient).
    var colors: [Color] = [MooniColor.accent]

    private var clampedValue: Double {
        min(max(value, 0), 1)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(backgroundOpacity))
                Capsule()
                    .fill(colors.first ?? MooniColor.accent)
                    .frame(width: geo.size.width * CGFloat(clampedValue))
            }
        }
        .frame(height: height)
    }
}

struct MooniPremiumLockCard: View {
    let icon: String
    let title: String
    let subtitle: String
    var badge: String = "Premium"
    var actionTitle: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            MooniCard(padding: 16, cornerRadius: 24) {
                // Wrap entire content in a single VStack so SwiftUI doesn't
                // collapse the sibling action title into the icon's HStack —
                // that was the source of the squished button text.
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(MooniColor.accent.opacity(0.14))
                                .frame(width: 48, height: 48)
                            Image(systemName: icon)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(MooniColor.accentSoft)
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 6) {
                                Text(title)
                                    .font(MooniFont.title(15))
                                    .foregroundColor(MooniColor.textPrimary)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                                Text(badge)
                                    .font(MooniFont.caption(10))
                                    .foregroundColor(MooniColor.background)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(MooniColor.accentSoft)
                                    .clipShape(Capsule())
                            }

                            Text(subtitle)
                                .font(MooniFont.caption(12))
                                .foregroundColor(MooniColor.textSecondary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if let actionTitle {
                        HStack(spacing: 6) {
                            Text(actionTitle)
                                .font(MooniFont.caption(13))
                                .foregroundColor(MooniColor.background)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(MooniColor.background)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule().fill(
                                LinearGradient(
                                    colors: [MooniColor.accentSoft, MooniColor.accent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        )
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}
