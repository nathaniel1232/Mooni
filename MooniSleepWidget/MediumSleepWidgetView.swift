import SwiftUI

/// Medium widget — typographic "score card" with a sleep timeline.
/// A complete redesign away from the old owl-in-ring: the top row pairs the
/// big gradient score with two stat chips; the bottom is a full-width moon→sun
/// timeline of the night (bedtime, duration, wake). No mascot, no ring.
struct MediumSleepWidgetView: View {
    let data: SleepWidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Brand + quality on one balanced row
            HStack(spacing: 4) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 9, weight: .black))
                Text("SleepOwl")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(0.2)
                    .lineLimit(1)
                    .fixedSize()
                Spacer(minLength: 4)
                qualityChip
            }
            .foregroundStyle(SleepWidgetPalette.textSecondary)

            Spacer(minLength: 4)

            // ── Score + stat chips
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: -2) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(data.score)")
                            .font(.system(size: 50, weight: .black, design: .rounded))
                            .foregroundStyle(scoreGradient)
                            .shadow(color: data.scoreTint.opacity(0.4), radius: 9)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text("/100")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(SleepWidgetPalette.textTertiary)
                    }
                    Text("LAST NIGHT")
                        .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(SleepWidgetPalette.textTertiary)
                }

                Spacer(minLength: 4)

                VStack(spacing: 6) {
                    miniChip(icon: "bed.double.fill",
                             value: data.sleepDuration,
                             tint: data.scoreTint)
                    miniChip(icon: "bolt.fill",
                             value: "\(data.energyScore)%",
                             tint: energyTint(for: data.energyScore))
                }
                .frame(width: 104)
            }

            Spacer(minLength: 6)

            // ── Sleep timeline: moon (bedtime) → sun (wake), duration centered.
            timelineBar
        }
    }

    // MARK: - Timeline

    private var timelineBar: some View {
        VStack(spacing: 5) {
            HStack(spacing: 0) {
                endpoint(icon: "moon.fill", time: data.sleepStart)
                Spacer(minLength: 4)
                Text("\(data.sleepDuration) asleep")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(SleepWidgetPalette.textSecondary)
                    .lineLimit(1)
                    .fixedSize()
                Spacer(minLength: 4)
                endpoint(icon: "sun.max.fill", time: data.wakeTime)
            }
            Capsule()
                .fill(SleepWidgetPalette.ringTrack)
                .frame(height: 9)
                .overlay(
                    Capsule()
                        .fill(LinearGradient(
                            colors: [data.scoreTint.opacity(0.55),
                                     data.scoreTint,
                                     Color(red: 1.0, green: 0.83, blue: 0.5)],
                            startPoint: .leading, endPoint: .trailing))
                        .shadow(color: data.scoreTint.opacity(0.4), radius: 4)
                )
        }
    }

    private func endpoint(icon: String, time: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(data.scoreTint)
            Text(time)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(SleepWidgetPalette.textPrimary)
                .lineLimit(1)
                .fixedSize()
        }
    }

    // MARK: - Chips

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

    private func miniChip(icon: String, value: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(SleepWidgetPalette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(SleepWidgetPalette.chipBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(tint.opacity(0.20), lineWidth: 0.6)
        )
    }

    // MARK: - Helpers

    private var scoreGradient: LinearGradient {
        LinearGradient(
            colors: [SleepWidgetPalette.textPrimary, data.scoreTint],
            startPoint: .top, endPoint: .bottom
        )
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
