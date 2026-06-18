import SwiftUI

// MARK: - Daily sleep facts (novelty hook)

/// A small curated pool of genuinely interesting sleep facts. One is shown
/// per day, rotating deterministically so it feels fresh every morning but
/// never flickers within a day. Pure novelty — a reason to look.
enum SleepFacts {
    static let all: [String] = [
        "Your brain clears toxic waste up to 2× faster while you sleep.",
        "You dream for about 2 hours every night — most of it forgotten within minutes.",
        "A single all-nighter can reduce next-day focus as much as being legally drunk.",
        "REM sleep is when your brain files yesterday into long-term memory.",
        "Body temperature drops ~1°C as you fall asleep — it's part of the trigger.",
        "Deep sleep releases most of your day's growth hormone.",
        "Your tallest moment of the day is right after waking — discs decompress overnight.",
        "Elite athletes who sleep 8–9h see measurably faster reaction times.",
        "Caffeine has a ~5–6 hour half-life — a 3pm coffee is still half-active at 9pm.",
        "Consistency matters more than duration: same bedtime beats a random long night.",
        "You cycle through sleep stages roughly every 90 minutes, 4–6 times a night.",
        "Dreams are most vivid in the last third of the night — that's REM-heavy.",
        "Even one bad night raises next-day sugar cravings measurably.",
        "A cool, dark room can add meaningful deep sleep without any effort.",
        "Morning sunlight within an hour of waking anchors your whole sleep clock."
    ]

    static var today: String {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return all[day % all.count]
    }
}

// MARK: - Hook model

/// The single most exciting true thing about last night, plus two quick
/// comparison numbers. This is the "why open the app" payload.
private struct MorningHook {
    let icon: String
    let headline: String
    let sub: String
    let tint: Color

    /// Better-than-N%-of-your-nights, average delta, etc.
    let percentile: Int?
    let avgDeltaMinutes: Int?
}

private enum MorningHookBuilder {
    static func build(_ ctx: SleepStoryContext,
                      streakCurrent: Int,
                      streakLongest: Int) -> MorningHook {
        let entry = ctx.entry
        let past = ctx.past

        // Percentile: how many past nights did this beat.
        var percentile: Int? = nil
        if past.count >= 4 {
            let beat = past.filter { entry.score > $0.score }.count
            percentile = Int((Double(beat) / Double(past.count) * 100).rounded())
        }

        // Duration vs personal average.
        var avgDeltaMinutes: Int? = nil
        if past.count >= 3 {
            let avgSec = past.map(\.totalSleepDuration).reduce(0, +) / Double(past.count)
            avgDeltaMinutes = Int(((entry.totalSleepDuration - avgSec) / 60).rounded())
        }

        let great = MooniColor.success
        let good = MooniColor.accent
        let soft = MooniColor.warning

        if ctx.newLongestStreak {
            return .init(icon: "flame.fill",
                         headline: "Longest streak ever",
                         sub: "\(streakCurrent) nights in a row — don't break it tonight.",
                         tint: soft, percentile: percentile, avgDeltaMinutes: avgDeltaMinutes)
        }
        if ctx.isPersonalBest {
            return .init(icon: "trophy.fill",
                         headline: "Best night ever",
                         sub: "Score \(entry.score) — your highest yet. Whatever you did, repeat it.",
                         tint: great, percentile: percentile, avgDeltaMinutes: avgDeltaMinutes)
        }
        if let n = ctx.bestInDays, n >= 7 {
            return .init(icon: "trophy.fill",
                         headline: "Best sleep in \(n) days",
                         sub: "You haven't felt this rested in over a week.",
                         tint: great, percentile: percentile, avgDeltaMinutes: avgDeltaMinutes)
        }
        if let p = percentile, p >= 80 {
            return .init(icon: "star.fill",
                         headline: "Top \(max(1, 100 - p))% night",
                         sub: "Better than \(p)% of your tracked nights.",
                         tint: great, percentile: percentile, avgDeltaMinutes: avgDeltaMinutes)
        }
        if let d = ctx.scoreDelta, d >= 8 {
            return .init(icon: "chart.line.uptrend.xyaxis",
                         headline: "+\(d) better than yesterday",
                         sub: "Momentum is building — keep the rhythm.",
                         tint: good, percentile: percentile, avgDeltaMinutes: avgDeltaMinutes)
        }
        if let s = entry.stages, s.totalSleep > 0,
           s.deepSleep / s.totalSleep >= 0.20 {
            let m = Int(s.deepSleep / 60)
            return .init(icon: "bolt.heart.fill",
                         headline: "Deep sleep on point",
                         sub: "\(m) min of physical recovery last night.",
                         tint: great, percentile: percentile, avgDeltaMinutes: avgDeltaMinutes)
        }
        if streakCurrent >= 3 {
            return .init(icon: "flame.fill",
                         headline: "\(streakCurrent)-night streak",
                         sub: "Personal best is \(max(streakLongest, streakCurrent)). Keep it alive tonight.",
                         tint: soft, percentile: percentile, avgDeltaMinutes: avgDeltaMinutes)
        }
        if entry.score >= 70 {
            return .init(icon: "checkmark.seal.fill",
                         headline: "Solid night",
                         sub: "A consistent bedtime tonight pushes this into top territory.",
                         tint: good, percentile: percentile, avgDeltaMinutes: avgDeltaMinutes)
        }
        return .init(icon: "arrow.up.forward",
                     headline: "Fresh start today",
                     sub: "One good night tonight starts a streak worth protecting.",
                     tint: soft, percentile: percentile, avgDeltaMinutes: avgDeltaMinutes)
    }
}

