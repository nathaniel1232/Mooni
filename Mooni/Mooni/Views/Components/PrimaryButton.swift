import SwiftUI

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(MooniColor.background)
                } else {
                    if let icon { Image(systemName: icon) }
                    Text(title)
                        .font(MooniFont.title(17))
                }
            }
            .foregroundColor(MooniColor.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [MooniColor.accentSoft, MooniColor.accent],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: MooniColor.accent.opacity(0.4), radius: 18, y: 8)
            .opacity(isLoading ? 0.7 : 1)
        }
        .disabled(isLoading)
        .animation(.easeInOut(duration: 0.18), value: isLoading)
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
