import SwiftUI

/// Small widget — hero-score layout. The score number is the focal point:
/// massive, tinted glow, paired with a gradient ring on the right. Brand mark
/// sits at the top, a single elegant chip at the bottom shows duration +
/// window in one line. Way more visual hierarchy than the previous design.
struct SmallSleepWidgetView: View {
    let data: SleepWidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top: brand mark + quality pill
            HStack(alignment: .center, spacing: 6) {
                brandMark
                    .layoutPriority(2)
                Spacer(minLength: 0)
                qualityChip
                    .layoutPriority(1)
            }

            Spacer(minLength: 0)

            // Hero row — massive score number + glowing ring with mascot
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: -4) {
                    Text("\(data.score)")
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .foregroundStyle(scoreGradient)
                        .shadow(color: data.scoreTint.opacity(0.55), radius: 12, y: 0)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(scoreCaption)
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .foregroundStyle(SleepWidgetPalette.textTertiary)
                        .tracking(1.4)
                        .textCase(.uppercase)
                }
                Spacer(minLength: 0)
                ringHero
            }

            Spacer(minLength: 0)

            // Footer — one elegant glassy chip: duration + window
            footerChip
        }
    }

    // MARK: Brand

    private var brandMark: some View {
        HStack(spacing: 4) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: [SleepWidgetPalette.textPrimary, data.scoreTint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text("SleepOwl")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .tracking(0.1)
                .foregroundStyle(SleepWidgetPalette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
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
            .frame(maxWidth: 52)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(data.scoreTint.opacity(0.22))
            )
            .overlay(
                Capsule().stroke(data.scoreTint.opacity(0.45), lineWidth: 0.6)
            )
    }

    // MARK: Ring hero

    private var ringHero: some View {
        ZStack {
            // Outer soft glow — gives the ring depth
            Circle()
                .fill(data.scoreTint.opacity(0.18))
                .frame(width: 70, height: 70)
                .blur(radius: 8)

            // Track
            Circle()
                .stroke(SleepWidgetPalette.ringTrack, lineWidth: 7)
                .frame(width: 58, height: 58)

            // Progress — gradient stroke, rotated so it starts at 12 o'clock
            Circle()
                .trim(from: 0, to: data.ringProgress)
                .stroke(
                    AngularGradient(
                        colors: [
                            data.scoreTint.opacity(0.6),
                            data.scoreTint,
                            data.scoreTint.opacity(0.9)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .frame(width: 58, height: 58)
                .rotationEffect(.degrees(-90))
                .shadow(color: data.scoreTint.opacity(0.55), radius: 6)

            MooniMascotView()
                .frame(width: 32, height: 32)
        }
        .frame(width: 70, height: 70)
    }

    private var scoreCaption: String {
        data.score >= 85 ? "sleep score" : "tonight"
    }

    private var scoreGradient: LinearGradient {
        LinearGradient(
            colors: [
                SleepWidgetPalette.textPrimary,
                data.scoreTint
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: Footer
    //
    // Stacked layout: duration on the top line, time-range on the line
    // below. Previously these two lived on a single horizontal row and the
    // time-range got shrunk to illegibility by minimumScaleFactor on small
    // devices. Two lines give each value its own font budget.

    private var footerChip: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: "bed.double.fill")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(data.scoreTint)
                Text(data.sleepDuration)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(SleepWidgetPalette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }
            Text("\(data.sleepStart) → \(data.wakeTime)")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(SleepWidgetPalette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
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
