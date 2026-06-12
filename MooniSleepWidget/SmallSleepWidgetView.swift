import SwiftUI

/// Small widget — the mascot-ring design, sized for 2×2.
/// Brand + quality share the top row, the gradient score (with TONIGHT
/// label) sits beside the owl-in-ring, and a single full-width duration
/// chip closes the layout. The bed→wake schedule lives on the medium
/// widget only — at this size it always truncated.
struct SmallSleepWidgetView: View {
    let data: SleepWidgetData

    var body: some View {
        VStack(spacing: 0) {
            // ── Top: brand + quality
            HStack(spacing: 3) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(data.scoreTint)
                Text("SleepOwl")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(SleepWidgetPalette.textSecondary)
                    .lineLimit(1)
                    .fixedSize()
                Spacer(minLength: 2)
                Text(data.quality.uppercased())
                    .font(.system(size: 7.5, weight: .heavy, design: .rounded))
                    .tracking(0.3)
                    .foregroundStyle(data.scoreTint)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(data.scoreTint.opacity(0.22)))
            }

            Spacer(minLength: 2)

            // ── Middle: score left, owl-in-ring right
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: -1) {
                    Text("\(data.score)")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(scoreGradient)
                        .shadow(color: data.scoreTint.opacity(0.45), radius: 8)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("TONIGHT")
                        .font(.system(size: 8, weight: .heavy, design: .rounded))
                        .tracking(1.3)
                        .foregroundStyle(SleepWidgetPalette.textTertiary)
                }
                Spacer(minLength: 2)
                ringHero
                    .frame(width: 58, height: 58)
            }

            Spacer(minLength: 2)

            // ── Bottom: one duration chip, full width — can't truncate
            HStack(spacing: 4) {
                Image(systemName: "bed.double.fill")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(data.scoreTint)
                Text(data.sleepDuration)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(SleepWidgetPalette.textPrimary)
                    .lineLimit(1)
                    .fixedSize()
                Text("asleep")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(SleepWidgetPalette.textTertiary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(SleepWidgetPalette.chipBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(data.scoreTint.opacity(0.18), lineWidth: 0.6)
            )
        }
    }

    private var ringHero: some View {
        ZStack {
            Circle()
                .fill(data.scoreTint.opacity(0.20))
                .frame(width: 60, height: 60)
                .blur(radius: 8)

            Circle()
                .stroke(SleepWidgetPalette.ringTrack, lineWidth: 5)
                .frame(width: 54, height: 54)

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
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .frame(width: 54, height: 54)
                .rotationEffect(.degrees(-90))
                .shadow(color: data.scoreTint.opacity(0.5), radius: 5)

            MooniMascotView()
                .frame(width: 32, height: 32)
        }
    }

    private var scoreGradient: LinearGradient {
        LinearGradient(
            colors: [SleepWidgetPalette.textPrimary, data.scoreTint],
            startPoint: .top, endPoint: .bottom
        )
    }
}
