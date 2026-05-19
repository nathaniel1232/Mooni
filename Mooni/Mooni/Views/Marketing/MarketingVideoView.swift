import SwiftUI

/// Hidden auto-looping marketing animation used to record TikTok / Reels /
/// App-Store demo clips.
///
/// Design rules (learned the hard way from cofounder feedback):
///  • ONE fixed layout skeleton — brand on top, a fixed-height hero in the
///    middle, one big caption below. Nothing is positioned with magic
///    offsets, so nothing jumps or sits "too high / too low" between phases.
///  • The middle is DATA, not mascot. Real-feeling charts that draw in:
///    an animated hypnogram, a 7-night trend chart, a counting score ring.
///  • Less owl. It only bookends the reel (intro + outro lockup).
///  • Big text, few words. Every phase holds long enough to actually read.
///
/// Surfaced from Profile → Dev Tools → "Start Marketing Video".
struct MarketingVideoView: View {
    @Environment(\.dismiss) private var dismiss

    private enum Phase: Int, CaseIterable {
        case intro, hypnogram, trends, score, summary, outro
    }
    @State private var phase: Phase = .intro

    // Per-phase animation drivers
    @State private var introIn = false
    @State private var hypnoProgress: CGFloat = 0
    @State private var trendsProgress: CGFloat = 0
    @State private var ringProgress: CGFloat = 0
    @State private var scoreShown: Int = 0
    @State private var summaryShown = 0          // how many tiles revealed
    @State private var outroIn = false

    // Chrome / loop
    @State private var loopTask: Task<Void, Never>? = nil
    @State private var chromeTask: Task<Void, Never>? = nil
    @State private var showChrome = true

    private let bedtime = "11:42 PM"
    private let waketime = "7:18 AM"

    private var owlPet: Pet {
        var p = Pet(); p.name = "SleepOwl"; p.species = .owl; p.mood = .sleepy
        return p
    }

    // Phases that use the persistent top wordmark (data phases). Intro &
    // outro carry their own, larger branding.
    private var showsWordmark: Bool {
        switch phase {
        case .intro, .outro: return false
        default:             return true
        }
    }

