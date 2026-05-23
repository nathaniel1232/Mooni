import SwiftUI

/// Medium widget — premium two-pane layout.
/// LEFT: glowing gradient ring with mascot at centre and a clean "tonight"
/// time-range pill beneath it.
/// RIGHT: score + quality + a tidy day-stats grid (duration / energy /
/// bedtime → wake). No sparkline — sparklines were unreadable at this
/// size and the text kept overflowing.
struct MediumSleepWidgetView: View {
    let data: SleepWidgetData

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            leftPane
                .frame(width: 116)
            rightPane
                .frame(maxWidth: .infinity, maxHeight: .infinity,
                       alignment: .topLeading)
        }
    }

    // MARK: - Left pane

    private var leftPane: some View {
        VStack(spacing: 8) {
            ringHero
                .frame(width: 104, height: 104)

            // Time-range pill — replaces the previous detail row
            HStack(spacing: 5) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(data.scoreTint)
                Text("\(data.sleepStart) → \(data.wakeTime)")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundStyle(SleepWidgetPalette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(SleepWidgetPalette.chipBackground)
            )
            .overlay(
                Capsule().stroke(data.scoreTint.opacity(0.18), lineWidth: 0.6)
            )
        }
    }

    private var ringHero: some View {
        ZStack {
            // Outer soft glow
            Circle()
                .fill(data.scoreTint.opacity(0.22))
                .frame(width: 110, height: 110)
                .blur(radius: 12)

            // Track
            Circle()
                .stroke(SleepWidgetPalette.ringTrack, lineWidth: 8)
                .frame(width: 94, height: 94)

            // Progress — angular gradient stroke
            Circle()
                .trim(from: 0, to: data.ringProgress)
                .stroke(
                    AngularGradient(
                        colors: [
                            data.scoreTint.opacity(0.55),
                            data.scoreTint,
                            data.scoreTint.opacity(0.9)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 94, height: 94)
                .rotationEffect(.degrees(-90))
                .shadow(color: data.scoreTint.opacity(0.55), radius: 8)

            MooniMascotView()
                .frame(width: 54, height: 54)
        }
    }

    // MARK: - Right pane
    //
    // Restructured to: brand wordmark + score+quality + a tidy 2x2 day-stats
    // grid. No more sparkline (it was unreadable at this height and the
    // gradient stroke kept making the layout feel busy). No more
    // firstTextBaseline alignment (which fought the mixed font sizes and
    // pushed the quality chip off the right edge). Everything now uses
    // .center alignment and stays inside the widget bounds.

    private var rightPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Brand wordmark (top, small, subtle)
            HStack(spacing: 4) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 9, weight: .black))
                Text("SleepOwl")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(0.2)
                Spacer(minLength: 0)
            }
            .foregroundStyle(SleepWidgetPalette.textSecondary)

            // Score block — center alignment now (no baseline collision)
            HStack(alignment: .center, spacing: 8) {
                Text("\(data.score)")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(scoreGradient)
                    .shadow(color: data.scoreTint.opacity(0.55), radius: 12)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                VStack(alignment: .leading, spacing: 3) {
                    qualityChip
                    Text(captionFor(data.score))
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .foregroundStyle(SleepWidgetPalette.textTertiary)
                        .tracking(1.0)
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
            }

            // Day stats — two mini chips side by side. Width-balanced
            // (each gets ½ of the right pane) so neither overflows.
            HStack(spacing: 6) {
                miniChip(icon: "bed.double.fill",
                         value: data.sleepDuration,
                         tint: data.scoreTint)
                miniChip(icon: "bolt.fill",
                         value: "\(data.energyScore)%",
                         tint: energyTint(for: data.energyScore))
            }
        }
    }

    private var qualityChip: some View {
        Text(data.quality)
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .tracking(0.3)
            .textCase(.uppercase)
            .foregroundStyle(data.scoreTint)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(data.scoreTint.opacity(0.22))
            )
            .overlay(
                Capsule().stroke(data.scoreTint.opacity(0.45), lineWidth: 0.6)
            )
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(SleepWidgetPalette.chipBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(tint.opacity(0.20), lineWidth: 0.6)
        )
    }

    // MARK: Helpers

    private func captionFor(_ score: Int) -> String {
        switch score {
        case 85...:  return "tonight · excellent"
        case 70..<85: return "tonight"
        case 50..<70: return "tonight · recovery"
        default:      return "tonight · debt"
        }
    }

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
