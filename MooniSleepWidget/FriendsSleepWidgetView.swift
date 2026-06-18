import SwiftUI

/// Medium "Sleep Circle" widget — a clean ranked leaderboard. Each person is a
/// row (rank · avatar · name + duration · score bar · score), sorted high → low,
/// with the night's winner subtly highlighted. A fresh, premium take that reads
/// at a glance, replacing the old three-card grid.
struct FriendsSleepWidgetView: View {
    let data: FriendsWidgetData

    /// "me + up to 2 friends", ranked by score (highest first).
    private var ranked: [FriendSleepSnapshot] {
        ([data.me] + data.friends.prefix(2)).sorted { $0.score > $1.score }
    }

    private var winnerID: String { ranked.first?.id ?? "" }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header

            VStack(spacing: 4) {
                ForEach(Array(ranked.enumerated()), id: \.element.id) { idx, person in
                    row(rank: idx + 1, person: person,
                        isMe: person.id == "me", isWinner: person.id == winnerID)
                }
                if data.friends.count < 2 {
                    inviteRow
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(data.me.scoreTint)
            Text("Sleep Circle")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .tracking(0.2)
                .foregroundStyle(SleepWidgetPalette.textPrimary)
            Spacer(minLength: 0)
            HStack(spacing: 3) {
                Image(systemName: "moon.stars.fill").font(.system(size: 9, weight: .heavy))
                Text("SleepOwl").font(.system(size: 10, weight: .black, design: .rounded))
            }
            .foregroundStyle(SleepWidgetPalette.textSecondary)
        }
    }

    // MARK: Row

    private func row(rank: Int, person: FriendSleepSnapshot, isMe: Bool, isWinner: Bool) -> some View {
        HStack(spacing: 9) {
            rankBadge(rank)

            avatar(for: person)
                .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 0) {
                Text(isMe ? "You" : person.name)
                    .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(SleepWidgetPalette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(person.quality == "Pending" ? "no data yet" : person.sleepDuration)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(SleepWidgetPalette.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            miniBar(person.quality == "Pending" ? 0 : person.ringProgress, tint: person.scoreTint)

            Text(person.quality == "Pending" ? "—" : "\(person.score)")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(person.scoreTint)
                .frame(width: 24, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 7)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(person.scoreTint.opacity(isWinner ? 0.16 : 0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(person.scoreTint.opacity(isWinner ? 0.4 : 0.0), lineWidth: 0.8)
        )
    }

    private func rankBadge(_ rank: Int) -> some View {
        Text(rank == 1 ? "👑" : "\(rank)")
            .font(.system(size: rank == 1 ? 13 : 12, weight: .black, design: .rounded))
            .foregroundStyle(SleepWidgetPalette.textSecondary)
            .frame(width: 18)
    }

    private func miniBar(_ progress: Double, tint: Color) -> some View {
        ZStack(alignment: .leading) {
            Capsule().fill(SleepWidgetPalette.ringTrack)
            Capsule()
                .fill(LinearGradient(colors: [tint.opacity(0.6), tint],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: max(6, 52 * progress))
        }
        .frame(width: 52, height: 6)
    }

    @ViewBuilder
    private func avatar(for person: FriendSleepSnapshot) -> some View {
        if person.id == "me" {
            MooniMascotView()
                .frame(width: 24, height: 24)
        } else {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [person.scoreTint.opacity(0.35),
                                                  person.scoreTint.opacity(0.10)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 0.8))
                Text(person.avatarEmoji).font(.system(size: 15))
            }
        }
    }

    // MARK: Invite

    private var inviteRow: some View {
        HStack(spacing: 9) {
            Text(" ").frame(width: 18)
            ZStack {
                Circle()
                    .strokeBorder(SleepWidgetPalette.textTertiary.opacity(0.5),
                                  style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(SleepWidgetPalette.textSecondary)
            }
            .frame(width: 26, height: 26)

            Text("Invite a friend")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(SleepWidgetPalette.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 7)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(SleepWidgetPalette.textTertiary.opacity(0.25),
                              style: StrokeStyle(lineWidth: 0.8, dash: [4, 3]))
        )
    }
}