    var body: some View {
        ZStack {
            MooniGradient.night.ignoresSafeArea()
            StarsBackground(count: 70).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                MarketingWordmark()
                    .opacity(showsWordmark ? 1 : 0)
                    .animation(.easeInOut(duration: 0.4), value: showsWordmark)

                Spacer().frame(height: 22)

                // Fixed-height hero — every phase draws inside the SAME box, so
                // the composition never shifts vertically.
                ZStack {
                    introHero.opacity(phase == .intro ? 1 : 0)
                    hypnoHero.opacity(phase == .hypnogram ? 1 : 0)
                    trendsHero.opacity(phase == .trends ? 1 : 0)
                    scoreHero.opacity(phase == .score ? 1 : 0)
                    summaryHero.opacity(phase == .summary ? 1 : 0)
                    outroHero.opacity(phase == .outro ? 1 : 0)
                }
                .frame(height: 380)
                .frame(maxWidth: .infinity)

                Spacer().frame(height: 26)

                // One big caption line — fixed area so it doesn't reflow.
                Text(caption)
                    .font(MooniFont.display(27))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .frame(height: 74)
                    .opacity(caption.isEmpty ? 0 : 1)
                    .id(phase)
                    .transition(.opacity)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 28)

            chrome
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .animation(.easeInOut(duration: 0.5), value: phase)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeIn(duration: 0.18)) { showChrome = true }
            scheduleChromeFade()
        }
        .onAppear { scheduleChromeFade(); startLoop() }
        .onDisappear { stopLoop() }
    }

    private var caption: String {
        switch phase {
        case .intro:     return ""
        case .hypnogram: return "Every stage, all night."
        case .trends:    return "See every night add up."
        case .score:     return ""
        case .summary:   return "Your night, explained."
        case .outro:     return ""
        }
    }

    // MARK: - Heroes

    private var introHero: some View {
        VStack(spacing: 22) {
            MarketingOwl(pet: owlPet, size: 168)
                .scaleEffect(introIn ? 1 : 0.86)
                .opacity(introIn ? 1 : 0)
            VStack(spacing: 8) {
                Text("Your sleep,\ndecoded.")
                    .font(MooniFont.display(40))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                Text("Tracked automatically while you rest.")
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textSecondary)
            }
            .opacity(introIn ? 1 : 0)
            .offset(y: introIn ? 0 : 14)
        }
    }

    private var hypnoHero: some View {
        MarketingHypnogram(progress: hypnoProgress,
                           startLabel: bedtime,
                           endLabel: waketime)
    }

    private var trendsHero: some View {
        MarketingTrendChart(progress: trendsProgress)
    }

    private var scoreHero: some View {
        VStack(spacing: 18) {
            MarketingRing(progress: ringProgress, score: scoreShown)
                .frame(width: 248, height: 248)
            Text("Your sleep score")
                .font(MooniFont.title(16))
                .foregroundColor(MooniColor.textSecondary)
                .tracking(1)
        }
    }

    private var summaryHero: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                MarketingStatTile(value: "7h 36m", label: "Time asleep",
                                  icon: "bed.double.fill", tint: MooniColor.accent,
                                  visible: summaryShown > 0)
                MarketingStatTile(value: "82", label: "Sleep score",
                                  icon: "sparkles", tint: MooniColor.success,
                                  visible: summaryShown > 1)
            }
            HStack(spacing: 12) {
                MarketingStatTile(value: "74%", label: "Energy",
                                  icon: "bolt.fill", tint: MooniColor.warning,
                                  visible: summaryShown > 2)
                MarketingStatTile(value: "1h 04m", label: "Deep sleep",
                                  icon: "moon.zzz.fill", tint: MooniColor.accentSoft,
                                  visible: summaryShown > 3)
            }
        }
    }

    private var outroHero: some View {
        VStack(spacing: 18) {
            MarketingAppIcon(size: 108)

            VStack(spacing: 7) {
                Text("Download SleepOwl")
                    .font(MooniFont.display(36))
                    .foregroundColor(MooniColor.textPrimary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("Search \u{201C}SleepOwl\u{201D} on the App Store")
                    .font(MooniFont.body(16))
                    .foregroundColor(MooniColor.textSecondary)
            }
        }
        .opacity(outroIn ? 1 : 0)
        .scaleEffect(outroIn ? 1 : 0.92)
        .offset(y: outroIn ? 0 : 12)
    }

    // MARK: - Chrome

    private var chrome: some View {
        VStack {
            HStack {
                Button {
                    stopLoop(); dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.55))
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                Spacer()
            }
            Spacer()
        }
        .padding(.top, 8)
        .padding(.leading, 14)
        .opacity(showChrome ? 1 : 0)
        .allowsHitTesting(showChrome)
        .animation(.easeOut(duration: 0.45), value: showChrome)
    }

    private func scheduleChromeFade() {
        chromeTask?.cancel()
        chromeTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.5)) { showChrome = false }
        }
    }

    // MARK: - Sequence

    private func startLoop() {
        loopTask?.cancel()
        loopTask = Task { @MainActor in
            while !Task.isCancelled {
                await runSequence()
                if Task.isCancelled { break }
                resetState()
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }

    private func stopLoop() {
        loopTask?.cancel(); loopTask = nil
        chromeTask?.cancel(); chromeTask = nil
    }

    private func runSequence() async {
        // INTRO ─ owl + headline
        phase = .intro
        withAnimation(.easeOut(duration: 0.7)) { introIn = true }
        await wait(2.4)
        withAnimation(.easeIn(duration: 0.3)) { introIn = false }
        await wait(0.25)

        // HYPNOGRAM ─ stages draw across the night
        phase = .hypnogram
        await wait(0.45)
        withAnimation(.easeInOut(duration: 1.7)) { hypnoProgress = 1 }
        await wait(2.6)

        // TRENDS ─ 7-night bars grow up
        phase = .trends
        await wait(0.45)
        withAnimation(.easeOut(duration: 1.25)) { trendsProgress = 1 }
        await wait(2.3)

        // SCORE ─ ring + counting number
        phase = .score
        await wait(0.4)
        withAnimation(.easeOut(duration: 1.5)) { ringProgress = 0.82 }
        await countUp(to: 82, over: 1.45)
        await wait(1.5)

        // SUMMARY ─ stat tiles
        phase = .summary
        await wait(0.4)
        for i in 1...4 {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) { summaryShown = i }
            await wait(0.22)
        }
        await wait(1.7)

        // OUTRO ─ logo lockup
        phase = .outro
        withAnimation(.easeOut(duration: 0.6)) { outroIn = true }
        await wait(2.1)
        withAnimation(.easeIn(duration: 0.3)) { outroIn = false }
        await wait(0.3)
    }

    /// Smoothly counts an Int up with an ease-out curve.
    private func countUp(to target: Int, over duration: Double) async {
        let steps = 30
        for i in 0...steps {
            if Task.isCancelled { return }
            let t = Double(i) / Double(steps)
            let eased = 1 - pow(1 - t, 2)
            scoreShown = Int((Double(target) * eased).rounded())
            try? await Task.sleep(nanoseconds: UInt64(duration / Double(steps) * 1_000_000_000))
        }
        scoreShown = target
    }

    private func wait(_ s: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000))
    }

    private func resetState() {
        phase = .intro
        introIn = false
        hypnoProgress = 0
        trendsProgress = 0
        ringProgress = 0
        scoreShown = 0
        summaryShown = 0
        outroIn = false
    }
}

