import SwiftUI

/// Small widget — typographic "score card" design (2×2).
/// A complete redesign away from the old owl-in-ring: a brand row, one big
/// gradient score with a quality-bar underneath, and a single duration chip.
/// Clean, data-forward, and legible at a glance — no mascot, no ring.
struct SmallSleepWidgetView: View {
    let data: SleepWidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                qualityPill
            }

            Spacer(minLength: 0)

            // ── Hero score
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(data.score)")
                    .font(.system(size: 54, weight: .black, design: .rounded))
                    .foregroundStyle(scoreGradient)
                    .shadow(color: data.scoreTint.opacity(0.35), radius: 8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("/100")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(SleepWidgetPalette.textTertiary)
            }
            Text("LAST NIGHT")
                .font(.system(size: 8, weight: .heavy, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(SleepWidgetPalette.textTertiary)

            Spacer(minLength: 6)

            // ── Quality bar (replaces the ring as the progress motif)
            qualityBar
                .padding(.bottom, 8)

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

    private var qualityPill: some View {
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

    private var qualityBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(SleepWidgetPalette.ringTrack)
                Capsule()
                    .fill(LinearGradient(
                        colors: [data.scoreTint.opacity(0.65), data.scoreTint],
                        startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(8, geo.size.width * data.ringProgress))
                    .shadow(color: data.scoreTint.opacity(0.45), radius: 4)
            }
        }
        .frame(height: 8)
    }

    private var scoreGradient: LinearGradient {
        LinearGradient(
            colors: [SleepWidgetPalette.textPrimary, data.scoreTint],
            startPoint: .top, endPoint: .bottom
        )
    }
}
