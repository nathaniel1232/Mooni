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

// MARK: - lifeTimeline — animated sleep-score chart Day 1 → Week 8

struct LifeTimelineScreen: View {
    /// Sleep-score samples ramping from 48 (rough first nights) → 91 (week 8).
    /// Slightly noisy so it reads as real data, not a clean curve.
    private let samples: [CGFloat] = [
        48, 52, 49, 56, 58, 61, 65,        // week 1
        67, 70, 72, 74, 78, 80, 79,        // week 2
        81, 83, 84, 86, 85, 87, 88,        // week 3-4
        88, 89, 90, 90, 91, 90, 91         // week 5-8
    ]

    /// 0..1 of the chart that's been drawn so far.
    @State private var draw: CGFloat = 0
    /// Highlighted marker indices (Day 1 / Week 2 / Week 4 / Week 8).
    @State private var milestoneVisible: [Bool] = [false, false, false, false]
    /// Big score number that climbs as the line draws.
    @State private var currentScore: Int = 48

    private struct Milestone {
        let week: String
        let line: String
        /// 0..1 along the sample timeline.
        let progress: CGFloat
    }
    private let milestones: [Milestone] = [
        .init(week: "Day 1", line: "Today",              progress: 0.00),
        .init(week: "Wk 2",  line: "Mornings feel sharp", progress: 0.34),
        .init(week: "Wk 4",  line: "Energy lasts the day", progress: 0.66),
        .init(week: "Wk 8",  line: "Best sleep of your life", progress: 1.00)
    ]

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 4)

            VStack(spacing: 10) {
                Text("Eight weeks.\nA whole different sleep.")
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

            chart
                .padding(.horizontal, 8)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .onAppear { play() }
    }

    // MARK: Chart

    private var chart: some View {
        GeometryReader { geo in
            let plot = CGSize(
                width: geo.size.width,
                height: geo.size.height - 30   // leave room for week labels
            )
            ZStack {
                gridLines(in: plot)
                areaFill(in: plot)
                lineStroke(in: plot)
                headDot(in: plot)
                milestoneCallouts(in: plot)
            }
            .overlay(weekLabels.padding(.top, plot.height + 6), alignment: .top)
        }
        .frame(height: 230)
    }

    private func gridLines(in size: CGSize) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { _ in
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
            }
            Spacer()
        }
        .frame(width: size.width, height: size.height)
    }

    private var weekLabels: some View {
        HStack {
            ForEach(["W1", "W2", "W3", "W4", "W5", "W6", "W7", "W8"], id: \.self) { w in
                Text(w)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.45))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Path drawing

    private func point(at i: Int, in size: CGSize) -> CGPoint {
        let xRatio = CGFloat(i) / CGFloat(samples.count - 1)
        let yMin: CGFloat = 40
        let yMax: CGFloat = 95
        let yRatio = 1 - ((samples[i] - yMin) / (yMax - yMin))
        return CGPoint(x: xRatio * size.width,
                       y: yRatio * size.height)
    }

    /// How many path segments to draw for current `draw` progress.
    private var drawnCount: Int {
        max(1, Int(CGFloat(samples.count - 1) * draw) + 1)
    }

    private func lineStroke(in size: CGSize) -> some View {
        Path { p in
            guard drawnCount >= 1 else { return }
            p.move(to: point(at: 0, in: size))
            for i in 1..<drawnCount {
                p.addLine(to: point(at: i, in: size))
            }
        }
        .stroke(Color.white,
                style: StrokeStyle(lineWidth: 2.8,
                                   lineCap: .round,
                                   lineJoin: .round))
        .shadow(color: .white.opacity(0.4), radius: 6, y: 0)
    }

    private func areaFill(in size: CGSize) -> some View {
        Path { p in
            guard drawnCount >= 1 else { return }
            let first = point(at: 0, in: size)
            p.move(to: CGPoint(x: first.x, y: size.height))
            p.addLine(to: first)
            for i in 1..<drawnCount {
                p.addLine(to: point(at: i, in: size))
            }
            let last = point(at: drawnCount - 1, in: size)
            p.addLine(to: CGPoint(x: last.x, y: size.height))
            p.closeSubpath()
        }
        .fill(LinearGradient(
            colors: [Color.white.opacity(0.22), Color.white.opacity(0)],
            startPoint: .top,
            endPoint: .bottom))
    }

    private func headDot(in size: CGSize) -> some View {
        let head = point(at: drawnCount - 1, in: size)
        return Circle()
            .fill(Color.white)
            .frame(width: 10, height: 10)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.4), lineWidth: 4)
            )
            .position(head)
            .shadow(color: .white.opacity(0.6), radius: 8)
    }

    @ViewBuilder
    private func milestoneCallouts(in size: CGSize) -> some View {
        ForEach(milestones.indices, id: \.self) { idx in
            let m = milestones[idx]
            let sampleIdx = Int(round(m.progress * CGFloat(samples.count - 1)))
            let pt = point(at: sampleIdx, in: size)
            let above = idx == 0 || idx == 3   // edges sit above
            VStack(spacing: 4) {
                Text(m.week)
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                Text(m.line)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 84)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.20), lineWidth: 0.5)
            )
            .position(
                x: edgeClamped(pt.x, in: size.width, halfWidth: 50),
                y: above ? max(28, pt.y - 32) : min(size.height - 28, pt.y + 38)
            )
            .opacity(milestoneVisible[idx] ? 1 : 0)
            .scaleEffect(milestoneVisible[idx] ? 1 : 0.85)
        }
    }

    private func edgeClamped(_ x: CGFloat, in width: CGFloat, halfWidth: CGFloat) -> CGFloat {
        min(max(halfWidth, x), width - halfWidth)
    }

    // MARK: Animation

    private func play() {
        // Total draw 3.6s. Score number tracks the head as it climbs.
        let total = 3.6
        let frames = 60
        for f in 0..<frames {
            let t = Double(f) / Double(frames - 1)
            DispatchQueue.main.asyncAfter(deadline: .now() + total * t) {
                withAnimation(.easeOut(duration: total / Double(frames))) {
                    draw = CGFloat(t)
                }
                let i = min(samples.count - 1,
                            Int(round(CGFloat(t) * CGFloat(samples.count - 1))))
                currentScore = Int(samples[i])
            }
        }
        // Milestone callouts appear as the line crosses them.
        for (idx, m) in milestones.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + total * Double(m.progress) + 0.05) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                    milestoneVisible[idx] = true
                }
                Haptics.tick()
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

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 4)

            VStack(spacing: 8) {
                Text("From scribbles to science.")
                    .font(MooniFont.display(26))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                Text("One is a guess. The other is your sleep, measured.")
                    .font(MooniFont.body(13))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }

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
            .frame(height: 360)
            .padding(.horizontal, 4)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .onAppear { play() }
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
                Text("9 out of 10 reach")
                    .font(MooniFont.display(26))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text(goalLine)
                    .font(MooniFont.display(20))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
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

            Text("Reach their first 7-day target with SleepOwl.")
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
                Text("Let \(petName.isEmpty ? "Mooni" : petName) nudge you at bedtime.")
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
            Text("👆")
                .font(.system(size: 30))
                .offset(x: 60, y: pointerBob ? 36 : 46)
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
        case .denied:
            // Already locked out. Open Settings so the user can flip it on,
            // then advance once we see them come back foregrounded.
            if let url = URL(string: UIApplication.openSettingsURLString) {
                _ = await UIApplication.shared.open(url)
            }
            await waitForReturnFromSettings()
        case .authorized:
            // Re-entry (e.g. they navigated back). Nothing to ask.
            break
        }
        // Only NOW post the advance event. The screen stays put until the
        // user actually picked something on the real OS sheet (or returned
        // from Settings).
        NotificationCenter.default.post(
            name: .onboardingNotifAllowTapped, object: nil)
    }

    /// Resolves once the app becomes active again after a Settings detour.
    @MainActor
    private func waitForReturnFromSettings() async {
        await withCheckedContinuation { cont in
            var token: NSObjectProtocol?
            token = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { _ in
                if let token { NotificationCenter.default.removeObserver(token) }
                cont.resume()
            }
        }
    }
}

