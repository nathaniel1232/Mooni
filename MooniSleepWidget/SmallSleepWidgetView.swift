import SwiftUI

/// Small widget — tight, balanced layout. SleepOwl brand top, mascot+ring
/// in the middle, time range across the bottom so you always see when
/// you slept at a glance.
struct SmallSleepWidgetView: View {
    let data: SleepWidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Brand + quality
            HStack(spacing: 6) {
                Image("owl_base")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                Text("SleepOwl")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(0.5)
                    .foregroundStyle(SleepWidgetPalette.textPrimary)
                Spacer(minLength: 0)
                qualityChip
            }

            // Hero — ring + score, packed tight
            HStack(spacing: 9) {
                SleepScoreRing(
                    progress: data.ringProgress,
                    tint: data.scoreTint,
                    lineWidth: 5
                ) {
                    MooniMascotView()
                }
                .frame(width: 60, height: 60)

                VStack(alignment: .leading, spacing: -3) {
                    Text("\(data.score)")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(SleepWidgetPalette.textPrimary)
                        .minimumScaleFactor(0.7)
                    Text("score")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(SleepWidgetPalette.textTertiary)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 2)

            Spacer(minLength: 0)

            // Footer — duration + bed → wake (always visible)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Image(systemName: "bed.double.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(data.scoreTint)
                    Text(data.sleepDuration)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(SleepWidgetPalette.textPrimary)
                }
                Text("\(data.sleepStart) → \(data.wakeTime)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(SleepWidgetPalette.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    private var qualityChip: some View {
        Text(data.quality)
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .tracking(0.3)
            .textCase(.uppercase)
            .foregroundStyle(data.scoreTint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(data.scoreTint.opacity(0.18)))
            .overlay(Capsule().stroke(data.scoreTint.opacity(0.35), lineWidth: 0.5))
    }
}
