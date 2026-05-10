import SwiftUI

/// Small widget — tight, balanced layout. SleepOwl brand top, mascot+ring
/// in the middle, time range across the bottom so you always see when
/// you slept at a glance.
struct SmallSleepWidgetView: View {
    let data: SleepWidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Brand row gets the priority — discoverability is half the
            // point of a widget on someone else's home screen. Quality
            // chip drops to a dot if there isn't room.
            HStack(alignment: .center, spacing: 6) {
                brandMark
                    .layoutPriority(2)
                Spacer(minLength: 0)
                qualityChip
                    .layoutPriority(1)
            }

            HStack(alignment: .center, spacing: 10) {
                SleepScoreRing(
                    progress: data.ringProgress,
                    tint: data.scoreTint,
                    lineWidth: 6
                ) {
                    MooniMascotView()
                }
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 0) {
                    Text("\(data.score)")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(SleepWidgetPalette.textPrimary)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text(scoreCaption)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(SleepWidgetPalette.textTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                footerMetric(
                    icon: "bed.double.fill",
                    value: data.sleepDuration,
                    label: "Asleep",
                    color: data.scoreTint
                )
                footerMetric(
                    icon: "alarm.fill",
                    value: "\(data.sleepStart)→\(data.wakeTime)",
                    label: "Window",
                    color: SleepWidgetPalette.textSecondary
                )
            }
        }
    }

    /// Made deliberately bold + slightly bigger than before so the app
    /// name reads at a glance. Anyone glancing at a friend's lock screen
    /// can identify the source app — that's the whole growth loop.
    private var brandMark: some View {
        HStack(spacing: 4) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: [SleepWidgetPalette.textPrimary, data.scoreTint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text("SleepOwl")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .tracking(0.1)
                .foregroundStyle(SleepWidgetPalette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .allowsTightening(true)
        }
    }

    private var qualityChip: some View {
        // Tightened width (was 58) so the brand mark always wins room when
        // the system pads the small widget tighter than expected.
        Text(data.quality)
            .font(.system(size: 8, weight: .heavy, design: .rounded))
            .tracking(0.15)
            .textCase(.uppercase)
            .foregroundStyle(data.scoreTint)
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .allowsTightening(true)
            .frame(maxWidth: 50)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(data.scoreTint.opacity(0.18)))
            .overlay(Capsule().stroke(data.scoreTint.opacity(0.35), lineWidth: 0.5))
    }

    private var scoreCaption: String {
        data.score >= 85 ? "sleep score" : "recovery score"
    }

    private func footerMetric(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(SleepWidgetPalette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                    .allowsTightening(true)
            }
            Text(label)
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .foregroundStyle(SleepWidgetPalette.textTertiary)
                .textCase(.uppercase)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(SleepWidgetPalette.chipBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
