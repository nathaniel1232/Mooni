import SwiftUI

/// Warm red blend overlay rendered on top of the whole app when the
/// wind-down dim controller is active. iOS won't let us flip the system
/// red Color Filter, so we approximate it inside Mooni.
struct WindDownTintOverlay: View {
    @ObservedObject private var controller = WindDownDimController.shared

    var body: some View {
        ZStack {
            if controller.isActive {
                Color(red: 0.85, green: 0.05, blue: 0.05)
                    .blendMode(.multiply)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.6), value: controller.isActive)
    }
}
