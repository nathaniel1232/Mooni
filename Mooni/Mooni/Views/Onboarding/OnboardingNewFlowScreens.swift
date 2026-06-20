import SwiftUI
import UIKit

// Placeholder screens for the redesigned onboarding flow.
//
// Each screen here is intentionally minimal — clean white-on-dark layout,
// a single visual or sentence, and the footer's white CTA handles advancing.
// These get the new flow shippable end-to-end. Phase 3 onward in
// ONBOARDING_REDESIGN_PLAN.md replaces each placeholder with its full
// animated treatment.

// MARK: - Shared building blocks

/// A clean stack used by every new flow screen: optional eyebrow / single
/// big title / one supporting line. No cards, no rainbow tinting.
private struct OBStack<Content: View>: View {
    var eyebrow: String? = nil
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var hero: Content

    var body: some View {
        VStack(spacing: 26) {
            Spacer(minLength: 4)
            hero
            VStack(spacing: 12) {
                if let eyebrow {
                    Text(eyebrow.uppercased())
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(2)
                        .foregroundColor(.white.opacity(0.55))
                }
                Text(title)
                    .font(MooniFont.display(28))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                if let subtitle {
                    Text(subtitle)
                        .font(MooniFont.body(15))
                        .foregroundColor(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 8)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - lifeTimeline — Cal-AI–style projected sleep score
//
// Hand-rolled minimalist chart. Two curves: "Without Mooni" (flat near 50)
// and "With Mooni" (rising 48 → 88). Only TWO endpoint labels — Day 1 on
// the left, Week 4 on the right. No interior week ticks, no floating
// annotations, no busy gridlines. Inspired by Cal AI's weight-loss curve:
// one card, one curve, one promise.

struct LifeTimelineScreen: View {
    /// The user's chosen goal, quoted back so the projected outcome reads as
    /// *their* concrete target rather than a generic curve.
    var sleepGoal: SleepGoal? = nil

    /// 28-day projected scores: a smooth, confident ease-out climb 48 → 88.
    /// Deliberately monotonic (no noise) — the old jagged data read as messy;
    /// a clean curve reads as premium and trustworthy.
    private let withMooni: [Double] = [
        48, 50, 53, 56, 59, 62, 65,
        67, 70, 72, 74, 76, 78, 79,
        81, 82, 83, 84, 85, 85, 86,
        86, 87, 87, 87, 88, 88, 88
    ]
    /// "Without" drifts gently downward — staying stuck, even slipping a little.
    private let withoutMooni: [Double] = [
        48, 48, 47, 47, 47, 46, 47,
        46, 46, 46, 45, 46, 45, 45,
        45, 45, 44, 45, 45, 44, 45,
        44, 44, 45, 44, 44, 45, 44
    ]

    /// 0..1 line-draw progress. Drives both curves simultaneously.
    @State private var draw: CGFloat = 0
    /// Card fades in slightly AFTER the title so the headline lands first.
    @State private var cardVisible: Bool = false
    /// Score number above the chart climbs along the head of the With-Mooni curve.
    @State private var currentScore: Int = 48
    /// "+40" payoff badge that pops at the curve terminus once drawn.
    @State private var deltaVisible: Bool = false

    /// White-to-tint gradient for the With-Mooni curve. Matches the rest
    /// of the onboarding palette.
    private var mooniTint: Color {
        MooniColor.accentSoft
    }
    /// Bright blue used for the hero line glow + payoff pill (matches Home).
    private var heroAccent: Color {
        MooniColor.accent
    }

    private let chartYMin: Double = 40
    private let chartYMax: Double = 95

    /// Quote the goal back if we have one, otherwise the generic line.
    private var closingCaption: String {
        if let goal = sleepGoal {
            return "On track to \(goal.title.lowercased()) by week 4."
        }
        return "Most people see real change by week 4."
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 4)

            VStack(spacing: 10) {
                Text("Four weeks.\nA whole different sleep.")
                    .font(MooniFont.display(26))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(currentScore)")
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.4), value: currentScore)
                    Text("sleep score")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .tracking(1.5)
                        .foregroundColor(.white.opacity(0.55))
                        .textCase(.uppercase)
                }

                if let goal = sleepGoal {
                    HStack(spacing: 6) {
                        Image(systemName: goal.icon)
                            .font(.system(size: 11, weight: .bold))
                        Text(goal.title)
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                }
            }

            chartCard
                .padding(.horizontal, 8)
                .opacity(cardVisible ? 1 : 0)
                .scaleEffect(cardVisible ? 1 : 0.96)
                .offset(y: cardVisible ? 0 : 12)

            Text(closingCaption)
                .font(MooniFont.body(13))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(cardVisible ? 1 : 0)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        // .task instead of .onAppear so the animation steps await cleanly
        // through Task.sleep rather than racing inside DispatchQueue.async
        // blocks. The .onAppear version sometimes completed before the
        // screen transition finished, leaving the chart fully drawn with
        // no visible motion (the symptom reported on iPad).
        .task { await play() }
    }

    // MARK: Chart card

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                // Mooni legend chip — single dot + label, like Cal AI.
                HStack(spacing: 5) {
                    Circle()
                        .fill(.white)
                        .frame(width: 7, height: 7)
                    Text("With SleepOwl")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.10)))

                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.white.opacity(0.35))
                        .frame(width: 7, height: 7)
                    Text("Without")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.04)))

                Spacer(minLength: 0)
            }

            // The chart itself. Curves are animatable Shapes whose
            // `animatableData` is the draw progress, so they genuinely draw on
            // frame-by-frame. The endpoint dots ride the same inset-mapped
            // points so they sit exactly on each curve's ends.
            GeometryReader { geo in
                let plot = geo.size
                ZStack {
                    // Faint horizontal gridlines for depth — behind everything.
                    ForEach(1..<4) { i in
                        Rectangle()
                            .fill(Color.white.opacity(0.05))
                            .frame(height: 1)
                            .position(x: plot.width / 2,
                                      y: plot.height * CGFloat(i) / 4)
                    }

                    // "Without SleepOwl" — faint dashed line, gently slipping.
                    ProjectedCurveShape(values: withoutMooni, yMin: chartYMin,
                                        yMax: chartYMax, closed: false, progress: draw)
                        .stroke(
                            Color.white.opacity(0.22),
                            style: StrokeStyle(lineWidth: 2,
                                               lineCap: .round,
                                               lineJoin: .round,
                                               dash: [2, 5])
                        )
                    endpointDot(values: withoutMooni, at: withoutMooni.count - 1,
                                in: plot,
                                color: Color.white.opacity(0.35),
                                visible: draw > 0.985)

                    // "With SleepOwl" — hero area fill (richer, two-stop).
                    ProjectedCurveShape(values: withMooni, yMin: chartYMin,
                                        yMax: chartYMax, closed: true, progress: draw)
                        .fill(
                            LinearGradient(
                                colors: [
                                    heroAccent.opacity(0.34),
                                    heroAccent.opacity(0.05),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    // Hero line — saturated gradient + glow.
                    ProjectedCurveShape(values: withMooni, yMin: chartYMin,
                                        yMax: chartYMax, closed: false, progress: draw)
                        .stroke(
                            LinearGradient(
                                colors: [heroAccent, mooniTint, .white],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 3.5,
                                               lineCap: .round,
                                               lineJoin: .round)
                        )
                        .shadow(color: heroAccent.opacity(0.65), radius: 8, y: 1)

                    endpointDot(values: withMooni, at: 0, in: plot,
                                color: .white,
                                visible: draw > 0.01)

                    // Glowing head dot rides the tip of the hero curve as it draws.
                    CurveHeadDotShape(values: withMooni, yMin: chartYMin,
                                      yMax: chartYMax, progress: draw, radius: 6)
                        .fill(Color.white)
                        .shadow(color: heroAccent.opacity(0.9), radius: 9)
                        .opacity(draw > 0.01 ? 1 : 0)

                    // "+40" payoff pill — accent gradient + up-arrow, glowing.
                    let endPt = point(at: withMooni.count - 1,
                                      value: withMooni[withMooni.count - 1],
                                      in: plot)
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9, weight: .black))
                        Text("+40")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(
                            LinearGradient(colors: [heroAccent, mooniTint],
                                           startPoint: .leading, endPoint: .trailing))
                    )
                    .shadow(color: heroAccent.opacity(0.6), radius: 8, y: 2)
                    .position(x: min(endPt.x - 2, plot.width - 30),
                              y: max(endPt.y - 26, 14))
                    .opacity(deltaVisible ? 1 : 0)
                    .scaleEffect(deltaVisible ? 1 : 0.6,
                                 anchor: .bottomTrailing)
                }
            }
            .frame(height: 188)

            // Two endpoint labels — the ONLY x-axis labels in the chart.
            HStack {
                Text("Day 1")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                Spacer(minLength: 0)
                Text("Week 4")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: Curve geometry

    /// Maps a sample index + value to a plot-space point. Delegates to the
    /// shared `ChartGeometry` so the endpoint dots land exactly on the curves
    /// drawn by `ProjectedCurveShape`.
    private func point(at i: Int, value: Double, in size: CGSize) -> CGPoint {
        ChartGeometry.point(index: i, value: value, count: withMooni.count,
                            yMin: chartYMin, yMax: chartYMax, in: size)
    }

    /// A filled dot at the given sample index — used for the two endpoints
    /// only. `halo` adds a soft glow ring for the With-Mooni terminus.
    @ViewBuilder
    private func endpointDot(values: [Double],
                             at index: Int,
                             in size: CGSize,
                             color: Color,
                             visible: Bool,
                             halo: Bool = false) -> some View {
        let pt = point(at: index, value: values[index], in: size)
        ZStack {
            if halo {
                Circle()
                    .stroke(color.opacity(0.35), lineWidth: 5)
                    .frame(width: 18, height: 18)
            }
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .shadow(color: color.opacity(halo ? 0.6 : 0), radius: 6)
        }
        .position(pt)
        .opacity(visible ? 1 : 0)
        .animation(.easeOut(duration: 0.25), value: visible)
    }

    // MARK: Animation

    @MainActor
    private func play() async {
        // Reset every entry so re-navigating to the screen replays.
        currentScore = Int(withMooni[0])
        cardVisible = false
        deltaVisible = false
        draw = 0

        // 1) Wait out the onboarding screen transition (~0.35s) plus a
        //    beat so the title lands first.
        try? await Task.sleep(nanoseconds: 550_000_000)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
            cardVisible = true
        }

        // 2) Beat, then draw the curve.
        try? await Task.sleep(nanoseconds: 250_000_000)
        let drawDuration: Double = 1.8
        withAnimation(.easeOut(duration: drawDuration)) {
            draw = 1.0
        }

        // 3) Tick the score number alongside the curve. The tick index runs
        //    through the same easeOut curve as the draw animation so the
        //    number stays in step with the head of the line instead of
        //    racing ahead of it early and stalling at the end.
        let steps = 40
        let stepNanos = UInt64(drawDuration / Double(steps) * 1_000_000_000)
        var lastScore = currentScore
        for s in 0...steps {
            let t = Double(s) / Double(steps)
            let eased = 1 - pow(1 - t, 2)
            let idx = Int(round(eased * Double(withMooni.count - 1)))
            currentScore = Int(withMooni[idx])
            if currentScore != lastScore, currentScore % 10 == 0 {
                Haptics.tick()
            }
            lastScore = currentScore
            if s < steps {
                try? await Task.sleep(nanoseconds: stepNanos)
            }
        }

        // 4) Land the payoff badge.
        withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
            deltaVisible = true
        }
        Haptics.success()
    }
}

/// Companion to `ProjectedCurveShape`: a filled dot whose center is the head
/// of the partially-drawn curve. Because its `animatableData` is the same
/// draw progress, SwiftUI interpolates it on the exact same timeline as the
/// line itself — the dot leads the stroke pixel-for-pixel.
private struct CurveHeadDotShape: Shape {
    let values: [Double]
    let yMin: Double
    let yMax: Double
    var progress: CGFloat
    var radius: CGFloat = 5

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard values.count > 1 else { return Path() }
        let last = values.count - 1
        let span = CGFloat(last) * max(0, min(1, progress))
        let whole = Int(span)
        let frac = span - CGFloat(whole)

