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
        .onAppear { play() }
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
                    Text("With Mooni")
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

            // The chart itself.
            GeometryReader { geo in
                let plot = CGSize(width: geo.size.width, height: geo.size.height)
                ZStack {
                    // "Without Mooni" — flat trailing curve, drawn faint.
                    smoothCurve(values: withoutMooni, in: plot, drawProgress: draw)
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
                                visible: draw > 0.97)

                    // "With Mooni" — the rising hero curve.
                    smoothArea(values: withMooni, in: plot, drawProgress: draw)
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
                    smoothCurve(values: withMooni, in: plot, drawProgress: draw)
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
                        .shadow(color: mooniTint.opacity(0.5), radius: 6)
                    endpointDot(values: withMooni, at: 0, in: plot,
                                color: .white,
                                visible: draw > 0.01)
                    endpointDot(values: withMooni,
                                at: withMooni.count - 1,
                                in: plot,
                                color: .white,
                                visible: draw > 0.97,
                                halo: true)
                }
            }
            .frame(height: 180)

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

    /// Maps a sample index + value to a plot-space point. Indices span the
    /// full width; values are mapped into [chartYMin, chartYMax].
    private func point(at i: Int, value: Double, in size: CGSize) -> CGPoint {
        let xRatio = CGFloat(i) / CGFloat(withMooni.count - 1)
        let yRatio = 1 - CGFloat((value - chartYMin) / (chartYMax - chartYMin))
        return CGPoint(x: xRatio * size.width,
                       y: max(0, min(yRatio, 1)) * size.height)
    }

    /// Number of segments to draw given current draw progress.
    private func drawnCount(_ progress: CGFloat, total: Int) -> Int {
        max(1, Int(round(CGFloat(total - 1) * progress)) + 1)
    }

    /// Smooth catmull-rom-ish curve via mid-point cubic interpolation.
    /// Keeps the line organic without using Swift Charts.
    private func smoothCurve(values: [Double],
                             in size: CGSize,
                             drawProgress: CGFloat) -> Path {
        Path { p in
            let count = drawnCount(drawProgress, total: values.count)
            guard count >= 1 else { return }
            let pts = (0..<count).map {
                point(at: $0, value: values[$0], in: size)
            }
            p.move(to: pts[0])
            if pts.count == 1 { return }
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
    }

    /// Area fill underneath a curve — closes back to the baseline.
    private func smoothArea(values: [Double],
                            in size: CGSize,
                            drawProgress: CGFloat) -> Path {
        Path { p in
            let count = drawnCount(drawProgress, total: values.count)
            guard count >= 1 else { return }
            let pts = (0..<count).map {
                point(at: $0, value: values[$0], in: size)
            }
            p.move(to: CGPoint(x: pts[0].x, y: size.height))
            p.addLine(to: pts[0])
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
            if let last = pts.last {
                p.addLine(to: CGPoint(x: last.x, y: size.height))
            }
            p.closeSubpath()
        }
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

    private func play() {
        currentScore = Int(withMooni[0])

        // 1) Title lands. Then the card fades in 0.45s later.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                cardVisible = true
            }
        }
        // 2) Draw both curves simultaneously over ~1.8s.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 1.8)) {
                draw = 1.0
            }
        }
        // 3) Score number ticks up to the final value as the curve draws.
        let totalTicks = withMooni.count
        let drawDuration: Double = 1.8
        for i in 0..<totalTicks {
            let t = Double(i) / Double(totalTicks - 1)
            DispatchQueue.main.asyncAfter(
                deadline: .now() + 0.8 + drawDuration * t
            ) {
                currentScore = Int(withMooni[i])
                if i == totalTicks / 2 || i == totalTicks - 1 {
                    Haptics.tick()
                }
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
                        manualJournal
                            .opacity(1 - Double(phase))
                            .scaleEffect(1 - 0.06 * phase)
                            .rotationEffect(.degrees(Double(phase) * -4))
                            .offset(x: -phase * 18, y: phase * 8)

                        liveReport
                            .opacity(Double(phase))
                            .scaleEffect(0.92 + 0.08 * phase)
                            .offset(y: (1 - phase) * 16)
                    }
                    .transition(.opacity)
                } else {
                    HStack(alignment: .top, spacing: 8) {
                        VStack(spacing: 6) {
                            sideBySideHeader(label: "BEFORE",
                                             tint: Color.white.opacity(0.55))
                            manualJournal
                                .frame(maxWidth: .infinity)
                        }
                        VStack(spacing: 6) {
                            sideBySideHeader(label: "WITH SLEEPOWL",
                                             tint: Color(red: 0.78, green: 0.78, blue: 1.0))
                            liveReport
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .frame(height: 360)
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

    private var manualJournal: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("MY SLEEP JOURNAL")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .foregroundColor(.black.opacity(0.55))
                Spacer()
                Text("LAST WEEK")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .tracking(1.2)
                    .foregroundColor(.black.opacity(0.4))
            }

            VStack(alignment: .leading, spacing: 9) {
                journalLine("Mon", "11pm? woke at 6, felt rough")
                journalLine("Tue", "forgot to log 😬")
                journalLine("Wed", "slept ok – maybe 7h? not sure")
                journalLine("Thu", "couldn't fall asleep. 1am? 5h?")
                journalLine("Fri", "—")
                journalLine("Sat", "long night, can't remember")
                journalLine("Sun", "skipped")
            }

            Spacer(minLength: 0)

            HStack {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.black.opacity(0.55))
                Text("3 of 7 nights logged. None measured.")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.black.opacity(0.55))
                Spacer()
            }
        }
        .padding(18)
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

    private func journalLine(_ day: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(day)
                .font(.system(size: 12, weight: .heavy, design: .serif))
                .foregroundColor(.black.opacity(0.7))
                .frame(width: 32, alignment: .leading)
            Text(text)
                .font(.system(size: 13, weight: .regular, design: .serif))
                .italic()
                .foregroundColor(.black.opacity(0.65))
        }
    }

    // MARK: Live Mooni report card

    private var liveReport: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.white)
                    Text("SleepOwl")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
                Spacer()
                Text("LAST NIGHT")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(1.5)
                    .foregroundColor(.white.opacity(0.5))
            }

            // Big sleep score reveal — copies the home ring style.
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 7)
                        .frame(width: 78, height: 78)
                    Circle()
                        .trim(from: 0, to: 0.87 * hypnoFill)
                        .stroke(Color.white,
                                style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .frame(width: 78, height: 78)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: -2) {
                        Text("87")
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .opacity(scoreVisible ? 1 : 0)
                        Text("score")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.55))
                            .opacity(scoreVisible ? 1 : 0)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("7h 38m")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Text("11:42p → 7:20a")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer(minLength: 0)
            }

            // Animated hypnogram — the wow visual.
            hypnogram
                .frame(height: 60)

            // Stage breakdown bars.
            VStack(spacing: 8) {
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
        .padding(18)
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
                bucket(label: "Mooni",  fill: mooniFill,  color: .white)
            }

            Text("Manual logging leaks. Mooni fills the bucket on its own.")
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
        }
    }

    // MARK: Faux iOS dialog

    private var mockDialog: some View {
        ZStack {
            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    Text("\"SleepOwl\" Would Like to\nSend You Notifications")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                    Text("Bedtime nudges and morning recaps.")
                        .font(.system(size: 12))
                        .foregroundColor(.black.opacity(0.55))
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 18)

                Divider().background(Color.black.opacity(0.18))

                // Two SHORT side-by-side buttons — replaces the previous
                // full-width Don't Allow / Allow bars that read as ugly.
                HStack(spacing: 10) {
                    iosButton(title: "Don't Allow", bold: false) {
                        triggerRealFlow()
                    }
                    iosButton(title: "Allow", bold: true) {
                        triggerRealFlow()
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .frame(maxWidth: 280)
            .background(Color(red: 0.95, green: 0.95, blue: 0.96))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.black.opacity(0.45), radius: 20, y: 8)

            // Animated pointing finger — hovers just above the Allow button.
            // Dialog sits centered in the ZStack; the button row is well below
            // center (title block + divider + button padding), so we offset
            // the finger DOWN so its fingertip lands right at the top of the
            // Allow pill instead of floating in the middle of the title text.
            Text("👆")
                .font(.system(size: 30))
                .offset(x: 60, y: pointerBob ? 64 : 76)
                .opacity(triggered ? 0 : 1)
                .animation(.easeInOut(duration: 0.25), value: triggered)
        }
    }

    private func iosButton(title: String, bold: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: bold ? .semibold : .regular))
                .foregroundColor(.blue)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(minWidth: 96)
                .background(Color.white)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.black.opacity(0.10), lineWidth: 0.5))
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
            subtitle: "Ratings are how new people find Mooni. It takes five seconds."
        ) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    .frame(width: 200, height: 200)
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    .frame(width: 150, height: 150)
                    .scaleEffect(twinkle ? 1.04 : 1)
                HStack(spacing: 7) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(goldTint)
                            .shadow(color: goldTint.opacity(0.55), radius: 6)
                    }
                }
                .scaleEffect(twinkle ? 1.06 : 1)
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
                .stroke(Color.white.opacity(0.12), lineWidth: 6)
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(Color.white,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(progress * 100))%")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: 160, height: 160)
    }

    private var subBars: some View {
        VStack(spacing: 14) {
            ForEach(subBarLabels.indices, id: \.self) { idx in
                let label = subBarLabels[idx]
                let local = subProgress(for: idx)
                HStack {
                    Text(label)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Text(local >= 1 ? "Done" : "")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.10))
                        Capsule()
                            .fill(Color.white)
                            .frame(width: geo.size.width * local)
                            .animation(.easeInOut(duration: 0.4), value: local)
                    }
                }
                .frame(height: 4)
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
        VStack(spacing: 24) {
            Spacer(minLength: 8)

            VStack(spacing: 8) {
                Text("Your plan is ready\(petName.isEmpty ? "" : ", \(petName)").")
                    .font(MooniFont.display(26))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text("Your home screen will look like this every morning.")
                    .font(MooniFont.body(14))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }

            // ONE widget mock, centered. Mirrors the real Medium widget
            // visually (ring on the left, big score + duration on the right).
            mediumWidgetMock
                .frame(maxWidth: 320)
                .frame(height: 140)
                .padding(.horizontal, 24)
                .opacity(widgetAppear ? 1 : 0)
                .scaleEffect(widgetAppear ? 1 : 0.92)
                .offset(y: widgetAppear ? 0 : 8)

            // ONE row of plain text — no card backgrounds, just values.
            HStack(spacing: 0) {
                statColumn(label: "BEDTIME", value: idealBedtime.hourMinuteString)
                divider
                statColumn(label: "WAKE",    value: wakeTime.hourMinuteString)
                divider
                statColumn(label: "TARGET",  value: sleepDurationLabel)
            }
            .padding(.horizontal, 12)
            .opacity(widgetAppear ? 1 : 0)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .onAppear { animateIn() }
    }

    // MARK: Widget mock

    private var mediumWidgetMock: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.13, green: 0.12, blue: 0.26),
                            Color(red: 0.06, green: 0.05, blue: 0.16)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.8)

            HStack(alignment: .center, spacing: 16) {
                ring
                    .frame(width: 92, height: 92)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 9, weight: .black))
                        Text("SleepOwl")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .tracking(0.3)
                    }
                    .foregroundColor(.white.opacity(0.7))

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(scoreCount)")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, scoreTint],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: scoreTint.opacity(0.55), radius: 8)
                            .contentTransition(.numericText())
                        Text("GREAT")
                            .font(.system(size: 8, weight: .heavy, design: .rounded))
                            .tracking(0.4)
                            .foregroundColor(scoreTint)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(scoreTint.opacity(0.22)))
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "bed.double.fill")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(scoreTint)
                        Text(sleepDurationLabel)
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        Text("·")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(.white.opacity(0.4))
                        Text(bedToWakeLabel)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
        }
    }

    private var ring: some View {
        ZStack {
            Circle()
                .fill(scoreTint.opacity(0.22))
                .blur(radius: 10)
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 7)
            Circle()
                .trim(from: 0, to: ringTrim)
                .stroke(
                    AngularGradient(
                        colors: [scoreTint.opacity(0.55), scoreTint, .white],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: scoreTint.opacity(0.55), radius: 8)

            // Mascot stand-in — soft moon disk.
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.95, green: 0.92, blue: 0.78),
                                Color(red: 0.82, green: 0.76, blue: 0.95)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                Circle()
                    .fill(Color.black.opacity(0.50))
                    .frame(width: 40, height: 40)
                    .offset(x: 12, y: -5)
                    .mask(Circle().frame(width: 50, height: 50))
            }
        }
    }

    // MARK: Stat row

    private func statColumn(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .tracking(1.2)
                .foregroundColor(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(width: 1, height: 28)
    }

    // MARK: Animation

    private func animateIn() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                widgetAppear = true
            }
        }
        withAnimation(.easeOut(duration: 1.4).delay(0.25)) {
            ringTrim = CGFloat(projectedScore) / 100
        }
        Timer.scheduledTimer(withTimeInterval: 0.018, repeats: true) { t in
            DispatchQueue.main.async {
                if scoreCount < projectedScore {
                    scoreCount += 1
                } else {
                    t.invalidate()
                }
            }
        }
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
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)

            // Faint guide line.
            GeometryReader { geo in
                Path { p in
                    let y = geo.size.height * 0.78
                    p.move(to: CGPoint(x: 24, y: y))
                    p.addLine(to: CGPoint(x: geo.size.width - 24, y: y))
                }
                .stroke(Color.white.opacity(0.18),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }

            if points.isEmpty {
                Text("Sign here")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.35))
            }

            // The drawn signature.
            Path { p in
                guard let first = points.first else { return }
                p.move(to: first)
                for pt in points.dropFirst() { p.addLine(to: pt) }
            }
            .stroke(Color.white, style: StrokeStyle(lineWidth: 2.4,
                                                    lineCap: .round,
                                                    lineJoin: .round))
        }
        .frame(height: 170)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in points.append(v.location) }
        )
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
                    .frame(width: 290, height: 200)
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

    @ViewBuilder
    private var widgetMock: some View {
        switch kind {
        case .small: smallWidget
        case .medium: mediumWidget
        }
    }

    private var smallWidget: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.13, green: 0.10, blue: 0.28),
                            Color(red: 0.07, green: 0.05, blue: 0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing)
                )
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(.white.opacity(0.75))
                    Text("SLEEPOWL")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .tracking(1.4)
                        .foregroundColor(.white.opacity(0.75))
                    Spacer()
                }
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("87")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Text("/100")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
                }
                Text("7h 32m · 6 day streak")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))
            }
            .padding(14)
        }
        .frame(width: 150, height: 150)
    }

    private var mediumWidget: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.13, green: 0.10, blue: 0.28),
                            Color(red: 0.07, green: 0.05, blue: 0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing)
                )
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(.white.opacity(0.75))
                        Text("SLEEPOWL")
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .tracking(1.4)
                            .foregroundColor(.white.opacity(0.75))
                    }
                    Spacer(minLength: 0)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("87")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        Text("/100")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundColor(.white.opacity(0.55))
                    }
                    Text("Last night")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
                }
                .frame(width: 96, alignment: .leading)

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1)

                VStack(alignment: .leading, spacing: 8) {
                    Text("THIS WEEK")
                        .font(.system(size: 8, weight: .heavy, design: .rounded))
                        .tracking(1.4)
                        .foregroundColor(.white.opacity(0.55))
                    sparkline
                        .frame(height: 36)
                    HStack(spacing: 10) {
                        miniStat(label: "Avg", value: "84")
                        miniStat(label: "Streak", value: "6d")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
        }
        .frame(width: 310, height: 150)
    }

    private var sparkline: some View {
        let pts: [CGFloat] = [0.55, 0.62, 0.58, 0.71, 0.74, 0.78, 0.87]
        return GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let step = w / CGFloat(pts.count - 1)
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h - h * pts[0]))
                    for i in 1..<pts.count {
                        p.addLine(to: CGPoint(x: CGFloat(i) * step,
                                              y: h - h * pts[i]))
                    }
                }
                .stroke(Color.white,
                        style: StrokeStyle(lineWidth: 1.6,
                                           lineCap: .round,
                                           lineJoin: .round))
                Circle()
                    .fill(Color.white)
                    .frame(width: 5, height: 5)
                    .position(x: w, y: h - h * pts.last!)
            }
        }
    }

    private func miniStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 8, weight: .heavy, design: .rounded))
                .tracking(1.0)
                .foregroundColor(.white.opacity(0.55))
            Text(value)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

