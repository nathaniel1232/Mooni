import SwiftUI
import RevenueCat
import RevenueCatUI

// MARK: - PaywallView
//
// Trial-first paywall. Annual plan leads with a 7-day free trial; user can
// flip to Monthly for instant access without a trial. The timeline visual
// is meant as an invitation — what happens day-by-day on the trial — rather
// than a price wall.
//
// To wire the trial up in RevenueCat / App Store Connect, see the notes in
// SubscriptionManager — the trial period is configured on the StoreKit
// product itself as a 7-day Free intro offer, not in code.

struct PaywallView: View {
    /// `.short` is whichever short-period package the current Offering exposes
    /// — weekly or monthly. The dashboard decides; the UI adapts. This is the
    /// hook RevenueCat Experiments uses to A/B test weekly vs monthly without
    /// any code change: ship two Offerings ("short_weekly" / "short_monthly"),
    /// assign them in an experiment, the SDK rotates `current` accordingly.
    enum Plan { case annual, short }

    @StateObject private var manager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss

    /// When true (during onboarding), the close button is barely visible and
    /// dismissing routes the user to the discount paywall instead of closing.
    var hideCloseButton: Bool = false
    var onSoftDismiss: (() -> Void)? = nil
    var onPurchased: (() -> Void)? = nil
    /// Called when the offerings failed to load and the user taps the
    /// "Continue without subscribing" escape hatch. Routes around the
    /// discount paywall (which would also fail) and lets onboarding
    /// complete cleanly. Falls back to `dismiss()` if not provided.
    var onErrorContinue: (() -> Void)? = nil

    @State private var plan: Plan = .annual
    @State private var showCustomerCenter = false
    @State private var showSuccess = false
    @State private var animateIn = false
    @State private var moonGlow = false

    private var heroPet: Pet {
        var p = Pet()
        p.mood = .rested
        return p
    }

    private var annualPackage: Package? {
        manager.currentOffering?.availablePackages.first { $0.packageType == .annual }
    }

    /// Whichever short-period package this offering ships with. Weekly wins
    /// over monthly when both are present (rare — usually only one is set).
    private var shortPackage: Package? {
        let packages = manager.currentOffering?.availablePackages ?? []
        if let w = packages.first(where: { $0.packageType == .weekly }) { return w }
        return packages.first { $0.packageType == .monthly }
    }

    private var shortPeriodLabel: String {
        switch shortPackage?.packageType {
        case .weekly:  return "Weekly"
        case .monthly: return "Monthly"
        default:       return "Monthly"
        }
    }

    private var shortPerLabel: String {
        switch shortPackage?.packageType {
        case .weekly:  return "/week"
        default:       return "/mo"
        }
    }

    private var selectedPackage: Package? {
        plan == .annual ? annualPackage : shortPackage
    }

    var body: some View {
        ZStack {
            MooniGradient.night
                .ignoresSafeArea()
            StarsBackground(count: 70)
                .opacity(0.9)

            if showSuccess {
                successOverlay
            } else if manager.isLoadingOfferings {
                ProgressView()
                    .tint(MooniColor.accentSoft)
                    .scaleEffect(1.4)
            } else if manager.currentOffering == nil {
                offeringsErrorView
            } else {
                mainContent
            }
        }
        .task { await manager.loadOfferings() }
        .sheet(isPresented: $showCustomerCenter) {
            CustomerCenterView()
        }
    }

