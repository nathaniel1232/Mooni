import SwiftUI

/// Medium widget — full rebuild.
/// Layout:
///   LEFT (118pt):  brand chip + big halo'd score ring with score in center
///   RIGHT:         "TONIGHT" eyebrow + quality, big bed→wake row,
///                  bottom stats row (duration · energy)
/// No sparkline, no firstTextBaseline collisions, no scale-to-fit. Every
/// value has its own font budget and prints at full size.
struct MediumSleepWidgetView: View {
    let data: SleepWidgetData

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            leftPane
                .frame(width: 118)
            rightPane
                .frame(maxWidth: .infinity, maxHeight: .infinity,
                       alignment: .topLeading)
        }
    }

    // MARK: - Left pane

    private var leftPane: some View {
        VStack(spacing: 8) {
            HStack(spacing: 3) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 9, weight: .black))
                Text("SleepOwl")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(0.2)
            }
            .foregroundStyle(SleepWidgetPalette.textSecondary)

            scoreRing
                .frame(width: 100, height: 100)
        }
    }

    private var scoreRing: some View {
        ZStack {
            // Soft halo
            Circle()
                .fill(data.scoreTint.opacity(0.22))
                .frame(width: 110, height: 110)
                .blur(radius: 12)

            // Track
            Circle()
                .stroke(SleepWidgetPalette.ringTrack, lineWidth: 6)
            // Progress
            Circle()
                .trim(from: 0, to: data.ringProgress)
                .stroke(
                    AngularGradient(
                        colors: [
                            data.scoreTint.opacity(0.45),
                            data.scoreTint,
                            .white,
                            data.scoreTint
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: data.scoreTint.opacity(0.55), radius: 6)

            VStack(spacing: -2) {
                Text("\(data.score)")
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                SleepWidgetPalette.textPrimary,
                                data.scoreTint
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                Text("SCORE")
                    .font(.system(size: 7, weight: .heavy, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(SleepWidgetPalette.textTertiary)
            }
        }
    }

    // MARK: - Right pane

    private var rightPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Eyebrow + quality
            HStack(spacing: 6) {
                Text("TONIGHT")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(SleepWidgetPalette.textTertiary)
                Text(data.quality.uppercased())
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(data.scoreTint)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        Capsule().fill(data.scoreTint.opacity(0.22))
                    )
                Spacer(minLength: 0)
            }
            .padding(.top, 2)

            Spacer(minLength: 0)

            // Bed → wake — the headline info
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(data.scoreTint)
                    Text(data.sleepStart)
                        .font(.system(size: 17, weight: .heavy,
                                      design: .rounded))
                        .foregroundStyle(SleepWidgetPalette.textPrimary)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(SleepWidgetPalette.textTertiary)
                    Text(data.wakeTime)
                        .font(.system(size: 17, weight: .heavy,
                                      design: .rounded))
                        .foregroundStyle(SleepWidgetPalette.textPrimary)
                }
                .lineLimit(1)

                Text("bedtime → wake")
                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                    .tracking(1.0)
                    .foregroundStyle(SleepWidgetPalette.textTertiary)
                    .padding(.top, 2)
            }

            Spacer(minLength: 0)

            // Bottom stats — duration + energy as two clean chips
            HStack(spacing: 6) {
                statChip(icon: "bed.double.fill",
                         value: data.sleepDuration,
                         tint: data.scoreTint)
                statChip(icon: "bolt.fill",
                         value: "\(data.energyScore)%",
                         tint: energyTint(for: data.energyScore))
            }
        }
    }

    private func statChip(icon: String, value: String,
                          tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(SleepWidgetPalette.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(SleepWidgetPalette.chipBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(tint.opacity(0.20), lineWidth: 0.6)
        )
    }

    // MARK: - Helpers

    private func energyTint(for value: Int) -> Color {
        switch value {
        case 80...:   return Color(red: 0.55, green: 0.85, blue: 0.78)
        case 60..<80: return Color(red: 0.72, green: 0.62, blue: 1.00)
        case 40..<60: return Color(red: 1.00, green: 0.78, blue: 0.55)
        default:      return Color(red: 1.00, green: 0.60, blue: 0.72)
        }
    }
}