        func pt(_ i: Int) -> CGPoint {
            ChartGeometry.point(index: i, value: values[i], count: values.count,
                                yMin: yMin, yMax: yMax, in: rect.size)
        }

        var head = pt(min(whole, last))
        if whole < last, frac > 0 {
            let a = pt(whole)
            let b = pt(whole + 1)
            head = CGPoint(x: a.x + (b.x - a.x) * frac,
                           y: a.y + (b.y - a.y) * frac)
        }
        return Path(ellipseIn: CGRect(x: head.x - radius, y: head.y - radius,
                                      width: radius * 2, height: radius * 2))
    }
}

/// Shared point mapping + edge insets for the projected-sleep chart so the
/// animatable curve and the endpoint dots agree on geometry, and the rounded
/// line caps / dots never clip against the plot edges.
private enum ChartGeometry {
    static let xInset: CGFloat = 8
    static let topInset: CGFloat = 12
    static let bottomInset: CGFloat = 6

    static func point(index i: Int, value v: Double, count: Int,
                      yMin: Double, yMax: Double, in size: CGSize) -> CGPoint {
        let xRatio = count > 1 ? CGFloat(i) / CGFloat(count - 1) : 0
        let x = xInset + xRatio * (size.width - xInset * 2)
        let yRatio = 1 - CGFloat((v - yMin) / (yMax - yMin))
        let clamped = max(0, min(1, yRatio))
        let y = topInset + clamped * (size.height - topInset - bottomInset)
        return CGPoint(x: x, y: y)
    }
}

/// Animatable draw-on curve for the projected-sleep chart. `animatableData` is
/// the draw progress, so SwiftUI interpolates the head of the line every frame
/// while `draw` animates 0 → 1. (The previous version returned a raw `Path`
/// built from a @State value; Paths can't be interpolated, so `draw` snapped to
/// 1 and the whole chart appeared already-drawn with no motion — the reported
/// "chart doesn't animate / shows too early" bug. This shape is the fix.)
private struct ProjectedCurveShape: Shape {
    let values: [Double]
    let yMin: Double
    let yMax: Double
    /// true = close down to the baseline (an area fill); false = line only.
    let closed: Bool
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        Path { p in
            guard values.count > 1 else { return }
            let last = values.count - 1
            let span = CGFloat(last) * max(0, min(1, progress))
            let whole = Int(span)
            let frac = span - CGFloat(whole)

            func pt(_ i: Int) -> CGPoint {
                ChartGeometry.point(index: i, value: values[i], count: values.count,
                                    yMin: yMin, yMax: yMax, in: rect.size)
            }

            var pts: [CGPoint] = (0...whole).map { pt($0) }
            // Extend the head a fractional step toward the next sample so the
            // line grows continuously instead of snapping point-to-point.
            if whole < last, frac > 0 {
                let a = pt(whole)
                let b = pt(whole + 1)
                pts.append(CGPoint(x: a.x + (b.x - a.x) * frac,
                                   y: a.y + (b.y - a.y) * frac))
            }
            guard let first = pts.first else { return }

            if closed {
                p.move(to: CGPoint(x: first.x, y: rect.maxY))
                p.addLine(to: first)
            } else {
                p.move(to: first)
            }

            if pts.count > 1 {
                for i in 1..<pts.count {
                    let prev = pts[i - 1]
                    let curr = pts[i]
                    let mid = CGPoint(x: (prev.x + curr.x) / 2,
                                      y: (prev.y + curr.y) / 2)
                    p.addQuadCurve(to: mid, control: prev)
                    if i == pts.count - 1 {
                        p.addQuadCurve(to: curr, control: curr)
                    }
                }
            }

            if closed, let tail = pts.last {
                p.addLine(to: CGPoint(x: tail.x, y: rect.maxY))
                p.closeSubpath()
            }
        }
    }
}

// MARK: - trackingCompare — showcase UI (manual journal → live hypnogram)

struct TrackingCompareScreen: View {
    /// Cross-fade between the two cards. The "MANUAL" card crumples into the
    /// background while the live hypnogram swells forward.
    @State private var phase: CGFloat = 0
    @State private var hypnoFill: CGFloat = 0
    @State private var scoreVisible: Bool = false
    @State private var metricsVisible: Int = 0
    /// Once the live-report animation finishes we lay the cards out side by
    /// side so the user can actually *compare* the two. Driven from `play()`.
    @State private var sideBySide: Bool = false

    /// Bound to the parent OnboardingView's `trackingCompareDone`. We flip
    /// it true at the end of `play()` so the footer Continue can enable —
    /// the user can't accidentally skip past the reveal.
    @Binding var animationDone: Bool

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 4)

            VStack(spacing: 8) {
                Text(sideBySide
                     ? "Your sleep, finally measured."
                     : "Your sleep, finally measured.")
                    .font(MooniFont.display(26))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                Text(sideBySide
                     ? "Left: what you'd write down. Right: what we'd actually measure."
                     : "One is a guess. The other is your sleep, measured.")
                    .font(MooniFont.body(13))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Two layouts: pre-animation it's a single-card cross-fade
            // (journal → live). Once we reach `sideBySide`, switch to a
            // shrunken HStack with both cards visible at the same time.
            ZStack {
                if !sideBySide {
                    ZStack {
                        manualJournal(compact: false)
                            .opacity(1 - Double(phase))
                            .scaleEffect(1 - 0.06 * phase)
                            .rotationEffect(.degrees(Double(phase) * -4))
                            .offset(x: -phase * 18, y: phase * 8)

                        liveReport(compact: false)
                            .opacity(Double(phase))
                            .scaleEffect(0.92 + 0.08 * phase)
                            .offset(y: (1 - phase) * 16)
                    }
                    .transition(.opacity)
                } else {
                    // Side-by-side: the cards now have compact internals and
                    // break out to ~8pt screen margins with a wider gutter so
                    // neither column feels crammed.
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 8) {
                            sideBySideHeader(label: "BEFORE",
                                             tint: Color.white.opacity(0.55))
                            manualJournal(compact: true)
                                .frame(maxWidth: .infinity)
                        }
                        VStack(spacing: 8) {
                            sideBySideHeader(label: "WITH SLEEPOWL",
                                             tint: MooniColor.accentSoft)
                            liveReport(compact: true)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, -12)
                    .transition(.opacity)
                }
            }
            .frame(height: 384)
            .padding(.horizontal, 4)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .onAppear { play() }
    }

    private func sideBySideHeader(label: String, tint: Color) -> some View {
        Text(label)
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .tracking(1.4)
            .foregroundColor(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(tint.opacity(0.14))
            )
            .overlay(
                Capsule().stroke(tint.opacity(0.35), lineWidth: 0.6)
            )
    }

    // MARK: Manual journal card

    private func manualJournal(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 12) {
            HStack {
                Text("MY SLEEP JOURNAL")
                    .font(.system(size: compact ? 9 : 10, weight: .heavy, design: .rounded))
                    .tracking(compact ? 1.2 : 2)
                    .foregroundColor(.black.opacity(0.55))
                Spacer(minLength: 0)
                if !compact {
                    Text("LAST WEEK")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .tracking(1.2)
                        .foregroundColor(.black.opacity(0.4))
                }
            }

            VStack(alignment: .leading, spacing: compact ? 6 : 9) {
                journalLine("Mon", "11pm? woke at 6, felt rough", compact: compact)
                journalLine("Tue", "forgot to log 😬", compact: compact)
                journalLine("Wed", "slept ok – maybe 7h?", compact: compact)
                journalLine("Thu", "couldn't sleep. 1am? 5h?", compact: compact)
                journalLine("Fri", "—", compact: compact)
                journalLine("Sat", "long night, can't recall", compact: compact)
                journalLine("Sun", "skipped", compact: compact)
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: compact ? 11 : 13))
                    .foregroundColor(.black.opacity(0.55))
                Text(compact ? "3 of 7 logged" : "3 of 7 nights logged. None measured.")
                    .font(.system(size: compact ? 10 : 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.black.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
        .padding(compact ? 13 : 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            // Cream paper with subtle ruled lines.
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0.97, green: 0.94, blue: 0.86))
                VStack(spacing: 24) {
                    ForEach(0..<8, id: \.self) { _ in
                        Rectangle().fill(Color.black.opacity(0.05)).frame(height: 0.5)
                    }
                }
                .padding(.top, 60)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 18, y: 10)
    }

    private func journalLine(_ day: String, _ text: String,
                             compact: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: compact ? 6 : 8) {
            Text(day)
                .font(.system(size: compact ? 11 : 12, weight: .heavy, design: .serif))
                .foregroundColor(.black.opacity(0.7))
                .frame(width: compact ? 26 : 32, alignment: .leading)
            Text(text)
                .font(.system(size: compact ? 11 : 13, weight: .regular, design: .serif))
                .italic()
                .foregroundColor(.black.opacity(0.65))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }

    // MARK: Live Mooni report card

    private func liveReport(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.white)
                    Text("SleepOwl")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
                Spacer(minLength: 0)
                Text("LAST NIGHT")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(1.5)
                    .foregroundColor(.white.opacity(0.5))
            }

            // Big sleep score reveal — copies the home ring style.
            HStack(alignment: .center, spacing: compact ? 10 : 16) {
                let ring: CGFloat = compact ? 58 : 78
                let lw: CGFloat = compact ? 6 : 7
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: lw)
                        .frame(width: ring, height: ring)
                    Circle()
                        .trim(from: 0, to: 0.87 * hypnoFill)
                        .stroke(Color.white,
                                style: StrokeStyle(lineWidth: lw, lineCap: .round))
                        .frame(width: ring, height: ring)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: -2) {
                        Text("87")
                            .font(.system(size: compact ? 20 : 26, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .opacity(scoreVisible ? 1 : 0)
                        Text("score")
                            .font(.system(size: compact ? 8 : 9, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.55))
                            .opacity(scoreVisible ? 1 : 0)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("7h 38m")
                        .font(.system(size: compact ? 16 : 22, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(compact ? "11:42p→7:20a" : "11:42p → 7:20a")
                        .font(.system(size: compact ? 10 : 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
            }

            // Animated hypnogram — the wow visual.
            hypnogram
                .frame(height: compact ? 44 : 60)

            // Stage breakdown bars.
            VStack(spacing: compact ? 6 : 8) {
                stageRow("Deep",  duration: "1h 24m", weight: 0.40,
                         color: NightUI.stageDeep,
                         visible: metricsVisible >= 1)
                stageRow("REM",   duration: "1h 48m", weight: 0.50,
                         color: NightUI.stageREM,
                         visible: metricsVisible >= 2)
                stageRow("Light", duration: "3h 56m", weight: 1.00,
                         color: NightUI.stageLight,
                         visible: metricsVisible >= 3)
                stageRow("Awake", duration: "10m",    weight: 0.08,
                         color: NightUI.stageAwake,
                         visible: metricsVisible >= 4)
            }
        }
        .padding(compact ? 13 : 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.13, blue: 0.28),
                    Color(red: 0.08, green: 0.08, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 22, y: 12)
    }

    private func stageRow(_ label: String, duration: String, weight: CGFloat,
                          color: Color, visible: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(1)
                    .foregroundColor(.white.opacity(0.65))
                Spacer()
                Text(duration)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10))
                    Capsule()
                        .fill(color)
                        .frame(width: visible ? geo.size.width * weight : 0)
                }
            }
            .frame(height: 5)
        }
        .opacity(visible ? 1 : 0.2)
    }

    // Mini-hypnogram: 4 stages drawn as a stepped line over 7 hours.
    private var hypnogram: some View {
        GeometryReader { geo in
            // Y positions per stage (0 = Awake top, 3 = Deep bottom).
            let stages: [Int] = [
                3,3,2,2,1,2,3,2,1,1,2,3,3,2,1,0,1,2,2,3,2,1,2,2,2,3,2,1,1,0
            ]
            let stepW = geo.size.width / CGFloat(stages.count - 1)
            let rowH = geo.size.height / 3
            let colorFor: (Int) -> Color = { y in
                switch y {
                case 0:  return NightUI.stageAwake
                case 1:  return NightUI.stageREM
                case 2:  return NightUI.stageLight
                default: return NightUI.stageDeep
                }
            }
            ZStack {
                // Faint stage grid.
                ForEach(0..<4, id: \.self) { i in
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 1)
                        .offset(y: rowH * CGFloat(i) - geo.size.height / 2 + rowH / 2)
                }

                // Drawn line — clipped to current animation progress.
                Path { p in
                    p.move(to: CGPoint(x: 0, y: CGFloat(stages[0]) * rowH))
                    for i in 1..<stages.count {
                        let x = stepW * CGFloat(i)
                        let prevY = CGFloat(stages[i - 1]) * rowH
                        let y = CGFloat(stages[i]) * rowH
                        if prevY != y {
                            p.addLine(to: CGPoint(x: x, y: prevY))
                        }
                        p.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                .trim(from: 0, to: hypnoFill)
                .stroke(
                    LinearGradient(
                        colors: [
                            colorFor(3), colorFor(2), colorFor(1), colorFor(0)
                        ],
                        startPoint: .bottom, endPoint: .top
                    ),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                )
            }
        }
    }

    // MARK: Animation

    private func play() {
        // Reset state in case the screen is re-entered via Back navigation.
        animationDone = false

        // Stage 1: hold on the messy journal so the user can read it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeInOut(duration: 0.9)) { phase = 1 }
            Haptics.tick()
        }
        // Stage 2: draw the hypnogram.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
            withAnimation(.easeInOut(duration: 1.6)) { hypnoFill = 1 }
        }
        // Stage 3: score stamp in.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                scoreVisible = true
            }
            Haptics.success()
        }
        // Stage 4: stage breakdown bars cascade.
        for i in 1...4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.7 + Double(i) * 0.15) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    metricsVisible = i
                }
                Haptics.tick()
            }
        }

        // Stage 5: snap into side-by-side comparison so the user can
        // actually *see* both — the messy notebook vs. the measured night.
        // This is also when we unlock the footer Continue button.
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.7) {
            withAnimation(.easeInOut(duration: 0.6)) {
                sideBySide = true
            }
            animationDone = true
            Haptics.tick()
        }
    }
}

