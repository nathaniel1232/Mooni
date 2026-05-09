import SwiftUI

/// Medium "Sleep Circle" widget — you + up to 2 friends side by side.
/// Each card shows: avatar in a score ring, score number, name, sleep
/// duration, and the bed → wake time range. "SleepOwl" branding sits subtly
/// in the top-right corner.
struct FriendsSleepWidgetView: View {
    let data: FriendsWidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header

            HStack(alignment: .top, spacing: 6) {
                personCard(data.me, isMe: true)
                ForEach(data.friends.prefix(2)) { friend in
                    personCard(friend, isMe: false)
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
        HStack(spacing: 5) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 10, weight: .semibold))
            Text("Sleep Circle")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(0.4)
            Spacer(minLength: 0)
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 10, weight: .semibold))
            Text("SleepOwl")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(0.5)
        }
        .foregroundStyle(SleepWidgetPalette.textSecondary)
    }

    // MARK: Person card

    private func personCard(_ person: FriendSleepSnapshot, isMe: Bool) -> some View {
        VStack(spacing: 3) {
            SleepScoreRing(
                progress: person.ringProgress,
                tint: person.scoreTint,
                lineWidth: 4
            ) {
                avatar(for: person)
            }
            .frame(width: 50, height: 50)

            Text("\(person.score)")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(person.scoreTint)
                .padding(.top, 1)

            Text(isMe ? "You" : person.name)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(SleepWidgetPalette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(person.sleepDuration)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(SleepWidgetPalette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Text("\(shorten(person.sleepStart)) → \(shorten(person.wakeTime))")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(SleepWidgetPalette.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
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
        } else {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                SleepWidgetPalette.mascotBubbleInner,
                                SleepWidgetPalette.mascotBubbleOuter
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 28
                        )
                    )
                    .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1))
                Text(person.avatarEmoji)
                    .font(.system(size: 20))
            }
        }
    }

    // MARK: Empty slot

    private var inviteCard: some View {
        VStack(spacing: 3) {
            ZStack {
                Circle()
                    .strokeBorder(
                        SleepWidgetPalette.textTertiary.opacity(0.55),
                        style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])
                    )
                    .frame(width: 50, height: 50)
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(SleepWidgetPalette.textTertiary)
            }
            Text("—")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(SleepWidgetPalette.textTertiary)
                .padding(.top, 1)
            Text("Invite")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(SleepWidgetPalette.textPrimary)
            Text("a friend")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(SleepWidgetPalette.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}