// MARK: - The card

/// Punchy, colourful, mostly-numbers card that gives the user a reason to
/// open the app the second they wake. One celebratory headline, two quick
/// comparison stats, one rotating fact. Colour here is meaningful — it
/// signals how good the night was.
struct MorningHookCard: View {
    let context: SleepStoryContext
    var streakCurrent: Int = 0
    var streakLongest: Int = 0

    private var hook: MorningHook {
        MorningHookBuilder.build(context,
                                 streakCurrent: streakCurrent,
                                 streakLongest: streakLongest)
    }

    var body: some View {
        let h = hook
        MooniCard(padding: 18, cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 14) {
                // Celebratory headline — colour = how good the night was.
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(h.tint.opacity(0.18)).frame(width: 44, height: 44)
                        Image(systemName: h.icon)
                            .font(.system(size: 19, weight: .bold))
                            .foregroundColor(h.tint)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(h.headline)
                            .font(MooniFont.title(18))
                            .foregroundColor(MooniColor.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(h.sub)
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }

                if h.percentile != nil || h.avgDeltaMinutes != nil {
                    HStack(spacing: 10) {
                        if let p = h.percentile {
                            hookStat(value: "\(p)%",
                                     label: "beat your nights",
                                     tint: p >= 60 ? MooniColor.success : MooniColor.accent)
                        }
                        if let d = h.avgDeltaMinutes {
                            let up = d >= 0
                            hookStat(
                                value: "\(up ? "+" : "−")\(abs(d) / 60 > 0 ? "\(abs(d)/60)h " : "")\(abs(d) % 60)m",
                                label: "vs your average",
                                tint: up ? MooniColor.success : MooniColor.warning)
                        }
                    }
                }

                Divider().background(MooniColor.hairline)

                HStack(alignment: .top, spacing: 8) {
                    Text("💤")
                        .font(.system(size: 14))
                    Text(SleepFacts.today)
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func hookStat(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(MooniFont.title(17))
                .foregroundColor(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label.uppercased())
                .font(MooniFont.caption(9))
                .foregroundColor(MooniColor.textMuted)
                .tracking(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Sleep tab records strip

/// Four quiet milestone tiles — totals & records. Identity / progress hook,
/// presented as pure numbers. Only "best score" carries a meaningful colour.
struct SleepStatsStrip: View {
    let context: SleepStoryContext

    private var nights: Int { context.history.count }
    private var totalHours: Int {
        Int((context.history.map(\.totalSleepDuration).reduce(0, +) / 3600).rounded())
    }
    private var avgText: String {
        guard !context.history.isEmpty else { return "—" }
        let avg = context.history.map(\.totalSleepDuration).reduce(0, +)
            / Double(context.history.count)
        let m = Int(avg / 60)
        return "\(m / 60)h \(String(format: "%02d", m % 60))m"
    }
    private var bestScore: Int { context.history.map(\.score).max() ?? context.entry.score }
    private var bestTint: Color {
        switch bestScore {
        case 85...:   return MooniColor.success
        case 70..<85: return MooniColor.accent
        default:      return MooniColor.warning
        }
    }

    var body: some View {
        MooniCard(padding: 16, cornerRadius: 22) {
            HStack(spacing: 0) {
                tile("\(nights)", "NIGHTS", MooniColor.textPrimary)
                sep
                tile("\(totalHours)h", "TRACKED", MooniColor.textPrimary)
                sep
                tile(avgText, "AVG", MooniColor.textPrimary)
                sep
                tile("\(bestScore)", "BEST", bestTint)
            }
        }
    }

    private var sep: some View {
        Divider().background(MooniColor.hairline).frame(height: 34)
    }

    private func tile(_ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(MooniFont.title(18))
                .foregroundColor(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(MooniFont.caption(9))
                .foregroundColor(MooniColor.textMuted)
                .tracking(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}