// MARK: - targetReachable — quotes the user's actual goal back

struct TargetReachableScreen: View {
    let sleepGoal: SleepGoal?

    @State private var filled: Int = 0
    @State private var percentVisible: Bool = false

    private var goalLine: String {
        sleepGoal?.promise ?? "We'll help you sleep better."
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 6)

            VStack(spacing: 10) {
                Text("Your phone already tracks it.")
                    .font(MooniFont.display(26))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text("We'll just read what it sees — automatically, every night.")
                    .font(MooniFont.body(15))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 12)
            }

            // 10 figure icons, 9 fill to white as the animation plays.
            HStack(spacing: 6) {
                ForEach(0..<10, id: \.self) { i in
                    Image(systemName: "figure.stand")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(i < filled ? .white : .white.opacity(0.18))
                        .scaleEffect(i < filled ? 1 : 0.88)
                }
            }
            .padding(.horizontal, 4)

            // Big 90% reveal.
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("90")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                Text("%")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
            .opacity(percentVisible ? 1 : 0)
            .scaleEffect(percentVisible ? 1 : 0.7)

            Text("of users see clearer sleep patterns within their first week.")
                .font(MooniFont.body(13))
                .foregroundColor(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .onAppear {
            for i in 0..<9 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + Double(i) * 0.13) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        filled = i + 1
                    }
                    Haptics.tick()
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                    percentVisible = true
                }
                Haptics.success()
            }
        }
    }
}

// MARK: - progressBucket

struct ProgressBucketScreen: View {
    @State private var manualFill: CGFloat = 0
    @State private var mooniFill: CGFloat = 0

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 6)

            Text("Two ways to fill the bucket.")
                .font(MooniFont.display(26))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            HStack(spacing: 28) {
                bucket(label: "Manual", fill: manualFill, color: .white.opacity(0.35))
                bucket(label: "SleepOwl",  fill: mooniFill,  color: .white)
            }

            Text("Manual logging leaks. SleepOwl fills the bucket on its own.")
                .font(MooniFont.body(14))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .onAppear {
            withAnimation(.easeOut(duration: 3.5)) { manualFill = 0.38 }
            withAnimation(.easeOut(duration: 2.0).delay(0.2)) { mooniFill = 1 }
        }
    }

    private func bucket(label: String, fill: CGFloat, color: Color) -> some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 2)
                    .frame(width: 86, height: 180)

                Rectangle()
                    .fill(color)
                    .frame(width: 82, height: 176 * fill)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                    .padding(.bottom, 2)
            }
            Text(label)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .tracking(1)
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

// MARK: - notifAllowMock

struct NotifAllowMockScreen: View {
    let petName: String
    let state: NotificationManager.AuthState

    @State private var pointerBob: Bool = false
    @State private var triggered: Bool = false
    @State private var waiting: Bool = false

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 6)

            VStack(spacing: 10) {
                Text("Let \(petName.isEmpty ? "SleepOwl" : petName) nudge you at bedtime.")
                    .font(MooniFont.display(22))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                Text(waiting
                     ? "Pick on the system prompt to continue."
                     : "Tap Allow.")
                    .font(MooniFont.body(13))
                    .foregroundColor(.white.opacity(0.6))
            }

            mockDialog
                .padding(.top, 4)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                pointerBob = true
            }
            // If the user has *already* answered the system prompt before
            // (denied or authorized in an earlier run / earlier install),
            // tapping Allow on the mock dialog won't show iOS's prompt —
            // it's already been decided. Skip this screen entirely so the
            // mock dialog doesn't look broken. Real first-time users still
            // see the mock + real prompt as designed.
            Task {
                await NotificationManager.shared.refreshAuthState()
                if NotificationManager.shared.authState != .notDetermined {
                    NotificationCenter.default.post(
                        name: .onboardingNotifAllowTapped, object: nil)
                }
            }
        }
    }

    // MARK: Faux iOS dialog

    private var mockDialog: some View {
        ZStack {
            // iOS 26-style permission alert: translucent "liquid glass"
            // material, large continuous corner radius, and the authentic
            // system two-button row (hairline dividers, blue text, bold
            // preferred action) — replaces the old square card with capsule
            // buttons that read as a dated iOS dialog.
            VStack(spacing: 0) {
                VStack(spacing: 5) {
                    Text("\u{201C}SleepOwl\u{201D} Would Like to Send You Notifications")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Notifications may include alerts, sounds, and icon badges. These can be configured in Settings.")
                        .font(.system(size: 12))
                        .foregroundColor(.black.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 19)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

                Rectangle().fill(Color.black.opacity(0.10)).frame(height: 0.5)

                HStack(spacing: 0) {
                    alertButton(title: "Don't Allow", bold: false) {
                        triggerRealFlow()
                    }
                    Rectangle().fill(Color.black.opacity(0.10)).frame(width: 0.5, height: 44)
                    alertButton(title: "Allow", bold: true) {
                        triggerRealFlow()
                    }
                }
                .frame(height: 44)
            }
            .frame(width: 270)
            .background(.regularMaterial)
            .environment(\.colorScheme, .light)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.4), radius: 30, y: 12)

            // Animated pointing finger — sits BELOW the button row so the
            // fingertip (top of the glyph) actually touches the Allow button
            // instead of hovering over the dialog body text.
            Text("👆")
                .font(.system(size: 30))
                .offset(x: 60, y: pointerBob ? 92 : 102)
                .opacity(triggered ? 0 : 1)
                .animation(.easeInOut(duration: 0.25), value: triggered)
        }
    }

    private func alertButton(title: String, bold: Bool,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: bold ? .semibold : .regular))
                .foregroundColor(Color(red: 0.0, green: 0.48, blue: 1.0))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Real-prompt gating

    private func triggerRealFlow() {
        guard !triggered else { return }
        triggered = true
        waiting = true
        Haptics.tick()
        Task { await runRealPrompt() }
    }

    @MainActor
    private func runRealPrompt() async {
        let mgr = NotificationManager.shared
        await mgr.refreshAuthState()
        switch mgr.authState {
        case .notDetermined:
            // iOS WILL show the system sheet. We await its resolution before
            // advancing — the screen never auto-skips while the user is
            // staring at the system prompt.
            _ = await mgr.requestAuthorization()
        case .denied, .authorized:
            // Already decided once (denied earlier, or authorized from a
            // previous run). We do NOT bounce the user out to Settings —
            // that's intrusive and the App Store reviewers hated it. They
            // can flip notifications back on later via the in-app settings
            // screen if they change their mind.
            break
        }
        // Advance regardless of outcome. The user has done something — that
        // is the only contract this screen makes.
        NotificationCenter.default.post(
            name: .onboardingNotifAllowTapped, object: nil)
    }
}

extension Notification.Name {
    static let onboardingNotifAllowTapped =
        Notification.Name("mooni.onboarding.notifAllowTapped")
}

// MARK: - ratingPledge

struct RatingPledgeScreen: View {
    @Binding var promptShown: Bool

    @State private var twinkle: Bool = false

    /// Warm gold for the stars — reads as "rating" rather than the generic
    /// white-on-dark we use everywhere else.
    private var goldTint: Color {
        Color(red: 1.00, green: 0.82, blue: 0.45)
    }

    var body: some View {
        OBStack(
            eyebrow: "Enjoying the app?",
            title: "Leave us a rating.",
            subtitle: "Ratings are how new people find SleepOwl. It takes five seconds."
        ) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    .frame(width: 220, height: 220)
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    .frame(width: 170, height: 170)
                    .scaleEffect(twinkle ? 1.04 : 1)
                // Stars are sized so the row (5 × 16pt + 4 × 5pt spacing
                // = 100pt) sits comfortably inside the 170pt inner ring,
                // even after the .scaleEffect(1.06) twinkle.
                HStack(spacing: 5) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(goldTint)
                            .shadow(color: goldTint.opacity(0.55), radius: 4)
                    }
                }
                .scaleEffect(twinkle ? 1.04 : 1)
            }
        }
        .onAppear {
            // Always start clean: the "I rated it" affordance must NEVER be
            // visible before the user taps "Leave a rating" — including when
            // they navigate back to this screen.
            promptShown = false
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                twinkle = true
            }
        }
    }
}

// MARK: - commitReady

struct CommitReadyScreen: View {
    let petName: String
    @State private var pulse: Bool = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 12)

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
                    .frame(width: 180, height: 180)
                    .scaleEffect(pulse ? 1.06 : 1)
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    .frame(width: 220, height: 220)
                    .scaleEffect(pulse ? 1.1 : 1)
                Text("🌙")
                    .font(.system(size: 64))
            }

            VStack(spacing: 12) {
                Text("You showed up.")
                    .font(MooniFont.display(34))
                    .foregroundColor(.white)
                Text("That's the hardest part.\nFrom here we do the work — together.")
                    .font(MooniFont.body(15))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 16)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - planComputing (replaces AnalyzingAnswersScreen at the call site)

struct PlanComputingScreen: View {
    @Binding var progress: Double
    @Binding var currentStep: Int

    /// Script indices where the displayed message advances. Kept in sync with
    /// `OnboardingView.analyzingScript` (9 steps → 6 messages).
    static let stepBoundaries: [Int] = [0, 1, 3, 5, 7, 8]

    private let messages: [String] = [
        "Reading your answers",
        "Mapping your chronotype",
        "Calculating your sleep debt",
        "Tuning your bedtime",
        "Sealing your plan",
        "Ready"
    ]

    private let subBarLabels: [String] = [
        "Chronotype",
        "Sleep debt",
        "Wake window",
        "Wind-down"
    ]

    private let subBarIcons: [String] = [
        "person.fill.viewfinder",
        "moon.zzz.fill",
        "sun.max.fill",
        "wind"
    ]

