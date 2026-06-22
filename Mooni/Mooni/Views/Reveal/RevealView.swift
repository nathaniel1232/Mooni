import SwiftUI

/// Full-screen Sleepowl Reveal presentation. Three beats:
///   1. **Build-up** — quick score counter from BEFORE → AFTER while the
///      template gradient fades in.
///   2. **Reveal** — owl scales in, tagline lands, stats strip slides up.
///   3. **Share / pick template** — user can swipe through 4 templates and
///      tap "Share" to fire a ShareLink with the rendered image.
///
/// Presented as a sheet from HomeView (or anywhere). Closes via the X in the
/// top-right or the system swipe-down.
struct RevealView: View {
    let stats: RevealStats
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @State private var template: RevealTemplate = .night
    @State private var animatedScore: Int = 0
    @State private var heroVisible: Bool = false
    @State private var statsVisible: Bool = false
    @State private var taglineVisible: Bool = false
    @State private var confettiTrigger: Int = 0

    @State private var sharePayload: SharePayload?

    var body: some View {
        ZStack {
            // The shareable card itself is the entire backdrop — what the user
            // sees on screen IS what gets shared (minus the close button).
            // Scale it to fit the device while preserving aspect.
            GeometryReader { geo in
                ZStack {
                    template.background
                        .ignoresSafeArea()

                    // Animated hero / stats overlay, rendered at the device's
                    // actual size (NOT at canvas size, so it reads on screen).
                    onScreenContent(deviceSize: geo.size)
                }
                .animation(.easeInOut(duration: 0.6), value: template)
            }

            ConfettiView(trigger: $confettiTrigger)
                .allowsHitTesting(false)

            // Chrome
            VStack {
                topBar
                Spacer()
                bottomControls
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { runBuildUp() }
        .onChange(of: template) { _, _ in
            Haptics.tap()
            // Re-trigger a small confetti pop when the user picks a fresh
            // template — sells the "another version" feel.
            confettiTrigger += 1
        }
        .sheet(item: $sharePayload) { payload in
            // Wrap the share sheet in our own sheet so we can also offer a
            // "Save to Photos" button next to the share action. UIActivityVC
            // already exposes both — keep it simple and reuse ShareLink in
            // the bottom bar instead. Sheet kept only for future expansion.
            VStack {
                Image(uiImage: payload.image)
                    .resizable()
                    .scaledToFit()
                    .padding()
            }
        }
    }

    // MARK: - On-screen content
    @ViewBuilder
    private func onScreenContent(deviceSize: CGSize) -> some View {
        // Re-implements the card layout at the device's coordinate system so
        // we can animate it. The actual SHARED image uses RevealCard at
        // 1080×1920 (see ShareLink wiring in `bottomControls`).
        let w = deviceSize.width
        let scale = w / 1080.0

        ZStack {
            if template.hasStars {
                StaticStarsOverlay(count: 90).opacity(0.85)
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [template.accent.opacity(0.45), .clear],
                        center: .center,
                        startRadius: 6,
                        endRadius: max(deviceSize.width, deviceSize.height) * 0.5
                    )
                )
                .frame(width: deviceSize.width * 1.5, height: deviceSize.width * 1.5)
                .offset(y: -deviceSize.height * 0.06)
                .blur(radius: 24 * scale)

            VStack(spacing: 0) {
                Spacer().frame(height: 96)

                // Header
                VStack(spacing: 6) {
                    HStack(spacing: 10) {
                        Image(systemName: "moon.stars.fill")
                            .foregroundColor(template.secondaryAccent)
                            .font(.system(size: 18, weight: .bold))
                        Text("SLEEPOWL REVEAL")
                            .font(MooniFont.title(15))
                            .tracking(3)
                            .foregroundColor(.white.opacity(0.85))
                    }
                    Text(stats.windowLabel.uppercased())
                        .font(MooniFont.caption(11))
                        .tracking(2)
                        .foregroundColor(.white.opacity(0.55))
                }

                Spacer()

                // Hero — big owl + counter
                VStack(spacing: 14) {
                    OnScreenOwl(pet: stats.pet, mood: stats.afterMood, size: 240)
                        .scaleEffect(heroVisible ? 1.0 : 0.6)
                        .opacity(heroVisible ? 1 : 0)
                        .shadow(color: template.accent.opacity(0.6), radius: 30, y: 6)

                    Text("\(animatedScore)")
                        .font(.system(size: 96, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText(value: Double(animatedScore)))
                        .shadow(color: template.accent.opacity(0.55), radius: 12, y: 3)

                    if taglineVisible {
                        Text(stats.tagline.uppercased())
                            .font(MooniFont.title(15))
                            .tracking(2)
                            .foregroundColor(template.accent)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }

                Spacer()

                if statsVisible {
                    onScreenStats
                        .padding(.horizontal, 22)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer().frame(height: 240) // leave room for bottom controls
            }
        }
    }

    private var onScreenStats: some View {
        HStack(spacing: 10) {
            statTile(icon: "flame.fill", color: MooniColor.streakFire, value: "\(stats.streakDays)", caption: "DAY STREAK")
            statTile(icon: "sparkle", color: MooniColor.xpGreen, value: "\(stats.level)", caption: "LEVEL")
            statTile(icon: "moon.zzz.fill", color: template.secondaryAccent, value: "\(stats.nightsTracked)", caption: "NIGHTS")
        }
    }

    private func statTile(icon: String, color: Color, value: String, caption: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundColor(color).font(.system(size: 18, weight: .bold))
            Text(value).font(.system(size: 30, weight: .bold, design: .rounded)).foregroundColor(.white)
            Text(caption).font(MooniFont.caption(10)).tracking(1.2).foregroundColor(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.08)))
    }

    // MARK: - Chrome
    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                Haptics.tap()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Circle().fill(Color.white.opacity(0.16)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var bottomControls: some View {
        VStack(spacing: 14) {
            templatePicker

            // Share button uses RevealRenderer to bake the high-res image
            // right before the share sheet opens, so the user always gets the
            // currently-selected template.
            if let img = renderedShareImage {
                ShareLink(
                    item: img,
                    preview: SharePreview(
                        "My SleepOwl glow-up — \(stats.windowLabel)",
                        image: img
                    )
                ) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share my Reveal")
                    }
                    .font(MooniFont.title(17))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 999, style: .continuous))
                }
                .simultaneousGesture(TapGesture().onEnded {
                    Haptics.celebrate()
                    confettiTrigger += 1
                })
            } else {
                // Fallback in case ImageRenderer hiccups.
                Text("Preparing your Reveal…")
                    .font(MooniFont.body(13))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.vertical, 18)
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 30)
    }

    private var templatePicker: some View {
        HStack(spacing: 10) {
            ForEach(RevealTemplate.allCases) { t in
                Button {
                    template = t
                } label: {
                    Text(t.displayName)
                        .font(MooniFont.title(13))
                        .foregroundColor(template == t ? .black : .white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(template == t ? .white : Color.white.opacity(0.10))
                        )
                        .overlay(
                            Capsule().stroke(Color.white.opacity(template == t ? 0 : 0.18), lineWidth: 1)
                        )
                }
            }
        }
    }

    // MARK: - Rendered share image (rebuilt when template changes)
    private var renderedShareImage: Image? {
        RevealRenderer.shareItem(stats: stats, template: template)
    }

    // MARK: - Build-up animation
    private func runBuildUp() {
        animatedScore = stats.beforeScore

        // Owl pops in immediately
        withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
            heroVisible = true
        }

        // Score counter tweens from before → after over ~1.4s
        let total = max(stats.afterScore - stats.beforeScore, 1)
        let stepInterval: Double = 1.2 / Double(max(abs(total), 1))
        let direction = stats.scoreDelta >= 0 ? 1 : -1
        var step = 0
        Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { timer in
            DispatchQueue.main.async {
                if step >= abs(total) {
                    animatedScore = stats.afterScore
                    timer.invalidate()
                    Haptics.celebrate()
                    confettiTrigger += 1
                    withAnimation(.easeOut(duration: 0.4)) { taglineVisible = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        withAnimation(.easeOut(duration: 0.4)) { statsVisible = true }
                    }
                    return
                }
                animatedScore += direction
                Haptics.tick()
                step += 1
            }
        }
    }

    private struct SharePayload: Identifiable {
        let id = UUID()
        let image: UIImage
    }
}

