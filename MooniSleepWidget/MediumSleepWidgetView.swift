import SwiftUI

/// Medium widget — the mascot-ring design.
/// LEFT: glowing gradient ring with the owl mascot at centre and the
/// bed→wake time pill beneath it (the schedule gets its own dedicated,
/// full-width spot so it never truncates).
/// RIGHT: one balanced brand row (wordmark left, quality pill right),
/// the big gradient score with its TONIGHT label, then duration/energy
/// chips. Every row owns its own width budget — nothing collides.
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
                .frame(width: 100, height: 100)

            // Bed → wake pill — full pane width, scales gracefully.
            HStack(spacing: 4) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(data.scoreTint)
                Text("\(data.sleepStart) → \(data.wakeTime)")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundStyle(SleepWidgetPalette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
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
            // Soft glow behind the ring
            Circle()
                .fill(data.scoreTint.opacity(0.20))
                .frame(width: 104, height: 104)
                .blur(radius: 12)

            // Track
            Circle()
                .stroke(SleepWidgetPalette.ringTrack, lineWidth: 7)
                .frame(width: 90, height: 90)

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
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .frame(width: 90, height: 90)
                .rotationEffect(.degrees(-90))
                .shadow(color: data.scoreTint.opacity(0.5), radius: 7)

            MooniMascotView()
                .frame(width: 52, height: 52)
        }
    }

    // MARK: - Right pane

    private var rightPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Brand + quality on ONE balanced row — the wordmark owns the
            // left edge, the quality pill the right. No floating brand.
            HStack(spacing: 4) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 9, weight: .black))
                Text("SleepOwl")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(0.2)
                    .lineLimit(1)
                    .fixedSize()
                Spacer(minLength: 4)
                qualityChip
            }
            .foregroundStyle(SleepWidgetPalette.textSecondary)
            .padding(.top, 2)

            Spacer(minLength: 2)

            // Score block — gradient number + stacked label
            HStack(alignment: .center, spacing: 9) {
                Text("\(data.score)")
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .foregroundStyle(scoreGradient)
                    .shadow(color: data.scoreTint.opacity(0.45), radius: 10)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("TONIGHT")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(SleepWidgetPalette.textTertiary)
            }

            Spacer(minLength: 2)

            // Day stats — duration + energy, width-balanced.
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
        Text(data.quality.uppercased())
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .tracking(0.4)
            .foregroundStyle(data.scoreTint)
            .lineLimit(1)
            .fixedSize()
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

    // MARK: - Helpers

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
