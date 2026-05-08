import SwiftUI

// MARK: - Daily Aura badge

struct DailyAuraBadge: View {
    let aura: HomeIntelligence.DailyAura
    var deck: [HomeIntelligence.DailyAura] = []
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: aura.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(aura.color)
                Text("Today's aura · \(aura.label.uppercased())")
                    .font(MooniFont.caption(11))
                    .foregroundColor(aura.color)
                    .tracking(0.6)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(aura.color.opacity(0.16))
                    .overlay(
                        Capsule().stroke(aura.color.opacity(0.4), lineWidth: 1)
                    )
            )
            .scaleEffect(pulse ? 1.03 : 1.0)
            .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pulse)

            if deck.count > 1 {
                HStack(spacing: 6) {
                    ForEach(Array(deck.dropFirst().prefix(2).enumerated()), id: \.offset) { _, mood in
                        HStack(spacing: 4) {
                            Image(systemName: mood.icon)
                                .font(.system(size: 9))
                            Text(mood.label.lowercased())
                                .font(MooniFont.caption(10))
                        }
                        .foregroundColor(mood.color.opacity(0.85))
                    }
                }
                .opacity(0.85)
            }
        }
        .onAppear { pulse = true }
    }
}

// MARK: - Rare event banner

struct RareEventBanner: View {
    let event: HomeIntelligence.RareEvent
    @State private var shimmer: CGFloat = -1

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(event.tint.opacity(0.22))
                    .frame(width: 44, height: 44)
                Image(systemName: event.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(event.tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("RARE")
                        .font(MooniFont.caption(9))
                        .foregroundColor(MooniColor.background)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(event.tint)
                        .clipShape(Capsule())
                    Text(event.title)
                        .font(MooniFont.title(14))
                        .foregroundColor(MooniColor.textPrimary)
                }
                Text(event.body)
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(MooniColor.surface)
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.0),
                        event.tint.opacity(0.18),
                        Color.white.opacity(0.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .offset(x: shimmer * 200)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(event.tint.opacity(0.45), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                shimmer = 1
            }
        }
    }
}

// MARK: - Morning insight carousel

struct MorningCardCarousel: View {
    let cards: [HomeIntelligence.MorningCard]
    @State private var index: Int = 0

    var body: some View {
        VStack(spacing: 12) {
            TabView(selection: $index) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { i, card in
                    InsightCard(card: card)
                        .padding(.horizontal, 4)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 180)

            HStack(spacing: 6) {
                ForEach(0..<cards.count, id: \.self) { i in
                    Capsule()
                        .fill(i == index ? cards[index].kind.color : Color.white.opacity(0.18))
                        .frame(width: i == index ? 16 : 6, height: 6)
                        .animation(.spring(response: 0.35), value: index)
                }
            }
        }
    }

    private struct InsightCard: View {
        let card: HomeIntelligence.MorningCard
        @State private var appeared = false

        var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(MooniGradient.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(card.kind.color.opacity(0.35), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(card.kind.color.opacity(0.22))
                                .frame(width: 36, height: 36)
                            Image(systemName: card.kind.icon)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(card.kind.color)
                        }
                        Text(card.kind.title)
                            .font(MooniFont.caption(11))
                            .foregroundColor(MooniColor.textSecondary)
                            .textCase(.uppercase)
                            .tracking(0.6)
                        Spacer()
                    }

                    Text(card.headline)
                        .font(MooniFont.display(22))
                        .foregroundColor(MooniColor.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(card.detail)
                        .font(MooniFont.body(13))
                        .foregroundColor(MooniColor.textSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .padding(18)
            }
            .scaleEffect(appeared ? 1 : 0.96)
            .opacity(appeared ? 1 : 0.5)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    appeared = true
                }
            }
        }
    }
}

// MARK: - Achievement chip

struct AchievementChip: View {
    let achievement: HomeIntelligence.Achievement
    @State private var glow = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: achievement.icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(MooniColor.warning)
            Text(achievement.title)
                .font(MooniFont.title(13))
                .foregroundColor(MooniColor.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Text("NEW")
                .font(MooniFont.caption(9))
                .foregroundColor(MooniColor.background)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(MooniColor.warning)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(MooniColor.warning.opacity(0.13))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(MooniColor.warning.opacity(glow ? 0.55 : 0.3), lineWidth: 1)
                )
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }
}

// MARK: - Tap-to-bounce hero wrapper

struct InteractiveLunaHero: View {
    let pet: Pet
    let mood: Pet.Mood
    var size: CGFloat = 218

    @State private var bounce: CGFloat = 1
    @State private var sparkles: [SparkleParticle] = []

    var body: some View {
        ZStack {
            ForEach(sparkles) { sparkle in
                Image(systemName: "sparkle")
                    .font(.system(size: 14))
                    .foregroundColor(MooniColor.warning)
                    .position(sparkle.start)
                    .offset(x: sparkle.endOffset.width, y: sparkle.endOffset.height)
                    .opacity(sparkle.opacity)
                    .animation(.easeOut(duration: 0.9), value: sparkle.endOffset)
            }

            LunaMoodHero(pet: pet, mood: mood, size: size, caption: nil)
                .scaleEffect(bounce)
                .animation(.spring(response: 0.32, dampingFraction: 0.45), value: bounce)
                .onTapGesture {
                    triggerBounce()
                    spawnSparkles()
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                }
        }
        .frame(height: size + 8)
    }

    private func triggerBounce() {
        bounce = 1.08
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { bounce = 1.0 }
    }

    private func spawnSparkles() {
        let center = CGPoint(x: size / 2, y: size / 2)
        let new = (0..<6).map { _ in
            SparkleParticle(
                id: UUID(),
                start: center,
                endOffset: .zero,
                opacity: 1
            )
        }
        sparkles = new

        DispatchQueue.main.async {
            sparkles = sparkles.map { p in
                let angle = Double.random(in: 0..<(2 * .pi))
                let dist = CGFloat.random(in: 60...110)
                return SparkleParticle(
                    id: p.id,
                    start: p.start,
                    endOffset: CGSize(width: cos(angle) * dist, height: sin(angle) * dist),
                    opacity: 0
                )
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            sparkles.removeAll()
        }
    }

    private struct SparkleParticle: Identifiable {
        let id: UUID
        let start: CGPoint
        let endOffset: CGSize
        let opacity: Double
    }
}
