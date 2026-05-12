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

    private var mainContent: some View {
        ScrollView(showsIndicators: false) {
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
                .padding(.top, 12)

                // Hero section
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(RadialGradient(
                                colors: [MooniColor.accent.opacity(0.40), .clear],
                                center: .center, startRadius: 4, endRadius: 130))
                            .frame(width: 260, height: 260)
                            .blur(radius: 6)
                        DreamSpiritView(pet: heroPet, size: 130)
                            .scaleEffect(animateIn ? 1 : 0.82)
                            .shadow(color: MooniColor.accent.opacity(0.45), radius: 28, y: 12)
                    }
                    .frame(height: 180)

                    VStack(spacing: 6) {
                        Text("SleepOwl Pro")
                            .font(MooniFont.display(30))
                            .foregroundColor(MooniColor.textPrimary)
                        Text("Sleep better. Grow stronger. Every night.")
                            .font(MooniFont.body(15))
                            .foregroundColor(MooniColor.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .opacity(animateIn ? 1 : 0)
                .animation(.spring(response: 0.7, dampingFraction: 0.75), value: animateIn)
                .padding(.top, 4)

                // Features
                featuresSection
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .offset(y: animateIn ? 0 : 10)
                    .opacity(animateIn ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.12), value: animateIn)

                // Plan picker
                planPicker
                    .padding(.top, 14)
                    .padding(.horizontal, 20)
                    .offset(y: animateIn ? 0 : 10)
                    .opacity(animateIn ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.20), value: animateIn)

                // Trial summary
                trialSummary
                    .padding(.top, 10)
                    .padding(.horizontal, 20)
                    .opacity(animateIn ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.28), value: animateIn)

                if let error = manager.errorMessage {
                    Text(error)
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.danger)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                }

                purchaseButton
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .opacity(animateIn ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.32), value: animateIn)

                footerLinks
                    .padding(.top, 10)
                    .padding(.bottom, 24)
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
            proFeatureRow(icon: "waveform.path.ecg", color: MooniColor.success,
                          title: "Auto sleep tracking", detail: "Zero manual logging — just sleep")
            proFeatureRow(icon: "chart.bar.fill", color: MooniColor.accent,
                          title: "Full sleep history & trends", detail: "Unlimited logs with score breakdowns")
            proFeatureRow(icon: "sparkles", color: MooniColor.warning,
                          title: "All spirit unlocks", detail: "Every color, animation & background")
            proFeatureRow(icon: "brain.head.profile", color: .pink,
                          title: "Deep sleep insights", detail: "REM, debt, recovery & sleep coach")
        }
    }

    private func proFeatureRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(MooniFont.title(15))
                    .foregroundColor(MooniColor.textPrimary)
                Text(detail)
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textSecondary)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(MooniColor.success)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }

    // MARK: - Trial summary (compact, replaces the timeline)

    private var trialSummary: some View {
        HStack(spacing: 10) {
            Image(systemName: selectedAnnual ? "gift.fill" : "bolt.fill")
                .foregroundColor(MooniColor.warning)
                .font(.system(size: 13, weight: .semibold))
            Text(selectedAnnual
                 ? "7-day free trial · cancel anytime"
                 : "Renews weekly · cancel in 2 taps")
                .font(MooniFont.caption(12))
                .foregroundColor(.white.opacity(0.85))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(MooniColor.warning.opacity(0.10))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(MooniColor.warning.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var selectedAnnual: Bool {
        selectedPackage?.packageType == .annual
    }

    // MARK: - Plan Picker

    private var planPicker: some View {
        VStack(spacing: 8) {
            if let annual = annualPackage {
                planCard(package: annual, badge: "7-day free trial", badgeColor: MooniColor.success)
            } else {
                planCardPlaceholder(title: "Yearly", price: "$39.99 / year", badge: "7-day free trial", badgeColor: MooniColor.success)
            }
            if let weekly = weeklyPackage {
                planCard(package: weekly, badge: nil, badgeColor: .clear)
            } else {
                planCardPlaceholder(title: "Weekly", price: "$4.99 / week", badge: nil, badgeColor: .clear)
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
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? MooniColor.accent.opacity(0.15) : Color.white.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
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
        VStack(spacing: 6) {
            // App Store guideline 3.1.2 requires: restore, EULA/terms, privacy,
            // and clear auto-renew disclosure — all visible on the paywall.
            HStack(spacing: 16) {
                Button { Task { await manager.restorePurchases() } } label: {
                    Text("Restore")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                        .underline()
                }
                Link("Terms",
                     destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textSecondary)
                    .underline()
                Link("Privacy",
                     destination: URL(string: "https://nathanielfiskaa.github.io/sleepowl-privacy/")!)
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textSecondary)
                    .underline()
                Button { showCustomerCenter = true } label: {
                    Text("Manage")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                        .underline()
                }
            }

            Text("Auto-renews unless cancelled in Settings → Apple ID → Subscriptions. Any unused portion of a free trial is forfeited when you purchase.")
                .font(MooniFont.caption(10))
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
