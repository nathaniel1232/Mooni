import SwiftUI
import RevenueCat
import RevenueCatUI

// MARK: - PaywallView

struct PaywallView: View {
    @StateObject private var manager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss

    /// When true (during onboarding), the close button is barely visible and
    /// dismissing routes the user to the discount paywall instead of closing.
    var hideCloseButton: Bool = false
    var onSoftDismiss: (() -> Void)? = nil
    var onPurchased: (() -> Void)? = nil

    @State private var selectedPackage: Package?
    @State private var showCustomerCenter = false
    @State private var showSuccess = false
    @State private var animateIn = false

    // Preview pet for the hero
    private var heroPet: Pet {
        var p = Pet()
        p.mood = .rested
        return p
    }

    private var weeklyPackage: Package? {
        manager.currentOffering?.availablePackages.first { $0.packageType == .weekly }
    }

    private var annualPackage: Package? {
        manager.currentOffering?.availablePackages.first { $0.packageType == .annual }
    }

    var body: some View {
        ZStack {
            MooniColor.background
                .ignoresSafeArea()
            StarsBackground(count: 60)

            if showSuccess {
                successOverlay
            } else {
                mainContent
            }
        }
        .task { await manager.loadOfferings() }
        .sheet(isPresented: $showCustomerCenter) {
            CustomerCenterView()
        }
    }

    // MARK: - Main content

    /// Single-screen, no-scroll paywall. Anchored top + bottom with one
    /// elastic Spacer between the value-prop block and the price block so the
    /// layout fills the whole sheet on every device size.
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Close button row
            HStack {
                Spacer()
                Button {
                    if hideCloseButton, let soft = onSoftDismiss { soft() } else { dismiss() }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(
                            size: hideCloseButton ? 10 : 13,
                            weight: hideCloseButton ? .regular : .semibold))
                        .foregroundColor(hideCloseButton
                                         ? Color.white.opacity(0.18)
                                         : MooniColor.textSecondary)
                        .padding(hideCloseButton ? 6 : 8)
                        .background(hideCloseButton ? Color.clear : Color.white.opacity(0.10))
                        .clipShape(Circle())
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Close paywall")
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            // Top zone — hero + rating + benefits
            VStack(spacing: 0) {
                heroBlock
                    .padding(.horizontal, 22)
                    .padding(.top, 4)
                    .opacity(animateIn ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.75), value: animateIn)

                ratingRow
                    .padding(.top, 10)
                    .opacity(animateIn ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.10), value: animateIn)