    private var offeringsErrorView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "wifi.slash")
                .font(.system(size: 38, weight: .semibold))
                .foregroundColor(MooniColor.textMuted)
            VStack(spacing: 8) {
                Text("Couldn't load plans")
                    .font(MooniFont.title(20))
                    .foregroundColor(MooniColor.textPrimary)
                Text("Check your connection and try again.")
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                Task { await manager.loadOfferings() }
            } label: {
                Text("Retry")
                    .font(MooniFont.title(16))
                    .foregroundColor(.white)
                    .frame(width: 140, height: 48)
                    .background(MooniColor.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            Spacer()
            // Bigger, more prominent escape hatch so a stuck App Review
            // (or any user with a transient StoreKit failure) can always
            // get into the app. Bypasses the discount paywall, which
            // depends on the same offerings load and would also fail.
            Button {
                if let err = onErrorContinue {
                    err()
                } else if let soft = onSoftDismiss {
                    soft()
                } else {
                    dismiss()
                }
            } label: {
                Text("Continue without subscribing")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Main content

    private var mainContent: some View {
        VStack(spacing: 0) {
            closeRow

            heroBlock
                .padding(.top, 4)
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 12)
                .animation(.spring(response: 0.65, dampingFraction: 0.78), value: animateIn)

            titleBlock
                .padding(.horizontal, 24)
                .padding(.top, 14)
                .opacity(animateIn ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.10), value: animateIn)

            planToggle
                .padding(.top, 14)
                .opacity(animateIn ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.14), value: animateIn)

            content
                .padding(.horizontal, 28)
                .padding(.top, 22)
                .opacity(animateIn ? 1 : 0)
                .animation(.easeOut(duration: 0.45).delay(0.18), value: animateIn)

            Spacer(minLength: 8)

            bottomBlock
                .opacity(animateIn ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.26), value: animateIn)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation { animateIn = true }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                moonGlow = true
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if plan == .annual {
            timeline
        } else {
            monthlyBenefits
        }
    }

    // MARK: - Close

    private var closeRow: some View {
        HStack {
            Spacer()
            Button {
                if hideCloseButton, let soft = onSoftDismiss { soft() } else { dismiss() }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(MooniColor.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Circle())
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Close paywall")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Hero (moon halo + owl)

    private var heroBlock: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [
                        MooniColor.accent.opacity(0.55),
                        MooniColor.accent.opacity(0.0)
                    ],
                    center: .center,
                    startRadius: 6,
                    endRadius: 140))
                .frame(width: 280, height: 200)
                .scaleEffect(moonGlow ? 1.04 : 0.96)
                .blur(radius: 6)

            Circle()
                .fill(LinearGradient(
                    colors: [
                        Color.white.opacity(0.18),
                        MooniColor.accent.opacity(0.35)
                    ],
                    startPoint: .top,
                    endPoint: .bottom))
                .frame(width: 140, height: 140)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.20), lineWidth: 1)
                )
                .shadow(color: MooniColor.accent.opacity(0.45), radius: 24, y: 6)

            DreamSpiritView(pet: heroPet, size: 95)
                .scaleEffect(animateIn ? 1 : 0.85)
        }
        .frame(height: 170)
    }

    // MARK: - Title

    private var titleBlock: some View {
        VStack(spacing: 6) {
            Text(plan == .annual && trialDays != nil ? "How your free trial works" : "Unlock SleepOwl Pro")
                .font(MooniFont.display(24))
                .foregroundStyle(LinearGradient(
                    colors: [MooniColor.textPrimary, MooniColor.accentSoft],
                    startPoint: .leading,
                    endPoint: .trailing))
                .multilineTextAlignment(.center)

            Text(planSubtitle)
                .font(MooniFont.body(13))
                .foregroundColor(MooniColor.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var planSubtitle: String {
        if plan == .annual {
            guard let pkg = annualPackage else {
                return "Yearly subscription. Cancel anytime."
            }
            let price = pkg.storeProduct.localizedPriceString
            let weeklyEquiv = (pkg.storeProduct.price as Decimal) / 52
            let symbol = pkg.storeProduct.priceFormatter?.currencySymbol ?? "$"
            let weeklyStr = String(format: "%@%.2f/week",
                                   symbol,
                                   NSDecimalNumber(decimal: weeklyEquiv).floatValue)
            if let days = trialDays {
                return "First \(days) day\(days == 1 ? "" : "s") free, then \(price) (\(weeklyStr))"
            }
            return "\(price) per year (\(weeklyStr)) · cancel anytime"
        } else {
            guard let pkg = shortPackage else {
                return "Billed \(shortPeriodLabel.lowercased()). Cancel anytime."
            }
            let unit = shortPackage?.packageType == .weekly ? "week" : "month"
            return "\(pkg.storeProduct.localizedPriceString) per \(unit) · cancel anytime"
        }
    }

    // MARK: - Plan toggle

    private var annualPriceLabel: String {
        guard let pkg = annualPackage else { return "" }
        return "\(pkg.storeProduct.localizedPriceString)/yr"
    }

    /// Number of trial days configured on the annual product in StoreKit, or
    /// nil if the product has no intro offer. We render the trial timeline
    /// from this so changing the trial length in App Store Connect does NOT
    /// require a code change.
    private var trialDays: Int? {
        guard let intro = annualPackage?.storeProduct.introductoryDiscount else { return nil }
        let value = intro.subscriptionPeriod.value
        switch intro.subscriptionPeriod.unit {
        case .day:   return value
        case .week:  return value * 7
        case .month: return value * 30
        case .year:  return value * 365
        @unknown default: return value
        }
    }

    /// Day the reminder fires — 2 days before the trial ends, or day 1 for
    /// very short trials so the timeline still reads in order.
    private var reminderDay: Int {
        guard let total = trialDays, total > 1 else { return 1 }
        return max(1, total - 2)
    }

    private var shortPriceLabel: String {
        guard let pkg = shortPackage else { return "" }
        let unit = pkg.packageType == .weekly ? "wk" : "mo"
        return "\(pkg.storeProduct.localizedPriceString)/\(unit)"
    }

    private var planToggle: some View {
        HStack(spacing: 0) {
            toggleSegment(title: "Annual", subtitle: trialDays != nil ? "Free trial" : "Best value", price: annualPriceLabel, value: .annual)
            toggleSegment(title: shortPeriodLabel, subtitle: "No trial", price: shortPriceLabel, value: .short)
        }
        .padding(4)
        .background(
            Capsule().fill(Color.white.opacity(0.08))
        )
        .overlay(
            Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .padding(.horizontal, 60)
    }

    private func toggleSegment(title: String, subtitle: String, price: String, value: Plan) -> some View {
        let active = plan == value
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { plan = value }
        } label: {
            VStack(spacing: 1) {
                Text(title)
                    .font(MooniFont.title(14))
                    .foregroundColor(active ? .white : MooniColor.textSecondary)
                Text(subtitle)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(active ? Color.white.opacity(0.85) : MooniColor.textMuted)
                if !price.isEmpty {
                    Text(price)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(active ? Color.white.opacity(0.9) : MooniColor.textMuted)
                        .padding(.top, 1)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(active
                          ? LinearGradient(colors: [MooniColor.accentSoft, MooniColor.accent],
                                           startPoint: .leading, endPoint: .trailing)
                          : LinearGradient(colors: [.clear, .clear],
                                           startPoint: .leading, endPoint: .trailing))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Annual: trial timeline

    @ViewBuilder
    private var timeline: some View {
        if let totalDays = trialDays {
            let reminder = reminderDay
            let connectorFill = totalDays > 1 ? Double(totalDays - reminder) / Double(totalDays) : 0.0
            VStack(alignment: .leading, spacing: 0) {
                timelineRow(
                    icon: "lock.open.fill",
                    tint: MooniColor.accent,
                    title: "Today",
                    body: "Unlock the full SleepOwl library — meditations, sleep sounds and deep insights.",
                    showConnector: true,
                    connectorFill: 1.0
                )
                timelineRow(
                    icon: "bell.fill",
                    tint: MooniColor.accentSoft,
                    title: reminder == 1 ? "Tomorrow" : "In \(reminder) day\(reminder == 1 ? "" : "s")",
                    body: "We'll send a gentle reminder that your trial is ending soon — no surprises.",
                    showConnector: true,
                    connectorFill: connectorFill
                )
                timelineRow(
                    icon: "star.fill",
                    tint: MooniColor.warning,
                    title: "In \(totalDays) day\(totalDays == 1 ? "" : "s")",
                    body: "Your subscription begins. Cancel anytime before then and you won't be charged.",
                    showConnector: false,
                    connectorFill: 0.0
                )
            }
        } else {
            // Fallback when annual product has no intro offer configured:
            // show the same benefit list the monthly tab uses.
            monthlyBenefits
        }
    }

    private func timelineRow(
        icon: String,
        tint: Color,
        title: String,
        body: String,
        showConnector: Bool,
        connectorFill: Double
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.22))
                        .frame(width: 36, height: 36)
                    Circle()
                        .stroke(tint.opacity(0.55), lineWidth: 1)
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(tint)
                }
                if showConnector {
                    ZStack(alignment: .top) {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 2, height: 44)
                        Capsule()
                            .fill(tint.opacity(0.55))
                            .frame(width: 2, height: 44 * connectorFill)
                    }
                    .padding(.top, 2)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(MooniFont.title(15))
                    .foregroundColor(MooniColor.textPrimary)
                Text(body)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundColor(MooniColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, showConnector ? 14 : 0)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Monthly: benefit list (no trial framing)

    private var monthlyBenefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            benefitRow(icon: "waveform", tint: MooniColor.accent,
                       title: "Auto sleep tracking",
                       body: "Just sleep. SleepOwl scores your night while you rest.")
            benefitRow(icon: "chart.bar.fill", tint: MooniColor.accentSoft,
                       title: "Full history & insights",
                       body: "Deep dives into REM, debt, and recovery — every night.")
            benefitRow(icon: "sparkles", tint: MooniColor.warning,
                       title: "Every sound & scene",
                       body: "All meditations and soundscapes unlocked.")
        }
    }

    private func benefitRow(icon: String, tint: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.22))
                    .frame(width: 36, height: 36)
                Circle()
                    .stroke(tint.opacity(0.55), lineWidth: 1)
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(tint)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(MooniFont.title(15))
                    .foregroundColor(MooniColor.textPrimary)
                Text(body)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundColor(MooniColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Bottom block

    private var bottomBlock: some View {
        VStack(spacing: 10) {
            if let error = manager.errorMessage {
                Text(error)
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.danger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Button { Task { await manager.restorePurchases() } } label: {
                Text("Restore purchase")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(MooniColor.accentSoft)
            }
            .padding(.bottom, 2)

            Text("Cancel anytime in the App Store")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(MooniColor.textMuted)

            purchaseButton
                .padding(.horizontal, 20)

            footerLinks
                .padding(.horizontal, 20)
                .padding(.top, 2)
        }
        .padding(.bottom, 14)
    }

    // MARK: - CTA

    private var ctaText: String {
        if plan == .annual {
            guard let pkg = annualPackage else { return "Continue" }
            if trialDays != nil {
                return "Try Free · \(pkg.storeProduct.localizedPriceString)/yr after"
            }
            return "Continue — \(pkg.storeProduct.localizedPriceString)/yr"
        }
        guard let pkg = shortPackage else { return "Continue" }
        return "Continue — \(pkg.storeProduct.localizedPriceString)\(shortPerLabel)"
    }

    private var purchaseButton: some View {
        Button {
            guard let pkg = selectedPackage else { return }
            Task {
                let success = await manager.purchase(package: pkg)
                if success {
                    showSuccess = true
                    onPurchased?()
                }
            }
        } label: {
            ZStack {
                if manager.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    HStack(spacing: 8) {
                        Text(ctaText)
                            .font(MooniFont.title(18))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                    }
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
            .shadow(color: MooniColor.accent.opacity(0.55), radius: 16, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(manager.isLoading || selectedPackage == nil)
    }

    // MARK: - Footer (App Store guideline 3.1.2)

    private var footerLinks: some View {
        HStack(spacing: 14) {
            Link("Terms",
                 destination: URL(string: "https://sleepowlapp.vercel.app/terms")!)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(MooniColor.textMuted)
                .underline()
            Link("Privacy",
                 destination: URL(string: "https://sleepowlapp.vercel.app/privacy")!)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(MooniColor.textMuted)
                .underline()
            Button { showCustomerCenter = true } label: {
                Text("Manage")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(MooniColor.textMuted)
                    .underline()
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Success overlay

    private var successOverlay: some View {
        VStack(spacing: 28) {
            Spacer()
            DreamSpiritView(pet: heroPet, size: 200)
            VStack(spacing: 12) {
                Text("You're a Dream Member!")
                    .font(MooniFont.display(30))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Lumi is glowing brighter than ever.\nEnjoy all of SleepOwl Pro.")
                    .font(MooniFont.body(16))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            PrimaryButton(title: "Let's Go") {
                if let soft = onSoftDismiss { soft() } else { dismiss() }
            }
            .padding(.horizontal, 32)
            Spacer()
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}

// MARK: - Paywall Presentation Modifier

extension View {
    func mooniPaywall(isPresented: Binding<Bool>) -> some View {
        sheet(isPresented: isPresented) {
            PaywallView()
        }
    }
}

#Preview {
    PaywallView()
        .environmentObject(AppState())
}
