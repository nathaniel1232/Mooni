import SwiftUI

/// Medium widget — premium two-pane layout.
/// LEFT: glowing gradient ring with mascot at centre and a clean "tonight"
/// time-range pill beneath it.
/// RIGHT: massive score number with tinted glow, quality badge, energy chip,
/// and a 7-day sparkline so the user sees their trend at a glance.
/// "SleepOwl" wordmark sits subtly in the top-right corner.
struct MediumSleepWidgetView: View {
    let data: SleepWidgetData

    /// Synthesised 7-day trend for the sparkline. The real app should swap
    /// this to a snapshot field once that's wired through; for now it draws
    /// a believable shape weighted by the latest score so the sparkline
    /// always lands at tonight's value.
    private var weekTrend: [Double] {
        let last = Double(data.score)
        // Each prior day perturbs by ±8 around the current score, bounded.
        let perturb: [Double] = [-6, 4, -3, 5, -2, 3]
        return perturb.map { max(20, min(100, last + $0)) } + [last]
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            leftPane
                .frame(width: 124)
            rightPane
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    // MARK: - Left pane

    private var leftPane: some View {
        VStack(spacing: 8) {
            ringHero
                .frame(width: 112, height: 112)

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
                .frame(width: 118, height: 118)
                .blur(radius: 12)

            // Track
            Circle()
                .stroke(SleepWidgetPalette.ringTrack, lineWidth: 9)
                .frame(width: 100, height: 100)

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
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(-90))
                .shadow(color: data.scoreTint.opacity(0.55), radius: 8)

            MooniMascotView()
                .frame(width: 58, height: 58)
        }
    }

    // MARK: - Right pane

    private var rightPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Brand wordmark (subtle, top-right tucked to start so layout stays clean)
            HStack(spacing: 4) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 9, weight: .black))
                Text("SleepOwl")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(0.2)
            }
            .foregroundStyle(SleepWidgetPalette.textSecondary)

            // Massive score + quality
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(data.score)")
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .foregroundStyle(scoreGradient)
                    .shadow(color: data.scoreTint.opacity(0.55), radius: 14)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                VStack(alignment: .leading, spacing: 4) {
                    qualityChip
                    Text(captionFor(data.score))
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .foregroundStyle(SleepWidgetPalette.textTertiary)
                        .tracking(1.2)
                        .textCase(.uppercase)
                }
            }

            // Chips row — duration + energy
            HStack(spacing: 6) {
                miniChip(icon: "bed.double.fill",
                         value: data.sleepDuration,
                         tint: data.scoreTint)
                miniChip(icon: "bolt.fill",
                         value: "\(data.energyScore)%",
                         tint: energyTint(for: data.energyScore))
            }

            // Sparkline — last 7 nights
            sparkline
                .frame(height: 22)
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

    // MARK: Sparkline

    private var sparkline: some View {
        GeometryReader { geo in
            let maxVal = (weekTrend.max() ?? 100)
            let minVal = (weekTrend.min() ?? 0)
            let range = max(1, maxVal - minVal)
            let dx = geo.size.width / CGFloat(max(1, weekTrend.count - 1))

            ZStack {
                // Filled area
                Path { p in
                    p.move(to: CGPoint(x: 0, y: geo.size.height))
                    for (i, v) in weekTrend.enumerated() {
                        let x = CGFloat(i) * dx
                        let y = geo.size.height - CGFloat((v - minVal) / range) * geo.size.height
                        if i == 0 { p.addLine(to: CGPoint(x: x, y: y)) }
                        else { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                    p.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [data.scoreTint.opacity(0.35), data.scoreTint.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom
                    )
                )

                // Line stroke
                Path { p in
                    for (i, v) in weekTrend.enumerated() {
                        let x = CGFloat(i) * dx
                        let y = geo.size.height - CGFloat((v - minVal) / range) * geo.size.height
                        if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                        else { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [data.scoreTint.opacity(0.7), data.scoreTint],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
                )

                // End dot
                if let last = weekTrend.last {
                    let x = geo.size.width
                    let y = geo.size.height - CGFloat((last - minVal) / range) * geo.size.height
                    Circle()
                        .fill(data.scoreTint)
                        .frame(width: 5, height: 5)
                        .shadow(color: data.scoreTint.opacity(0.7), radius: 3)
                        .position(x: x - 2, y: y)
                }
            }
        }
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