                benefitsSection
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                    .opacity(animateIn ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.16), value: animateIn)
            }

            Spacer(minLength: 12)

            // Bottom zone — plan picker + CTA + footer, anchored to the floor
            VStack(spacing: 10) {
                planPicker
                    .padding(.horizontal, 20)

                if let error = manager.errorMessage {
                    Text(error)
                        .font(MooniFont.caption(11))
                        .foregroundColor(MooniColor.danger)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                purchaseButton
                    .padding(.horizontal, 20)
                trialReminderInline
                footerLinks
                    .padding(.horizontal, 20)
            }
            .padding(.bottom, 12)
            .opacity(animateIn ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.22), value: animateIn)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if selectedPackage == nil {
                selectedPackage = annualPackage ?? weeklyPackage
            }
            withAnimation { animateIn = true }
        }
        .onChange(of: manager.currentOffering) { _, _ in
            if selectedPackage == nil {
                selectedPackage = annualPackage ?? weeklyPackage
            }
        }
    }

    // MARK: - Compact hero

    private var heroBlock: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [MooniColor.accent.opacity(0.45), .clear],
                        center: .center, startRadius: 4, endRadius: 90))
                    .frame(width: 180, height: 130)
                    .blur(radius: 4)
                DreamSpiritView(pet: heroPet, size: 84)
                    .scaleEffect(animateIn ? 1 : 0.82)
                    .shadow(color: MooniColor.accent.opacity(0.5), radius: 18, y: 8)
            }
            .frame(height: 100)

            Text("SleepOwl Pro")
                .font(MooniFont.display(26))
                .foregroundStyle(LinearGradient(
                    colors: [MooniColor.textPrimary, MooniColor.accentSoft],
                    startPoint: .leading,
                    endPoint: .trailing))

            Text("Invest in your sleep — and your health.")
                .font(MooniFont.body(13))
                .foregroundColor(MooniColor.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Rating row

    private var ratingRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(MooniColor.warning)
                }
            }
            Text("4.9")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(MooniColor.textPrimary)
            Text("·")
                .foregroundColor(MooniColor.textMuted)
            Text("Loved by 1,000+ sleepers")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(MooniColor.textSecondary)
        }
    }

    // MARK: - Compact trial reminder

    private var trialReminderInline: some View {
        HStack(spacing: 6) {
            Image(systemName: selectedAnnual ? "gift.fill" : "bolt.fill")
                .foregroundColor(MooniColor.warning)
                .font(.system(size: 11, weight: .semibold))
            Text(selectedAnnual
                 ? "7-day free trial · cancel anytime"
                 : "Renews weekly · cancel anytime")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(MooniColor.textSecondary)
        }
    }

    // MARK: - Benefits

    /// 4 scannable bullets — short enough that the user reads all of them at a
    /// glance without scrolling. Two pre-launch features were dropped from
    /// this view to stay one-screen; they're still surfaced in onboarding.
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            benefitRow(text: "Auto sleep tracking — just sleep")
            benefitRow(text: "Full history & score breakdowns")
            benefitRow(text: "Deep insights: REM, debt, recovery")
            benefitRow(text: "Every color, animation & background")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func benefitRow(text: String) -> some View {
        HStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [MooniColor.accentSoft, MooniColor.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing))
                    .frame(width: 22, height: 22)
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.white)
            }
            Text(text)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(MooniColor.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    private var selectedAnnual: Bool {
        selectedPackage?.packageType == .annual
    }

    // MARK: - Plan Picker

    private var planPicker: some View {
        VStack(spacing: 6) {
            if let annual = annualPackage {
                planCard(package: annual, badge: "FREE TRIAL", badgeColor: MooniColor.success)
            } else {
                planCardPlaceholder(title: "Yearly", price: "$39.99 / yr", badge: "FREE TRIAL", badgeColor: MooniColor.success)
            }
            if let weekly = weeklyPackage {
                planCard(package: weekly, badge: nil, badgeColor: .clear)
            } else {
                planCardPlaceholder(title: "Weekly", price: "$4.99 / wk", badge: nil, badgeColor: .clear)
            }
        }
    }

    /// Honest savings % for the annual plan relative to weekly × 52 — falls
    /// back to nil when prices aren't loaded so we don't ship a fake number.
    private var annualSavingsPercent: Int? {
        guard let annual = annualPackage,
              let weekly = weeklyPackage else { return nil }
        let yearlyEquiv = (weekly.storeProduct.price as Decimal) * 52
        guard yearlyEquiv > 0 else { return nil }
        let saved = (yearlyEquiv - (annual.storeProduct.price as Decimal)) / yearlyEquiv
        let percent = Int((NSDecimalNumber(decimal: saved).doubleValue * 100).rounded())
        return percent > 0 ? percent : nil
    }

    private func planCard(package: Package, badge: String?, badgeColor: Color) -> some View {
        let isSelected = selectedPackage?.identifier == package.identifier
        let isAnnual = package.packageType == .annual
        let priceText = package.storeProduct.localizedPriceString
        let periodText = isAnnual ? "/ yr" : "/ wk"

        return Button {
            withAnimation(.spring(response: 0.3)) {
                selectedPackage = package
            }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? MooniColor.accent : Color.white.opacity(0.35),
                                lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                    if isSelected {
                        Circle()
                            .fill(MooniColor.accent)
                            .frame(width: 10, height: 10)
                    }
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(isAnnual ? "Yearly" : "Weekly")
                            .font(MooniFont.title(15))
                            .foregroundColor(MooniColor.textPrimary)
                        if let badge = badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .tracking(0.5)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(badgeColor)
                                .clipShape(Capsule())
                        }
                    }
                    if isAnnual {
                        let weeklyEquiv = (package.storeProduct.price as Decimal) / 52
                        Text(String(format: "Only %@%.2f / week",
                                    package.storeProduct.priceFormatter?.currencySymbol ?? "$",
                                    NSDecimalNumber(decimal: weeklyEquiv).floatValue))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(MooniColor.textSecondary)
                    }
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(priceText)
                        .font(MooniFont.title(15))
                        .foregroundColor(MooniColor.textPrimary)
                    Text(periodText)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(MooniColor.textMuted)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? MooniColor.accent.opacity(0.15) : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? MooniColor.accent : Color.white.opacity(0.10),
                            lineWidth: isSelected ? 2 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if isAnnual, let pct = annualSavingsPercent {
                    Text("SAVE \(pct)%")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(0.8)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(
                                LinearGradient(
                                    colors: [MooniColor.danger, MooniColor.warning],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        )
                        .shadow(color: MooniColor.warning.opacity(0.45), radius: 6, y: 2)
                        .offset(x: -8, y: -10)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func planCardPlaceholder(title: String, price: String, badge: String?, badgeColor: Color) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(MooniFont.title(16))
                        .foregroundColor(MooniColor.textPrimary)
                    if let badge = badge {
                        Text(badge)
                            .font(MooniFont.caption(11))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(badgeColor)
                            .clipShape(Capsule())
                    }
                }
            }
            Spacer()
            Text(price)
                .font(MooniFont.title(15))
                .foregroundColor(MooniColor.textMuted)
        }
        .padding(16)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .redacted(reason: .placeholder)
    }

    // MARK: - Purchase Button

    private var purchaseCTA: String {
        guard selectedPackage != nil else { return "Loading…" }
        return selectedAnnual ? "Start 7-day free trial" : "Start Dream Journey"
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
                        Image(systemName: "sparkles")
                        Text(purchaseCTA)
                            .font(MooniFont.title(17))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                LinearGradient(
                    colors: [MooniColor.accentSoft, MooniColor.accent],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: MooniColor.accent.opacity(0.55), radius: 14, y: 5)
        }
        .buttonStyle(.plain)
        .disabled(manager.isLoading || selectedPackage == nil)
    }

    // MARK: - Footer

    private var footerLinks: some View {
        VStack(spacing: 3) {
            // App Store guideline 3.1.2 requires: restore, EULA/terms, privacy,
            // and clear auto-renew disclosure — all visible on the paywall.
            HStack(spacing: 14) {
                Button { Task { await manager.restorePurchases() } } label: {
                    Text("Restore")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(MooniColor.textMuted)
                        .underline()
                }
                Link("Terms",
                     destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(MooniColor.textMuted)
                    .underline()
                Link("Privacy",
                     destination: URL(string: "https://nathanielfiskaa.github.io/sleepowl-privacy/")!)
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

            Text("Auto-renews unless cancelled in Settings.")
                .font(.system(size: 9, weight: .regular, design: .rounded))
                .foregroundColor(MooniColor.textMuted.opacity(0.7))
                .multilineTextAlignment(.center)

        }
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
