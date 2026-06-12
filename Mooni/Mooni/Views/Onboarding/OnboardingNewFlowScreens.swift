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
    /// 28-day projected scores climbing 48 → 88 over 4 weeks.
    private let withMooni: [Double] = [
        48, 52, 49, 56, 58, 61, 65,
        67, 70, 72, 74, 76, 78, 77,
        78, 80, 81, 83, 82, 84, 85,
        85, 86, 86, 87, 88, 87, 88
    ]
    /// "Without" stays flat in the 48-55 band — gentle noise, no climb.
    private let withoutMooni: [Double] = [
        48, 50, 48, 51, 49, 52, 50,
        49, 51, 50, 52, 49, 51, 50,
        51, 52, 49, 50, 51, 49, 50,
        51, 50, 52, 49, 50, 51, 50
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
        Color(red: 0.78, green: 0.78, blue: 1.0)
    }

    private let chartYMin: Double = 40
    private let chartYMax: Double = 95

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
            }

            chartCard
                .padding(.horizontal, 8)
                .opacity(cardVisible ? 1 : 0)
                .scaleEffect(cardVisible ? 1 : 0.96)
                .offset(y: cardVisible ? 0 : 12)

            Text("Most people see real change by week 4.")
                .font(MooniFont.body(13))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
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
                    // "Without SleepOwl" — flat trailing curve, drawn faint.
                    ProjectedCurveShape(values: withoutMooni, yMin: chartYMin,
                                        yMax: chartYMax, closed: false, progress: draw)
                        .stroke(
                            Color.white.opacity(0.30),
                            style: StrokeStyle(lineWidth: 2,
                                               lineCap: .round,
                                               lineJoin: .round)
                        )
                    endpointDot(values: withoutMooni, at: 0, in: plot,
                                color: Color.white.opacity(0.40),
                                visible: draw > 0.01)
                    endpointDot(values: withoutMooni, at: withoutMooni.count - 1,
                                in: plot,
                                color: Color.white.opacity(0.40),
                                visible: draw > 0.985)

                    // "With SleepOwl" — the rising hero curve + soft area fill.
                    ProjectedCurveShape(values: withMooni, yMin: chartYMin,
                                        yMax: chartYMax, closed: true, progress: draw)
                        .fill(
                            LinearGradient(
                                colors: [
                                    mooniTint.opacity(0.30),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    ProjectedCurveShape(values: withMooni, yMin: chartYMin,
                                        yMax: chartYMax, closed: false, progress: draw)
                        .stroke(
                            LinearGradient(
                                colors: [mooniTint, .white],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 3,
                                               lineCap: .round,
                                               lineJoin: .round)
                        )
                    endpointDot(values: withMooni, at: 0, in: plot,
                                color: .white,
                                visible: draw > 0.01)

                    // Head dot rides the tip of the hero curve while it draws.
                    // Same animatableData as the curve shape, so SwiftUI keeps
                    // them frame-locked instead of the dot lagging the line.
                    CurveHeadDotShape(values: withMooni, yMin: chartYMin,
                                      yMax: chartYMax, progress: draw)
                        .fill(Color.white)
                        .opacity(draw > 0.01 ? 1 : 0)

                    // "+40" payoff badge anchored above the terminus.
                    let endPt = point(at: withMooni.count - 1,
                                      value: withMooni[withMooni.count - 1],
                                      in: plot)
                    Text("+40")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white))
                        .position(x: min(endPt.x - 6, plot.width - 26),
                                  y: max(endPt.y - 24, 12))
                        .opacity(deltaVisible ? 1 : 0)
                        .scaleEffect(deltaVisible ? 1 : 0.6,
                                     anchor: .bottomTrailing)
                }
            }
            .frame(height: 184)

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
                     ? "From scribbles to science."
                     : "From scribbles to science.")
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
                                             tint: Color(red: 0.78, green: 0.78, blue: 1.0))
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
                         color: Color(red: 0.65, green: 0.62, blue: 1.0),
                         visible: metricsVisible >= 1)
                stageRow("REM",   duration: "1h 48m", weight: 0.50,
                         color: Color(red: 0.95, green: 0.65, blue: 0.85),
                         visible: metricsVisible >= 2)
                stageRow("Light", duration: "3h 56m", weight: 1.00,
                         color: Color(red: 0.85, green: 0.83, blue: 1.0),
                         visible: metricsVisible >= 3)
                stageRow("Awake", duration: "10m",    weight: 0.08,
                         color: Color(red: 1.0, green: 0.78, blue: 0.55),
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
                case 0:  return Color(red: 1.0, green: 0.78, blue: 0.55)
                case 1:  return Color(red: 0.95, green: 0.65, blue: 0.85)
                case 2:  return Color(red: 0.85, green: 0.83, blue: 1.0)
                default: return Color(red: 0.65, green: 0.62, blue: 1.0)
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

            // Animated pointing finger — hovers just above the Allow button
            // (the right-hand action in the two-button row).
            Text("👆")
                .font(.system(size: 30))
                .offset(x: 60, y: pointerBob ? 60 : 72)
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

    private var accent: Color { Color(red: 0.62, green: 0.62, blue: 1.00) }

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

    private var projectedScore: Int { 87 }

    /// Accent tint pulled from the real SleepWidgetPalette — "great" range.
    private var scoreTint: Color {
        Color(red: 0.62, green: 0.62, blue: 1.00)
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 2)

            // Title block
            VStack(spacing: 8) {
                Text("Your plan is ready\(petName.isEmpty ? "" : ", \(petName)").")
                    .font(MooniFont.display(28))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                Text("Built from everything you told us — here's what changes.")
                    .font(MooniFont.body(14))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            // Hero projected-score ring + the improvement it represents. This
            // is the emotional anchor: where they are now → where they'll be.
            VStack(spacing: 14) {
                heroRing
                    .frame(width: 188, height: 188)
                    .scaleEffect(widgetAppear ? 1 : 0.9)
                improvementBadge
            }
            .opacity(widgetAppear ? 1 : 0)

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

            // Progress arc
            Circle()
                .trim(from: 0, to: ringTrim)
                .stroke(
                    scoreTint,
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text("\(scoreCount)")
                    .font(.system(size: 76, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                Text("PROJECTED SCORE")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(1.6)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }

    // MARK: Plan data

    private var petNameOrDefault: String { petName.isEmpty ? "SleepOwl" : petName }

    /// Where they are now (honest, derived from their answers) → drives the
    /// "now → projected" improvement story.
    private var currentScore: Int { profile.derivedSleepScore }

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
            Text("\(currentScore)")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundColor(.white.opacity(0.55))
            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(scoreTint)
            Text("\(projectedScore)")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
            Text("projected by week 4")
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

        try? await Task.sleep(nanoseconds: 200_000_000)
        withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
            widgetAppear = true
        }

        // Draw ring and tick number concurrently over ~1.6s.
        let duration: Double = 1.6
        withAnimation(.easeOut(duration: duration)) {
            ringTrim = CGFloat(projectedScore) / 100
        }
        let totalTicks = projectedScore
        let stepNanos = UInt64(duration / Double(max(1, totalTicks))
                               * 1_000_000_000)
        for _ in 0..<totalTicks {
            scoreCount += 1
            try? await Task.sleep(nanoseconds: stepNanos)
        }
        Haptics.success()
    }
}

// MARK: - autoTrackStoneAge

struct AutoTrackStoneAgeScreen: View {
    var body: some View {
        OBStack(
            eyebrow: "Tracking, evolved",
            title: "Manual sleep journals are over.",
            subtitle: "You will not remember to log every night. We don't ask you to."
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
        Color(red: 0.62, green: 0.62, blue: 1.00)
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 4)

            VStack(spacing: 10) {
                Text("Just you and your phone.")
                    .font(MooniFont.display(26))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text("Your phone activity already tells the story.\nWe just read it — no watch, no wearable.")
                    .font(MooniFont.body(14))
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 12)
            }

            timelineCard
                .padding(.horizontal, 8)

            Text("Detected automatically. No alarms, no logging.")
                .font(MooniFont.body(12))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .onAppear { play() }
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
        Color(red: 0.62, green: 0.62, blue: 1.00)
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 8)

            VStack(spacing: 10) {
                Text("Set it once.\nForget it forever.")
                    .font(MooniFont.display(26))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                Text("Your sleep tracks itself. You wake up — the report is already there.")
                    .font(MooniFont.body(14))
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 12)
            }

            // ── Old way (3 struck-out tiles)
            HStack(spacing: 12) {
                strikedTile(title: "Smartwatch", icon: "applewatch")
                strikedTile(title: "Ring", icon: "circle.circle")
                strikedTile(title: "Manual log", icon: "pencil.and.list.clipboard")
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

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .onAppear { play() }
    }

    // MARK: - Building blocks

    private func strikedTile(title: String, icon: String) -> some View {
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
            Text(title)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
                .strikethrough(strikeProgress >= 1, color: .white.opacity(0.4))
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
                Text("Your iPhone")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                Text("Already in your pocket. Already tracking.")
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

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 6)

            VStack(spacing: 10) {
                Text("Every night, scored.")
                    .font(MooniFont.display(26))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text("Sleep Score, Deep, REM and Light — tracked automatically.")
                    .font(MooniFont.body(14))
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            scoreRing

            VStack(spacing: 10) {
                stageRow(label: "Deep",  minutes: "1h 22m", progress: deep,  color: Color(red: 0.55, green: 0.46, blue: 0.95))
                stageRow(label: "REM",   minutes: "1h 38m", progress: rem,   color: Color(red: 0.42, green: 0.66, blue: 0.96))
                stageRow(label: "Light", minutes: "4h 12m", progress: light, color: Color.white.opacity(0.55))
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .onAppear { animateIn() }
    }

    private var scoreRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 8)
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(Color.white,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(score)")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                Text("Sleep Score")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                    .foregroundColor(.white.opacity(0.55))
            }
        }
        .frame(width: 140, height: 140)
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
                     ? "A glance is all it takes."
                     : "Last night, your trend, your streak — at a tap.")
                    .font(MooniFont.body(14))
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.05),
                                Color.white.opacity(0.01)
                            ],
                            startPoint: .top,
                            endPoint: .bottom)
                    )
                    .frame(width: kind == .small ? 240 : 358, height: 212)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )

                widgetMock
                    .scaleEffect(pulse ? 1.0 : 0.96)
                    .shadow(color: .black.opacity(0.35), radius: 20, y: 8)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
                pulse = true
            }
        }
    }

    /// The REAL widget views (shared with the MooniSleepWidget target),
    /// wrapped in the same background + corner chrome WidgetKit applies.
    /// Whatever ships on the home screen is exactly what's previewed here.
    @ViewBuilder
    private var widgetMock: some View {
        switch kind {
        case .small:
            widgetChrome(width: 158, height: 158) {
                SmallSleepWidgetView(data: .sample)
            }
        case .medium:
            widgetChrome(width: 329, height: 155) {
                MediumSleepWidgetView(data: .sample)
            }
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

    private var accent: Color { Color(red: 0.62, green: 0.62, blue: 1.00) }

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

