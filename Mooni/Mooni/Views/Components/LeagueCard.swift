import SwiftUI

/// Duolingo-inspired weekly league card. Shows the user's current tier, their
/// position on the leaderboard, and a row of co-competitors (real friends in
/// Phase 5; community averages until then).
///
/// The card is *always present* on Home so the social hook is visible from day
/// one — even before the user has invited a friend. With zero friends we show
/// an "Invite to climb the league" CTA in place of the leaderboard rank.
struct LeagueCard: View {
    enum Tier: String, CaseIterable {
        case bronze, silver, gold, emerald, diamond, owl

        var displayName: String {
            switch self {
            case .bronze:  return "Bronze Owls"
            case .silver:  return "Silver Owls"
            case .gold:    return "Gold Owls"
            case .emerald: return "Emerald Owls"
            case .diamond: return "Diamond Owls"
            case .owl:     return "Legendary Owls"
            }
        }

        var medalColor: Color {
            switch self {
            case .bronze:  return Color(red: 0.78, green: 0.55, blue: 0.32)
            case .silver:  return Color(red: 0.85, green: 0.86, blue: 0.92)
            case .gold:    return Color(red: 1.0,  green: 0.84, blue: 0.45)
            case .emerald: return Color(red: 0.50, green: 0.92, blue: 0.70)
            case .diamond: return Color(red: 0.70, green: 0.92, blue: 1.0)
            case .owl:     return Color(red: 0.86, green: 0.80, blue: 1.0)
            }
        }

        var subtitle: String {
            switch self {
            case .bronze:  return "Just getting started"
            case .silver:  return "Solid rhythm"
            case .gold:    return "Real consistency"
            case .emerald: return "Sleep machine"
            case .diamond: return "Top tier"
            case .owl:     return "Hall of fame"
            }
        }

        /// Derive tier from the user's longest streak. Tunable.
        static func from(streak: Int) -> Tier {
            switch streak {
            case ..<3:    return .bronze
            case 3..<7:   return .silver
            case 7..<14:  return .gold
            case 14..<30: return .emerald
            case 30..<60: return .diamond
            default:      return .owl
            }
        }
    }

    struct Member: Identifiable {
        let id = UUID()
        let initial: String
        let score: Int
        let isYou: Bool
        let color: Color
    }

    let tier: Tier
    let userScore: Int
    /// `nil` or empty = no friends yet, show invite CTA. Caller passes the
    /// real friend list in Phase 5.
    let friends: [Member]
    var onInviteFriends: (() -> Void)? = nil

    private var sortedMembers: [Member] {
        var list = friends
        if !list.contains(where: { $0.isYou }) {
            list.append(Member(initial: "Y", score: userScore, isYou: true, color: MooniColor.accentSoft))
        }
        return list.sorted { $0.score > $1.score }
    }

    private var youRank: Int {
        (sortedMembers.firstIndex(where: { $0.isYou }) ?? 0) + 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if friends.isEmpty {
                inviteSlate
            } else {
                membersList
            }
        }
        .padding(18)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(tier.medalColor.opacity(0.32), lineWidth: 1)
            }
        )
    }

    // MARK: - Header
    private var header: some View {
        HStack(spacing: 14) {
            medal

            VStack(alignment: .leading, spacing: 3) {
                Text(tier.displayName)
                    .font(MooniFont.title(17))
                    .foregroundColor(MooniColor.textPrimary)
                Text(tier.subtitle)
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textSecondary)
            }

            Spacer(minLength: 0)

            if !friends.isEmpty {
                rankBadge
            }
        }
    }

    private var medal: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [tier.medalColor.opacity(0.85), tier.medalColor.opacity(0.35)],
                        center: .center,
                        startRadius: 4,
                        endRadius: 26
                    )
                )
                .frame(width: 44, height: 44)
                .shadow(color: tier.medalColor.opacity(0.5), radius: 8)

            Image(systemName: "rosette")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(MooniColor.background)
        }
    }

    private var rankBadge: some View {
        VStack(spacing: 0) {
            Text("#\(youRank)")
                .font(MooniFont.display(20))
                .foregroundColor(MooniColor.textPrimary)
            Text("YOU")
                .font(MooniFont.caption(9))
                .tracking(1.2)
                .foregroundColor(MooniColor.textMuted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }

    // MARK: - Members list (mini-leaderboard)
    private var membersList: some View {
        VStack(spacing: 8) {
            ForEach(Array(sortedMembers.prefix(4).enumerated()), id: \.element.id) { idx, m in
                memberRow(rank: idx + 1, member: m)
            }
        }
    }

    private func memberRow(rank: Int, member: Member) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(MooniFont.title(13))
                .foregroundColor(member.isYou ? tier.medalColor : MooniColor.textMuted)
                .frame(width: 18, alignment: .leading)

            ZStack {
                Circle()
                    .fill(member.color.opacity(0.32))
                    .frame(width: 28, height: 28)
                Text(member.initial)
                    .font(MooniFont.title(13))
                    .foregroundColor(member.isYou ? MooniColor.textPrimary : MooniColor.textSecondary)
            }

            Text(member.isYou ? "You" : "Friend")
                .font(MooniFont.body(14))
                .foregroundColor(member.isYou ? MooniColor.textPrimary : MooniColor.textSecondary)

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                Image(systemName: "sparkle")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(MooniColor.xpGreen)
                Text("\(member.score)")
                    .font(MooniFont.title(14))
                    .foregroundColor(MooniColor.textPrimary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(member.isYou ? tier.medalColor.opacity(0.10) : Color.clear)
        )
    }

    // MARK: - Empty / invite state
    private var inviteSlate: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { i in
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 36, height: 36)
                        Image(systemName: "person.fill.questionmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(MooniColor.textMuted)
                    }
                    .opacity(0.65 - Double(i) * 0.18)
                }
                Spacer(minLength: 0)
                Text("Invite to climb")
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textSecondary)
            }

            Button {
                Haptics.tap()
                onInviteFriends?()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                    Text("Invite friends")
                }
                .font(MooniFont.title(15))
                .foregroundColor(MooniColor.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(MooniColor.accent)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    ZStack {
        MooniGradient.night.ignoresSafeArea()
        VStack(spacing: 18) {
            LeagueCard(
                tier: .gold,
                userScore: 86,
                friends: [
                    .init(initial: "A", score: 92, isYou: false, color: Color.pink),
                    .init(initial: "M", score: 78, isYou: false, color: Color.blue),
                    .init(initial: "J", score: 65, isYou: false, color: Color.green)
                ]
            )
            LeagueCard(
                tier: .silver,
                userScore: 71,
                friends: []
            )
        }
        .padding(20)
    }
}
