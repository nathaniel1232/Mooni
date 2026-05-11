import SwiftUI
import Combine
import RevenueCat

/// Win-back paywall shown when the user dismisses the main paywall.
/// Reframes the discount as a "gift" — the user spins a wheel and lands on
/// the predetermined 80%-off slice. The mechanic is the marketing: it feels
/// earned, not imposed.
///
/// The spin is theatrically random but always lands on the same discount
/// slice — RevenueCat's `discount` offering is the source of truth, and
/// nothing here ever changes the price the user is actually charged.
struct DiscountPaywallView: View {
    let petName: String
    let onAccept: () -> Void
    let onDecline: () -> Void

    @StateObject private var manager = SubscriptionManager.shared

    // 5-minute urgency window. Starts ticking only after the wheel is spun
    // so the user has time to read the gift screen first.
    @State private var secondsRemaining: Int = 5 * 60
    @State private var animateIn = false
    @State private var pulse = false

    // Spin state machine
    private enum Stage { case gift, spinning, won }
    @State private var stage: Stage = .gift
    @State private var wheelRotation: Double = 0
    @State private var canSpin: Bool = true

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var minutes: Int { secondsRemaining / 60 }
    private var seconds: Int { secondsRemaining % 60 }
    private var timeLabel: String { String(format: "%d:%02d", minutes, seconds) }

    /// The real, lower-priced annual package from the `discount` offering in
    /// RevenueCat. If this is nil the dashboard hasn't been set up — we fall
    /// back to a non-discount CTA so we never show "80% off" while charging
    /// the full price.
    private var discountPackage: Package? { manager.discountAnnualPackage }
    private var regularPackage: Package? { manager.regularAnnualPackage }
    private var purchasePackage: Package? { discountPackage ?? regularPackage }
    private var hasRealDiscount: Bool { discountPackage != nil && regularPackage != nil }

    /// True savings %, computed from the actual prices RevenueCat returned.
    /// Used to label the winning slice and the "won" headline so we never
    /// promise 80% when the dashboard is configured for, say, 60%.
    private var actualDiscountPercent: Int {
        guard let r = regularPackage, let d = discountPackage else { return 0 }
        let regular = NSDecimalNumber(decimal: r.storeProduct.price as Decimal).doubleValue
        let disc = NSDecimalNumber(decimal: d.storeProduct.price as Decimal).doubleValue
        guard regular > 0, disc < regular else { return 0 }
        return max(1, Int(round((1 - disc / regular) * 100)))
    }

    /// 8-slice wheel. Index 0 is the winning slice; the wheel always lands
    /// there. When no real discount exists we relabel slice 0 as a free
    /// "claim your spot" win so we never show "80% OFF" while charging full
    /// price.
    private var slices: [WheelSlice] {
        let winnerLabel: String
        if hasRealDiscount {
            let pct = actualDiscountPercent
            winnerLabel = pct >= 5 ? "\(pct)% OFF" : "VIP slot"
        } else {
            winnerLabel = "VIP slot"
        }
        return [
            .init(label: winnerLabel, color: MooniColor.warning, isWinner: true),
            .init(label: "Try again", color: Color(white: 0.18), isWinner: false),
            .init(label: "10% off", color: MooniColor.accentSoft.opacity(0.6), isWinner: false),
            .init(label: "Try again", color: Color(white: 0.22), isWinner: false),
            .init(label: "30% off", color: MooniColor.accentSoft.opacity(0.7), isWinner: false),
            .init(label: "Try again", color: Color(white: 0.18), isWinner: false),
            .init(label: "20% off", color: MooniColor.accentSoft.opacity(0.6), isWinner: false),
            .init(label: "Try again", color: Color(white: 0.22), isWinner: false)
        ]
    }