extension Notification.Name {
    static let onboardingNotifAllowTapped =
        Notification.Name("mooni.onboarding.notifAllowTapped")
}

// MARK: - ratingPledge

struct RatingPledgeScreen: View {
    @Binding var promptShown: Bool

    var body: some View {
        OBStack(
            eyebrow: "One small ask",
            title: "If this app helps you sleep, give it a rating.",
            subtitle: "Ratings are how new people find us. It takes five seconds."
        ) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    .frame(width: 110, height: 110)
                Image(systemName: "star.fill")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
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

struct PlanRevealScreen: View {
    let profile: OnboardingProfile
    let bedtime: Date
    let wakeTime: Date
    let petName: String

    @State private var rows: Int = 0

    /// Sleep need in hours, derived from age (NSF guidance, conservative).
    private var sleepNeedHours: Double {
        switch profile.age ?? 28 {
        case ..<14:  return 9.5
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
        return cal.date(byAdding: .second, value: -Int(seconds), to: wakeTime) ?? bedtime
    }

    private var deepTargetMinutes: Int {
        // ~18% of total sleep need is a reasonable deep-sleep target.
        Int(sleepNeedHours * 60 * 0.18)
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 6)

            VStack(spacing: 10) {
                Text("Your plan is ready\(petName.isEmpty ? "" : ", \(petName)").")
                    .font(MooniFont.display(26))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text("Built from your answers. Yours to keep.")
                    .font(MooniFont.body(14))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                row("Sleep target",
                    String(format: "%.1f hrs / night", sleepNeedHours),
                    icon: "moon.zzz.fill",
                    visible: rows >= 1)
                row("Ideal bedtime",
                    idealBedtime.hourMinuteString,
                    icon: "bed.double.fill",
                    visible: rows >= 2)
                row("Ideal wake",
                    wakeTime.hourMinuteString,
                    icon: "sunrise.fill",
                    visible: rows >= 3)
                row("Deep sleep target",
                    "\(deepTargetMinutes) min",
                    icon: "waveform.path.ecg",
                    visible: rows >= 4)
            }
            .padding(.horizontal, 16)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .onAppear {
            for i in 0..<4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + Double(i) * 0.45) {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                        rows = i + 1
                    }
                    Haptics.tick()
                }
            }
        }
    }

    private func row(_ title: String, _ value: String, icon: String, visible: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 38, height: 38)
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
                Text(value)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .opacity(visible ? 1 : 0)
        .offset(x: visible ? 0 : -14)
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

