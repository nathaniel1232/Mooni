import SwiftUI

/// Medium widget — clean two-pane layout.
/// LEFT: hero ring with the Mooni mascot, no separate score number under it.
/// RIGHT: big score, quality subtitle, then the three detail rows.
/// "Mooni" wordmark sits subtly in the top-right so the brand is always visible.
struct MediumSleepWidgetView: View {
    let data: SleepWidgetData

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // LEFT — single hero element
            SleepScoreRing(
                progress: data.ringProgress,
                tint: data.scoreTint,
                lineWidth: 7
            ) {
                MooniMascotView()
            }
            .frame(width: 110, height: 110)

            // RIGHT — content
            VStack(alignment: .leading, spacing: 6) {
                // Brand strip
                HStack(spacing: 4) {
                    Spacer(minLength: 0)
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Mooni")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(0.5)
                }
                .foregroundStyle(SleepWidgetPalette.textTertiary)

                // Score + quality
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(data.score)")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(SleepWidgetPalette.textPrimary)
                    qualityChip
                    Spacer(minLength: 0)
                }
                .padding(.bottom, 1)

                detailRow(
                    icon: "bed.double.fill",
                    text: data.sleepDuration,
                    accent: data.scoreTint
                )
                detailRow(
                    icon: "alarm.fill",
                    text: "\(data.sleepStart) → \(data.wakeTime)",
                    accent: SleepWidgetPalette.textSecondary
                )
                detailRow(
                    icon: "bolt.fill",
                    text: "Energy \(data.energyScore)%",
                    accent: energyTint(for: data.energyScore)
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var qualityChip: some View {
        Text(data.quality)
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .tracking(0.3)
            .textCase(.uppercase)
            .foregroundStyle(data.scoreTint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(data.scoreTint.opacity(0.18)))
            .overlay(Capsule().stroke(data.scoreTint.opacity(0.35), lineWidth: 0.5))
    }

    private func detailRow(icon: String, text: String, accent: Color) -> some View {
        HStack(spacing: 9) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.20))
                    .frame(width: 22, height: 22)
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(accent)
            }
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(SleepWidgetPalette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }

    private func energyTint(for value: Int) -> Color {
        switch value {
        case 80...:    return Color(red: 0.55, green: 0.85, blue: 0.78)
        case 60..<80:  return Color(red: 0.72, green: 0.62, blue: 1.00)
        case 40..<60:  return Color(red: 1.00, green: 0.78, blue: 0.55)
        default:       return Color(red: 1.00, green: 0.60, blue: 0.72)
        }
    }
}
