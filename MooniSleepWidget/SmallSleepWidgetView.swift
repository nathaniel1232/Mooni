import SwiftUI

/// Small widget — a calm "score gauge" card. A single open-bottom arc gauge is
/// the hero (premium, instantly readable, like a readiness ring), with a quiet
/// brand line above and one duration line below. A deliberate, uncluttered
/// redesign away from the old flat number-card.
struct SmallSleepWidgetView: View {
    let data: SleepWidgetData

    var body: some View {
        VStack(spacing: 0) {
            // Brand + quality
            HStack(spacing: 3) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(data.scoreTint)
                Text("SleepOwl")
                    .font(.system(size: 9.5, weight: .black, design: .rounded))
                    .foregroundStyle(SleepWidgetPalette.textSecondary)
                    .lineLimit(1)
                    .fixedSize()
                Spacer(minLength: 2)
                qualityPill
            }

            Spacer(minLength: 4)

            SleepGauge(score: data.score, tint: data.scoreTint, size: 92, lineWidth: 9)

            Spacer(minLength: 4)

            // Duration footer
            HStack(spacing: 4) {
                Image(systemName: "bed.double.fill")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(data.scoreTint)
                Text(data.sleepDuration)
                    .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(SleepWidgetPalette.textPrimary)
                    .fixedSize()
                Text("asleep")
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(SleepWidgetPalette.textTertiary)
            }
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
}

// MARK: - Shared gauge

/// Open-bottom (270°) arc gauge with the score centered. Shared by the small &
/// medium widgets so the whole set reads as one design language.
struct SleepGauge: View {
    let score: Int
    let tint: Color
    var size: CGFloat = 90
    var lineWidth: CGFloat = 9
    var showCaption: Bool = true

    private var progress: Double { max(0, min(1, Double(score) / 100)) }

    var body: some View {
        ZStack {
            // Track — 270° arc, gap centered at the bottom.
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(SleepWidgetPalette.ringTrack,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(135))

            // Progress fill.
            Circle()
                .trim(from: 0, to: 0.75 * progress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [tint.opacity(0.55), tint]),
                        center: .center,
                        startAngle: .degrees(135),
                        endAngle: .degrees(135 + 270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(135))
                .shadow(color: tint.opacity(0.45), radius: 4)

            VStack(spacing: 0) {
                Text("\(score)")
                    .font(.system(size: size * 0.36, weight: .black, design: .rounded))
                    .foregroundStyle(SleepWidgetPalette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if showCaption {
                    Text("SCORE")
                        .font(.system(size: max(7, size * 0.085), weight: .heavy, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(SleepWidgetPalette.textTertiary)
                }
            }
        }
        .frame(width: size, height: size)
    }
}