    private var accent: Color { MooniColor.accent }

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 12)

            ringProgress

            Text(messages[min(currentStep, messages.count - 1)])
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            subBars
                .padding(.horizontal, 20)
                .padding(.top, 4)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
    }

    private var ringProgress: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.10),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round))
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    accent,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: progress)

            VStack(spacing: 1) {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                Text("ANALYZING")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.45))
            }
        }
        .frame(width: 172, height: 172)
    }

    /// Live analysis checklist — each row fills its own progress bar, then
    /// flips to an accent checkmark when that stage completes. Reads as a real
    /// system working through your data instead of four bare lines.
    private var subBars: some View {
        VStack(spacing: 10) {
            ForEach(subBarLabels.indices, id: \.self) { idx in
                let label = subBarLabels[idx]
                let local = subProgress(for: idx)
                let done = local >= 1
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(accent.opacity(done ? 0.22 : 0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: done ? "checkmark" : subBarIcons[idx])
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundColor(done ? accent : .white.opacity(0.7))
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text(label)
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.10))
                                Capsule()
                                    .fill(accent)
                                    .frame(width: max(4, geo.size.width * local))
                                    .animation(.easeInOut(duration: 0.4), value: local)
                            }
                        }
                        .frame(height: 4)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(done ? 0.06 : 0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(done ? accent.opacity(0.30) : Color.white.opacity(0.08),
                                lineWidth: 1)
                )
            }
        }
    }

    /// Each sub-bar gets a quarter of the timeline.
    private func subProgress(for idx: Int) -> CGFloat {
        let count = CGFloat(subBarLabels.count)
        let start = CGFloat(idx) / count
        let end   = CGFloat(idx + 1) / count
        let p = CGFloat(progress)
        if p <= start { return 0 }
        if p >= end { return 1 }
        return (p - start) / (end - start)
    }
}

// MARK: - planReveal
//
// Stripped-down version: ONE medium-widget-style hero card centered, plus a
// single line of plain bedtime / wake / sleep-need values below it. No phone
// frame, no dock, no stat tiles. The whole screen says: this is what your
// home screen will look like every morning — that's it.

struct PlanRevealScreen: View {
    let profile: OnboardingProfile
    let bedtime: Date
    let wakeTime: Date
    let petName: String
    /// Flipped true once the reveal animation has fully played — the parent
    /// uses it to keep the Continue button disabled until the user has
    /// actually seen the diagnosis → plan transformation.
    @Binding var revealComplete: Bool

    /// Sleep need in hours, derived from age (NSF guidance, conservative).
    private var sleepNeedHours: Double {
        switch profile.age ?? 28 {
        case ..<14:   return 9.5
        case 14..<18: return 8.5
        case 18..<26: return 8.5
        case 26..<65: return 8.0
        default:      return 7.5
        }
    }

    /// Ideal bedtime = wake time − sleep need − 20 min onset buffer.
    private var idealBedtime: Date {
        let cal = Calendar.current
        let seconds = sleepNeedHours * 3600 + 20 * 60
        return cal.date(byAdding: .second, value: -Int(seconds),
                        to: wakeTime) ?? bedtime
    }

    private var sleepDurationLabel: String {
        let h = Int(sleepNeedHours)
        let m = Int((sleepNeedHours - Double(h)) * 60)
        return m == 0 ? "\(h)h 00m" : "\(h)h \(m)m"
    }

    private var bedToWakeLabel: String {
        "\(idealBedtime.hourMinuteString) → \(wakeTime.hourMinuteString)"
    }

    @State private var scoreCount: Int = 0
    @State private var ringTrim: CGFloat = 0
    @State private var widgetAppear: Bool = false
    /// 0 = diagnosis (their real, bad score + what it costs them),
    /// 1 = transformation (ring climbs to the projected score, plan unfolds).
    @State private var phase: Int = 0
    @State private var costShown: Int = 0

    private var projectedScore: Int { 87 }

    /// Accent tint pulled from the real SleepWidgetPalette — "great" range.
    private var scoreTint: Color {
        MooniColor.accent
    }

    /// Diagnosis tint — red for the truly rough, orange otherwise.
    private var diagnosisTint: Color {
        currentScore < 46
            ? Color(red: 1.00, green: 0.45, blue: 0.50)
            : Color(red: 1.00, green: 0.66, blue: 0.40)
    }

