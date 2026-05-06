import SwiftUI

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    let action: () -> Void

    @State private var pulse = false
    @State private var shimmerOffset: CGFloat = -1.2
    @State private var pressed = false
    @State private var iconBob = false

    var body: some View {
        Button {
            // Tactile press feedback
            withAnimation(.spring(response: 0.18, dampingFraction: 0.55)) { pressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.6)) { pressed = false }
            }
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
            action()
        } label: {
            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .offset(y: iconBob ? -1.5 : 1.5)
                }
                Text(title)
                    .font(MooniFont.title(17))
            }
            .foregroundColor(MooniColor.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    LinearGradient(
                        colors: [MooniColor.accentSoft, MooniColor.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    // Sweeping shimmer
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0),
                                Color.white.opacity(0.55),
                                Color.white.opacity(0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 0.5)
                        .offset(x: geo.size.width * shimmerOffset)
                        .blendMode(.plusLighter)
                    }
                    .allowsHitTesting(false)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(pulse ? 0.35 : 0.15), lineWidth: 1)
            )
            .shadow(color: MooniColor.accent.opacity(pulse ? 0.55 : 0.35),
                    radius: pulse ? 22 : 14, y: 8)
            .scaleEffect(pressed ? 0.96 : (pulse ? 1.012 : 1.0))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulse = true
            }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                iconBob = true
            }
            // Loop the shimmer with a pause between sweeps.
            startShimmerLoop()
        }
    }

    private func startShimmerLoop() {
        shimmerOffset = -1.2
        withAnimation(.easeInOut(duration: 1.4)) {
            shimmerOffset = 1.4
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            startShimmerLoop()
        }
    }
}

struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon) }
                Text(title)
                    .font(MooniFont.title(15))
            }
            .foregroundColor(MooniColor.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
