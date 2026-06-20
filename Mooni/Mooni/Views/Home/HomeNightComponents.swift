import SwiftUI

// MARK: - Redesign palette
//
// The home redesign leans into a black / navy / blue / white world (with rare
// warm accents). These tokens are scoped to the new Home so we can iterate on
// the look without disturbing the rest of the app's purple branding yet.

enum NightUI {
    static let accent      = Color(red: 0.23, green: 0.56, blue: 1.00)   // bright blue
    static let accentBright = Color(red: 0.45, green: 0.74, blue: 1.00)
    static let accentDeep  = Color(red: 0.10, green: 0.30, blue: 0.78)

    // Sleep-stage hues — a smooth green → cyan → blue → indigo ramp.
    static let stageAwake = Color(red: 0.43, green: 0.90, blue: 0.66)   // mint green
    static let stageREM   = Color(red: 0.30, green: 0.82, blue: 0.86)   // cyan
    static let stageLight = Color(red: 0.36, green: 0.64, blue: 1.00)   // blue
    static let stageDeep  = Color(red: 0.34, green: 0.40, blue: 0.96)   // indigo
    static let snoreDot   = Color.white

    static let card        = Color(red: 0.07, green: 0.10, blue: 0.20)
    static let cardHi       = Color(red: 0.10, green: 0.14, blue: 0.26)
    static let stroke      = Color.white.opacity(0.07)
    static let track       = Color.white.opacity(0.08)

    /// One calm, near-flat navy surface for the whole screen — no starfield, so
    /// it reads as a single backdrop rather than a static layer behind content.
    static let background = LinearGradient(
        colors: [Color(red: 0.055, green: 0.075, blue: 0.16),
                 Color(red: 0.03, green: 0.04, blue: 0.09)],
        startPoint: .top, endPoint: .bottom)

    static let textPrimary   = Color.white
    static let textSecondary = Color.white.opacity(0.62)
    static let textMuted     = Color.white.opacity(0.38)

    /// Score → colour. Blue for good, warm only for poor nights.
    static func scoreColor(_ score: Int) -> Color {
        switch score {
        case 85...:   return accentBright
        case 70..<85: return accent
        case 50..<70: return Color(red: 1.0, green: 0.78, blue: 0.45)
        default:      return Color(red: 1.0, green: 0.55, blue: 0.55)
        }
    }

    static let curveGradient = LinearGradient(
        colors: [stageAwake, stageREM, stageLight, stageDeep],
        startPoint: .top, endPoint: .bottom)
}

// MARK: - Card container