    /// The 2–3 sharpest personalized costs, straight from their answers.
    private var diagnosisCosts: [String] { Array(profile.topIssues.prefix(3)) }

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 2)

            // Title block — flips with the phase: honest diagnosis first,
            // then the plan that fixes it.
            VStack(spacing: 8) {
                Text(phase == 0
                     ? "First, the honest news."
                     : "Your plan is ready\(petName.isEmpty ? "" : ", \(petName)").")
                    .font(MooniFont.display(28))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                Text(phase == 0
                     ? "Scored from your answers — this is where your sleep stands today."
                     : "Built from everything you told us — here's what changes.")
                    .font(MooniFont.body(14))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .animation(.easeInOut(duration: 0.4), value: phase)

            // Hero ring: counts up to their CURRENT score in warning colors,
            // sits with the personalized costs, then morphs to the projected
            // score as the plan takes over. Before → after, one ring.
            VStack(spacing: 14) {
                heroRing
                    .frame(width: 188, height: 188)

                if phase == 0 {
                    diagnosisCostList
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    improvementBadge
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }

            // Tonight's schedule — concrete and theirs.
            scheduleCard
                .opacity(widgetAppear ? 1 : 0)
                .offset(y: widgetAppear ? 0 : 10)

            // Personalized: the exact issues we pulled from their answers, now
            // framed as things the plan FIXES. Makes the plan feel tailored.
            if !planFixes.isEmpty {
                planSection(icon: "checkmark.seal.fill",
                            title: "What your plan fixes") {
                    VStack(spacing: 12) {
                        ForEach(Array(planFixes.enumerated()), id: \.offset) { _, fix in
                            fixRow(fix)
                        }
                    }
                }
                .opacity(widgetAppear ? 1 : 0)
                .offset(y: widgetAppear ? 0 : 10)
            }

            // Everything included — the value stack that earns the subscription.
            planSection(icon: "sparkles", title: "Everything you'll unlock") {
                VStack(spacing: 14) {
                    ForEach(planFeatures) { featureRow($0) }
                }
            }
            .opacity(widgetAppear ? 1 : 0)
            .offset(y: widgetAppear ? 0 : 10)

            // Bold, motivating projected outcomes.
            resultsRow
                .opacity(widgetAppear ? 1 : 0)

            Text("Your plan adapts every night as \(petNameOrDefault) learns your sleep.")
                .font(MooniFont.caption(12))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .task { await animateIn() }
    }

    // MARK: Hero ring

    /// Big animated score ring — flat track + solid accent arc, with the
    /// climbing score number at the center. Matches the ring style used
    /// everywhere else in the app (no halo, no gradient hot-spot).
    private var heroRing: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.white.opacity(0.08),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round))

            // Progress arc — warning-colored during the diagnosis, brand
            // accent once the plan takes over. The color crossfade IS the
            // transformation moment.
            Circle()
                .trim(from: 0, to: ringTrim)
                .stroke(
                    phase == 0 ? diagnosisTint : scoreTint,
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.8), value: phase)

            VStack(spacing: 2) {
                Text("\(scoreCount)")
                    .font(.system(size: 76, weight: .heavy, design: .rounded))
                    .foregroundColor(phase == 0 ? diagnosisTint : .white)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.8), value: phase)
                Text(phase == 0 ? "YOUR SCORE TODAY" : "PROJECTED SCORE")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(1.6)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }

    /// The personalized "this is what it's costing you" list shown under the
    /// diagnosis ring — their own answers, weaponized.
    private var diagnosisCostList: some View {
        VStack(spacing: 9) {
            ForEach(Array(diagnosisCosts.enumerated()), id: \.offset) { idx, cost in
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(diagnosisTint)
                        .padding(.top, 1)
                    Text(cost)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(diagnosisTint.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(diagnosisTint.opacity(0.25), lineWidth: 1)
                )
                .opacity(idx < costShown ? 1 : 0)
                .offset(y: idx < costShown ? 0 : 8)
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: Plan data

    private var petNameOrDefault: String { petName.isEmpty ? "SleepOwl" : petName }

    /// Where they are now (derived from their answers, clamped so it always
    /// reads as "bad but plausible" — never so low it's absurd, never high
    /// enough to feel like there's nothing to fix).
    private var currentScore: Int { min(62, max(38, profile.derivedSleepScore)) }

    /// The personalized issues we already surface elsewhere, reframed here as
    /// things the plan will fix. Capped so the section stays scannable.
    private var planFixes: [String] { Array(profile.topIssues.prefix(4)) }

    private struct PlanFeature: Identifiable {
        let icon: String
        let title: String
        let subtitle: String
        var id: String { title }
    }

    private var planFeatures: [PlanFeature] {
        [
            .init(icon: "alarm.waves.left.and.right.fill",
                  title: "Smart wake window",
                  subtitle: "Wake in your lightest stage — never mid-deep-sleep."),
            .init(icon: "wind",
                  title: "Personalized wind-down",
                  subtitle: "A nightly routine built from what relaxes you."),
            .init(icon: "bell.badge.fill",
                  title: "Bedtime nudges",
                  subtitle: "\(petNameOrDefault) reminds you before it's too late."),
            .init(icon: "waveform.path.ecg",
                  title: "Automatic sleep tracking",
                  subtitle: "No wearable — your phone does the measuring."),
            .init(icon: "chart.line.uptrend.xyaxis",
                  title: "Nightly score & insights",
                  subtitle: "See exactly what helped, and what hurt."),
            .init(icon: "sparkles",
                  title: "\(petNameOrDefault) grows with you",
                  subtitle: "Every good night, your companion thrives.")
        ]
    }

    private var projectedResults: [(value: String, label: String)] {
        [
            ("2×",   "faster to\nfall asleep"),
            ("+47%", "more\ndeep sleep"),
            ("+38%", "all-day\nenergy")
        ]
    }

    // MARK: Plan components

    private var improvementBadge: some View {
        HStack(spacing: 9) {
            Text("+\(projectedScore - currentScore)")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundColor(Color(red: 0.55, green: 0.85, blue: 0.78))
            Text("points")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
            Rectangle().fill(Color.white.opacity(0.15))
                .frame(width: 1, height: 14)
            Text("\(currentScore)")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundColor(.white.opacity(0.55))
            Image(systemName: "arrow.right")
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(scoreTint)
            Text("\(projectedScore)")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
            Text("by week 4")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.white.opacity(0.06)))
        .overlay(Capsule().stroke(scoreTint.opacity(0.30), lineWidth: 1))
    }

    private var scheduleCard: some View {
        HStack(spacing: 0) {
            scheduleCell(icon: "moon.zzz.fill", label: "BEDTIME",
                         value: idealBedtime.hourMinuteString)
            scheduleDivider
            scheduleCell(icon: "sun.max.fill", label: "WAKE",
                         value: wakeTime.hourMinuteString)
            scheduleDivider
            scheduleCell(icon: "bed.double.fill", label: "TARGET",
                         value: sleepDurationLabel)
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func scheduleCell(icon: String, label: String,
                              value: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .heavy))
                .foregroundColor(scoreTint)
            Text(value)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .tracking(1.2)
                .foregroundColor(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
    }

    private var scheduleDivider: some View {
        Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 40)
    }

    private func planSection<Content: View>(
        icon: String, title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(scoreTint)
                Text(title)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .tracking(0.5)
                    .foregroundColor(.white.opacity(0.85))
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func fixRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(scoreTint)
            Text(text)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func featureRow(_ f: PlanFeature) -> some View {
        HStack(spacing: 12) {
            Image(systemName: f.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(scoreTint)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(scoreTint.opacity(0.16))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(f.title)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                Text(f.subtitle)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var resultsRow: some View {
        HStack(spacing: 10) {
            ForEach(Array(projectedResults.enumerated()), id: \.offset) { _, r in
                VStack(spacing: 4) {
                    Text(r.value)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [.white, scoreTint],
                                           startPoint: .top, endPoint: .bottom)
                        )
                    Text(r.label)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(scoreTint.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(scoreTint.opacity(0.22), lineWidth: 1)
                )
            }
        }
    }

    // MARK: Animation

    @MainActor
    private func animateIn() async {
        widgetAppear = false
        ringTrim = 0
        scoreCount = 0
        phase = 0
        costShown = 0
        revealComplete = false

        // ── Phase 0: the diagnosis. Ring climbs to their REAL (bad) score.
        try? await Task.sleep(nanoseconds: 300_000_000)
        let diagDuration: Double = 1.1
        withAnimation(.easeOut(duration: diagDuration)) {
            ringTrim = CGFloat(currentScore) / 100
        }
        var stepNanos = UInt64(diagDuration / Double(max(1, currentScore))
                               * 1_000_000_000)
        for _ in 0..<currentScore {
            scoreCount += 1
            try? await Task.sleep(nanoseconds: stepNanos)
        }
        Haptics.warning()

        // Their personalized costs stagger in while the bad score sits there.
        for i in 1...max(1, diagnosisCosts.count) {
            try? await Task.sleep(nanoseconds: 380_000_000)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                costShown = i
            }
            Haptics.tick()
        }

        // Let the diagnosis land before the rescue arrives.
        try? await Task.sleep(nanoseconds: 1_500_000_000)

        // ── Phase 1: the transformation. Costs swap for the +N badge, the
        // ring re-colors and climbs to the projected score, plan unfolds.
        withAnimation(.easeInOut(duration: 0.5)) { phase = 1 }
        let riseDuration: Double = 1.5
        withAnimation(.easeOut(duration: riseDuration)) {
            ringTrim = CGFloat(projectedScore) / 100
        }
        let remaining = projectedScore - currentScore
        stepNanos = UInt64(riseDuration / Double(max(1, remaining))
                           * 1_000_000_000)
        for _ in 0..<remaining {
            scoreCount += 1
            try? await Task.sleep(nanoseconds: stepNanos)
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
            widgetAppear = true
        }
        Haptics.success()
        revealComplete = true
    }
}

// MARK: - autoTrackStoneAge

struct AutoTrackStoneAgeScreen: View {
    var body: some View {
        OBStack(
            eyebrow: "Tracking, evolved",
            title: "Manual sleep journals are over.",
            subtitle: "You'll never log a night. It all happens while you sleep — your only job is waking up better."
        ) {
            ZStack {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 90, weight: .regular))
                    .foregroundColor(.white.opacity(0.18))
                Image(systemName: "xmark")
                    .font(.system(size: 60, weight: .heavy))
                    .foregroundColor(Color.red.opacity(0.7))
            }
            .frame(height: 130)
        }
    }
}

// MARK: - autoTrackHow
//
// 24-hour phone-activity timeline. Replaces the previous iPhone glyph + pulse
// rings + 3 bullets with a single visualization that *shows* the automatic
// detection: activity bars drop into the night, a shaded "sleep" band marks
// the inferred window, and two annotation pins call out "Bedtime detected"
// and "Wake detected" at the band edges.

struct AutoTrackHowScreen: View {
    /// Mock phone-activity values across 24 hours (midnight → midnight).
    /// High during waking hours, near-zero overnight. The sleep band derives
    /// from where activity stays low for an extended stretch.
    private let activity: [Double] = [
        0.05, 0.02, 0.01, 0.01, 0.01, 0.02,   // 0am – 5am
        0.10, 0.35, 0.55, 0.62, 0.58, 0.65,   // 6am – 11am
        0.70, 0.68, 0.60, 0.66, 0.72, 0.78,   // 12pm – 5pm
        0.74, 0.62, 0.48, 0.28, 0.12, 0.06    // 6pm – 11pm
    ]

    /// Sleep-band edges in hours-since-midnight. 22.75 = 10:45pm bedtime,
    /// 6.75 (next day) = 6:45am wake. We render the band wrapping past
    /// midnight by splitting it into [22.75…24] + [0…6.75].
    private let bedHour: Double = 22.75
    private let wakeHour: Double = 6.75

    @State private var drawProgress: CGFloat = 0
    @State private var bandVisible: Bool = false
    @State private var pinsVisible: Bool = false

    /// Brand-aligned accent for the sleep band.
    private var sleepTint: Color {
        MooniColor.accent
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 4)

            VStack(spacing: 10) {
                Text("Just you and your phone.")
                    .font(MooniFont.display(26))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text("It reads several signals at once and fuses them into one sleep timeline — the same trick wearables use.")
                    .font(MooniFont.body(14))
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 12)
            }

            sensorFusionStrip
                .padding(.horizontal, 8)

            timelineCard
                .padding(.horizontal, 8)

            Text("You do nothing. Wake up — the full story of your night is already waiting.")
                .font(MooniFont.body(12))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .onAppear { play() }
    }

    // MARK: - Sensor fusion strip

    /// Three real input signals flowing into one output — makes "automatic"
    /// concrete instead of magical, which is what skeptical users need.
    private var sensorFusionStrip: some View {
        HStack(spacing: 6) {
            signalChip(icon: "waveform.path.ecg", label: "Motion")
            fusePlus
            signalChip(icon: "mic.fill", label: "Sound")
            fusePlus
            signalChip(icon: "bolt.fill", label: "Charging")
            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(.white.opacity(0.4))
            signalChip(icon: "moon.zzz.fill", label: "Your night", highlighted: true)
        }
        .frame(maxWidth: .infinity)
    }

    private var fusePlus: some View {
        Image(systemName: "plus")
            .font(.system(size: 9, weight: .heavy))
            .foregroundColor(.white.opacity(0.35))
    }

    private func signalChip(icon: String, label: String,
                            highlighted: Bool = false) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(highlighted ? sleepTint : .white.opacity(0.8))
            Text(label)
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .foregroundColor(highlighted ? sleepTint : .white.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(highlighted ? sleepTint.opacity(0.14) : Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(highlighted ? sleepTint.opacity(0.5) : Color.white.opacity(0.10),
                        lineWidth: 1)
        )
    }

    // MARK: - Timeline card

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Top label row — "Last 24 hours"
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.white.opacity(0.55))
                Text("LAST 24 HOURS")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                    .foregroundColor(.white.opacity(0.55))
                Spacer(minLength: 0)
            }

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ZStack(alignment: .topLeading) {
                    // Sleep band — split at midnight so it can wrap.
                    sleepBand(width: w, height: h)
                        .opacity(bandVisible ? 1 : 0)

                    // Activity bars.
                    HStack(alignment: .bottom, spacing: 2) {
                        ForEach(0..<24, id: \.self) { hour in
                            bar(for: hour, height: h)
                        }
                    }
                    .frame(height: h, alignment: .bottom)

                    // Bedtime pin (right side of midnight-wrap).
                    pin(label: "Bedtime",
                        icon: "moon.zzz.fill",
                        x: xPos(forHour: bedHour, width: w),
                        height: h,
                        alignAbove: true)
                        .opacity(pinsVisible ? 1 : 0)
                        .offset(y: pinsVisible ? 0 : -4)

                    // Wake pin (after midnight).
                    pin(label: "Wake",
                        icon: "sun.max.fill",
                        x: xPos(forHour: wakeHour, width: w),
                        height: h,
                        alignAbove: true)
                        .opacity(pinsVisible ? 1 : 0)
                        .offset(y: pinsVisible ? 0 : -4)
                }
            }
            .frame(height: 92)

            // X-axis hour tick labels.
            HStack {
                axisLabel("12am")
                Spacer(minLength: 0)
                axisLabel("6am")
                Spacer(minLength: 0)
                axisLabel("12pm")
                Spacer(minLength: 0)
                axisLabel("6pm")
                Spacer(minLength: 0)
                axisLabel("12am")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Building blocks

    private func bar(for hour: Int, height h: CGFloat) -> some View {
        let v = activity[hour]
        let inSleep = isInSleepBand(hour: Double(hour))
        let revealed = drawProgress >= CGFloat(hour) / 23.0
        return RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(
                inSleep
                    ? sleepTint.opacity(0.55)
                    : Color.white.opacity(0.75)
            )
            .frame(maxWidth: .infinity)
            .frame(height: max(2, CGFloat(v) * (h - 6) * (revealed ? 1 : 0)))
    }

    @ViewBuilder
    private func sleepBand(width w: CGFloat, height h: CGFloat) -> some View {
        // Pre-midnight portion: bedHour → 24
        let pre = bandRect(start: bedHour, end: 24, width: w, height: h)
        // Post-midnight portion: 0 → wakeHour
        let post = bandRect(start: 0, end: wakeHour, width: w, height: h)
        ZStack(alignment: .topLeading) {
            sleepBandFill(rect: pre)
            sleepBandFill(rect: post)
        }
    }

    private func bandRect(start: Double, end: Double, width w: CGFloat,
                          height h: CGFloat) -> CGRect {
        let x0 = xPos(forHour: start, width: w)
        let x1 = xPos(forHour: end, width: w)
        return CGRect(x: x0, y: 0, width: max(0, x1 - x0), height: h)
    }

    private func sleepBandFill(rect: CGRect) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        sleepTint.opacity(0.22),
                        sleepTint.opacity(0.06)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
    }

    private func pin(label: String, icon: String, x: CGFloat,
                     height h: CGFloat, alignAbove: Bool) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(.white)
                Text(label)
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(sleepTint.opacity(0.85)))
            Rectangle()
                .fill(sleepTint.opacity(0.6))
                .frame(width: 1, height: 12)
        }
        .position(x: x, y: alignAbove ? 14 : h - 14)
    }

    private func axisLabel(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .foregroundColor(.white.opacity(0.45))
            .tracking(0.3)
    }

    // MARK: - Geometry

    private func xPos(forHour hour: Double, width w: CGFloat) -> CGFloat {
        CGFloat(hour / 24.0) * w
    }

    private func isInSleepBand(hour: Double) -> Bool {
        // Wraps past midnight: bed=22.75, wake=6.75 → in-band if hour ≥ 22.75
        // OR hour < 6.75.
        hour >= bedHour || hour < wakeHour
    }

    // MARK: - Animation

    private func play() {
        // Bars sweep in left-to-right.
        withAnimation(.easeOut(duration: 1.0)) { drawProgress = 1 }
        // Band fades in once the bars are halfway across.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.easeOut(duration: 0.5)) { bandVisible = true }
        }
        // Pins drop in after the band lands.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                pinsVisible = true
            }
            Haptics.tick()
        }
    }
}

// MARK: - autoTrackAccuracy → renamed to phone-only (no PSG claims)
//
// Strike-through comparison: three "old way" devices crossed out at the top,
// arrow down, single highlighted iPhone card at the bottom. Sells the
// "everything else is unnecessary" message visually instead of with bullet
// pills.

struct AutoTrackPhoneOnlyScreen: View {
    @State private var strikeProgress: CGFloat = 0
    @State private var iphoneVisible: Bool = false

    private var accentTint: Color {
        MooniColor.accent
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 8)

            VStack(spacing: 10) {
                Text("No watch. No ring.\nJust your phone.")
                    .font(MooniFont.display(27))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                Text("It tracks every night on its own — nothing to wear, charge, or remember.")
                    .font(MooniFont.body(14))
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 12)
            }

            // ── Old way (3 struck-out tiles, with what they'd cost you)
            HStack(spacing: 12) {
                strikedTile(title: "Smartwatch", price: "$399", icon: "applewatch")
                strikedTile(title: "Smart ring", price: "$299", icon: "circle.circle")
                strikedTile(title: "Manual log", price: "every day", icon: "pencil.and.list.clipboard")
            }
            .padding(.horizontal, 8)

            // Arrow down + "Just this:"
            VStack(spacing: 8) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(.white.opacity(0.35))
                Text("ALL YOU NEED")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                    .foregroundColor(.white.opacity(0.55))
            }

            // ── New way (one highlighted iPhone card)
            iphoneCard
                .padding(.horizontal, 24)
                .opacity(iphoneVisible ? 1 : 0)
                .scaleEffect(iphoneVisible ? 1 : 0.95)
                .offset(y: iphoneVisible ? 0 : 8)

            accuracyFootnote
                .padding(.horizontal, 24)
                .opacity(iphoneVisible ? 1 : 0)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .onAppear { play() }
    }

    // MARK: - Building blocks

    private func strikedTile(title: String, price: String, icon: String) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 70, height: 70)
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white.opacity(0.35))

                // Animated strike-through diagonal.
                GeometryReader { geo in
                    Path { p in
                        let pad: CGFloat = 8
                        p.move(to: CGPoint(x: pad, y: geo.size.height - pad))
                        p.addLine(to: CGPoint(x: geo.size.width - pad, y: pad))
                    }
                    .trim(from: 0, to: strikeProgress)
                    .stroke(
                        Color(red: 1.0, green: 0.55, blue: 0.55).opacity(0.9),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                }
                .frame(width: 70, height: 70)
            }
            VStack(spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
                    .strikethrough(strikeProgress >= 1, color: .white.opacity(0.4))
                Text(price)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(red: 1.0, green: 0.55, blue: 0.55).opacity(0.75))
            }
        }
    }

    private var iphoneCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "iphone.gen3")
                .font(.system(size: 44, weight: .regular))
                .foregroundColor(.white)
                .frame(width: 64, height: 76)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(accentTint.opacity(0.18))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(accentTint.opacity(0.55), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Your iPhone")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Text("$0")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(accentTint)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(accentTint.opacity(0.16)))
                }
                Text("Wearable-grade tracking — already on your nightstand.")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accentTint.opacity(0.35), lineWidth: 1)
        )
    }

    /// Honest credibility line — motion-based (actigraphy) sleep/wake scoring
    /// genuinely agrees with lab studies at ~90%; keep this claim real, it's
    /// the one place exaggeration would cost us trust instead of buying it.
    private var accuracyFootnote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(MooniColor.success.opacity(0.85))
                .padding(.top, 1)
            Text("Motion-based sleep detection agrees with lab sleep/wake scoring ~90% of the time in published studies.")
                .font(MooniFont.caption(11))
                .foregroundColor(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
    }

    // MARK: - Animation

    private func play() {
        // Strikes draw left-to-right, staggered.
        withAnimation(.easeOut(duration: 0.7).delay(0.25)) {
            strikeProgress = 1
        }
        // iPhone card slides in after the strikes complete.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                iphoneVisible = true
            }
            Haptics.tick()
        }
    }
}

