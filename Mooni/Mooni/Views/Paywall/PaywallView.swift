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
        p.equippedHat = "hat_nightcap"
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

    private var mainContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Close button — small + faint when shown during onboarding
                HStack {
                    Spacer()
                    Button {
                        if hideCloseButton, let soft = onSoftDismiss {
                            soft()
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(
                                size: hideCloseButton ? 9 : 14,
                                weight: hideCloseButton ? .regular : .semibold))
                            .foregroundColor(
                                hideCloseButton
                                    ? Color.white.opacity(0.16)
                                    : MooniColor.textSecondary
                            )
                            .padding(hideCloseButton ? 6 : 10)
                            .background(
                                hideCloseButton
                                    ? Color.clear
                                    : Color.white.opacity(0.10)
                            )
                            .clipShape(Circle())
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Close paywall")
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Hero spirit
                DreamSpiritView(pet: heroPet, size: 120)
                    .padding(.top, 0)
                    .scaleEffect(animateIn ? 1.0 : 0.85)
                    .opacity(animateIn ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animateIn)

                // Title
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundColor(MooniColor.warning)
                        Text("Mooni Pro")
                            .font(MooniFont.display(28))
                            .foregroundColor(MooniColor.textPrimary)
                        Image(systemName: "sparkles")
                            .foregroundColor(MooniColor.warning)
                    }
                    Text("Sleep better. Grow stronger.")
                        .font(MooniFont.body(15))
                        .foregroundColor(MooniColor.textSecondary)
                }
                .padding(.top, 4)
                .offset(y: animateIn ? 0 : 12)
                .opacity(animateIn ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.15), value: animateIn)

                // Features
                featuresSection
                    .padding(.top, 16)
                    .padding(.horizontal, 20)
                    .offset(y: animateIn ? 0 : 16)
                    .opacity(animateIn ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.25), value: animateIn)

                // Plan picker
                planPicker
                    .padding(.top, 14)
                    .padding(.horizontal, 20)
                    .offset(y: animateIn ? 0 : 16)
                    .opacity(animateIn ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.35), value: animateIn)

                // Error
                if let error = manager.errorMessage {
                    Text(error)
                        .font(MooniFont.caption(13))
                        .foregroundColor(MooniColor.danger)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                }

                // Purchase CTA
                purchaseButton
                    .padding(.top, 14)
                    .padding(.horizontal, 20)

                // Footer links
                footerLinks
                    .padding(.top, 10)
                    .padding(.bottom, 20)
            }
        }
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

    // MARK: - Features

    private var featuresSection: some View {
        VStack(spacing: 8) {
            proFeatureRow(icon: "chart.bar.fill", color: MooniColor.accent,
                          title: "Full Sleep History",
                          detail: "Unlimited logs with trends")
            proFeatureRow(icon: "sparkles", color: MooniColor.warning,
                          title: "Exclusive Spirit Items",
                          detail: "All hats, colors & backgrounds")
            proFeatureRow(icon: "waveform.path.ecg", color: MooniColor.success,
                          title: "Advanced Analytics",
                          detail: "Sleep score breakdowns")
            proFeatureRow(icon: "checklist", color: MooniColor.accentSoft,
                          title: "Unlimited Habits",
                          detail: "Customize your wind-down")
        }
    }

    private func proFeatureRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(MooniFont.title(13))
                    .foregroundColor(MooniColor.textPrimary)
                Text(detail)
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.textSecondary)
            }
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(MooniColor.success)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Plan Picker

    private var planPicker: some View {
        VStack(spacing: 10) {
            if let annual = annualPackage {
                planCard(package: annual, badge: "Best Value", badgeColor: MooniColor.success)
            } else {
                planCardPlaceholder(title: "Yearly", price: "$XX.XX / year", badge: "Best Value", badgeColor: MooniColor.success)
            }
            if let weekly = weeklyPackage {
                planCard(package: weekly, badge: nil, badgeColor: .clear)
            } else {
                planCardPlaceholder(title: "Weekly", price: "$X.XX / week", badge: nil, badgeColor: .clear)
            }
        }
    }

    private func planCard(package: Package, badge: String?, badgeColor: Color) -> some View {
        let isSelected = selectedPackage?.identifier == package.identifier
        let isAnnual = package.packageType == .annual
        let priceText = package.storeProduct.localizedPriceString
        let periodText = isAnnual ? "/ year" : "/ week"

        return Button {
            withAnimation(.spring(response: 0.3)) {
                selectedPackage = package
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(isAnnual ? "Yearly" : "Weekly")
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
                    if isAnnual {
                        let weeklyEquiv = (package.storeProduct.price as Decimal) / 52
                        Text(String(format: "Only ~$%.2f / week", NSDecimalNumber(decimal: weeklyEquiv).floatValue))
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.textMuted)
                    }
                }
                Spacer()
                Text("\(priceText) \(periodText)")
                    .font(MooniFont.title(15))
                    .foregroundColor(isSelected ? MooniColor.accent : MooniColor.textSecondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? MooniColor.accent.opacity(0.15) : Color.white.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? MooniColor.accent : Color.white.opacity(0.10), lineWidth: isSelected ? 1.5 : 1)
            )
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
                        Text(selectedPackage != nil ? "Start Dream Journey" : "Loading…")
                            .font(MooniFont.title(17))
                    }
                    .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                LinearGradient(
                    colors: [MooniColor.accentSoft, MooniColor.accent],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: MooniColor.accent.opacity(0.5), radius: 14, y: 5)
        }
        .buttonStyle(.plain)
        .disabled(manager.isLoading || selectedPackage == nil)
    }

    // MARK: - Footer

    private var footerLinks: some View {
        VStack(spacing: 10) {
            Button {
                Task { await manager.restorePurchases() }
            } label: {
                Text("Restore Purchases")
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                    .underline()
            }

            Button {
                showCustomerCenter = true
            } label: {
                Text("Manage Subscription")
                    .font(MooniFont.caption(13))
                    .foregroundColor(MooniColor.textMuted)
            }

            Text("Subscriptions auto-renew unless cancelled.\nCancel any time in Settings → App Store.")
                .font(MooniFont.caption(11))
                .foregroundColor(MooniColor.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
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
                Text("Lumi is glowing brighter than ever.\nEnjoy all of Mooni Pro.")
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
