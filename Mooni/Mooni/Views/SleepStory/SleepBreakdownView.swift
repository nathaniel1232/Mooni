import SwiftUI

/// Shared, deliberately restrained palette for sleep-stage visuals.
/// One hue (accent) at different weights + one neutral — so the whole
/// app reads as "simple", never a rainbow.
enum StagePalette {
    static let deep  = MooniColor.accent
    static let rem   = MooniColor.accent.opacity(0.74)
    static let light = MooniColor.accent.opacity(0.42)
    /// Neutral "awake" stage — adaptive so it stays visible on the cream
    /// morning surface (a faint white vanishes there). Computed, not `let`, so
    /// it re-reads the theme instead of freezing at first access.
    static var awake: Color {
        MooniColor.dyn(light: Color.black.opacity(0.20), dark: MooniColor.hairline)
    }

    static func color(_ name: String) -> Color {
        switch name.lowercased() {
        case "deep":  return deep
        case "rem":   return rem
        case "light": return light
        default:      return awake
        }
    }
}

/// The Sleep Story data, presented as a calm, scannable breakdown.
/// `style` controls how much shows: a tight glance on Home, the full
/// explained report on the Sleep tab. Visual-first, science on tap.
struct SleepBreakdownView: View {
    enum Style { case homeGlance, fullReport }

    let context: SleepStoryContext
    var style: Style = .fullReport

    private var entry: SleepEntry { context.entry }
    private var cards: [SleepStoryCard] { SleepStoryModel.cards(context) }
    private var metricCards: [SleepStoryCard] { cards.filter { $0.kind == .metric } }
    private var verdict: SleepStoryCard? { cards.first { $0.kind == .verdict } }
    private var tonight: SleepStoryCard? { cards.first { $0.kind == .tonight } }

    private var segments: [(name: String, seconds: TimeInterval)] {
        guard let s = entry.stages, s.totalSleep > 0 else { return [] }
        return [
            ("Deep", s.deepSleep),
            ("REM", s.remSleep),
            ("Light", s.lightSleep),
            ("Awake", s.awakeTime)
        ].filter { $0.seconds > 0 }
    }

    var body: some View {
        switch style {
        case .homeGlance:  glance
        case .fullReport:  fullReport
        }
    }

    // MARK: - Home: a single quiet glance card