// MARK: - Brand wordmark

private struct MarketingWordmark: View {
    var body: some View {
        HStack(spacing: 10) {
            MarketingAppIcon(size: 30)
            Text("SleepOwl")
                .font(MooniFont.title(19))
                .foregroundColor(MooniColor.textPrimary)
                .tracking(0.3)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

/// The real App Store icon, presented the way it appears on a home screen:
/// the actual `app_icon` artwork clipped to an iOS squircle with a hairline
/// edge and a soft accent bloom.
private struct MarketingAppIcon: View {
    var size: CGFloat = 96

    var body: some View {
        Image("app_icon")
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.28), .clear,
                                     MooniColor.accent.opacity(0.30)],
                            startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1))
            .shadow(color: MooniColor.accent.opacity(0.45),
                    radius: size * 0.22, y: size * 0.08)
    }
}

// MARK: - Owl with glow

private struct MarketingOwl: View {
    let pet: Pet
    var size: CGFloat = 168
    @State private var bob: CGFloat = 0
    @State private var glow: CGFloat = 0.92
    @State private var aura: Double = 0.4

    var body: some View {
        ZStack {
            // Wide soft halo — breathes slowly.
            Circle()
                .fill(RadialGradient(
                    colors: [MooniColor.accent.opacity(0.46 * aura + 0.16),
                             MooniColor.accent.opacity(0.12), .clear],
                    center: .center, startRadius: 6, endRadius: size * 1.1))
                .frame(width: size * 2.1, height: size * 2.1)
                .scaleEffect(glow)
                .blur(radius: 10)
            // Tight inner core glow so the owl reads as lit from within.
            Circle()
                .fill(RadialGradient(
                    colors: [MooniColor.petGlow.opacity(0.32), .clear],
                    center: .center, startRadius: 2, endRadius: size * 0.55))
                .frame(width: size * 1.1, height: size * 1.1)
                .blur(radius: 4)

            DreamSpiritView(pet: pet, size: size)
                .offset(y: bob)
                .shadow(color: MooniColor.accent.opacity(0.55), radius: 24)
                .shadow(color: Color.black.opacity(0.30), radius: 10, y: 8)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) { bob = -11 }
            withAnimation(.easeInOut(duration: 4.6).repeatForever(autoreverses: true)) { glow = 1.07 }
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) { aura = 1.0 }
        }
    }
}

