import SwiftUI

struct PrimaryButton: View {
    enum Variant {
        /// Default app style — accent (purple) fill with dark text.
        case accent
        /// Onboarding style — pure white pill with black text, very rounded.
        case white
    }

    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    var variant: Variant = .accent
    let action: () -> Void

    private var foreground: Color {
        switch variant {
        case .accent: return MooniColor.background
        case .white:  return .black
        }
    }
    private var fill: Color {
        switch variant {
        case .accent: return MooniColor.accent
        case .white:  return .white
        }
    }
    private var corner: CGFloat {
        switch variant {
        case .accent: return 18
        case .white:  return 999   // capsule
        }
    }

    var body: some View {
        Button {
            Haptics.soft()
            action()
        } label: {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(foreground)
                } else {
                    if let icon { Image(systemName: icon) }
                    Text(title)
                        .font(MooniFont.title(17))
                }
            }
            .foregroundColor(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
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
        Button {
            Haptics.tap()
            action()
        } label: {
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