    private var glance: some View {
        Group {
            if !segments.isEmpty {
                MooniCard(padding: 18, cornerRadius: 24) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("LAST NIGHT")
                            .font(MooniFont.caption(11))
                            .foregroundColor(MooniColor.textMuted)
                            .tracking(1.8)

                        stagesBar(height: 12)

                        HStack(spacing: 0) {
                            ForEach(segments, id: \.name) { seg in
                                stageStat(seg.name, seg.seconds)
                                if seg.name != segments.last?.name {
                                    Divider()
                                        .background(MooniColor.hairline)
                                        .frame(height: 30)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func stageStat(_ name: String, _ seconds: TimeInterval) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 5) {
                Circle().fill(StagePalette.color(name)).frame(width: 6, height: 6)
                Text(name.uppercased())
                    .font(MooniFont.caption(9))
                    .foregroundColor(MooniColor.textMuted)
                    .tracking(0.6)
            }
            Text(durationText(seconds))
                .font(MooniFont.title(15))
                .foregroundColor(MooniColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sleep tab: the full explained report

    private var fullReport: some View {
        VStack(spacing: 16) {
            if !segments.isEmpty {
                MooniCard(padding: 18, cornerRadius: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("SLEEP STAGES")
                            .font(MooniFont.caption(11))
                            .foregroundColor(MooniColor.textMuted)
                            .tracking(1.8)

                        stagesBar(height: 16)

                        VStack(spacing: 0) {
                            ForEach(Array(segments.enumerated()), id: \.element.name) { idx, seg in
                                legendRow(seg.name, seg.seconds)
                                if idx < segments.count - 1 {
                                    Divider()
                                        .background(MooniColor.hairline)
                                        .padding(.vertical, 2)
                                }
                            }
                        }
                    }
                }
            }

            MooniCard(padding: 18, cornerRadius: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("WHAT IT MEANS")
                        .font(MooniFont.caption(11))
                        .foregroundColor(MooniColor.textMuted)
                        .tracking(1.8)
                        .padding(.bottom, 8)

                    ForEach(Array(metricCards.enumerated()), id: \.element.eyebrow) { idx, card in
                        MetricDisclosure(card: card)
                        if idx < metricCards.count - 1 {
                            Divider()
                                .background(MooniColor.hairline)
                                .padding(.vertical, 4)
                        }
                    }
                }
            }

            if let tonight {
                MooniCard(padding: 16, cornerRadius: 22) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "sunrise.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(MooniColor.accentText)
                            .frame(width: 26)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("TONIGHT")
                                .font(MooniFont.caption(10))
                                .foregroundColor(MooniColor.textMuted)
                                .tracking(1.5)
                            Text(tonight.plain)
                                .font(MooniFont.body(14))
                                .foregroundColor(MooniColor.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private func legendRow(_ name: String, _ seconds: TimeInterval) -> some View {
        let total = max(segments.reduce(0) { $0 + $1.seconds }, 1)
        let pct = Int((seconds / total * 100).rounded())
        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(StagePalette.color(name))
                .frame(width: 12, height: 12)
            Text(name)
                .font(MooniFont.body(14))
                .foregroundColor(MooniColor.textPrimary)
            Spacer()
            Text("\(pct)%")
                .font(MooniFont.caption(12))
                .foregroundColor(MooniColor.textMuted)
            Text(durationText(seconds))
                .font(MooniFont.title(14))
                .foregroundColor(MooniColor.textPrimary)
                .frame(minWidth: 64, alignment: .trailing)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Shared stages bar (single hue)

    private func stagesBar(height: CGFloat) -> some View {
        let total = max(segments.reduce(0) { $0 + $1.seconds }, 1)
        return GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(segments, id: \.name) { seg in
                    StagePalette.color(seg.name)
                        .frame(width: max(3, geo.size.width * CGFloat(seg.seconds / total)))
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: height)
    }

    private func durationText(_ seconds: TimeInterval) -> String {
        let m = Int((seconds / 60).rounded())
        let h = m / 60
        let r = m % 60
        if h == 0 { return "\(r)m" }
        return r == 0 ? "\(h)h" : "\(h)h \(r)m"
    }
}

// MARK: - One expandable metric

/// Calm row: name + value always visible; the science is one tap away
/// inside a clean disclosure. No icons fighting for attention.
private struct MetricDisclosure: View {
    let card: SleepStoryCard
    @State private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                Haptics.tap()
                withAnimation(.easeInOut(duration: 0.24)) { open.toggle() }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(card.eyebrow)
                            .font(MooniFont.caption(10))
                            .foregroundColor(MooniColor.textMuted)
                            .tracking(1.4)
                        Text(card.plain)
                            .font(MooniFont.body(14))
                            .foregroundColor(MooniColor.textPrimary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Text(card.bigValue)
                        .font(MooniFont.title(17))
                        .foregroundColor(MooniColor.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Image(systemName: open ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(MooniColor.textMuted)
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 10)

            if open {
                Text(card.science)
                    .font(MooniFont.body(13))
                    .foregroundColor(MooniColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MooniColor.hairline)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.bottom, 10)
                    .transition(.opacity)
            }
        }
    }
}

// MARK: - Context convenience

extension SleepStoryContext {
    @MainActor
    init(appState: AppState, entry: SleepEntry) {
        self.init(
            entry: entry,
            pet: appState.pet,
            petName: appState.pet.name,
            history: appState.entries,
            goalHours: appState.goalHours,
            currentStreak: StreakManager.shared.current,
            longestStreak: StreakManager.shared.longest,
            consistencyDays: appState.bedtimeConsistencyDays,
            leveledUpTo: appState.lastLevelUp
        )
    }
}