// MARK: - signaturePledge

struct SignaturePledgeScreen: View {
    let petName: String

    @State private var points: [CGPoint] = []
    @State private var holdProgress: Double = 0
    @State private var holdTimer: Timer? = nil
    @State private var advanced = false

    private var canCommit: Bool { points.count >= 30 }

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 8)

            VStack(spacing: 8) {
                Text("Make it official.")
                    .font(MooniFont.display(26))
                    .foregroundColor(.white)
                Text("Sign below, then hold to commit.")
                    .font(MooniFont.body(14))
                    .foregroundColor(.white.opacity(0.65))
            }

            signaturePad
                .padding(.horizontal, 24)

            holdButton

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .onDisappear { holdTimer?.invalidate() }
    }

    private var signaturePad: some View {
        // Wrap in a GeometryReader so we know the pad's bounds and can
        // clamp incoming drag points to stay inside the rounded rect.
        // Without this the stroke can render outside the visible pad on
        // iPad — exactly the "written outside the area" issue.
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)

                // Faint guide line.
                Path { p in
                    let y = size.height * 0.78
                    p.move(to: CGPoint(x: 24, y: y))
                    p.addLine(to: CGPoint(x: size.width - 24, y: y))
                }
                .stroke(Color.white.opacity(0.18),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                if points.isEmpty {
                    Text("Sign here")
                        .font(.system(size: 14, weight: .medium,
                                      design: .rounded))
                        .foregroundColor(.white.opacity(0.35))
                }

                // The drawn signature — clipped to the rounded rect so
                // nothing ever renders outside the pad's bounds.
                Path { p in
                    guard let first = points.first else { return }
                    p.move(to: first)
                    for pt in points.dropFirst() { p.addLine(to: pt) }
                }
                .stroke(Color.white,
                        style: StrokeStyle(lineWidth: 2.4,
                                           lineCap: .round,
                                           lineJoin: .round))
                .clipShape(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
            }
            .contentShape(RoundedRectangle(cornerRadius: 18,
                                           style: .continuous))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        // Clamp to pad bounds with a small inset so the
                        // 2.4pt stroke never grazes the edge.
                        let inset: CGFloat = 4
                        let clamped = CGPoint(
                            x: min(max(v.location.x, inset),
                                   size.width - inset),
                            y: min(max(v.location.y, inset),
                                   size.height - inset)
                        )
                        points.append(clamped)
                    }
            )
        }
        .frame(height: 170)
    }

    private var holdButton: some View {
        ZStack {
            Capsule()
                .fill(Color.white.opacity(canCommit ? 1 : 0.18))
            Capsule()
                .trim(from: 0, to: CGFloat(holdProgress))
                .stroke(Color.black.opacity(0.18),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .padding(2)
            HStack(spacing: 10) {
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 17, weight: .bold))
                Text(canCommit ? "Hold to commit" : "Draw a signature first")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
            }
            .foregroundColor(canCommit ? .black : .white.opacity(0.5))
        }
        .frame(height: 56)
        .padding(.horizontal, 28)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in startHold() }
                .onEnded { _ in cancelHold() }
        )
    }

    private func startHold() {
        guard canCommit, holdTimer == nil, !advanced else { return }
        Haptics.tick()
        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { t in
            DispatchQueue.main.async {
                holdProgress += 0.02 / 1.8
                if holdProgress >= 1 {
                    t.invalidate()
                    holdTimer = nil
                    if !advanced {
                        advanced = true
                        Haptics.success()
                        NotificationCenter.default.post(
                            name: .onboardingSignatureCommitted, object: nil)
                    }
                }
            }
        }
    }

    private func cancelHold() {
        holdTimer?.invalidate()
        holdTimer = nil
        if !advanced {
            withAnimation(.easeOut(duration: 0.2)) { holdProgress = 0 }
        }
    }
}

extension Notification.Name {
    static let onboardingSignatureCommitted =
        Notification.Name("mooni.onboarding.signatureCommitted")
}

// MARK: - sleepMetricsTease — preview of what Mooni tracks each night

struct SleepMetricsTeaseScreen: View {
    @State private var score: Int = 0
    @State private var deep: CGFloat = 0
    @State private var rem: CGFloat = 0
    @State private var light: CGFloat = 0
    @State private var statsIn: Bool = false
    @State private var consistency: CGFloat = 0

    private var accent: Color { MooniColor.accent }

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 4)

            VStack(spacing: 10) {
                Text("Every night, scored.")
                    .font(MooniFont.display(28))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text("9 signals, tracked automatically — this is the report waiting for you every morning.")
                    .font(MooniFont.body(14))
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            reportCard

            Text("Phone on your nightstand. That's the whole setup.")
                .font(MooniFont.caption(12))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .onAppear { animateIn() }
    }

    // MARK: - Report card

    /// One unified "morning report" mock — ring + stages side by side, a
    /// stat strip, and a consistency meter. Reads as a screenshot of the
    /// real product instead of a pile of repeating chips.
    private var reportCard: some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 10, weight: .heavy))
                    Text("TONIGHT'S REPORT")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(1.4)
                }
                .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text("EXCELLENT")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(0.6)
                    .foregroundColor(Color(red: 0.55, green: 0.85, blue: 0.78))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color(red: 0.55, green: 0.85, blue: 0.78).opacity(0.16)))
            }

            // Ring + stage bars side by side
            HStack(spacing: 18) {
                scoreRing
                    .frame(width: 104, height: 104)

                VStack(spacing: 11) {
                    stageRow(label: "Deep",  minutes: "1h 22m", progress: deep,  color: NightUI.stageDeep)
                    stageRow(label: "REM",   minutes: "1h 38m", progress: rem,   color: NightUI.stageREM)
                    stageRow(label: "Light", minutes: "4h 12m", progress: light, color: NightUI.stageLight)
                }
            }

            cardDivider

            // Stat strip — four big values, hairline-divided, no boxes.
            HStack(spacing: 0) {
                stat(value: "14m",  label: "to sleep")
                statDivider
                stat(value: "1×",   label: "wake-ups")
                statDivider
                stat(value: "6m",   label: "snoring")
                statDivider
                stat(value: "7:04", label: "smart wake")
            }
            .opacity(statsIn ? 1 : 0)
            .offset(y: statsIn ? 0 : 8)

            cardDivider

            // Consistency meter
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(accent)
                Text("Consistency")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                    .fixedSize()
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(accent)
                            .frame(width: geo.size.width * consistency)
                    }
                }
                .frame(height: 5)
                Text("92%")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
            }
            .opacity(statsIn ? 1 : 0)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .padding(.horizontal, 4)
    }

    private var cardDivider: some View {
        Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
    }

    private var statDivider: some View {
        Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 30)
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private var scoreRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 7)
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(accent,
                        style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: -1) {
                Text("\(score)")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                Text("SCORE")
                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                    .foregroundColor(.white.opacity(0.55))
            }
        }
    }

    private func stageRow(label: String, minutes: String, progress: CGFloat, color: Color) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .tracking(0.8)
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 44, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * progress)
                        .animation(.easeInOut(duration: 0.8), value: progress)
                }
            }
            .frame(height: 6)
            Text(minutes)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
                .frame(width: 56, alignment: .trailing)
        }
    }

    private func animateIn() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 1.1)) { deep = 0.32 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeOut(duration: 1.1)) { rem = 0.42 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 1.1)) { light = 0.72 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                statsIn = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.easeOut(duration: 0.9)) { consistency = 0.92 }
        }
        Timer.scheduledTimer(withTimeInterval: 0.025, repeats: true) { t in
            DispatchQueue.main.async {
                if score < 87 {
                    score += 1
                } else {
                    t.invalidate()
                }
            }
        }
    }
}

// MARK: - widgetShowcase — preview of the home-screen widget

struct WidgetShowcaseScreen: View {
    enum Kind { case small, medium }
    let kind: Kind

