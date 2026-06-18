import SwiftUI

/// Medium widget — the score gauge paired with a clean, divider-separated stat
/// list (Asleep · Bedtime · Wake · Energy). Reads like a premium health summary
/// card; shares the `SleepGauge` hero with the small widget for a unified look.
struct MediumSleepWidgetView: View {
    let data: SleepWidgetData

    var body: some View {
        VStack(spacing: 0) {
            // Brand + quality
            HStack(spacing: 4) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 9, weight: .black))
                Text("SleepOwl")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .fixedSize()
                Spacer(minLength: 4)
                qualityChip
            }
            .foregroundStyle(SleepWidgetPalette.textSecondary)

            Spacer(minLength: 6)

            HStack(spacing: 16) {
                SleepGauge(score: data.score, tint: data.scoreTint, size: 96, lineWidth: 9)

                VStack(spacing: 0) {
                    statRow(icon: "bed.double.fill", label: "Asleep", value: data.sleepDuration)
                    divider
                    statRow(icon: "moon.fill", label: "Bedtime", value: data.sleepStart)
                    divider
                    statRow(icon: "sun.max.fill", label: "Wake", value: data.wakeTime)
                    divider
                    statRow(icon: "bolt.fill", label: "Energy", value: "\(data.energyScore)%",
                            tint: energyTint(for: data.energyScore))
                }
                .frame(maxWidth: .infinity)
            }

            Spacer(minLength: 2)
        }
    }

    // MARK: - Stat list

    private func statRow(icon: String, label: String, value: String, tint: Color? = nil) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(tint ?? data.scoreTint)
                .frame(width: 14)
            Text(label)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundStyle(SleepWidgetPalette.textSecondary)
            Spacer(minLength: 6)
            Text(value)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(SleepWidgetPalette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .fixedSize()
        }
        .padding(.vertical, 5)
    }

    private var divider: some View {
        Rectangle()
            .fill(SleepWidgetPalette.ringTrack)
            .frame(height: 0.6)
    }

    private var qualityChip: some View {
        Text(data.quality.uppercased())
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .tracking(0.4)
            .foregroundStyle(data.scoreTint)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(data.scoreTint.opacity(0.22)))
            .overlay(Capsule().stroke(data.scoreTint.opacity(0.45), lineWidth: 0.6))
    }

    private func energyTint(for value: Int) -> Color {
        switch value {
        case 80...:   return Color(red: 0.55, green: 0.85, blue: 0.78)
        case 60..<80: return Color(red: 0.72, green: 0.62, blue: 1.00)
        case 40..<60: return Color(red: 1.00, green: 0.78, blue: 0.55)
        default:      return Color(red: 1.00, green: 0.60, blue: 0.72)
        }
    }
}