    var body: some View {
        ZStack {
            MooniColor.background.ignoresSafeArea()
            StarsBackground(count: 60)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    // Hidden close — small + faint, always available.
                    HStack {
                        Spacer()
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

                    headerForStage
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 8)

                    // The wheel. Stays on screen across all stages — only
                    // the surrounding copy and CTA change as the user spins.
                    wheelView
                        .padding(.top, 4)
                        .padding(.horizontal, 24)

                    Group {
                        switch stage {
                        case .gift:
                            spinCTA
                        case .spinning:
                            // Disabled CTA while spinning — just feedback.
                            spinningCTA
                        case .won:
                            wonContent
                        }
                    }
                    .padding(.horizontal, 24)

                    // Tiny no-thanks
                    Button(action: onDecline) {
                        Text("No thanks, I'll skip the gift")
                            .font(MooniFont.caption(11))
                            .foregroundColor(.white.opacity(0.30))
                            .underline()
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 8)

                    HStack(spacing: 14) {
                        Button { Task { await manager.restorePurchases() } } label: {
                            Text("Restore")
                                .font(MooniFont.caption(11))
                                .foregroundColor(.white.opacity(0.55))
                                .underline()
                        }
                        Link("Terms",
                             destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                            .font(MooniFont.caption(11))
                            .foregroundColor(.white.opacity(0.55))
                            .underline()
                        Link("Privacy",
                             destination: URL(string: "https://nathanielfiskaa.github.io/sleepowl-privacy/")!)
                            .font(MooniFont.caption(11))
                            .foregroundColor(.white.opacity(0.55))
                            .underline()
                    }
                    .padding(.top, 2)

                    Text("Auto-renews unless cancelled in Settings → Apple ID → Subscriptions.")
                        .font(MooniFont.caption(10))
                        .foregroundColor(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 24)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { animateIn = true }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) { pulse = true }
        }
        .onReceive(timer) { _ in
            // Only start the urgency clock once the wheel has been spun —
            // before that, the gift framing should breathe.
            if stage == .won && secondsRemaining > 0 {
                secondsRemaining -= 1
            }
        }
        .task { await manager.loadOfferings() }
    }

    // MARK: - Header per stage

