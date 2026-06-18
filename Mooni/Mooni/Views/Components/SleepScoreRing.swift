import SwiftUI

struct SleepScoreRing: View {
    let score: Int
    var size: CGFloat = 140
    var lineWidth: CGFloat = 14

    private var progress: CGFloat { CGFloat(min(max(score, 0), 100)) / 100 }

    private var color: Color {
        switch score {
        case 85...:   return MooniColor.success
        case 70..<85: return MooniColor.accent
        case 50..<70: return MooniColor.warning
        default:      return MooniColor.danger
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(MooniColor.hairline, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.8), value: progress)

            // Just the number — the context (a sleep-score ring) is always
            // clear from where it's used, and the label overflowed the smaller
            // rings in the history list.
            Text("\(score)")
                .font(MooniFont.display(size * 0.34))
                .foregroundColor(MooniColor.textPrimary)
        }
        .frame(width: size, height: size)
    }
}
