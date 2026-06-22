import SwiftUI
import RevenueCat

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
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    /// When true (during onboarding), the close button is barely visible and
    /// dismissing routes the user to the discount paywall instead of closing.
    var hideCloseButton: Bool = false
    /// When true, this paywall is the app's hard gate (no free tier): the
    /// close button and every "continue without subscribing" escape are
    /// removed, so the only ways past are a purchase/restore or the hidden
    /// developer unlock. Presented at the root once onboarding is complete.
    var hardLock: Bool = false
    var onSoftDismiss: (() -> Void)? = nil
    var onPurchased: (() -> Void)? = nil
    /// Called when the offerings failed to load and the user taps the
    /// "Continue without subscribing" escape hatch. Routes around the
    /// discount paywall (which would also fail) and lets onboarding
    /// complete cleanly. Falls back to `dismiss()` if not provided.
    var onErrorContinue: (() -> Void)? = nil

    @State private var plan: Plan = .annual
    @State private var showSuccess = false
    /// Set when a purchase succeeded but the entitlement isn't yet visible.
    /// We show a calm "finalizing" state instead of bouncing the user back to
    /// the buy screen, and watch manager.isPro to transition to success.
    @State private var finalizing = false
    @State private var animateIn = false
    @State private var moonGlow = false

    /// Hidden developer unlock: silently tapping the owl this many times flips
    /// the app to Pro without a purchase. No visible feedback by design — only
    /// someone who knows the gesture can trigger it.
    @State private var secretTapCount = 0
    private let secretUnlockTaps = 20

    // Restore feedback
    @State private var showRestoreAlert = false
    @State private var restoreAlertTitle = ""
    @State private var restoreAlertMessage = ""

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
            // Darkening scrim so the bright 4.2× band and CTA pop harder and
            // the screen reads calmer / more focused.
            Color.black.opacity(0.28)
                .ignoresSafeArea()
            // Stars stay in the middle band of the screen — faded out under
            // the pinned close row (top) and CTA block (bottom) so nothing
            // drifts behind the X button or through the purchase button.
            StarsBackground(count: 30)
                .opacity(0.8)
                .mask(
                    VStack(spacing: 0) {
                        LinearGradient(colors: [.clear, .white],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: 120)
                        Color.white
                        LinearGradient(colors: [.white, .clear],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: 210)
                    }
                    .ignoresSafeArea()
                )

            if showSuccess {
                successOverlay
            } else if finalizing {
                finalizingOverlay
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
        .alert(restoreAlertTitle, isPresented: $showRestoreAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreAlertMessage)
        }
        // If the entitlement lands while we're showing the finalizing state
        // (delegate push or a late poll), promote to the success overlay.
        .onChange(of: manager.isPro) { _, isPro in
            if isPro && finalizing {
                finalizing = false
                withAnimation { showSuccess = true }
                onPurchased?()
            }
        }
    }

    private var offeringsErrorView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "wifi.slash")
                .font(.system(size: 38, weight: .semibold))
                .foregroundColor(MooniColor.textMuted)
                // Keep the hidden developer unlock reachable even when plans
                // fail to load, so a hard-locked build can't brick itself.
                .contentShape(Rectangle())
                .onTapGesture(perform: registerSecretTap)
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
            // Escape hatch so a stuck App Review (or any user with a transient
            // StoreKit failure) can always get into the app. Bypasses the
            // discount paywall, which depends on the same offerings load and
            // would also fail. Suppressed under the hard lock — there is no
            // free tier to fall through to.
            if !hardLock {
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
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Main content

    private var mainContent: some View {
        VStack(spacing: 0) {
            // Close stays pinned at the top so it's always reachable.
            closeRow

            // Scrollable region — on small devices (SE/mini) the full pitch no
            // longer clips; on large devices it simply doesn't need to scroll.
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroBlock
                        .padding(.top, 4)
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 12)
                        .animation(.spring(response: 0.65, dampingFraction: 0.78), value: animateIn)

                    titleBlock
                        .padding(.horizontal, 28)
                        .padding(.top, 12)
                        .opacity(animateIn ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.10), value: animateIn)

                    // Honest social proof (hidden until real numbers are set).
                    socialProofRow
                        .padding(.horizontal, 28)
                        .padding(.top, 10)
                        .opacity(animateIn ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.13), value: animateIn)

                    // Value / reassurance: trial timeline (trial) or benefits.
                    content
                        .padding(.horizontal, 28)
                        .padding(.top, 18)
                        .opacity(animateIn ? 1 : 0)
                        .animation(.easeOut(duration: 0.45).delay(0.16), value: animateIn)

                    // The choice: one featured plan + a quiet switch link,
                    // right above the CTA so picking flows straight into action.
                    VStack(spacing: 12) {
                        featuredPlan
                        planSwitchLink
                    }
                        .padding(.horizontal, 22)
                        .padding(.top, 18)
                        .opacity(animateIn ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.22), value: animateIn)
                }
                .padding(.bottom, 8)
            }

            // CTA + trust row stay pinned at the bottom so the primary action
            // is reliably reachable regardless of scroll position.
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
        // Trial selected → the reassurance timeline (the conversion driver:
        // "here's exactly what happens, no surprises"). Otherwise → the
        // scannable benefit pillars. Never both — that's what felt cluttered.
        if plan == .annual, trialDays != nil {
            timeline
        } else {
            proBenefits
        }
    }

    // MARK: - Close

    @ViewBuilder
    private var closeRow: some View {
        if hardLock {
            // Hard gate: no escape. Keep the same top spacing the X row gave
            // so the hero doesn't jump up under the notch.
            Color.clear.frame(height: 38)
        } else {
            closeRowButton
        }
    }

    private var closeRowButton: some View {
        HStack {
            Spacer()
            Button {
                // Always prefer onSoftDismiss when the caller supplied one.
                // The onboarding paywall sits over a Color.clear placeholder
                // step — if we just call dismiss() and don't fire the soft-
                // dismiss callback that finishes onboarding, the user lands
                // on a blank screen with no way forward. Matches the same
                // pattern used by the success overlay's "Let's Go" button.
                if let soft = onSoftDismiss { soft() } else { dismiss() }
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

    // MARK: - Hero (app logo on a soft halo)

    private var heroBlock: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [
                        MooniColor.accent.opacity(0.40),
                        MooniColor.accent.opacity(0.0)
                    ],
                    center: .center,
                    startRadius: 6,
                    endRadius: 105))
                .frame(width: 180, height: 120)
                .scaleEffect(moonGlow ? 1.04 : 0.96)
                .blur(radius: 6)

            // The real App Store icon (squircle) instead of the in-app owl.
            Image("app_icon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 82, height: 82)
                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
                .shadow(color: MooniColor.accent.opacity(0.3), radius: 12, y: 5)
                .scaleEffect(animateIn ? 1 : 0.9)
                // Hidden developer unlock — silent, no feedback.
                .contentShape(Rectangle())
                .onTapGesture(perform: registerSecretTap)
        }
        .frame(height: 102)
    }

    /// Hidden developer unlock. Counts silent taps on the hero owl; on the
    /// Nth tap it grants Pro without a purchase and leaves the paywall exactly
    /// as a real purchase would. No visible cue at any point — only someone who
    /// knows the gesture will ever trigger it.
    private func registerSecretTap() {
        secretTapCount += 1
        guard secretTapCount >= secretUnlockTaps else { return }
        secretTapCount = 0
        manager.enableDevPro()
        // Same gesture also unlocks the hidden developer menu in Profile.
        DeveloperMode.shared.unlock()
        Haptics.celebrate()
        if let onPurchased {
            onPurchased()
        } else {
            dismiss()
        }
    }

    // MARK: - Title

    private var titleBlock: some View {
        VStack(spacing: 8) {
            Text("Your best sleep starts tonight")
                .font(MooniFont.display(26))
                .foregroundStyle(LinearGradient(
                    colors: [MooniColor.textPrimary, MooniColor.accentSoft],
                    startPoint: .leading,
                    endPoint: .trailing))
                .multilineTextAlignment(.center)

            Text(headlineSubtitle)
                .font(MooniFont.body(14))
                .foregroundColor(MooniColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// One clean value line — no price (price + terms live on the plan cards),
    /// so the header reads as a promise rather than a wall of numbers.
    private var headlineSubtitle: String {
        if let days = trialDays {
            return "Your nightly fix, full insights and every sound — free for \(days) days."
        }
        return "Your nightly fix, full insights and every sound. Cancel anytime."
    }

    // MARK: - Social proof (optional — REAL data only)

    /// Set these to your ACTUAL App Store numbers to show a trust line under the
    /// headline. Honest social proof reliably lifts conversion (e.g. Speak shows
    /// "4.8 from 140k+ reviews"). LEAVE THESE nil to hide the row — and NEVER
    /// fabricate a rating, review count, or testimonial: Apple rejects fake
    /// social proof (guideline 3.1.x / 2.3) and it destroys trust. Fill in once
    /// you have real numbers and the row appears automatically.
    private let socialProofRating: String? = nil       // e.g. "4.8"
    private let socialProofCount: String? = nil        // e.g. "1,200+ ratings"
    private let socialProofTestimonial: String? = nil  // e.g. "I finally sleep through the night."

    @ViewBuilder
    private var socialProofRow: some View {
        if let rating = socialProofRating, let count = socialProofCount {
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundColor(MooniColor.warning)
                    }
                    Text("\(rating) · \(count)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(MooniColor.textSecondary)
                        .padding(.leading, 4)
                }
                if let quote = socialProofTestimonial {
                    Text("\u{201C}\(quote)\u{201D}")
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .foregroundColor(MooniColor.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
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

    // MARK: - Plan (single-plan focus)

    /// Research-backed: lead with ONE plan as the hero and demote the other to a
    /// quiet switch link, instead of a symmetric two-card grid (which causes
    /// analysis paralysis and buries the trial — Calm/Headspace/Cal AI all focus
    /// one plan). The featured card shows the currently-selected plan; the small
    /// per-week number leads, with the real billed price + cancel terms beneath
    /// it (kept prominent for App Store guideline 3.1.2).
    @ViewBuilder
    private var featuredPlan: some View {
        let isAnnual = plan == .annual
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                if isAnnual, trialDays != nil { badgePill("7-DAY FREE TRIAL") }
                if isAnnual, let pct = annualSavingsPercent { badgePill("SAVE \(pct)%") }
                if !isAnnual { badgePill(shortPeriodLabel.uppercased()) }
                Spacer(minLength: 0)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(featuredHeroPrice)
                    .font(MooniFont.display(30))
                    .foregroundColor(MooniColor.textPrimary)
                Text(featuredHeroUnit)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(MooniColor.textSecondary)
            }
            Text(featuredTerms)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(MooniColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(MooniColor.accent.opacity(0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(MooniColor.accentSoft, lineWidth: 2)
        )
        .shadow(color: MooniColor.accent.opacity(0.25), radius: 18, y: 6)
    }

    /// Quiet text link to switch to the non-featured plan (only when a short
    /// plan exists). Keeps the choice available without a competing card.
    @ViewBuilder
    private var planSwitchLink: some View {
        if shortPackage != nil {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    plan = (plan == .annual) ? .short : .annual
                }
                Haptics.tap()
            } label: {
                Text(planSwitchLabel)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundColor(MooniColor.accentSoft)
                    .underline()
            }
            .buttonStyle(.plain)
        }
    }

    // Featured-card content helpers --------------------------------------

    /// Big hero number: the per-week equivalent for annual ("$0.77"), or the
    /// real weekly/monthly price for the short plan.
    private var featuredHeroPrice: String {
        if plan == .annual {
            if let w = annualWeeklyEquivLabel { return w.replacingOccurrences(of: "/week", with: "") }
            return annualPackage?.storeProduct.localizedPriceString ?? ""
        }
        return shortPackage?.storeProduct.localizedPriceString ?? ""
    }

    private var featuredHeroUnit: String {
        if plan == .annual { return "/ week" }
        return shortPackage?.packageType == .weekly ? "/ week" : "/ month"
    }

    /// Real billed price + period + cancel terms. The per-week hero number only
    /// SUPPLEMENTS this — the true charge stays prominent (guideline 3.1.2).
    private var featuredTerms: String {
        if plan == .annual {
            guard let pkg = annualPackage else { return "Cancel anytime." }
            let price = pkg.storeProduct.localizedPriceString
            if let days = trialDays {
                return "Free for \(days) days, then \(price)/year. Cancel anytime."
            }
            return "Billed \(price)/year. Cancel anytime."
        }
        guard let pkg = shortPackage else { return "Cancel anytime." }
        let unit = shortPackage?.packageType == .weekly ? "week" : "month"
        return "Billed \(pkg.storeProduct.localizedPriceString)/\(unit). Cancel anytime."
    }

    private var planSwitchLabel: String {
        if plan == .annual {
            return "Prefer to pay weekly? \(shortPriceLabel)"
        }
        if let pct = annualSavingsPercent {
            return "Best value: 7-day free trial · save \(pct)% yearly"
        }
        return "Switch to the annual plan with a free trial"
    }

    private func badgePill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .tracking(0.4)
            .foregroundColor(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(LinearGradient(
                    colors: [MooniColor.accentSoft, MooniColor.accent],
                    startPoint: .leading, endPoint: .trailing))
            )
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
                    body: "Unlock your nightly fix, full sleep insights, and every meditation and sound.",
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
                            .frame(width: 2, height: 30)
                        Capsule()
                            .fill(tint.opacity(0.55))
                            .frame(width: 2, height: 30 * connectorFill)
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
            .padding(.bottom, showConnector ? 9 : 0)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Pro benefits (scannable value section)

    /// The four pillars of Pro, kept tight and scannable. No fabricated stats,
    /// ratings, or testimonials — App Review forbids those. Just the features.
    private var proBenefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            benefitRow(icon: "wand.and.stars", tint: MooniColor.accent,
                       title: "A nightly fix for your sleep",
                       body: "One concrete move every night — SleepOwl turns last night into tonight's plan.")
            benefitRow(icon: "waveform", tint: MooniColor.accentSoft,
                       title: "Tracked while you sleep",
                       body: "Just sleep. SleepOwl reads the whole night on its own — no logging.")
            benefitRow(icon: "chart.line.uptrend.xyaxis", tint: MooniColor.success,
                       title: "Watch it actually improve",
                       body: "Before→after trends in REM, sleep debt, and recovery.")
            benefitRow(icon: "sparkles", tint: MooniColor.warning,
                       title: "Sounds, scenes & your owl",
                       body: "Every meditation and soundscape, plus a companion that grows as you do.")
        }
    }

    /// Kept for the trial-timeline fallback; mirrors the Pro benefit list.
    private var monthlyBenefits: some View { proBenefits }

    // MARK: - Annual vs short value math

    /// Honest annual saving vs paying the short (weekly/monthly) plan for a full
    /// year. Returns a whole-number percent only when it's real and positive —
    /// never a fabricated figure. Surfaced as the "SAVE X%" card badge.
    private var annualSavingsPercent: Int? {
        guard let annual = annualPackage, let short = shortPackage else { return nil }
        let annualPrice = NSDecimalNumber(decimal: annual.storeProduct.price as Decimal).doubleValue
        let shortPrice  = NSDecimalNumber(decimal: short.storeProduct.price as Decimal).doubleValue
        guard annualPrice > 0, shortPrice > 0 else { return nil }
        let yearlyAtShortRate = short.packageType == .weekly ? shortPrice * 52 : shortPrice * 12
        guard yearlyAtShortRate > annualPrice else { return nil }
        let pct = Int(round((1 - annualPrice / yearlyAtShortRate) * 100))
        return pct >= 1 ? pct : nil
    }

    /// Per-week equivalent of the annual plan (e.g. "$0.77/week"), shown as the
    /// annual card's trailing price so the headline reads as a tiny number.
    private var annualWeeklyEquivLabel: String? {
        guard let pkg = annualPackage else { return nil }
        let weekly = (pkg.storeProduct.price as Decimal) / 52
        guard weekly > 0 else { return nil }
        let symbol = pkg.storeProduct.priceFormatter?.currencySymbol ?? "$"
        return String(format: "%@%.2f/week", symbol,
                      NSDecimalNumber(decimal: weekly).doubleValue)
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
        VStack(spacing: 8) {
            if let error = manager.errorMessage {
                Text(error)
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.danger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // One confident primary CTA, always pinned and reachable.
            purchaseButton
                .padding(.horizontal, 20)
                .padding(.top, 2)

            // Reassurance right at the tap point — the highest-leverage copy
            // for trial starts (Cal AI / Blinkist): defuses the "I'll forget to
            // cancel and get charged" fear that blocks Day-0 conversions.
            if let reassurance = ctaReassurance {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(MooniColor.accentSoft)
                    Text(reassurance)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(MooniColor.textSecondary)
                }
            }

            // Restore + legal links live on one compact row so the CTA block
            // stays short and the scrollable pitch above always has room.
            footerLinks
                .padding(.horizontal, 20)
                .padding(.top, 2)
        }
        .padding(.bottom, 4)
    }

    // MARK: - CTA

    /// Clean action verb — the price + terms are already on the selected card,
    /// so the button doesn't need to repeat them.
    private var ctaText: String {
        if plan == .annual, trialDays != nil { return "Start my free trial" }
        if plan == .annual { return "Get SleepOwl Pro" }
        return "Get SleepOwl Pro"
    }

    /// One short anxiety-reducer under the CTA for the trial (the most common
    /// drop-off worry). Paid plans rely on the card's terms + the trust row.
    private var ctaReassurance: String? {
        if plan == .annual, trialDays != nil {
            return "No payment due now · cancel anytime"
        }
        return "Cancel anytime"
    }

    private var purchaseButton: some View {
        Button {
            guard let pkg = selectedPackage else { return }
            Task {
                let outcome = await manager.purchase(package: pkg)
                switch outcome {
                case .active:
                    withAnimation { showSuccess = true }
                    onPurchased?()
                case .pendingActivation:
                    // Charged but entitlement not yet visible — never bounce
                    // the user back to the buy screen. Show the calm
                    // finalizing state and keep watching manager.isPro.
                    // (If the delegate already flipped isPro in the meantime,
                    // go straight to success rather than getting stuck.)
                    if manager.isPro {
                        withAnimation { showSuccess = true }
                        onPurchased?()
                    } else {
                        withAnimation { finalizing = true }
                    }
                case .cancelled:
                    // Stay on the buy UI; nothing to do.
                    break
                case .failed:
                    // Error is surfaced inline via manager.errorMessage in
                    // bottomBlock; keep the buy UI visible.
                    break
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
                // Saturated indigo, dark enough that the white label always
                // reads — the old accentSoft start was nearly white-on-white.
                LinearGradient(
                    colors: [
                        Color(red: 0.48, green: 0.42, blue: 0.96),
                        Color(red: 0.38, green: 0.30, blue: 0.88)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .shadow(color: MooniColor.accent.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(manager.isLoading || selectedPackage == nil)
    }

    // MARK: - Footer (App Store guideline 3.1.2)

    private var footerLinks: some View {
        HStack(spacing: 14) {
            // Restore reads as slightly more prominent than the legal links
            // (accentSoft vs. muted) since it's the one with a real user task,
            // but it no longer eats its own line above the footer.
            Button { Task { await runRestore() } } label: {
                Text("Restore")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(MooniColor.accentSoft)
                    .underline()
            }
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
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Restore

    private func runRestore() async {
        let outcome = await manager.restorePurchases()
        switch outcome {
        case .restored:
            restoreAlertTitle = "Purchases restored"
            restoreAlertMessage = "Your SleepOwl Pro subscription is active again."
        case .nothingToRestore:
            restoreAlertTitle = "No purchases to restore"
            restoreAlertMessage = "We couldn't find an active subscription for this Apple ID."
        case .failed(let message):
            restoreAlertTitle = "Restore failed"
            restoreAlertMessage = message
        }
        showRestoreAlert = true
    }

    // MARK: - Finalizing overlay (charged, awaiting entitlement)

    private var finalizingOverlay: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [MooniColor.accent.opacity(0.45), MooniColor.accent.opacity(0.0)],
                        center: .center,
                        startRadius: 6,
                        endRadius: 120))
                    .frame(width: 200, height: 200)
                    .scaleEffect(moonGlow ? 1.04 : 0.96)
                    .blur(radius: 6)
                DreamSpiritView(pet: heroPet, size: 120)
            }
            ProgressView()
                .tint(MooniColor.accentSoft)
                .scaleEffect(1.2)
            VStack(spacing: 10) {
                Text("Finalizing your subscription…")
                    .font(MooniFont.title(20))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Your payment went through. We're just confirming your access with the App Store — this only takes a moment.")
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, 32)

            Button { Task { await runRestore() } } label: {
                Text("Restore")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(MooniColor.accentSoft)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 28)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, 24)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                moonGlow = true
            }
        }
        .transition(.opacity)
    }

    // MARK: - Success overlay

    /// Reassuring success copy that personalises to the user's companion when
    /// we have a name, with a safe name-free fallback when it's blank.
    private var successMessage: String {
        let name = appState.pet.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            return "Your sleep companion is glowing brighter than ever.\nEnjoy all of SleepOwl Pro."
        }
        return "\(name) is glowing brighter than ever.\nEnjoy all of SleepOwl Pro."
    }

    private var successOverlay: some View {
        VStack(spacing: 28) {
            Spacer()
            DreamSpiritView(pet: heroPet, size: 200)
            VStack(spacing: 12) {
                Text("You're a Dream Member!")
                    .font(MooniFont.display(30))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text(successMessage)
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
