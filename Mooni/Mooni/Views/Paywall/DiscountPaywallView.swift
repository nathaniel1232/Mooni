import SwiftUI
import RevenueCat

struct DiscountPaywallView: View {
    let petName: String
    let onAccept: () -> Void
    let onDecline: () -> Void

    @StateObject private var manager = SubscriptionManager.shared

    @State private var secondsRemaining: Int = 10 * 60
    @State private var animateIn = false
    @State private var badgePulse = false
    @State private var isPurchasing = false



    private var minutes: Int { secondsRemaining / 60 }
    private var seconds: Int { secondsRemaining % 60 }
    private var timeLabel: String { String(format: "%d:%02d", minutes, seconds) }

    private var discountPackage: Package? { manager.discountAnnualPackage }
    private var regularPackage: Package? { manager.regularAnnualPackage }
    private var purchasePackage: Package? { discountPackage ?? regularPackage }
    private var hasRealDiscount: Bool { discountPackage != nil && regularPackage != nil }

    private var actualDiscountPercent: Int {
        guard let r = regularPackage, let d = discountPackage else { return 0 }
        let regular = NSDecimalNumber(decimal: r.storeProduct.price as Decimal).doubleValue
        let disc    = NSDecimalNumber(decimal: d.storeProduct.price as Decimal).doubleValue
        guard regular > 0, disc < regular else { return 0 }
        return max(1, Int(round((1 - disc / regular) * 100)))
    }

    private var monthlyEquiv: String {
        guard let pkg = purchasePackage else { return "" }
        let annual = NSDecimalNumber(decimal: pkg.storeProduct.price as Decimal).doubleValue
        let symbol = pkg.storeProduct.priceFormatter?.currencySymbol ?? "$"
        return String(format: "%@%.2f/mo", symbol, annual / 12)
    }

    private var hasIntroOffer: Bool {
        purchasePackage?.storeProduct.introductoryDiscount != nil
    }

    private var trialLabel: String {
        guard let intro = purchasePackage?.storeProduct.introductoryDiscount else { return "" }
        return "\(intro.subscriptionPeriod.value)-\(periodUnit(intro.subscriptionPeriod.unit).uppercased()) FREE TRIAL"
    }

    private func periodUnit(_ unit: SubscriptionPeriod.Unit) -> String {
        switch unit {
        case .day:   return "day"
        case .week:  return "week"
        case .month: return "month"
        case .year:  return "year"
        @unknown default: return "day"
        }
    }