// MARK: - On-screen owl (file-private, animated breathing version)

private struct OnScreenOwl: View {
    let pet: Pet
    let mood: Pet.Mood
    let size: CGFloat

    @State private var pulse = false

    private var tint: Color {
        if pet.equippedColor == "default_color" {
            return pet.species.tint
        }
        return UnlockableItem.color(for: pet.equippedColor)
    }

    private var imageName: String {
        switch mood.legacyBucket {
        case .rested: return "spirit_dream"
        case .good:   return "spirit_awake"
        case .tired:  return "spirit_sleep"
        case .low:    return "spirit_tired"
        default:      return "spirit_awake"
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [tint.opacity(0.55), .clear], center: .center, startRadius: 0, endRadius: size * 0.6))
                .frame(width: size * 1.5, height: size * 1.5)
                .blur(radius: 28)
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .scaleEffect(pulse ? 1.04 : 0.98)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

private struct StaticStarsOverlay: View {
    let count: Int
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<count, id: \.self) { i in
                    let a = Double((i &* 9301 &+ 49297) % 233280) / 233280.0
                    let b = Double((i &* 89 &+ 17) % 233280) / 233280.0
                    let c = Double((i &* 7919 &+ 99) % 233280) / 233280.0
                    Circle()
                        .fill(Color.white.opacity(0.25 + c * 0.55))
                        .frame(width: 1 + CGFloat(c) * 2.4, height: 1 + CGFloat(c) * 2.4)
                        .position(x: CGFloat(a) * geo.size.width, y: CGFloat(b) * geo.size.height)
                }
            }
        }
    }
}

#Preview {
    RevealView(stats: .demo)
        .environmentObject(AppState.preview)
}
