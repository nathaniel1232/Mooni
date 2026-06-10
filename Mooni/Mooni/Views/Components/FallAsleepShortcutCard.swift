import SwiftUI

/// Compact "drift off" promo for the Home view. Picks a contextual sound
/// recommendation — always a free, bundled sound (rain) so the advertised
/// track is actually playable for everyone — and opens `FallAsleepView` on tap.
///
/// The recommendation is just copy-level — the actual playback happens
/// inside FallAsleepView after the sheet opens. This keeps the Home page
/// reading as "help me sleep, not just track sleep."
struct FallAsleepShortcutCard: View {
    /// What the small icon and copy advertise. The actual sound the user
    /// plays is picked inside FallAsleepView after tapping.
    let recommendation: Recommendation
    let onTap: () -> Void

    struct Recommendation {
        let title: String         // "Rain in pines"
        let subtitle: String      // "14 min · drift in 5"
        let icon: String          // SF symbol
        let tint: Color
    }

    var body: some View {
        Button {
            Haptics.soft()
            onTap()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [recommendation.tint.opacity(0.55), recommendation.tint.opacity(0.18)],
                                center: .center,
                                startRadius: 4,
                                endRadius: 28
                            )
                        )
                        .frame(width: 52, height: 52)
                    Image(systemName: recommendation.icon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "headphones")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(recommendation.tint)
                        Text("DRIFT OFF")
                            .font(MooniFont.caption(11))
                            .tracking(1.4)
                            .foregroundColor(recommendation.tint)
                    }
                    Text(recommendation.title)
                        .font(MooniFont.title(17))
                        .foregroundColor(MooniColor.textPrimary)
                    Text(recommendation.subtitle)
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(MooniColor.background)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(.white))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(recommendation.tint.opacity(0.32), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    /// Pick a contextual recommendation. Reads simple signals off AppState:
    /// the user's wake-feeling profile (from OnboardingProfile) and time of
    /// day. Falls back to "Rain in pines" — the universally calming default.
    static func recommend(profile: OnboardingProfile?, now: Date = Date()) -> Recommendation {
        let hour = Calendar.current.component(.hour, from: now)
        // Both branches recommend rain — it's free and bundled, so the
        // advertised track always plays. We just vary the framing/length copy
        // by time of day. (Premium sounds like Fireplace live inside the
        // FallAsleep sheet behind the paywall; we never advertise an
        // unplayable track here.)
        let lateNight = hour >= 22 || hour < 5

        if lateNight {
            return Recommendation(
                title: "Rain & Thunder",
                subtitle: "30 min · steady rainfall",
                icon: "cloud.bolt.rain.fill",
                tint: Color(red: 0.65, green: 0.78, blue: 1.00)
            )
        }
        return Recommendation(
            title: "Rain & Thunder",
            subtitle: "20 min · gentle rainfall",
            icon: "cloud.bolt.rain.fill",
            tint: Color(red: 0.65, green: 0.78, blue: 1.00)
        )
    }
}

#Preview {
    ZStack {
        MooniGradient.night.ignoresSafeArea()
        VStack(spacing: 18) {
            FallAsleepShortcutCard(
                recommendation: FallAsleepShortcutCard.recommend(profile: nil, now: Date()),
                onTap: {}
            )
            FallAsleepShortcutCard(
                recommendation: .init(
                    title: "Brown noise",
                    subtitle: "30 min · deep, even hum",
                    icon: "waveform",
                    tint: Color(red: 0.85, green: 0.78, blue: 1.00)
                ),
                onTap: {}
            )
        }
        .padding(20)
    }
}
