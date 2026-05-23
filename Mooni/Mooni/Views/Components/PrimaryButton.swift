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
    enum Variant {
        /// Default app style — rounded rectangle (16pt corner).
        case standard
        /// Onboarding style — capsule pill matching `PrimaryButton.white`,
        /// so a stacked "primary white" + "secondary" pair share the same
        /// silhouette instead of one being noticeably less rounded.
        case capsule
    }

    let title: String
    var icon: String? = nil
    var variant: Variant = .standard
    let action: () -> Void

    private var corner: CGFloat {
        switch variant {
        case .standard: return 16
        case .capsule:  return 999
        }
    }
    private var verticalPadding: CGFloat {
        switch variant {
        case .standard: return 14
        case .capsule:  return 17 // matches PrimaryButton.white
        }
    }
    private var titleFont: Font {
        switch variant {
        case .standard: return MooniFont.title(15)
        case .capsule:  return MooniFont.title(17) // matches PrimaryButton.white
        }
    }

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon) }
                Text(title)
                    .font(titleFont)
            }
            .foregroundColor(MooniColor.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, verticalPadding)
            .background(Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        }
    }
}