// MARK: - Hypnogram (the signature "this is a sleep app" chart)

private struct MarketingHypnogram: View {
    let progress: CGFloat
    let startLabel: String
    let endLabel: String

    private enum Stage: Int, CaseIterable {
        case awake = 0, rem, light, deep
        var label: String {
            switch self {
            case .awake: return "Awake"
            case .rem:   return "REM"
            case .light: return "Light"
            case .deep:  return "Deep"
            }
        }
        var color: Color {
            switch self {
            case .awake: return MooniColor.danger
            case .rem:   return MooniColor.warning
            case .light: return MooniColor.accentSoft
            case .deep:  return MooniColor.accent
            }
        }
    }

    // A believable night: (endFraction, stage). Each entry runs from the
    // previous fraction to this one.
    private let stages: [(end: CGFloat, stage: Stage)] = [
        (0.05, .awake), (0.13, .light), (0.26, .deep), (0.34, .light),
        (0.40, .rem),   (0.52, .deep),  (0.60, .light), (0.66, .rem),
        (0.78, .deep),  (0.85, .light), (0.92, .rem),   (0.97, .light),
        (1.00, .awake)
    ]

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                // Lane labels
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Stage.allCases, id: \.rawValue) { s in
                        HStack(spacing: 6) {
                            Circle().fill(s.color).frame(width: 7, height: 7)
                            Text(s.label)
                                .font(MooniFont.caption(11))
                                .foregroundColor(MooniColor.textSecondary)
                        }
                        .frame(height: 62, alignment: .center)
                    }
                }
                .frame(width: 58)

                GeometryReader { geo in
                    let w = geo.size.width
                    let laneH = geo.size.height / CGFloat(Stage.allCases.count)
                    ZStack(alignment: .leading) {
                        // Lane gridlines
                        VStack(spacing: 0) {
                            ForEach(0..<4, id: \.self) { _ in
                                Rectangle()
                                    .fill(Color.white.opacity(0.05))
                                    .frame(height: 1)
                                    .frame(height: laneH, alignment: .center)
                            }
                        }

                        // Stage bars
                        ZStack(alignment: .leading) {
                            ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                                let x0 = seg.start * w
                                let x1 = seg.end * w
                                Capsule()
                                    .fill(seg.stage.color)
                                    .frame(width: max(4, x1 - x0), height: 13)
                                    .position(
                                        x: (x0 + x1) / 2,
                                        y: laneH * (CGFloat(seg.stage.rawValue) + 0.5)
                                    )
                                    .shadow(color: seg.stage.color.opacity(0.5), radius: 5)
                            }
                        }
                        .mask(
                            Rectangle()
                                .frame(width: w * progress)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        )

                        // Scan head
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [.clear, MooniColor.accentSoft],
                                startPoint: .leading, endPoint: .trailing))
                            .frame(width: 2, height: geo.size.height)
                            .position(x: max(1, w * progress), y: geo.size.height / 2)
                            .opacity(progress > 0.01 && progress < 0.99 ? 1 : 0)
                            .shadow(color: MooniColor.accentSoft, radius: 8)
                    }
                }
                .frame(height: 248)
            }

            HStack {
                timeChip(icon: "moon.fill", text: startLabel, color: MooniColor.accentSoft)
                Spacer()
                Text("Hypnogram")
                    .font(MooniFont.caption(11))
                    .tracking(2)
                    .foregroundColor(MooniColor.textMuted)
                Spacer()
                timeChip(icon: "sunrise.fill", text: endLabel, color: MooniColor.warning)
            }
        }
    }

    private struct Seg { let start: CGFloat; let end: CGFloat; let stage: Stage }
    private var segments: [Seg] {
        var out: [Seg] = []
        var prev: CGFloat = 0
        for s in stages {
            out.append(Seg(start: prev, end: s.end, stage: s.stage))
            prev = s.end
        }
        return out
    }

    private func timeChip(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
            Text(text)
                .font(MooniFont.title(13))
                .foregroundColor(MooniColor.textPrimary)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
    }
}

