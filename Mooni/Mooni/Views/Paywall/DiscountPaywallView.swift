import SwiftUI
import Combine
import RevenueCat

/// Win-back paywall shown when the user dismisses the main paywall.
/// 5-minute countdown, 50% off framing, single tap to accept or decline.
struct DiscountPaywallView: View {
    let petName: String
    let onAccept: () -> Void
    let onDecline: () -> Void

    @StateObject private var manager = SubscriptionManager.shared
    @State private var secondsRemaining: Int = 5 * 60
    @State private var animateIn = false
    @State private var pulse = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var minutes: Int { secondsRemaining / 60 }
    private var seconds: Int { secondsRemaining % 60 }
    private var timeLabel: String {
        String(format: "%d:%02d", minutes, seconds)
    }

    /// The real, lower-priced annual package from the `discount` offering in
    /// RevenueCat. If this is nil the dashboard hasn't been set up — we fall
    /// back to a non-discount CTA so we never show "50% off" while charging
    /// the full price.
    private var discountPackage: Package? { manager.discountAnnualPackage }
    private var regularPackage: Package? { manager.regularAnnualPackage }
    private var purchasePackage: Package? { discountPackage ?? regularPackage }
    private var hasRealDiscount: Bool { discountPackage != nil && regularPackage != nil }

    var body: some View {
        ZStack {
            MooniColor.background
                .ignoresSafeArea()
            StarsBackground(count: 60)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    // Top urgency bar
                    HStack {
                        Spacer()
                        // Even more hidden close — small, faint, top-trailing
                        Button(action: onDecline) {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .regular))
                                .foregroundColor(Color.white.opacity(0.18))
                                .padding(8)
                                .contentShape(Rectangle())
                        }
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 16)

                    // Hero
                    VStack(spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "gift.fill")
                                .foregroundColor(MooniColor.warning)
                            Text("JUST FOR YOU")
                                .font(MooniFont.caption(13))
                                .foregroundColor(MooniColor.warning)
                                .tracking(2)
                        }
                        Text(hasRealDiscount ? "Wait — special offer" : "One last chance")
                            .font(MooniFont.display(38))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        Text("\(petName) doesn't want you to leave.")
                            .font(MooniFont.body(15))
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                    }
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 8)

                    // Countdown card
                    VStack(spacing: 10) {
                        Text("Offer expires in")
                            .font(MooniFont.caption(13))
                            .foregroundColor(.white.opacity(0.7))
                        Text(timeLabel)
                            .font(.system(size: 56, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .scaleEffect(pulse ? 1.05 : 1.0)
                            .shadow(color: MooniColor.warning.opacity(0.5), radius: pulse ? 18 : 8)
                        ProgressView(value: Double(secondsRemaining), total: 300.0)
                            .tint(MooniColor.warning)
                            .padding(.horizontal, 20)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.10))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(MooniColor.warning.opacity(0.45), lineWidth: 1.5)
                    )
                    .padding(.horizontal, 24)

                    // Price comparison — only show "Was → Now" if a real
                    // discount package exists, otherwise just show the price.
                    if hasRealDiscount {
                        priceComparison
                            .padding(.horizontal, 24)
                    } else if let pkg = purchasePackage {
                        singlePriceCard(pkg)
                            .padding(.horizontal, 24)
                    }

                    // Why this offer
                    VStack(spacing: 10) {
                        offerRow(icon: "checkmark.seal.fill", text: "Full SleepOwl Pro — every feature unlocked")
                        offerRow(icon: "pawprint.fill", text: "All pet evolutions & rare forms")
                        offerRow(icon: "wind", text: "Sleep stories, breathing & 7-day reset")
                        offerRow(icon: "chart.bar.fill", text: "Advanced analytics & sleep coach")
                    }
                    .padding(.horizontal, 24)

                    // CTA
                    PrimaryButton(title: ctaTitle, icon: "sparkles") {
                        Task {
                            if let pkg = purchasePackage {
                                let success = await manager.purchase(package: pkg)
                                if success { onAccept() }
                            } else {
                                onAccept()
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 4)

                    // Tiny no-thanks
                    Button(action: onDecline) {
                        Text("No thanks, I don't want to feel rested")
                            .font(MooniFont.caption(11))
                            .foregroundColor(.white.opacity(0.30))
                            .underline()
                    }
                    .padding(.bottom, 8)

                    Text("Subscriptions auto-renew. Cancel anytime in Settings.")
                        .font(MooniFont.caption(10))
                        .foregroundColor(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 32)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { animateIn = true }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) { pulse = true }
        }
        .onReceive(timer) { _ in
            if secondsRemaining > 0 { secondsRemaining -= 1 }
        }
        .task { await manager.loadOfferings() }
    }

    private var priceComparison: some View {
        HStack(spacing: 12) {
            VStack(spacing: 6) {
                Text("Was")
                    .font(MooniFont.caption(11))
                    .foregroundColor(.white.opacity(0.7))
                Text(originalPriceLabel)
                    .font(MooniFont.title(20))
                    .foregroundColor(.white.opacity(0.55))
                    .strikethrough()
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Image(systemName: "arrow.right")
                .foregroundColor(MooniColor.warning)

            VStack(spacing: 6) {
                Text("NOW")
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.warning)
                Text(discountPriceLabel)
                    .font(MooniFont.title(22))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(MooniColor.warning.opacity(0.20))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(MooniColor.warning, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    /// Localized price string of the regular annual package — comes straight
    /// from StoreKit so it's always the user's local currency.
    private var originalPriceLabel: String {
        guard let p = regularPackage else { return "" }
        return "\(p.storeProduct.localizedPriceString) / yr"
    }

    /// Localized price of the actual discount package the user will be
    /// charged. No client-side arithmetic, no formatter mismatch — whatever
    /// App Store Connect reports is what we display and what we charge.
    private var discountPriceLabel: String {
        guard let p = discountPackage else { return "" }
        return "\(p.storeProduct.localizedPriceString) / yr"
    }

    private var ctaTitle: String {
        if hasRealDiscount, let p = discountPackage {
            return "Claim — \(p.storeProduct.localizedPriceString) / yr"
        }
        if let p = purchasePackage {
            return "Continue — \(p.storeProduct.localizedPriceString) / yr"
        }
        return "Continue"
    }

    private func singlePriceCard(_ pkg: Package) -> some View {
        VStack(spacing: 6) {
            Text("Annual plan")
                .font(MooniFont.caption(11))
                .foregroundColor(.white.opacity(0.7))
            Text("\(pkg.storeProduct.localizedPriceString) / yr")
                .font(MooniFont.title(22))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MooniColor.accent.opacity(0.35), lineWidth: 1)
        )
    }

    private func offerRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(MooniColor.success)
            Text(text)
                .font(MooniFont.title(14))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    DiscountPaywallView(petName: "Nova", onAccept: {}, onDecline: {})
}
