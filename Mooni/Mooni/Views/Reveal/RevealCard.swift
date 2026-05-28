import SwiftUI

/// The portrait shareable card. Same view drives the on-screen preview AND
/// the rendered share image — `RevealRenderer` wraps this in `ImageRenderer`
/// to produce a UIImage at the card's natural size.
///
/// Animations are intentionally absent here so the image render is
/// deterministic. The animated "build-up" lives in `RevealView`, which
/// composes its hero from this same layout.
struct RevealCard: View {
    let stats: RevealStats
    let template: RevealTemplate
    /// Render size; defaults to a 9:16 portrait that's perfect for TikTok /
    /// Instagram Stories / Reels. Caller can override for smaller previews.
    var canvasSize: CGSize = CGSize(width: 1080, height: 1920)

    init(stats: RevealStats, template: RevealTemplate, canvasSize: CGSize? = nil) {
        self.stats = stats
        self.template = template
        if let canvasSize { self.canvasSize = canvasSize }
    }

    var body: some View {
        let scale = canvasSize.width / 1080.0

        ZStack {
            template.background
                .ignoresSafeArea()

            if template.hasStars {
                StaticStarsBackground(count: 110)
                    .opacity(0.85)
            }

            // Dreamy radial spotlight behind the hero owl.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [template.accent.opacity(0.45), .clear],
                        center: .center,
                        startRadius: 6 * scale,
                        endRadius: 520 * scale
                    )
                )
                .frame(width: canvasSize.width, height: canvasSize.width)
                .offset(y: -canvasSize.height * 0.06)
                .blur(radius: 24 * scale)

            VStack(spacing: 0) {
                header(scale: scale)
                    .padding(.top, 76 * scale)

                Spacer()

                hero(scale: scale)

                Spacer()

                beforeAfterStrip(scale: scale)
                    .padding(.horizontal, 60 * scale)

                statsStrip(scale: scale)
                    .padding(.top, 36 * scale)
                    .padding(.horizontal, 60 * scale)

                watermark(scale: scale)
                    .padding(.top, 44 * scale)
                    .padding(.bottom, 60 * scale)
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .clipped()
    }

    // MARK: - Header
    @ViewBuilder
    private func header(scale: CGFloat) -> some View {
        VStack(spacing: 10 * scale) {
            HStack(spacing: 10 * scale) {
                Image(systemName: "moon.stars.fill")
                    .foregroundColor(template.secondaryAccent)
                    .font(.system(size: 28 * scale, weight: .bold))
                Text("SLEEPOWL REVEAL")
                    .font(MooniFont.title(28 * scale))
                    .tracking(4 * scale)
                    .foregroundColor(.white.opacity(0.85))
            }

            Text(stats.windowLabel.uppercased())
                .font(MooniFont.caption(20 * scale))
                .tracking(2 * scale)
                .foregroundColor(.white.opacity(0.55))
        }
    }

    // MARK: - Hero (big AFTER owl)
    @ViewBuilder
    private func hero(scale: CGFloat) -> some View {
        let owlBox: CGFloat = 620 * scale
        VStack(spacing: 22 * scale) {
            StaticOwl(pet: stats.pet, mood: stats.afterMood, size: owlBox)
                .shadow(color: template.accent.opacity(0.6), radius: 40 * scale, y: 12 * scale)

            // Score reveal — big AFTER number with a delta chip.
            VStack(spacing: 6 * scale) {
                Text("\(stats.afterScore)")
                    .font(.system(size: 220 * scale, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: template.accent.opacity(0.55), radius: 20 * scale, y: 8 * scale)

                Text(stats.tagline.uppercased())
                    .font(MooniFont.title(28 * scale))
                    .tracking(3 * scale)
                    .foregroundColor(template.accent)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40 * scale)
            }
        }
    }

