import SwiftUI
import UIKit

/// On iPad, the app's iPhone-shaped layout would stretch absurdly wide. The
/// `.responsiveContainer()` modifier caps the content column at a comfortable
/// reading width (≤540pt) and centers it horizontally, while leaving any
/// edge-to-edge background (stars, gradients) free to fill the whole screen.
///
/// Apply it to a view's *content* — not the background — e.g. wrap the inner
/// VStack rather than the outer ZStack. On iPhone the modifier is a no-op so
/// nothing changes.
///
/// App Review specifically calls out: "users expect apps to function on all
/// the devices where they are available." On iPad, the unconstrained iPhone
/// layout reads as broken; this gives it a deliberate, comfortable column.
struct ResponsiveContainerModifier: ViewModifier {
    let maxWidth: CGFloat

    func body(content: Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            content
                .frame(maxWidth: maxWidth)
                .frame(maxWidth: .infinity, alignment: .center)
        } else {
            content
        }
    }
}

extension View {
    /// Caps content at `maxWidth` and centers it on iPad. No-op on iPhone.
    func responsiveContainer(maxWidth: CGFloat = 540) -> some View {
        modifier(ResponsiveContainerModifier(maxWidth: maxWidth))
    }
}
