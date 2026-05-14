import SwiftUI

/// Medium "Sleep Circle" widget — premium 3-up layout. Each card is its own
/// tinted glass surface (subtle gradient + accent stroke) with a glowing
/// gradient ring around the avatar. The highest-scoring person wears a tiny
/// crown 👑 — a clear "winner of the night" signal you spot at a glance.
struct FriendsSleepWidgetView: View {
    let data: FriendsWidgetData

    /// Combined "me + friends" list with scores for winner detection.
    private var rankedPeople: [FriendSleepSnapshot] {
        ([data.me] + data.friends.prefix(2)).sorted { $0.score > $1.score }
    }

    /// id of whoever scored highest tonight — used to drop a 👑 on their card.
    private var winnerID: String { rankedPeople.first?.id ?? "" }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            HStack(alignment: .top, spacing: 8) {
                personCard(data.me, isMe: true, isWinner: data.me.id == winnerID)
                ForEach(data.friends.prefix(2)) { friend in
                    personCard(friend, isMe: false, isWinner: friend.id == winnerID)
                }
                if data.friends.count < 2 {
                    inviteCard
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
                .foregroundStyle(
                    LinearGradient(
                        colors: [SleepWidgetPalette.textPrimary, data.me.scoreTint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text("Sleep Circle")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .tracking(0.2)
                .foregroundStyle(SleepWidgetPalette.textPrimary)
            Spacer(minLength: 0)
            HStack(spacing: 3) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 9, weight: .heavy))
                Text("SleepOwl")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(0.4)
            }
            .foregroundStyle(SleepWidgetPalette.textSecondary)
        }
    }

    // MARK: Person card

    private func personCard(_ person: FriendSleepSnapshot, isMe: Bool, isWinner: Bool) -> some View {
        VStack(spacing: 4) {
            // Avatar + glowing gradient ring + crown when applicable
            ZStack {
                // Outer glow
                Circle()
                    .fill(person.scoreTint.opacity(0.22))
                    .frame(width: 60, height: 60)
                    .blur(radius: 8)

                // Track
                Circle()
                    .stroke(SleepWidgetPalette.ringTrack, lineWidth: 4)
                    .frame(width: 50, height: 50)

                // Gradient progress
                Circle()
                    .trim(from: 0, to: person.ringProgress)
                    .stroke(
                        AngularGradient(
                            colors: [
                                person.scoreTint.opacity(0.55),
                                person.scoreTint,
                                person.scoreTint.opacity(0.85)
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: person.scoreTint.opacity(0.5), radius: 4)

                avatar(for: person)

                if isWinner {
                    Text("👑")
                        .font(.system(size: 14))
                        .offset(x: 22, y: -22)
                        .shadow(color: Color(red: 1.0, green: 0.85, blue: 0.3).opacity(0.7), radius: 4)
                }
            }
            .frame(width: 60, height: 60)

            Text("\(person.score)")
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundStyle(person.scoreTint)
                .shadow(color: person.scoreTint.opacity(0.45), radius: 4)
                .padding(.top, 1)

            Text(isMe ? "You" : person.name)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(SleepWidgetPalette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(person.sleepDuration)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(SleepWidgetPalette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Text("\(shorten(person.sleepStart)) → \(shorten(person.wakeTime))")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(SleepWidgetPalette.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            person.scoreTint.opacity(isWinner ? 0.20 : 0.10),
                            person.scoreTint.opacity(0.02)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    person.scoreTint.opacity(isWinner ? 0.45 : 0.20),
                    lineWidth: isWinner ? 1.0 : 0.6
                )
        )
    }

    /// Compact a string like "11:42 PM" → "11:42p" so the bed→wake fits.
    private func shorten(_ time: String) -> String {
        time
            .replacingOccurrences(of: " AM", with: "a")
            .replacingOccurrences(of: " PM", with: "p")
    }

    @ViewBuilder
    private func avatar(for person: FriendSleepSnapshot) -> some View {
        if person.id == "me" {
            MooniMascotView()
                .frame(width: 30, height: 30)
        } else {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                person.scoreTint.opacity(0.35),
                                person.scoreTint.opacity(0.10)
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: 32, height: 32)
                    .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 0.8))
                Text(person.avatarEmoji)
                    .font(.system(size: 20))
            }
        }
    }

    // MARK: Empty slot

    private var inviteCard: some View {
        VStack(spacing: 4) {
            ZStack {
                // Soft glow so the invite still feels alive
                Circle()
                    .fill(SleepWidgetPalette.textTertiary.opacity(0.10))
                    .frame(width: 60, height: 60)
                    .blur(radius: 6)
                Circle()
                    .strokeBorder(
                        SleepWidgetPalette.textTertiary.opacity(0.55),
                        style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])
                    )
                    .frame(width: 50, height: 50)
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(SleepWidgetPalette.textPrimary.opacity(0.7))
            }
            .frame(width: 60, height: 60)

            Text("—")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(SleepWidgetPalette.textTertiary)
                .padding(.top, 1)
            Text("Invite")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(SleepWidgetPalette.textPrimary)
            Text("a friend")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(SleepWidgetPalette.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    SleepWidgetPalette.textTertiary.opacity(0.30),
                    style: StrokeStyle(lineWidth: 0.6, dash: [4, 3])
                )
        )
    }
}