struct AutoTrackHowScreen: View {
    @State private var pulse: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 8)

            VStack(spacing: 10) {
                Text("Just you and your phone.")
                    .font(MooniFont.display(28))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text("No watch. No wearable. Nothing to charge.\nYour phone tracks your sleep on its own.")
                    .font(MooniFont.body(14))
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 12)
            }

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    .frame(width: 240, height: 240)
                    .scaleEffect(pulse ? 1.05 : 1)
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    .frame(width: 180, height: 180)
                    .scaleEffect(pulse ? 1.03 : 1)
                Image(systemName: "iphone.gen3")
                    .font(.system(size: 80, weight: .regular))
                    .foregroundColor(.white)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }

            VStack(spacing: 8) {
                bullet("Bedtime signal", "Phone activity tapers between 8pm–4am")
                bullet("Wake signal", "First morning unlock between 4am–noon")
                bullet("Sanity filter", "Drops windows that don't look like sleep")
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }

    private func bullet(_ title: String, _ sub: String) -> some View {
        HStack(spacing: 10) {
            Circle().fill(Color.white).frame(width: 5, height: 5)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                Text(sub)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - autoTrackAccuracy → renamed to phone-only (no PSG claims)

struct AutoTrackPhoneOnlyScreen: View {
    var body: some View {
        OBStack(
            eyebrow: "Fully automated",
            title: "Set it once. Forget it forever.",
            subtitle: "Your sleep tracks itself every night. You wake up and the report is already there."
        ) {
            HStack(spacing: 14) {
                pill(title: "No watch",   icon: "applewatch.slash")
                pill(title: "No wearable", icon: "ear")
                pill(title: "No logging",  icon: "pencil.slash")
            }
        }
    }

    private func pill(title: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            Text(title)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
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
