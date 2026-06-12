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
                .stroke(Color.white.opacity(0.08), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.8), value: progress)

            VStack(spacing: 2) {
                Text("\(score)")
                    .font(MooniFont.display(size * 0.32))
                    .foregroundColor(MooniColor.textPrimary)
                Text("Sleep score")
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.textSecondary)
            }
        }
        .frame(width: size, height: size)
    }
}