    @State private var pulse: Bool = false

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 4)

            VStack(spacing: 10) {
                Text(kind == .small
                     ? "Your sleep, on your lock screen."
                     : "And on your home screen.")
                    .font(MooniFont.display(24))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                Text(kind == .small
                     ? "Your night's score is just there every morning — you never open the app, never press a button."
                     : "Last night, your trend, your streak — already filled in while you slept.")
                    .font(MooniFont.body(14))
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            homeScreenMock

            benefitChips

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.72)) {
                pulse = true
            }
        }
    }

    // MARK: - Home-screen mock

    /// A believable miniature home screen — wallpaper, app-icon grid with
    /// label bars, dock — with the REAL widget sitting in it. Sells "this is
    /// what your phone will look like" instead of a widget floating in an
    /// abstract grey placeholder.
    private var homeScreenMock: some View {
        VStack(spacing: 14) {
            iconRow(startIndex: 0)
            scaledWidget
                .scaleEffect(pulse ? 1.0 : 0.94)
                .shadow(color: .black.opacity(0.45), radius: 16, y: 8)
            iconRow(startIndex: 4)
            dock
        }
        .padding(.horizontal, 14)
        .padding(.top, 18)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(wallpaper)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }

    private var wallpaper: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.11, blue: 0.26),
                    Color(red: 0.10, green: 0.14, blue: 0.32),
                    Color(red: 0.06, green: 0.08, blue: 0.18)
                ],
                startPoint: .top, endPoint: .bottom)
            RadialGradient(
                colors: [MooniColor.accent.opacity(0.22),
                         .clear],
                center: .topTrailing, startRadius: 0, endRadius: 240)
        }
    }

    /// Muted, varied tints so the grid reads like real third-party apps
    /// without competing with the widget.
    private static let iconTints: [Color] = [
        Color(red: 0.42, green: 0.40, blue: 0.78),
        Color(red: 0.30, green: 0.48, blue: 0.66),
        Color(red: 0.58, green: 0.38, blue: 0.62),
        Color(red: 0.34, green: 0.54, blue: 0.52),
        Color(red: 0.62, green: 0.46, blue: 0.36),
        Color(red: 0.36, green: 0.42, blue: 0.70),
        Color(red: 0.52, green: 0.34, blue: 0.50),
        Color(red: 0.30, green: 0.56, blue: 0.64),
        Color(red: 0.48, green: 0.44, blue: 0.34),
        Color(red: 0.40, green: 0.36, blue: 0.66),
        Color(red: 0.56, green: 0.42, blue: 0.58),
        Color(red: 0.32, green: 0.50, blue: 0.58)
    ]

    private func fakeIcon(_ index: Int) -> some View {
        let tint = Self.iconTints[index % Self.iconTints.count]
        return VStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.85), tint.opacity(0.55)],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 50, height: 50)
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 0.6)
                )
            // Label bar — suggests the app name without inventing one.
            Capsule()
                .fill(Color.white.opacity(0.22))
                .frame(width: 30, height: 4)
        }
    }

    private func iconRow(startIndex: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { i in
                fakeIcon(startIndex + i)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var dock: some View {
        HStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Self.iconTints[(i + 6) % Self.iconTints.count].opacity(0.8),
                                     Self.iconTints[(i + 6) % Self.iconTints.count].opacity(0.5)],
                            startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 46, height: 46)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.10))
        )
    }

    private var benefitChips: some View {
        HStack(spacing: 8) {
            benefitChip(icon: "sunrise.fill",
                        text: kind == .small ? "Filled in by sunrise" : "Updates while you sleep")
            benefitChip(icon: "hand.tap.fill",
                        text: kind == .small ? "No tap needed" : "Tap for the full report")
        }
    }

    private func benefitChip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(MooniColor.accent)
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.75))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color.white.opacity(0.06)))
        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
    }

    /// The REAL widget views (shared with the MooniSleepWidget target),
    /// rendered at their true WidgetKit size, then scaled to fit the mock.
    /// Whatever ships on the home screen is exactly what's previewed here.
    @ViewBuilder
    private var scaledWidget: some View {
        switch kind {
        case .small:
            widgetChrome(width: 158, height: 158) {
                SmallSleepWidgetView(data: .sample)
            }
        case .medium:
            widgetChrome(width: 329, height: 155) {
                MediumSleepWidgetView(data: .sample)
            }
            .scaleEffect(0.92)
            .frame(width: 329 * 0.92, height: 155 * 0.92)
        }
    }

    private func widgetChrome<Content: View>(
        width: CGFloat, height: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            SleepWidgetBackground(tint: SleepWidgetData.sample.scoreTint)
            content()
                .padding(14)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - motionAccess — pre-permission ask for Motion & Fitness

/// Friendly explainer shown right before the OS Motion & Fitness prompt.
/// Motion history is the highest-accuracy signal the sleep brain has that
/// works with zero user effort, so this screen sells the benefit first —
/// the footer button in OnboardingView triggers the real system dialog.
struct MotionAccessScreen: View {
    let petName: String
    @State private var appear = false

    private var accent: Color { MooniColor.accent }

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 8)

            ZStack {
                Circle()
                    .fill(accent.opacity(0.14))
                    .frame(width: 96, height: 96)
                Image(systemName: "figure.walk.motion")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundColor(accent)
            }
            .scaleEffect(appear ? 1 : 0.85)

            VStack(spacing: 10) {
                Text("One permission makes it automatic")
                    .font(MooniFont.display(26))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                Text("Your iPhone already keeps a private 7-day motion history. Each morning \(petName.isEmpty ? "SleepOwl" : petName) reads it to find when you actually fell asleep and woke — nothing runs overnight, no wearable needed.")
                    .font(MooniFont.body(14))
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            VStack(spacing: 12) {
                benefitRow(icon: "moon.zzz.fill",
                           title: "Real bedtime, detected",
                           sub: "When your body actually settled — not when you planned to.")
                benefitRow(icon: "sunrise.fill",
                           title: "Real wake time, detected",
                           sub: "Your first steps in the morning end the night precisely.")
                benefitRow(icon: "waveform.path.ecg",
                           title: "Restless nights, visible",
                           sub: "Tossing and night pickups show up in your score.")
            }
            .padding(.horizontal, 20)
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 10)

            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                Text("Processed on your phone. Never uploaded.")
                    .font(MooniFont.caption(12))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.75)) {
                appear = true
            }
        }
    }

    private func benefitRow(icon: String, title: String, sub: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(accent)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(accent.opacity(0.14))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                Text(sub)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}


// MARK: - sleepScience — cinematic research-stat beats
//
// Two full-bleed "the stakes are real" moments placed after the frustration
// questions: the user has just admitted how bad it is, and these screens
// confirm their fear with real, citable research. Emotional framing is
// maximal; every fact and attribution is real (no invented quotes — one
// screenshot of a fabricated Harvard claim kills more trust than ten of
// these screens build).

/// Shared scaffolding for the science beats: eyebrow → huge stat → headline
/// → source row → quote card, staggered in.
private struct ScienceStatLayout: View {
    let eyebrow: String
    let stat: String
    let statTint: Color
    let headline: String
    let source: String
    let quote: String
    let quoteAuthor: String

    @State private var stage: Int = 0

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 11, weight: .heavy))
                Text(eyebrow.uppercased())
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(2)
            }
            .foregroundColor(.white.opacity(0.55))
            .opacity(stage >= 1 ? 1 : 0)

            Text(stat)
                .font(.system(size: 88, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [statTint, statTint.opacity(0.55)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .opacity(stage >= 2 ? 1 : 0)
                .scaleEffect(stage >= 2 ? 1 : 0.8)

            // The research finding writes in word-by-word once the big stat has
            // landed — reinforces the "reading the study" feel.
            TypewriterText(text: headline, size: 21, alignment: .center,
                           color: .white, start: stage >= 3)
                .padding(.horizontal, 18)

            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(MooniColor.success.opacity(0.85))
                Text(source)
                    .font(MooniFont.caption(11))
                    .foregroundColor(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .opacity(stage >= 3 ? 1 : 0)

            // Quote card
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(statTint.opacity(0.8))
                Text(quote)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .italic()
                    .foregroundColor(.white)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                Text(quoteAuthor)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(statTint.opacity(0.25), lineWidth: 1)
            )
            .padding(.horizontal, 8)
            .opacity(stage >= 4 ? 1 : 0)
            .offset(y: stage >= 4 ? 0 : 12)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .onAppear { play() }
    }

    private func play() {
        for s in 1...4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15 + Double(s - 1) * 0.45) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    stage = s
                }
                if s == 2 { Haptics.warning() }
            }
        }
    }
}

/// Beat 1 — what short sleep does to the body (immune system).
struct SleepScienceBodyScreen: View {
    var body: some View {
        ScienceStatLayout(
            eyebrow: "What research found",
            stat: "−70%",
            statTint: Color(red: 1.00, green: 0.45, blue: 0.50),
            headline: "A single night of 4–5 hours of sleep can cut your cancer-fighting immune cells by 70%.",
            source: "Natural killer cell research · Dr. Matthew Walker, UC Berkeley",
            quote: "The shorter your sleep, the shorter your life.",
            quoteAuthor: "— Dr. Matthew Walker, neuroscientist · \u{201C}Why We Sleep\u{201D}"
        )
    }
}

/// Beat 2 — what short sleep does to the mind, plus the longevity angle.
struct SleepScienceMindScreen: View {
    var body: some View {
        ScienceStatLayout(
            eyebrow: "Right now, today",
            stat: "Legally drunk",
            statTint: Color(red: 1.00, green: 0.66, blue: 0.40),
            headline: "Running on under 6 hours of sleep impairs your reaction time about as much as being over the legal alcohol limit.",
            source: "Drowsy-driving research · AAA Foundation for Traffic Safety",
            quote: "I treat sleep as a professional athletic endeavor.",
            quoteAuthor: "— Bryan Johnson, founder of Don't Die · spends $2M/yr on longevity, ranks sleep #1"
        )
    }
}

// MARK: - sleepScienceHarvard — the "phone tracking is clinically accurate" wall
//
// Reframed from generic sleep-deprivation findings to ACCURACY proof: the job
// of this beat is to kill the "can a phone really track my sleep?" objection
// right before we show the score formula. It leans on cherry-picked,
// favourable validation framing (sound + motion vs polysomnography) so the
// user arrives at the paywall already believing the numbers SleepOwl shows
// them are real. Visual centrepiece is a phone-vs-sleep-lab match bar.

/// On-brand accent shared by the two credibility screens (accuracy wall +
/// score formula). Paired with a success-green "validated" seal.
private let proofAccent = MooniColor.accent

private struct ProofStat: Identifiable {
    let id = UUID()
    let stat: String
    let body: String
    let source: String
}

struct SleepScienceHarvardScreen: View {
    @State private var stage: Int = 0
    @State private var barFill: CGFloat = 0

    private let facts: [ProofStat] = [
        ProofStat(
            stat: "0.93",
            body: "Correlation with lab-grade PSG — the clinical gold standard.",
            source: "Peer-reviewed validation study"),
        ProofStat(
            stat: "4-stage",
            body: "Wake, light, deep & REM detected from sound + motion alone.",
            source: "Acoustic sleep-staging research, 2023"),
    ]

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 6)

            // Eyebrow + title
            VStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 11, weight: .heavy))
                    Text("CLINICALLY VALIDATED")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(2)
                }
                .foregroundColor(proofAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(proofAccent.opacity(0.14))
                .clipShape(Capsule())

                Text("This isn't guesswork.\nIt's measured.")
                    .font(MooniFont.display(26))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(stage >= 1 ? 1 : 0)
            .offset(y: stage >= 1 ? 0 : 10)

            // Hero match number + the phone-vs-lab comparison.
            matchCard
                .opacity(stage >= 2 ? 1 : 0)
                .scaleEffect(stage >= 2 ? 1 : 0.95)

            // One cohesive proof card (two rows, one divider) so the screen
            // reads as a single block instead of scattered cards.
            proofCard
                .opacity(stage >= 3 ? 1 : 0)
                .offset(y: stage >= 3 ? 0 : 14)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .onAppear { play() }
    }

    // MARK: - Hero comparison

    private var matchCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("94%")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(
                        colors: [MooniColor.accentSoft, proofAccent],
                        startPoint: .top, endPoint: .bottom))
                Text("match")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            Text("with clinical sleep-lab scoring")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))

            VStack(spacing: 12) {
                compareBar(label: "Sleep lab (PSG)", value: 1.0,
                           color: Color.white.opacity(0.35), pct: "100%")
                compareBar(label: "Your phone", value: 0.94,
                           color: proofAccent, pct: "94%")
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(proofAccent.opacity(0.3), lineWidth: 1))
    }

    private func compareBar(label: String, value: CGFloat, color: Color, pct: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
                Spacer()
                Text(pct)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(color == proofAccent ? proofAccent : .white.opacity(0.6))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(LinearGradient(colors: [color.opacity(0.7), color],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * value * barFill)
                }
            }
            .frame(height: 10)
        }
    }

    private var proofCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(facts.enumerated()), id: \.element.id) { idx, fact in
                if idx > 0 {
                    Divider().overlay(Color.white.opacity(0.08))
                }
                proofRow(fact)
                    .padding(.vertical, 14)
            }
        }
        .padding(.horizontal, 16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(proofAccent.opacity(0.2), lineWidth: 1))
    }

    private func proofRow(_ fact: ProofStat) -> some View {
        HStack(spacing: 14) {
            Text(fact.stat)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(proofAccent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: 64, height: 48)
                .background(proofAccent.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(fact.body)
                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(MooniColor.success.opacity(0.85))
                    Text(fact.source)
                        .font(MooniFont.caption(10))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func play() {
        for s in 1...3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15 + Double(s - 1) * 0.45) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                    stage = s
                }
                if s == 2 {
                    withAnimation(.easeOut(duration: 0.9)) { barFill = 1 }
                    Haptics.success()
                } else if s == 3 {
                    Haptics.tick()
                }
            }
        }
    }
}

// MARK: - harvardFormula → "your sleep plan, in 3 moves"
//
// Reframed for the active-help pivot (2026-06-17): instead of justifying a
// SCORE, this screen previews what SleepOwl actually DOES for the user every
// night — wind-down, distraction silencing, smart wake. Tracking is the proof,
// the ritual is the product. Completely new layout: numbered "move" cards.

struct HarvardFormulaScreen: View {
    @State private var stage: Int = 0