    var body: some View {
        ZStack {
            MooniGradient.night.ignoresSafeArea()
            StarsBackground(count: 60).opacity(0.7)

            VStack(spacing: 0) {
                // Close
                HStack {
                    Spacer()
                    Button(action: onDecline) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.75))
                            .frame(width: 30, height: 30)
                            .background(Color.white.opacity(0.10))
                            .clipShape(Circle())
                            .contentShape(Rectangle())
                    }
                }
                .padding(.top, 12)
                .padding(.horizontal, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {

                        // Header
                        VStack(spacing: 6) {
                            Text("Your one-time offer")
                                .font(.system(size: 28, weight: .heavy, design: .rounded))
                                .foregroundColor(MooniColor.textPrimary)
                                .multilineTextAlignment(.center)
                                .opacity(animateIn ? 1 : 0)
                                .offset(y: animateIn ? 0 : 8)
                        }
                        .padding(.top, 4)

                        // Big discount badge
                        ZStack {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [MooniColor.accent.opacity(0.85), MooniColor.accentSoft.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 240, height: 120)
                                .shadow(color: MooniColor.accent.opacity(0.5), radius: 24, y: 8)
                                .scaleEffect(badgePulse ? 1.03 : 1.0)

                            VStack(spacing: 2) {
                                if hasRealDiscount && actualDiscountPercent >= 5 {
                                    Text("\(actualDiscountPercent)% OFF")
                                        .font(.system(size: 38, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                    Text("FOREVER")
                                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                                        .foregroundColor(.white.opacity(0.85))
                                        .tracking(4)
                                } else {
                                    Text("SPECIAL")
                                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                                        .foregroundColor(.white.opacity(0.85))
                                        .tracking(4)
                                    Text("OFFER")
                                        .font(.system(size: 38, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                }
                            }

                            // Sparkles
                            ForEach([(CGPoint(x: -105, y: -45), 18.0),
                                     (CGPoint(x:  110, y: -50), 22.0),
                                     (CGPoint(x: -100, y:  40), 14.0),
                                     (CGPoint(x:  108, y:  42), 16.0)], id: \.0.x) { pos, size in
                                Image(systemName: "sparkle")
                                    .font(.system(size: size, weight: .bold))
                                    .foregroundColor(.white.opacity(0.75))
                                    .offset(x: pos.x, y: pos.y)
                            }
                        }
                        .opacity(animateIn ? 1 : 0)
                        .animation(.easeOut(duration: 0.5).delay(0.1), value: animateIn)

                        // Price comparison
                        if hasRealDiscount {
                            HStack(spacing: 10) {
                                Text(regularPackage?.storeProduct.localizedPriceString ?? "")
                                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white.opacity(0.40))
                                    .strikethrough(color: .white.opacity(0.4))

                                Text(monthlyEquiv)
                                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                                    .foregroundColor(MooniColor.textPrimary)
                            }
                            .opacity(animateIn ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.18), value: animateIn)
                        }

                        // Subtitle
                        VStack(spacing: 4) {
                            Text("Once you close this offer, it's gone.")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(MooniColor.textSecondary)
                                .multilineTextAlignment(.center)

                            HStack(spacing: 5) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(MooniColor.warning)
                                Text("Expires in \(timeLabel)")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(MooniColor.warning)
                            }
                        }
                        .opacity(animateIn ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.22), value: animateIn)

                        // Plan card
                        if let pkg = purchasePackage {
                            VStack(spacing: 0) {
                                if hasIntroOffer {
                                    Text(trialLabel)
                                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                                        .foregroundColor(.white)
                                        .tracking(1.5)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(MooniColor.accent)
                                }

                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Yearly Plan")
                                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                                            .foregroundColor(MooniColor.textPrimary)
                                        Text("12 mo · \(pkg.storeProduct.localizedPriceString)")
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundColor(MooniColor.textSecondary)
                                    }
                                    Spacer()
                                    Text(monthlyEquiv)
                                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                                        .foregroundColor(MooniColor.textPrimary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.06))
                            }
                            .clipShape(RoundedRectangle(cornerRadius: hasIntroOffer ? 14 : 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(MooniColor.accent.opacity(0.5), lineWidth: 1.5)
                            )
                            .opacity(animateIn ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.26), value: animateIn)
                        }

                        // CTA
                        Button {
                            guard let pkg = purchasePackage else { return }
                            isPurchasing = true
                            Task {
                                let outcome = await manager.purchase(package: pkg)
                                isPurchasing = false
                                // Treat charged-but-finalizing the same as
                                // active here — this win-back screen has no
                                // separate finalizing state and is dead in the
                                // shipped flow; entitlement reconciles shortly.
                                switch outcome {
                                case .active, .pendingActivation:
                                    onAccept()
                                case .cancelled, .failed:
                                    break
                                }
                            }
                        } label: {
                            ZStack {
                                if isPurchasing || manager.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(hasIntroOffer ? "Start Free Trial" : "Claim Offer")
                                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: [MooniColor.accentSoft, MooniColor.accent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: MooniColor.accent.opacity(0.5), radius: 14, y: 5)
                        }
                        .buttonStyle(.plain)
                        .disabled(manager.isLoading || isPurchasing || purchasePackage == nil)
                        .opacity(animateIn ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.30), value: animateIn)

                        // Footer
                        VStack(spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                Text("No Commitment – Cancel Anytime")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(MooniColor.textSecondary)

                            Button { Task { await manager.restorePurchases() } } label: {
                                Text("Restore purchase")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(MooniColor.accentSoft)
                            }

                            Text("Auto-renews unless cancelled in Settings → Apple ID → Subscriptions.")
                                .font(.system(size: 10, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.35))
                                .multilineTextAlignment(.center)

                            HStack(spacing: 14) {
                                Link("Terms",
                                     destination: URL(string: "https://sleepowlapp.vercel.app/terms")!)
                                Link("Privacy",
                                     destination: URL(string: "https://sleepowlapp.vercel.app/privacy")!)
                            }
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.40))
                        }
                        .opacity(animateIn ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.34), value: animateIn)

                        // No thanks
                        Button(action: onDecline) {
                            Text("No thanks, I'll pay full price")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.25))
                                .underline()
                        }
                        .padding(.bottom, 24)
                        .opacity(animateIn ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.38), value: animateIn)
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { animateIn = true }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { badgePulse = true }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if secondsRemaining > 0 { secondsRemaining -= 1 }
            }
        }
        .task { await manager.loadOfferings() }
    }
}

#Preview {
    DiscountPaywallView(petName: "Luna", onAccept: {}, onDecline: {})
}