// MARK: - 7-night trend chart

private struct MarketingTrendChart: View {
    let progress: CGFloat

    // Hours slept, last 7 nights. Last value = tonight (highlighted).
    private let values: [CGFloat] = [6.1, 5.4, 7.0, 6.6, 7.7, 7.1, 7.6]
    private let days = ["M", "T", "W", "T", "F", "S", "S"]
    private let goal: CGFloat = 8.0
    private let maxScale: CGFloat = 9.0

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("7-night average")
                    .font(MooniFont.title(16))
                    .foregroundColor(MooniColor.textSecondary)
                Spacer()
                Text("7h 04m")
                    .font(MooniFont.display(22))
                    .foregroundColor(MooniColor.textPrimary)
            }

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let slot = w / CGFloat(values.count)
                let barW = slot * 0.46

                ZStack(alignment: .bottomLeading) {
                    // Goal line (dashed)
                    let goalY = h - (goal / maxScale) * h
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: goalY))
                        p.addLine(to: CGPoint(x: w, y: goalY))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .foregroundColor(MooniColor.textMuted.opacity(0.7))

                    Text("Goal 8h")
                        .font(MooniFont.caption(10))
                        .foregroundColor(MooniColor.textMuted)
                        .position(x: 34, y: goalY - 9)

                    ForEach(values.indices, id: \.self) { i in
                        let isToday = i == values.count - 1
                        let full = (values[i] / maxScale) * h
                        // Slight left-to-right stagger as the chart grows in.
                        let local = max(0, min(1, (progress - CGFloat(i) * 0.05) / 0.6))
                        let barH = full * local
                        let cx = slot * CGFloat(i) + slot / 2

                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: isToday
                                            ? [MooniColor.accentSoft, MooniColor.accent]
                                            : [MooniColor.accent.opacity(0.35),
                                               MooniColor.accent.opacity(0.18)],
                                        startPoint: .top, endPoint: .bottom)
                                )
                                .frame(width: barW, height: max(3, barH))
                                .shadow(color: isToday ? MooniColor.accent.opacity(0.6) : .clear,
                                        radius: 8)
                            if isToday {
                                Text("7.6h")
                                    .font(MooniFont.caption(11))
                                    .foregroundColor(MooniColor.textPrimary)
                                    .offset(y: -(max(3, barH) + 14))
                                    .opacity(local > 0.9 ? 1 : 0)
                            }
                        }
                        .position(x: cx, y: h - max(3, barH) / 2)
                    }
                }
            }
            .frame(height: 230)

            HStack(spacing: 0) {
                ForEach(days.indices, id: \.self) { i in
                    Text(days[i])
                        .font(MooniFont.caption(11))
                        .foregroundColor(i == days.count - 1
                                         ? MooniColor.accentSoft : MooniColor.textMuted)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - Score ring

private struct MarketingRing: View {
    let progress: CGFloat
    let score: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 18)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [MooniColor.accentSoft, MooniColor.accent,
                                 MooniColor.success, MooniColor.accentSoft],
                        center: .center),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: MooniColor.accent.opacity(0.55), radius: 18)
            VStack(spacing: 2) {
                Text("\(score)")
                    .font(MooniFont.display(92))
                    .foregroundColor(MooniColor.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("/ 100")
                    .font(MooniFont.title(15))
                    .foregroundColor(MooniColor.textMuted)
            }
        }
    }
}

// MARK: - Stat tile

private struct MarketingStatTile: View {
    let value: String
    let label: String
    let icon: String
    let tint: Color
    let visible: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            Text(value)
                .font(MooniFont.display(30))
                .foregroundColor(MooniColor.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(MooniFont.caption(12))
                .foregroundColor(MooniColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(tint.opacity(0.28), lineWidth: 1))
        )
        .opacity(visible ? 1 : 0)
        .scaleEffect(visible ? 1 : 0.9)
        .offset(y: visible ? 0 : 14)
    }
}

#Preview {
    MarketingVideoView()
}
