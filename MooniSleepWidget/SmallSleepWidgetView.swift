import SwiftUI

/// Small widget — tight, balanced layout. SleepOwl brand top, mascot+ring
/// in the middle, time range across the bottom so you always see when
/// you slept at a glance.
struct SmallSleepWidgetView: View {
    let data: SleepWidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 6) {
                brandMark
                Spacer(minLength: 0)
                qualityChip
            }

            HStack(alignment: .center, spacing: 10) {
                SleepScoreRing(
                    progress: data.ringProgress,
                    tint: data.scoreTint,
                    lineWidth: 6
                ) {
                    MooniMascotView()
                }
                .frame(width: 68, height: 68)

                VStack(alignment: .leading, spacing: 0) {
                    Text("\(data.score)")
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
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

    private var brandMark: some View {
        HStack(spacing: 5) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(SleepWidgetPalette.textPrimary)
            Text("SleepOwl")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(0.2)
                .foregroundStyle(SleepWidgetPalette.textPrimary)
                .lineLimit(1)
        }
    }

    private var qualityChip: some View {
        Text(data.quality)
            .font(.system(size: 8, weight: .heavy, design: .rounded))
            .tracking(0.15)
            .textCase(.uppercase)
            .foregroundStyle(data.scoreTint)
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .allowsTightening(true)
            .frame(maxWidth: 58)
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