    @ViewBuilder
    private var headerForStage: some View {
        switch stage {
        case .gift:
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "gift.fill")
                        .foregroundColor(MooniColor.warning)
                    Text("A GIFT FROM \(petName.uppercased())")
                        .font(MooniFont.caption(13))
                        .foregroundColor(MooniColor.warning)
                        .tracking(2)
                }
                Text("Spin the wheel,\nclaim your discount")
                    .font(MooniFont.display(34))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                Text("One spin — keep what you land on.")
                    .font(MooniFont.body(15))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
        case .spinning:
            VStack(spacing: 10) {
                Text("Spinning…")
                    .font(MooniFont.display(34))
                    .foregroundColor(.white)
                Text("Hold tight.")
                    .font(MooniFont.body(15))
                    .foregroundColor(.white.opacity(0.7))
            }
        case .won:
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundColor(MooniColor.warning)
                    Text("YOU WON!")
                        .font(MooniFont.caption(13))
                        .foregroundColor(MooniColor.warning)
                        .tracking(2)
                    Image(systemName: "sparkles")
                        .foregroundColor(MooniColor.warning)
                }
                Text(hasRealDiscount && actualDiscountPercent >= 5
                     ? "\(actualDiscountPercent)% OFF\nyearly plan"
                     : "Your VIP\nyearly slot")
                    .font(MooniFont.display(34))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                // Countdown lives inside the won state — the offer only
                // expires once the user has actually won it.
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(MooniColor.warning)
                    Text("Locked for \(timeLabel)")
                        .font(MooniFont.caption(12))
                        .foregroundColor(.white.opacity(0.85))
                        .scaleEffect(pulse ? 1.04 : 1.0)
                }
            }
        }
    }

    // MARK: - Wheel

    private var wheelView: some View {
        ZStack {
            // Outer dotted halo for celebration feel.
            Circle()
                .stroke(MooniColor.warning.opacity(0.45),
                        style: StrokeStyle(lineWidth: 1.5, dash: [3, 5]))
                .frame(width: 210, height: 210)
                .scaleEffect(pulse ? 1.02 : 0.98)

            // The slices.
            ZStack {
                ForEach(Array(slices.enumerated()), id: \.offset) { idx, slice in
                    WheelSliceShape(index: idx, total: slices.count)
                        .fill(slice.color)
                        .overlay(
                            WheelSliceShape(index: idx, total: slices.count)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                    WheelSliceLabel(index: idx, total: slices.count, label: slice.label, isWinner: slice.isWinner)
                }
            }
            .frame(width: 180, height: 180)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(LinearGradient(
                    colors: [MooniColor.warning, MooniColor.accentSoft],
                    startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2.5)
            )
            .rotationEffect(.degrees(wheelRotation))

            // Center cap.
            ZStack {
                Circle().fill(Color.black)
                    .frame(width: 36, height: 36)
                Circle().stroke(MooniColor.warning, lineWidth: 2)
                    .frame(width: 36, height: 36)
                Image(systemName: "gift.fill")
                    .font(.system(size: 14))
                    .foregroundColor(MooniColor.warning)
            }

            // Pointer at 12 o'clock.
            VStack(spacing: 0) {
                Triangle()
                    .fill(MooniColor.warning)
                    .frame(width: 18, height: 18)
                    .shadow(color: MooniColor.warning.opacity(0.6), radius: 5)
                Spacer()
            }
            .frame(height: 210)
        }
        .frame(width: 210, height: 210)
    }

    // MARK: - CTAs per stage

    private var spinCTA: some View {
        VStack(spacing: 10) {
            Button {
                spin()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "wand.and.stars")
                    Text("Spin to win")
                        .font(MooniFont.title(17))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    LinearGradient(
                        colors: [MooniColor.warning, MooniColor.danger],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: MooniColor.warning.opacity(0.5), radius: 14, y: 5)
                .scaleEffect(pulse ? 1.02 : 1.0)
            }
            .disabled(!canSpin)

            Text("Just one spin — limited to first-time users.")
                .font(MooniFont.caption(11))
                .foregroundColor(.white.opacity(0.55))
        }
    }

    private var spinningCTA: some View {
        HStack(spacing: 10) {
            ProgressView().tint(.white)
            Text("Good luck…")
                .font(MooniFont.title(15))
                .foregroundColor(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var wonContent: some View {
        VStack(spacing: 14) {
            // Price comparison (real prices via StoreKit).
            if hasRealDiscount {
                priceComparison
            } else if let pkg = purchasePackage {
                singlePriceCard(pkg)
            }

            // What they get
            VStack(spacing: 8) {
                offerRow(icon: "checkmark.seal.fill", text: "Full SleepOwl Pro — every feature unlocked")
                offerRow(icon: "pawprint.fill", text: "All pet evolutions & rare forms")
                offerRow(icon: "wind", text: "Sleep stories, breathing & 7-day reset")
                offerRow(icon: "chart.bar.fill", text: "Advanced analytics & sleep coach")
            }

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
        }
    }

    // MARK: - Spin animation

    private func spin() {
        guard canSpin else { return }
        canSpin = false
        stage = .spinning
        Haptics.medium()

        // Always lands on slice 0 (the winning slice).
        // 5 full rotations + offset to align slice 0 with the top pointer.
        let sliceAngle = 360.0 / Double(slices.count)
        let target = wheelRotation + 360.0 * 5 + (360.0 - sliceAngle * 0.5)

        withAnimation(.easeOut(duration: 3.4)) {
            wheelRotation = target
        }

        // Slice-tick haptics during the spin — decelerating to match the
        // ease-out curve so it feels like a real wheel slowing down.
        let totalSlices = slices.count
        let totalTicks = 5 * totalSlices + Int(round(target.truncatingRemainder(dividingBy: 360) / sliceAngle))
        let totalDuration = 3.4
        for tick in 0..<totalTicks {
            let progress = Double(tick) / Double(max(1, totalTicks - 1))
            // Inverse of ease-out: 1 - (1 - p)^3
            let eased = 1 - pow(1 - progress, 3)
            let delay = eased * totalDuration
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                Haptics.tick()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            Haptics.success()
            withAnimation(.easeInOut(duration: 0.4)) {
                stage = .won
            }
        }
    }

    // MARK: - Price views

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
                Text("YOUR PRICE")
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

    private var originalPriceLabel: String {
        guard let p = regularPackage else { return "" }
        return "\(p.storeProduct.localizedPriceString) / yr"
    }

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

// MARK: - Wheel primitives

private struct WheelSlice {
    let label: String
    let color: Color
    let isWinner: Bool
}

/// Pie slice for the discount wheel. `index` 0 is centred at the top so
/// the winning slice aligns perfectly with the 12-o'clock pointer when the
/// rotation lands on a multiple of 360°.
private struct WheelSliceShape: Shape {
    let index: Int
    let total: Int

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let sliceAngle = 360.0 / Double(total)
        // -90° puts slice 0 centred at the top (pointer).
        let start = Angle.degrees(-90 - sliceAngle / 2 + Double(index) * sliceAngle)
        let end = Angle.degrees(start.degrees + sliceAngle)

        var p = Path()
        p.move(to: center)
        p.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        p.closeSubpath()
        return p
    }
}

private struct WheelSliceLabel: View {
    let index: Int
    let total: Int
    let label: String
    let isWinner: Bool

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2
            let sliceAngle = 360.0 / Double(total)
            let mid = -90.0 + Double(index) * sliceAngle
            let r = radius * 0.66
            let rad = mid * .pi / 180
            let x = center.x + CGFloat(cos(rad)) * r
            let y = center.y + CGFloat(sin(rad)) * r

            // The wheel itself rotates as a whole; we want each label to
            // read along its own slice, so we counter-rotate by the slice's
            // mid angle (text feet pointing at center → readable from
            // outside). 8 narrow slices = 45° each, so width must stay
            // small enough that adjacent labels never collide.
            Text(label)
                .font(.system(size: isWinner ? 11 : 9,
                              weight: isWinner ? .black : .semibold,
                              design: .rounded))
                .foregroundColor(isWinner ? .black : .white.opacity(0.92))
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .allowsTightening(true)
                .frame(width: 54)
                .rotationEffect(.degrees(mid + 90))
                .position(x: x, y: y)
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

#Preview {
    DiscountPaywallView(petName: "Nova", onAccept: {}, onDecline: {})
}
