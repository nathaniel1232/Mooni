import SwiftUI

/// Home-screen card that teases the Sleepowl Reveal feature. Two states:
///   • **Ready** — user has enough nights → shows a sparkle illustration,
///     headline, and "Reveal & share" CTA. Tapping opens RevealView.
///   • **Locked** — too few nights → shows progress ("2 of 3 nights") and
///     a softer hint. No CTA.
///
/// Caller-side pattern (Phase 4 wires this into HomeView):
///   if let stats = appState.revealStatsIfReady() {
///       RevealTeaserCard.ready(stats: stats) { showReveal = true }
///   } else {
///       RevealTeaserCard.locked(nightsTracked: count, required: 3)
///   }
struct RevealTeaserCard: View {
    enum Mode {
        case ready(RevealStats, onTap: () -> Void)
        case locked(nightsTracked: Int, required: Int)
    }

    let mode: Mode

    var body: some View {
        switch mode {
        case .ready(let stats, let onTap):
            readyCard(stats: stats, onTap: onTap)
        case .locked(let n, let need):
            lockedCard(nightsTracked: n, required: need)
        }
    }

    // MARK: - Ready (the eye-catcher)
    @ViewBuilder
    private func readyCard(stats: RevealStats, onTap: @escaping () -> Void) -> some View {
        Button {
            Haptics.soft()
            onTap()
        } label: {
            ZStack {
                // Layered gradient + spotlight to make the card pop on Home
                LinearGradient(
                    colors: [
                        Color(red: 0.20, green: 0.10, blue: 0.40),
                        Color(red: 0.55, green: 0.25, blue: 0.60),
                        Color(red: 0.80, green: 0.50, blue: 0.55)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.28), .clear],
                            center: .center,
                            startRadius: 4,
                            endRadius: 120
                        )
                    )
                    .frame(width: 200, height: 200)
                    .offset(x: -90, y: -20)
                    .blur(radius: 10)

                HStack(spacing: 14) {
                    miniOwl(pet: stats.pet, mood: stats.afterMood)
                        .frame(width: 88, height: 88)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.white)
                                .font(.system(size: 12, weight: .bold))
                            Text("NEW REVEAL")
                                .font(MooniFont.caption(11))
                                .tracking(1.4)
                                .foregroundColor(.white.opacity(0.85))
                        }

                        Text("Your glow-up is ready")
                            .font(MooniFont.title(18))
                            .foregroundColor(.white)
                            .lineLimit(2)

                        Text(stats.tagline)
                            .font(MooniFont.body(13))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(1)
                    }
                    .padding(.vertical, 4)

                    Spacer(minLength: 4)

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Circle().fill(Color.white.opacity(0.22)))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Locked
    @ViewBuilder
    private func lockedCard(nightsTracked: Int, required: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(MooniColor.textMuted)
                Text("SLEEPOWL REVEAL")
                    .font(MooniFont.caption(11))
                    .tracking(1.4)
                    .foregroundColor(MooniColor.textMuted)
            }

            Text("Sleep \(required) nights to unlock your first Reveal")
                .font(MooniFont.title(16))
                .foregroundColor(MooniColor.textPrimary)
                .lineLimit(2)

            HStack(spacing: 6) {
                ForEach(0..<required, id: \.self) { i in
                    Capsule()
                        .fill(i < nightsTracked ? MooniColor.accent : MooniColor.hairline)
                        .frame(height: 6)
                }
            }
            .padding(.top, 2)

            Text("\(nightsTracked) of \(required) nights")
                .font(MooniFont.caption(12))
                .foregroundColor(MooniColor.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(MooniColor.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(MooniColor.hairline, lineWidth: 1)
        )
    }

    // MARK: - Mini owl thumbnail
    private func miniOwl(pet: Pet, mood: Pet.Mood) -> some View {
        let name: String = {
            switch mood.legacyBucket {
            case .rested: return "spirit_dream"
            case .good:   return "spirit_awake"
            case .tired:  return "spirit_sleep"
            case .low:    return "spirit_tired"
            default:      return "spirit_awake"
            }
        }()
        let tint: Color = (pet.equippedColor == "default_color")
            ? pet.species.tint
            : UnlockableItem.color(for: pet.equippedColor)

        return ZStack {
            Circle()
                .fill(RadialGradient(colors: [tint.opacity(0.6), .clear], center: .center, startRadius: 0, endRadius: 50))
                .blur(radius: 8)
            Image(name)
                .resizable()
                .scaledToFit()
        }
    }
}

#Preview {
    ZStack {
        MooniGradient.night.ignoresSafeArea()
        VStack(spacing: 20) {
            RevealTeaserCard(mode: .ready(.demo, onTap: {}))
            RevealTeaserCard(mode: .locked(nightsTracked: 1, required: 3))
            RevealTeaserCard(mode: .locked(nightsTracked: 2, required: 3))
        }
        .padding(20)
    }
}