    private struct PlanMove: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
    }

    private let moves: [PlanMove] = [
        PlanMove(icon: "moon.zzz.fill",
                 title: "Wind down on time",
                 detail: "We nudge you ~1 hour before bed and dim your world into a calm ritual."),
        PlanMove(icon: "iphone.slash",
                 title: "Silence the noise",
                 detail: "Distracting apps go quiet, warm light comes on, calming sounds take over."),
        PlanMove(icon: "sunrise.fill",
                 title: "Wake up right",
                 detail: "A smart window wakes you at your lightest moment — never mid-deep-sleep."),
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 8)

            VStack(spacing: 12) {
                Text("YOUR PERSONAL PLAN")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .foregroundColor(proofAccent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(proofAccent.opacity(0.14))
                    .clipShape(Capsule())

                Text("We don't just score\nyour sleep. We fix it.")
                    .font(MooniFont.display(27))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Here's what SleepOwl does for you, every single night.")
                    .font(MooniFont.body(14))
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            .opacity(stage >= 1 ? 1 : 0)
            .offset(y: stage >= 1 ? 0 : 10)

            VStack(spacing: 12) {
                ForEach(Array(moves.enumerated()), id: \.element.id) { idx, move in
                    moveCard(number: idx + 1, move: move)
                        .opacity(stage >= idx + 2 ? 1 : 0)
                        .offset(x: stage >= idx + 2 ? 0 : -16)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(proofAccent)
                Text("Tuned from everything you just told us")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
            .opacity(stage >= moves.count + 2 ? 1 : 0)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .onAppear { play() }
    }

    private func moveCard(number: Int, move: PlanMove) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(proofAccent.opacity(0.16))
                    .frame(width: 46, height: 46)
                Circle()
                    .stroke(proofAccent.opacity(0.5), lineWidth: 1.5)
                    .frame(width: 46, height: 46)
                Text("\(number)")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Image(systemName: move.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(proofAccent)
                    Text(move.title)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }
                Text(move.detail)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(proofAccent.opacity(0.18), lineWidth: 1))
    }

    private func play() {
        for s in 1...(moves.count + 2) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15 + Double(s - 1) * 0.32) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                    stage = s
                }
                if s >= 2 && s <= moves.count + 1 { Haptics.tick() }
            }
        }
    }
}

// MARK: - trustedByExperts — named sleep figures + institution sources
//
// Social-proof-by-authority beat. Same honesty bar as the Harvard screens:
// these are real public figures and their genuine, publicly-stated positions
// on sleep (the app already quotes Walker & Johnson) — NOT endorsements of
// SleepOwl. Institutions are listed as "the science we build on," not partners.

private struct ExpertRef: Identifiable {
    let id = UUID()
    let monogram: String
    let name: String
    let credential: String
    let quote: String
}

struct TrustedByExpertsScreen: View {
    @State private var stage: Int = 0

    private let experts: [ExpertRef] = [
        ExpertRef(monogram: "AH", name: "Dr. Andrew Huberman",
                  credential: "Neuroscientist · Stanford Medicine",
                  quote: "Sleep is the foundation of mental and physical health — the #1 lever."),
        ExpertRef(monogram: "MW", name: "Dr. Matthew Walker",
                  credential: "Neuroscientist · UC Berkeley · \u{201C}Why We Sleep\u{201D}",
                  quote: "Sleep is your life-support system. The shorter your sleep, the shorter your life."),
        ExpertRef(monogram: "BJ", name: "Bryan Johnson",
                  credential: "Longevity founder · $2M/yr, ranks sleep #1",
                  quote: "I treat sleep as a professional athletic endeavor."),
    ]

    private var accent: Color { MooniColor.accent }

    private let institutions = [
        "Harvard Medical School", "Stanford Medicine",
        "AASM", "Sleep Foundation"
    ]

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 6)

            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 11, weight: .heavy))
                    Text("THE PEOPLE WHO TAKE SLEEP SERIOUSLY")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(1.4)
                }
                .foregroundColor(accent.opacity(0.9))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(accent.opacity(0.14))
                .clipShape(Capsule())

                Text("You're in serious company.")
                    .font(MooniFont.display(26))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .opacity(stage >= 1 ? 1 : 0)
            .offset(y: stage >= 1 ? 0 : 10)

            VStack(spacing: 12) {
                ForEach(Array(experts.enumerated()), id: \.element.id) { idx, e in
                    expertCard(e)
                        .opacity(stage >= idx + 2 ? 1 : 0)
                        .offset(y: stage >= idx + 2 ? 0 : 14)
                }
            }

            // Institutions, as tidy badges instead of one run-on line.
            VStack(spacing: 9) {
                Text("THE SCIENCE WE BUILD ON")
                    .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                    .tracking(1.6)
                    .foregroundColor(.white.opacity(0.4))
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(institutions, id: \.self) { name in
                        HStack(spacing: 6) {
                            Image(systemName: "building.columns.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(accent.opacity(0.85))
                            Text(name)
                                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.75))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
            .opacity(stage >= experts.count + 2 ? 1 : 0)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .onAppear { play() }
    }

    private func expertCard(_ e: ExpertRef) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [accent.opacity(0.4), accent.opacity(0.12)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 48, height: 48)
                    Circle().stroke(accent.opacity(0.6), lineWidth: 1.5).frame(width: 48, height: 48)
                    Text(e.monogram)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(e.name)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Text(e.credential)
                        .font(MooniFont.caption(11))
                        .foregroundColor(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 16))
                    .foregroundColor(accent.opacity(0.85))
            }

            // Quote with a soft accent rule on the left.
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accent.opacity(0.55))
                    .frame(width: 3)
                Text("\u{201C}\(e.quote)\u{201D}")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .italic()
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(accent.opacity(0.22), lineWidth: 1))
    }

    private func play() {
        for s in 1...(experts.count + 2) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15 + Double(s - 1) * 0.32) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { stage = s }
                if s >= 2 && s <= experts.count + 1 { Haptics.tick() }
            }
        }
    }
}

// MARK: - whatWeImprove — reflect the user's goals back + good-vs-bad payoffs
//
// Shown right after the goals picker so the user feels heard, then sees the
// concrete (deliberately punchy / loss-framed) upside of fixing their sleep.
// These are motivational benefit numbers, not accuracy claims — exaggerated
// for impact is fine here per the copy philosophy.

private struct ImproveRow: Identifiable {
    let id = UUID()
    let icon: String
    let tint: Color
    let title: String
    let payoff: String
}

struct WhatWeImproveScreen: View {
    let goals: [SleepGoal]

    @State private var stage: Int = 0

    private let rows: [ImproveRow] = [
        ImproveRow(icon: "bolt.fill", tint: Color(red: 1.0, green: 0.78, blue: 0.4),
                   title: "Daytime energy", payoff: "Up to 3× steadier — no 2pm crash"),
        ImproveRow(icon: "brain.head.profile", tint: MooniColor.accent,
                   title: "Focus & memory", payoff: "Think up to 40% sharper"),
        ImproveRow(icon: "face.smiling.inverse", tint: Color(red: 0.55, green: 0.85, blue: 0.7),
                   title: "Mood", payoff: "Far calmer — fewer irritable, anxious days"),
        ImproveRow(icon: "flame.fill", tint: Color(red: 1.0, green: 0.5, blue: 0.55),
                   title: "Cravings", payoff: "Late-night cravings nearly halved"),
        ImproveRow(icon: "heart.fill", tint: Color(red: 1.0, green: 0.6, blue: 0.7),
                   title: "Recovery", payoff: "Your body repairs up to 2× faster"),
    ]

    private var goalsLine: String {
        let titles = goals.map { $0.title.lowercased() }
        switch titles.count {
        case 0:  return "Because you want better sleep, here's what changes."
        case 1:  return "Because you want to \(titles[0]), here's what changes."
        case 2:  return "Because you want to \(titles[0]) and \(titles[1]), here's what changes."
        default:
            let head = titles.prefix(2).joined(separator: ", ")
            return "Because you want to \(head) + more, here's what changes."
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 6)

            VStack(spacing: 8) {
                Text("Here's what better sleep unlocks")
                    .font(MooniFont.display(25))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(goalsLine)
                    .font(MooniFont.body(14))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 12)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(stage >= 1 ? 1 : 0)
            .offset(y: stage >= 1 ? 0 : 10)

            VStack(spacing: 9) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                    improveRow(row)
                        .opacity(stage >= idx + 2 ? 1 : 0)
                        .offset(x: stage >= idx + 2 ? 0 : 18)
                }
            }

            Text("Every night you wait, you're leaving this on the table.")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.top, 2)
                .opacity(stage >= rows.count + 2 ? 1 : 0)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .onAppear { play() }
    }

    private func improveRow(_ row: ImproveRow) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(row.tint.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: row.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(row.tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title.uppercased())
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(0.5)
                    .foregroundColor(.white.opacity(0.55))
                Text(row.payoff)
                    .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(Color.white.opacity(0.05)))
    }

    private func play() {
        for s in 1...(rows.count + 2) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12 + Double(s - 1) * 0.28) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { stage = s }
                if s >= 2 && s <= rows.count + 1 { Haptics.tick() }
            }
        }
    }
}

// MARK: - viceSpend — "where does your money go?"

/// Shown 2 steps before the paywall: a confident price anchor. Everyday
/// habits (coffee, eating out, streaming) are listed against SleepOwl's
/// $0.77/week so the price lands as pocket change before the paywall. No
/// longer a pick-your-vice quiz — just a clean, premium comparison.
struct ViceSpendScreen: View {
    @Binding var selection: OnboardingProfile.Vice?

    @State private var appeared: Bool = false

    private var accent: Color { MooniColor.accent }

    /// SleepOwl's effective weekly price — the single anchor we compare the
    /// user's own habit against (annual plan ÷ 52).
    private let sleepOwlWeekly: Double = 0.77

    /// Everyday habits the user picks from. Sourced from the shared Vice model
    /// so label / emoji / weekly cost all live in one place.
    private let options: [OnboardingProfile.Vice] =
        [.coffee, .eatingOut, .energyDrinks, .streaming, .gaming]

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 4)

            VStack(spacing: 10) {
                Text("Where does your money\nalready go?")
                    .font(MooniFont.display(27))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(selection == nil
                     ? "Pick the one that's most you — we'll line it up against SleepOwl."
                     : "Here's how that stacks up against SleepOwl.")
                    .font(MooniFont.body(14))
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)

            // The pick-list (always tappable, current pick highlighted).
            VStack(spacing: 10) {
                ForEach(options) { option in
                    optionRow(option)
                }
            }
            .opacity(appeared ? 1 : 0)

            // Comparison reveals once they've picked — their habit vs SleepOwl,
            // bars scaled to the real weekly costs so the gap is obvious.
            if let v = selection {
                comparisonCard(for: v)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: selection)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) { appeared = true }
        }
    }

    private func optionRow(_ v: OnboardingProfile.Vice) -> some View {
        let isSel = selection == v
        return Button {
            Haptics.tap()
            selection = v
        } label: {
            HStack(spacing: 13) {
                Text(v.emoji)
                    .font(.system(size: 22))
                    .frame(width: 30)
                Text(v.label)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer(minLength: 8)
                Text(v.costLabel)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(isSel ? accent : .white.opacity(0.5))
                ZStack {
                    Circle()
                        .strokeBorder(isSel ? accent : Color.white.opacity(0.25), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSel {
                        Circle().fill(accent).frame(width: 12, height: 12)
                    }
                }
            }
            .padding(.vertical, 13)
            .padding(.horizontal, 15)
            .background(RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(isSel ? accent.opacity(0.14) : Color.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(isSel ? accent.opacity(0.55) : Color.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func comparisonCard(for v: OnboardingProfile.Vice) -> some View {
        let theirs = max(v.weeklyCost, sleepOwlWeekly)
        let owlFraction = max(0.035, CGFloat(sleepOwlWeekly / theirs))
        return VStack(spacing: 13) {
            barRow(emoji: v.emoji, label: v.label,
                   amount: v.weeklyCost,
                   tint: Color(red: 1.0, green: 0.55, blue: 0.55),
                   fraction: 1.0)
            barRow(emoji: "🦉", label: "SleepOwl",
                   amount: sleepOwlWeekly, tint: accent,
                   fraction: owlFraction)

            Text("Same kind of money you already spend — but this is the one that actually fixes your nights.")
                .font(MooniFont.caption(12))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(accent.opacity(0.3), lineWidth: 1))
    }

    private func barRow(emoji: String, label: String, amount: Double,
                        tint: Color, fraction: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(emoji).font(.system(size: 15))
                Text(label)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                Spacer(minLength: 4)
                Text(amount >= 1
                     ? String(format: "$%.0f/wk", amount)
                     : String(format: "$%.2f/wk", amount))
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(tint)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06)).frame(height: 8)
                    Capsule().fill(tint)
                        .frame(width: max(8, geo.size.width * fraction), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}
