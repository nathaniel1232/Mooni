import SwiftUI

struct StarsBackground: View {
    let count: Int
    @State private var twinkle: Bool = false

    init(count: Int = 60) { self.count = count }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<count, id: \.self) { i in
                    let seed = Double(i)
                    let x = CGFloat((seed * 73.31).truncatingRemainder(dividingBy: 1.0)) * geo.size.width
                    let y = CGFloat((seed * 191.97).truncatingRemainder(dividingBy: 1.0)) * geo.size.height
                    let size = CGFloat(((seed * 11.7).truncatingRemainder(dividingBy: 1.0)) * 2.2 + 0.6)
                    let opacity = ((seed * 17.3).truncatingRemainder(dividingBy: 1.0)) * 0.6 + 0.2

                    Circle()
                        .fill(Color.white)
                        .frame(width: size, height: size)
                        .position(x: x, y: y)
                        .opacity(twinkle ? opacity : opacity * 0.5)
                        .animation(
                            .easeInOut(duration: 2.0 + Double(i % 5) * 0.4)
                                .repeatForever(autoreverses: true),
                            value: twinkle
                        )
                }
            }
        }
        .onAppear { twinkle = true }
        .allowsHitTesting(false)
    }
}