    // MARK: - Before vs After mini-strip
    @ViewBuilder
    private func beforeAfterStrip(scale: CGFloat) -> some View {
        HStack(spacing: 18 * scale) {
            scorePill(
                label: "BEFORE",
                value: "\(stats.beforeScore)",
                accent: .white.opacity(0.55),
                scale: scale
            )

            Image(systemName: stats.scoreDelta >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 44 * scale, weight: .heavy))
                .foregroundColor(stats.scoreDelta >= 0 ? template.accent : .white.opacity(0.6))

            scorePill(
                label: "NOW",
                value: "\(stats.afterScore)",
                accent: template.accent,
                scale: scale
            )
        }
    }

    private func scorePill(label: String, value: String, accent: Color, scale: CGFloat) -> some View {
        VStack(spacing: 4 * scale) {
            Text(label)
                .font(MooniFont.caption(18 * scale))
                .tracking(2 * scale)
                .foregroundColor(accent.opacity(0.8))
            Text(value)
                .font(.system(size: 76 * scale, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22 * scale)
        .background(
            RoundedRectangle(cornerRadius: 32 * scale, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32 * scale, style: .continuous)
                .stroke(accent.opacity(0.32), lineWidth: 2 * scale)
        )
    }

    // MARK: - Stats strip (streak, level, nights)
    @ViewBuilder
    private func statsStrip(scale: CGFloat) -> some View {
        HStack(spacing: 14 * scale) {
            statTile(
                icon: "flame.fill",
                iconColor: MooniColor.streakFire,
                value: "\(stats.streakDays)",
                caption: stats.streakDays == 1 ? "day streak" : "day streak",
                scale: scale
            )
            statTile(
                icon: "sparkle",
                iconColor: MooniColor.xpGreen,
                value: "\(stats.level)",
                caption: "level",
                scale: scale
            )
            statTile(
                icon: "moon.zzz.fill",
                iconColor: template.secondaryAccent,
                value: "\(stats.nightsTracked)",
                caption: "nights",
                scale: scale
            )
        }
    }

    private func statTile(
        icon: String,
        iconColor: Color,
        value: String,
        caption: String,
        scale: CGFloat
    ) -> some View {
        VStack(spacing: 6 * scale) {
            Image(systemName: icon)
                .font(.system(size: 36 * scale, weight: .bold))
                .foregroundColor(iconColor)
            Text(value)
                .font(.system(size: 56 * scale, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
            Text(caption.uppercased())
                .font(MooniFont.caption(15 * scale))
                .tracking(1.6 * scale)
                .foregroundColor(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22 * scale)
        .background(
            RoundedRectangle(cornerRadius: 28 * scale, style: .continuous)
                .fill(Color.white.opacity(0.07))
        )
    }

    // MARK: - Watermark
    @ViewBuilder
    private func watermark(scale: CGFloat) -> some View {
        HStack(spacing: 6 * scale) {
            Image(systemName: "moon.stars.fill")
                .foregroundColor(.white.opacity(0.55))
                .font(.system(size: 14 * scale, weight: .bold))
            Text("made with Sleepowl")
                .font(MooniFont.caption(16 * scale))
                .tracking(1.4 * scale)
                .foregroundColor(.white.opacity(0.55))
        }
    }
}

// MARK: - Static owl renderer (no animations — render-safe)

/// Static version of `PetIllustration` for capture in `ImageRenderer`. Same
/// asset mapping as PetIllustration but with no state-driven animations, so
/// the rendered image is deterministic.
private struct StaticOwl: View {
    let pet: Pet
    let mood: Pet.Mood
    let size: CGFloat

    private var tint: Color {
        if pet.equippedColor == "default_color" {
            return pet.species.tint
        }
        return UnlockableItem.color(for: pet.equippedColor)
    }

    private var owlImageName: String {
        switch mood.legacyBucket {
        case .rested: return "spirit_dream"
        case .good:   return "spirit_awake"
        case .tired:  return "spirit_sleep"
        case .low:    return "spirit_tired"
        default:      return "spirit_awake"
        }
    }

    private var moodSaturation: Double {
        switch mood {
        case .energized, .excited, .proud, .rested: return 1.10
        case .cozy, .calm, .recovering, .good:      return 1.0
        case .sleepy, .tired:                        return 0.85
        case .groggy, .restless, .low:               return 0.70
        }
    }

    var body: some View {
        ZStack {
            // Halo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [tint.opacity(0.55), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.65
                    )
                )
                .frame(width: size * 1.4, height: size * 1.4)
                .blur(radius: 32)

            Image(owlImageName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .saturation(moodSaturation)
                .shadow(color: tint.opacity(0.55), radius: 22, y: 6)
        }
        .frame(width: size * 1.5, height: size * 1.5)
    }
}

// MARK: - Static starfield (render-safe — no animations)

private struct StaticStarsBackground: View {
    let count: Int

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<count, id: \.self) { i in
                    // Use a deterministic pseudo-random so the layout doesn't
                    // jitter across renders. ImageRenderer only captures one
                    // pass anyway, but this also keeps SwiftUI previews stable.
                    let r = Self.seeded(i)
                    let x = CGFloat(r.x) * geo.size.width
                    let y = CGFloat(r.y) * geo.size.height
                    let s = CGFloat(r.size)
                    Circle()
                        .fill(Color.white.opacity(r.opacity))
                        .frame(width: s, height: s)
                        .position(x: x, y: y)
                }
            }
        }
    }

    private static func seeded(_ i: Int) -> (x: Double, y: Double, size: Double, opacity: Double) {
        let a = Double((i &* 9301 &+ 49297) % 233280) / 233280.0
        let b = Double((i &* 89  &+ 17) % 233280) / 233280.0
        let c = Double((i &* 7919 &+ 99) % 233280) / 233280.0
        return (
            x: a,
            y: b,
            size: 1.0 + c * 2.6,
            opacity: 0.25 + c * 0.55
        )
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(RevealTemplate.allCases) { template in
                RevealCard(
                    stats: .demo,
                    template: template,
                    canvasSize: CGSize(width: 270, height: 480)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(20)
    }
    .background(Color.black)
}
