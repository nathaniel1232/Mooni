import SwiftUI

/// Medium widget — clean two-pane layout.
/// LEFT: hero ring with the SleepOwl mascot, no separate score number under it.
/// RIGHT: big score, quality subtitle, then the three detail rows.
/// "SleepOwl" wordmark sits subtly in the top-right so the brand is always visible.
struct MediumSleepWidgetView: View {
    let data: SleepWidgetData

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("SleepOwl")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(0.2)
                }
                .foregroundStyle(SleepWidgetPalette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

                SleepScoreRing(
                    progress: data.ringProgress,
                    tint: data.scoreTint,
                    lineWidth: 8
                ) {
                    MooniMascotView()
                }
                .frame(width: 104, height: 104)
            }

            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .center, spacing: 8) {
                    Text("\(data.score)")
                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                        .foregroundStyle(SleepWidgetPalette.textPrimary)
                        .lineLimit(1)
                    VStack(alignment: .leading, spacing: 3) {
                        qualityChip
                        Text("sleep score")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(SleepWidgetPalette.textTertiary)
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    detailTile(icon: "bed.double.fill", title: "Asleep", text: data.sleepDuration, accent: data.scoreTint)
                    detailTile(icon: "bolt.fill", title: "Energy", text: "\(data.energyScore)%", accent: energyTint(for: data.energyScore))
                }

                detailRow(
                    icon: "alarm.fill",
                    text: "\(data.sleepStart) → \(data.wakeTime)",
                    accent: SleepWidgetPalette.textSecondary
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private var qualityChip: some View {
        Text(data.quality)
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .tracking(0.3)
            .textCase(.uppercase)
            .foregroundStyle(data.scoreTint)
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .allowsTightening(true)
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

    private func detailTile(icon: String, title: String, text: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(accent)
            Text(text)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(SleepWidgetPalette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(title)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(SleepWidgetPalette.textTertiary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(SleepWidgetPalette.chipBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
