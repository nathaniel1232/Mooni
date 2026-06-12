import SwiftUI

/// Small widget — full rebuild.
/// Layout: brand row at top, big score-in-ring center, bedtime → wake row
/// at the bottom. The previous version cropped the time-range with
/// `minimumScaleFactor(0.6)`; this version gives each value its own row
/// so the user can read both at a glance.
struct SmallSleepWidgetView: View {
    let data: SleepWidgetData

    var body: some View {
        VStack(spacing: 0) {
            // ── Top: brand row
            HStack(spacing: 4) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(data.scoreTint)
                Text("SleepOwl")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(SleepWidgetPalette.textSecondary)
                    .tracking(0.2)
                Spacer(minLength: 0)
                qualityPill
            }

            Spacer(minLength: 0)

            // ── Center: big score on a tinted halo
            scoreHero

            Spacer(minLength: 0)

            // ── Bottom: bed → wake (two lines so neither shrinks)
            footer
        }
    }

    // MARK: Quality pill

    private var qualityPill: some View {
        Text(data.quality.uppercased())
            .font(.system(size: 8, weight: .heavy, design: .rounded))
            .tracking(0.5)
            .foregroundStyle(data.scoreTint)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(data.scoreTint.opacity(0.22))
            )
            .overlay(
                Capsule().stroke(data.scoreTint.opacity(0.45), lineWidth: 0.5)
            )
    }

    // MARK: Score hero

    private var scoreHero: some View {
        ZStack {
            // Track + progress — flat solid arc, no halo, no white hot-spot.
            Circle()
                .stroke(SleepWidgetPalette.ringTrack, lineWidth: 5)
                .frame(width: 84, height: 84)
            Circle()
                .trim(from: 0, to: data.ringProgress)
                .stroke(
                    data.scoreTint,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .frame(width: 84, height: 84)
                .rotationEffect(.degrees(-90))

            VStack(spacing: -2) {
                Text("\(data.score)")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(SleepWidgetPalette.textPrimary)
                Text("SCORE")
                    .font(.system(size: 7, weight: .heavy, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(SleepWidgetPalette.textTertiary)
            }
        }
    }

    // MARK: Footer — two rows, no scale-to-fit

    private var footer: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "bed.double.fill")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(data.scoreTint)
                Text(data.sleepDuration)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(SleepWidgetPalette.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            HStack(spacing: 4) {
                Text(data.sleepStart)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(SleepWidgetPalette.textSecondary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 7, weight: .heavy))
                    .foregroundStyle(SleepWidgetPalette.textTertiary)
                Text(data.wakeTime)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(SleepWidgetPalette.textSecondary)
                Spacer(minLength: 0)
            }
            .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(SleepWidgetPalette.chipBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(data.scoreTint.opacity(0.18), lineWidth: 0.6)
        )
    }
}