/// A flat, slightly-raised navy card used across the redesign.
struct NightCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NightUI.card)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(NightUI.stroke, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// MARK: - Score ring

struct ScoreRingView: View {
    let score: Int
    var size: CGFloat = 132
    var animate: Bool = true
    @State private var shown = false

    private var fraction: CGFloat { CGFloat(max(0, min(100, score))) / 100 }
    private var tint: Color { NightUI.scoreColor(score) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(NightUI.track, lineWidth: size * 0.085)
            // Solid tint (no angular gradient) so there's no colour seam / line
            // at the 12-o'clock start of the ring.
            Circle()
                .trim(from: 0, to: shown ? fraction : 0)
                .stroke(tint, style: StrokeStyle(lineWidth: size * 0.085, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.45), radius: 7)
            VStack(spacing: 0) {
                Text("\(score)")
                    .font(MooniFont.custom(size * 0.38, weight: .bold))
                    .foregroundColor(NightUI.textPrimary)
                    .monospacedDigit()
                HStack(spacing: 3) {
                    Text("Score")
                    Image(systemName: "chevron.right").font(MooniFont.custom(size * 0.07, weight: .bold))
                }
                .font(MooniFont.custom(size * 0.11, weight: .medium))
                .foregroundColor(NightUI.textMuted)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            guard animate else { shown = true; return }
            withAnimation(.easeOut(duration: 1.0)) { shown = true }
        }
    }
}

// MARK: - Week-day score circle

struct DayScoreCircle: View {
    let letter: String     // first letter of the weekday, shown inside the ring
    let score: Int?        // nil = untracked; drives the ring fill, no number shown
    let isToday: Bool
    let isSelected: Bool

    private var size: CGFloat { isToday ? 46 : 40 }
    private var ringColor: Color { score.map { NightUI.scoreColor($0) } ?? NightUI.track }

    var body: some View {
        ZStack {
            // Faint base track + the score-proportional ring on top.
            Circle().stroke(NightUI.track, lineWidth: isToday ? 4 : 3)
            if let score {
                Circle()
                    .trim(from: 0, to: CGFloat(max(0, min(100, score))) / 100)
                    .stroke(NightUI.scoreColor(score),
                            style: StrokeStyle(lineWidth: isToday ? 4 : 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            Text(letter)
                .font(MooniFont.custom(isToday ? 16 : 14, weight: isToday ? .semibold : .medium))
                .foregroundColor(score == nil && !isToday ? NightUI.textMuted : NightUI.textPrimary)
        }
        .frame(width: size, height: size)
        .frame(maxWidth: .infinity)
        .opacity(score == nil && !isToday ? 0.6 : 1)
    }
}

// MARK: - Sleep-stage chart (synthesized hypnogram)

/// A stylised hypnogram: a smooth blue curve where the top is "Awake" and the
/// bottom is "Deep". Until real per-night stage timelines / snore timestamps
/// exist, the curve and snore markers are synthesised DETERMINISTICALLY from
/// the night (so the same night always looks the same), shaped by the real
/// stage shares we do have.
struct SleepStageChartView: View {
    let bedtime: Date
    let wakeTime: Date
    let stages: SleepStagesEstimate?
    let score: Int

    private struct Curve { let points: [CGFloat]; let snore: [CGFloat] }

    private var curve: Curve {
        let hours = max(1, wakeTime.timeIntervalSince(bedtime) / 3600)
        let total = stages?.totalSleep ?? 1
        let deepShare = (stages.map { $0.deepSleep } ?? 0) / max(total, 1)
        let awakeShare = (stages.map { $0.awakeTime } ?? 0) / max(total, 1)
        let seed = UInt64(bitPattern: Int64(score &* 7919 &+ Int(bedtime.timeIntervalSince1970)))
        let (p, s) = Self.synth(seed: seed, hours: hours,
                                deepShare: deepShare, awakeShare: awakeShare,
                                snoreCount: NightSynth.snoreCount(score: score, bedtime: bedtime))
        return Curve(points: p, snore: s)
    }

    private let bands: [(String, Color)] = [
        ("Awake", NightUI.stageAwake),
        ("REM",   NightUI.stageREM),
        ("Light", NightUI.stageLight),
        ("Deep",  NightUI.stageDeep)
    ]

    var body: some View {
        let c = curve
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(bands, id: \.0) { name, color in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 9, height: 9)
                        Text(name)
                            .font(MooniFont.custom(11, weight: .medium))
                            .foregroundColor(NightUI.textSecondary)
                    }
                }
            }
            .frame(width: 60, alignment: .leading)
            .padding(.top, 4)

            VStack(spacing: 6) {
                ZStack {
                    ForEach(0..<4) { i in
                        VStack {
                            Rectangle().fill(NightUI.track).frame(height: 1)
                            Spacer()
                        }
                        .offset(y: CGFloat(i) * 30)
                    }
                    NightHypnogramShape(points: c.points, closed: true)
                        .fill(LinearGradient(
                            colors: [NightUI.stageAwake.opacity(0.16), NightUI.stageLight.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom))
                    NightHypnogramShape(points: c.points, closed: false)
                        .stroke(NightUI.curveGradient,
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    SnoreMarkers(points: c.points, fractions: c.snore)
                }
                .frame(height: 120)

                // Hourly time axis, positioned at each clock hour.
                GeometryReader { geo in
                    ForEach(hourTicks(), id: \.frac) { tick in
                        Text(tick.label)
                            .font(MooniFont.custom(9.5, weight: .medium))
                            .foregroundColor(NightUI.textMuted)
                            .fixedSize()
                            .position(x: min(max(geo.size.width * tick.frac, 16),
                                             geo.size.width - 16),
                                      y: 8)
                    }
                }
                .frame(height: 16)
            }
        }
    }

    /// One label at each clock hour between bedtime and wake (e.g. 23:00,
    /// 00:00, 01:00 …), thinned only if too many would overlap.
    private func hourTicks() -> [(frac: CGFloat, label: String)] {
        let span = wakeTime.timeIntervalSince(bedtime)
        guard span > 0 else { return [] }
        let cal = Calendar.current
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        var t = cal.nextDate(after: bedtime.addingTimeInterval(-1),
                             matching: DateComponents(minute: 0),
                             matchingPolicy: .nextTime) ?? bedtime
        var all: [Date] = []
        while t <= wakeTime { all.append(t); t = t.addingTimeInterval(3600) }
        let maxLabels = 9
        let step = max(1, Int(ceil(Double(all.count) / Double(maxLabels))))
        return all.enumerated().compactMap { idx, d in
            idx % step == 0
                ? (CGFloat(d.timeIntervalSince(bedtime) / span), f.string(from: d))
                : nil
        }
    }

    // Deterministic hypnogram generator.
    private static func synth(seed: UInt64, hours: Double,
                              deepShare: Double, awakeShare: Double,
                              snoreCount: Int) -> ([CGFloat], [CGFloat]) {
        var rng = SeededRNG(seed)
        let n = 90
        let cycles = max(3, min(6, Int((hours / 1.5).rounded())))
        var pts = [CGFloat]()
        for i in 0..<n {
            let t = Double(i) / Double(n - 1)
            let phase = -cos(t * Double(cycles) * 2 * .pi)        // dip into deep after onset
            var v = 0.46 + 0.22 * phase + 0.16 * t               // shallower toward morning
            v -= deepShare * 0.14
            v += rng.range(-0.05, 0.05)
            pts.append(CGFloat(min(0.92, max(0.06, v))))
        }
        for i in 0..<4 { pts[i] = CGFloat(0.92 - Double(i) * 0.20) }      // settle in
        for k in 0..<3 { pts[n - 1 - k] = CGFloat(0.86 - Double(k) * 0.12) } // wake
        let spikes = max(1, min(5, Int(awakeShare * 22) + 1))
        for _ in 0..<spikes {
            let idx = Int(rng.range(8, Double(n - 6)))
            pts[idx] = 0.9
            if idx + 1 < n { pts[idx + 1] = 0.78 }
        }
        var snore = [CGFloat]()
        for _ in 0..<snoreCount {
            let idx = Int(rng.range(6, Double(n - 6)))
            snore.append(CGFloat(Double(idx) / Double(n - 1)))
        }
        return (pts, snore.sorted())
    }
}

/// Smooth curve (or closed area) through normalized points (0 = bottom/deep,
/// 1 = top/awake), drawn left→right across the rect.
struct NightHypnogramShape: Shape {
    var points: [CGFloat]
    var closed: Bool

    func path(in r: CGRect) -> Path {
        var p = Path()
        guard points.count > 1 else { return p }
        func pt(_ i: Int) -> CGPoint {
            CGPoint(x: r.minX + r.width * CGFloat(i) / CGFloat(points.count - 1),
                    y: r.minY + r.height * (1 - points[i]))
        }
        p.move(to: pt(0))
        for i in 1..<points.count {
            let prev = pt(i - 1); let cur = pt(i)
            let mid = CGPoint(x: (prev.x + cur.x) / 2, y: (prev.y + cur.y) / 2)
            p.addQuadCurve(to: mid, control: prev)
        }
        p.addLine(to: pt(points.count - 1))
        if closed {
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            p.closeSubpath()
        }
        return p
    }
}

/// Snore dots sitting on the curve.
private struct SnoreMarkers: View {
    let points: [CGFloat]
    let fractions: [CGFloat]

    var body: some View {
        GeometryReader { geo in
            ForEach(Array(fractions.enumerated()), id: \.offset) { _, f in
                let x = geo.size.width * f
                let y = geo.size.height * (1 - yAt(f))
                Circle()
                    .fill(NightUI.card)
                    .overlay(Circle().stroke(Color.white, lineWidth: 1.8))
                    .frame(width: 9, height: 9)
                    .position(x: x, y: y)
            }
        }
    }

    private func yAt(_ f: CGFloat) -> CGFloat {
        guard points.count > 1 else { return 0.5 }
        let pos = f * CGFloat(points.count - 1)
        let i = max(0, min(points.count - 2, Int(pos)))
        let frac = pos - CGFloat(i)
        return points[i] * (1 - frac) + points[i + 1] * frac
    }
}

// MARK: - Stat tile

struct NightStatTile: View {
    let icon: String
    let title: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(MooniFont.custom(11, weight: .semibold))
                Text(title).font(MooniFont.custom(11, weight: .medium))
            }
            .foregroundColor(NightUI.textMuted)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(MooniFont.custom(19, weight: .bold))
                    .foregroundColor(NightUI.textPrimary)
                Text(unit)
                    .font(MooniFont.custom(11, weight: .medium))
                    .foregroundColor(NightUI.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 13)
        .background(NightUI.cardHi)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Seeded RNG

struct SeededRNG {
    private var state: UInt64
    init(_ seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }
    mutating func next() -> UInt64 {
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 2685821657736338717
    }
    mutating func unit() -> Double { Double(next() >> 11) / Double(UInt64(1) << 53) }
    mutating func range(_ a: Double, _ b: Double) -> Double { a + (b - a) * unit() }
}

// MARK: - Derived placeholder stats
//
// Until the voice-capture pipeline is fused into each night, a few stats
// (snore count, sleep-onset latency, awakenings) don't exist on `SleepEntry`.
// These produce stable, plausible values per night so the redesigned cards are
// complete — they get replaced by real data once capture feeds the entry.

enum NightSynth {
    static func seed(score: Int, bedtime: Date) -> UInt64 {
        UInt64(bitPattern: Int64(score &* 7919 &+ Int(bedtime.timeIntervalSince1970)))
    }
    static func snoreCount(score: Int, bedtime: Date) -> Int {
        var r = SeededRNG(seed(score: score, bedtime: bedtime) &+ 11)
        return Int(r.range(3, 7))
    }
    static func snoreMinutes(score: Int, bedtime: Date) -> Int {
        var r = SeededRNG(seed(score: score, bedtime: bedtime) &+ 17)
        return Int(r.range(Double(snoreCount(score: score, bedtime: bedtime)) * 3,
                           Double(snoreCount(score: score, bedtime: bedtime)) * 6).rounded())
    }
    static func asleepAfterMin(score: Int, bedtime: Date) -> Int {
        var r = SeededRNG(seed(score: score, bedtime: bedtime) &+ 23)
        let base = score >= 80 ? 6.0 : (score >= 65 ? 12.0 : 22.0)
        return max(2, Int(r.range(base - 3, base + 8).rounded()))
    }
    static func wokeCount(score: Int, bedtime: Date) -> Int {
        var r = SeededRNG(seed(score: score, bedtime: bedtime) &+ 37)
        return Int(r.range(0, score >= 80 ? 2 : 4))
    }
}
