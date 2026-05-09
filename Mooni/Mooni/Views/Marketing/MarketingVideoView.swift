import SwiftUI

/// Hidden 10-second auto-looping marketing animation used to record
/// TikTok / Reels demo clips. Visuals are emotionally obvious without
/// sound: owl asleep → night timeline draws → score calculates → result
/// card → "Wake up smarter with SleepOwl." Then loops.
///
/// Surfaced from Profile → Dev Tools → "Start Marketing Video" so it
/// never reaches a real user.
struct MarketingVideoView: View {
    @Environment(\.dismiss) private var dismiss

    // MARK: - Phase state
    private enum Phase: Int { case intro, timeline, speedUp, analysis, score, result, outro }
    @State private var phase: Phase = .intro

    // Mascot placement
    @State private var mascotScale: CGFloat = 1.0
    @State private var mascotOffsetY: CGFloat = 0
    @State private var mascotOpacity: Double = 1

    // Intro
    @State private var introTextOpacity: Double = 0

    // Timeline
    @State private var timelineProgress: CGFloat = 0
    @State private var event1Visible = false
    @State private var event2Visible = false
    @State private var event3Visible = false
    @State private var event4Visible = false

    // Speed-up
    @State private var displayedDuration: String = "1h 12m"
    @State private var allNightOpacity: Double = 0

    // Analysis cards
    @State private var card1Visible = false
    @State private var card2Visible = false
    @State private var card3Visible = false
    @State private var card4Visible = false

    // Score
    @State private var ringProgress: CGFloat = 0
    @State private var displayedScore: Int = 0
    @State private var goodSleepOpacity: Double = 0

    // Result + outro
    @State private var resultCardVisible = false
    @State private var outroOpacity: Double = 0

    // Loop + chrome
    @State private var loopTask: Task<Void, Never>? = nil
    @State private var chromeTask: Task<Void, Never>? = nil
    @State private var showChrome = true

    // Sample (fake) data
    private let sleepStart = "11:42 PM"
    private let wakeTime = "7:18 AM"
    private let durationSteps = ["1h 12m", "3h 48m", "6h 20m", "7h 36m"]
    private let scoreSteps: [Int] = [24, 47, 68, 82]

    private var sleepyPet: Pet {
        var p = Pet()
        p.name = "SleepOwl"
        p.species = .owl
        p.mood = .sleepy
        return p
    }

    var body: some View {
        ZStack {
            // Layer 0 — backdrop
            MooniGradient.night.ignoresSafeArea()
            StarsBackground(count: 80)
                .ignoresSafeArea()

            // Layer 1 — mascot persists across phases, repositioned per phase.
            MarketingMooniMascot(pet: sleepyPet, size: 180)
                .scaleEffect(mascotScale)
                .offset(y: mascotOffsetY)
                .opacity(mascotOpacity)

            // Layer 2 — phase-specific content (each gated by opacity for
            // smooth cross-fades between phases).
            introContent
                .opacity(phase == .intro ? 1 : 0)

            timelineContent
                .opacity(phase == .timeline || phase == .speedUp ? 1 : 0)

            analysisContent
                .opacity(phase == .analysis ? 1 : 0)

            scoreContent
                .opacity(phase == .score ? 1 : 0)

            resultContent
                .opacity(phase == .result ? 1 : 0)

            outroContent
                .opacity(phase == .outro ? 1 : 0)

            // Layer 3 — subtle close chrome that auto-fades during recording
            chrome
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .animation(.easeInOut(duration: 0.45), value: phase)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeIn(duration: 0.18)) { showChrome = true }
            scheduleChromeFade()
        }
        .onAppear {
            scheduleChromeFade()
            startLoop()
        }
        .onDisappear { stopLoop() }
    }

    // MARK: - Phase content

    private var introContent: some View {
        VStack {
            Spacer()
            Spacer()
            VStack(spacing: 8) {
                Text("SleepOwl watches your sleep")
                    .font(MooniFont.display(28))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text("All night, while you rest.")
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textSecondary)
            }
            .opacity(introTextOpacity)
            .padding(.horizontal, 32)
            .padding(.bottom, 90)
        }
    }

    private var timelineContent: some View {
        VStack(spacing: 18) {
            Text(phase == .speedUp ? "All night, automatically" : "Detecting your night")
                .font(MooniFont.title(18))
                .foregroundColor(MooniColor.accentSoft)
                .opacity(allNightOpacity)
                .animation(.easeInOut(duration: 0.3), value: allNightOpacity)

            MarketingSleepTimeline(
                progress: timelineProgress,
                event1Visible: event1Visible,
                event2Visible: event2Visible,
                event3Visible: event3Visible,
                event4Visible: event4Visible,
                startLabel: sleepStart,
                endLabel: wakeTime
            )
            .padding(.horizontal, 22)

            if phase == .speedUp {
                HStack(spacing: 10) {
                    Image(systemName: "moon.zzz.fill")
                        .foregroundColor(MooniColor.accentSoft)
                    Text(displayedDuration)
                        .font(MooniFont.display(36))
                        .foregroundColor(MooniColor.textPrimary)
                        .contentTransition(.numericText())
                        .monospacedDigit()
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .padding(.top, 280)
        .padding(.horizontal, 18)
    }

    private var analysisContent: some View {
        VStack(spacing: 14) {
            Text("SleepOwl analyzes everything")
                .font(MooniFont.display(24))
                .foregroundColor(MooniColor.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 6)

            VStack(spacing: 12) {
                MarketingAnalysisCard(
                    icon: "moon.zzz.fill",
                    title: "Sleep Duration",
                    value: "7h 36m",
                    color: MooniColor.accent,
                    visible: card1Visible
                )
                MarketingAnalysisCard(
                    icon: "waveform.path.ecg",
                    title: "Sleep Consistency",
                    value: "Strong",
                    color: MooniColor.accentSoft,
                    visible: card2Visible
                )
                MarketingAnalysisCard(
                    icon: "heart.fill",
                    title: "Recovery",
                    value: "82%",
                    color: MooniColor.success,
                    visible: card3Visible
                )
                MarketingAnalysisCard(
                    icon: "bolt.fill",
                    title: "Energy",
                    value: "74%",
                    color: MooniColor.warning,
                    visible: card4Visible
                )
            }
            .padding(.horizontal, 28)
        }
        .padding(.top, 240)
    }

    private var scoreContent: some View {
        VStack(spacing: 22) {
            Spacer().frame(height: 80)
            MarketingScoreRing(progress: ringProgress, score: displayedScore)
                .frame(width: 240, height: 240)

            Text("Good Sleep")
                .font(MooniFont.display(28))
                .foregroundColor(MooniColor.success)
                .opacity(goodSleepOpacity)
            Spacer()
        }
    }

    private var resultContent: some View {
        VStack {
            Spacer().frame(height: 60)
            MarketingResultCard()
                .padding(.horizontal, 22)
                .scaleEffect(resultCardVisible ? 1 : 0.92)
                .opacity(resultCardVisible ? 1 : 0)
            Spacer()
        }
    }

    private var outroContent: some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                Text("Wake up smarter")
                    .font(MooniFont.display(34))
                    .foregroundColor(MooniColor.textPrimary)
                Text("with SleepOwl")
                    .font(MooniFont.display(34))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [MooniColor.accentSoft, MooniColor.accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("Your sleep, explained.")
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textSecondary)
                    .padding(.top, 4)
            }
            .opacity(outroOpacity)
            Spacer()
            Spacer()
        }
    }

    // MARK: - Chrome

    private var chrome: some View {
        VStack {
            HStack {
                Button {
                    stopLoop()
                    dismiss()
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

    // MARK: - Animation timeline

    private func startLoop() {
        loopTask?.cancel()
        loopTask = Task { @MainActor in
            while !Task.isCancelled {
                await runSequence()
                if Task.isCancelled { break }
                resetState()
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
        }
    }

    private func stopLoop() {
        loopTask?.cancel()
        loopTask = nil
        chromeTask?.cancel()
        chromeTask = nil
    }

    /// One full ~10s pass.
    private func runSequence() async {
        // ───── 0.0–1.0s — INTRO ─────
        phase = .intro
        withAnimation(.easeOut(duration: 0.55)) { introTextOpacity = 1 }
        await sleep(seconds: 1.0)

        // ───── 1.0–2.5s — TIMELINE ─────
        phase = .timeline
        withAnimation(.easeInOut(duration: 0.45)) {
            introTextOpacity = 0
            mascotScale = 0.55
            mascotOffsetY = -260
        }
        await sleep(seconds: 0.18)
        withAnimation(.easeOut(duration: 1.05)) { timelineProgress = 1 }
        await sleep(seconds: 0.18)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) { event1Visible = true }
        await sleep(seconds: 0.27)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) { event2Visible = true }
        await sleep(seconds: 0.27)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) { event3Visible = true }
        await sleep(seconds: 0.27)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) { event4Visible = true }
        await sleep(seconds: 0.33)

        // ───── 2.5–4.0s — SPEED-UP ─────
        phase = .speedUp
        withAnimation(.easeOut(duration: 0.3)) { allNightOpacity = 1 }
        for step in durationSteps {
            withAnimation(.easeOut(duration: 0.22)) { displayedDuration = step }
            await sleep(seconds: 0.36)
        }
        await sleep(seconds: 0.06)

        // ───── 4.0–5.8s — ANALYSIS ─────
        phase = .analysis
        withAnimation(.easeIn(duration: 0.25)) { allNightOpacity = 0 }
        withAnimation(.easeInOut(duration: 0.4)) {
            mascotScale = 0.42
            mascotOffsetY = -310
        }
        await sleep(seconds: 0.12)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) { card1Visible = true }
        await sleep(seconds: 0.22)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) { card2Visible = true }
        await sleep(seconds: 0.22)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) { card3Visible = true }
        await sleep(seconds: 0.22)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) { card4Visible = true }
        await sleep(seconds: 0.7)

        // ───── 5.8–7.5s — SCORE ─────
        phase = .score
        withAnimation(.easeOut(duration: 0.4)) {
            mascotOpacity = 0
        }
        withAnimation(.easeOut(duration: 1.1)) { ringProgress = 0.82 }
        for value in scoreSteps {
            withAnimation(.easeOut(duration: 0.22)) { displayedScore = value }
            await sleep(seconds: 0.32)
        }
        withAnimation(.easeIn(duration: 0.3)) { goodSleepOpacity = 1 }
        await sleep(seconds: 0.34)

        // ───── 7.5–9.0s — RESULT CARD ─────
        phase = .result
        withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) { resultCardVisible = true }
        // Mascot returns subtly (still happy, smaller, near top).
        withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
            mascotOpacity = 1
            mascotScale = 0.4
            mascotOffsetY = -340
        }
        await sleep(seconds: 1.5)

        // ───── 9.0–10.0s — OUTRO ─────
        phase = .outro
        withAnimation(.easeOut(duration: 0.45)) {
            resultCardVisible = false
            outroOpacity = 1
            mascotScale = 0.6
            mascotOffsetY = -180
        }
        await sleep(seconds: 0.95)

        // Brief crossfade-out before reset
        withAnimation(.easeIn(duration: 0.2)) { outroOpacity = 0 }
        await sleep(seconds: 0.2)
    }

    private func sleep(seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    private func resetState() {
        // Snap (no animation) so the next loop starts visibly fresh.
        phase = .intro
        introTextOpacity = 0
        mascotScale = 1.0
        mascotOffsetY = 0
        mascotOpacity = 1
        timelineProgress = 0
        event1Visible = false
        event2Visible = false
        event3Visible = false
        event4Visible = false
        displayedDuration = durationSteps.first ?? "1h 12m"
        allNightOpacity = 0
        card1Visible = false
        card2Visible = false
        card3Visible = false
        card4Visible = false
        ringProgress = 0
        displayedScore = 0
        goodSleepOpacity = 0
        resultCardVisible = false
        outroOpacity = 0
    }
}

// MARK: - MarketingMooniMascot

private struct MarketingMooniMascot: View {
    let pet: Pet
    var size: CGFloat = 180

    @State private var bob: CGFloat = 0
    @State private var glowPulse: CGFloat = 0.92

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            MooniColor.accent.opacity(0.55),
                            MooniColor.accent.opacity(0.18),
                            .clear
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: size * 1.2
                    )
                )
                .frame(width: size * 2.2, height: size * 2.2)
                .scaleEffect(glowPulse)
                .blur(radius: 6)

            DreamSpiritView(pet: pet, size: size)
                .offset(y: bob)
                .shadow(color: MooniColor.accent.opacity(0.5), radius: 24)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                bob = -10
            }
            withAnimation(.easeInOut(duration: 4.6).repeatForever(autoreverses: true)) {
                glowPulse = 1.06
            }
        }
    }
}

// MARK: - MarketingSleepTimeline

private struct MarketingSleepTimeline: View {
    let progress: CGFloat
    let event1Visible: Bool
    let event2Visible: Bool
    let event3Visible: Bool
    let event4Visible: Bool
    let startLabel: String
    let endLabel: String

    var body: some View {
        VStack(spacing: 22) {
            // Floating events sit *above* the timeline at evenly spaced
            // positions, fading/popping in one-by-one.
            HStack(alignment: .bottom, spacing: 0) {
                FloatingSleepEvent(
                    label: "Fell asleep",
                    icon: "moon.fill",
                    visible: event1Visible
                )
                .frame(maxWidth: .infinity)

                FloatingSleepEvent(
                    label: "Deep sleep",
                    icon: "moon.zzz.fill",
                    visible: event2Visible
                )
                .frame(maxWidth: .infinity)

                FloatingSleepEvent(
                    label: "Restless",
                    icon: "wind",
                    visible: event3Visible
                )
                .frame(maxWidth: .infinity)

                FloatingSleepEvent(
                    label: "Woke up",
                    icon: "sunrise.fill",
                    visible: event4Visible
                )
                .frame(maxWidth: .infinity)
            }

            // Glowing horizontal track
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.10))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [MooniColor.accentSoft, MooniColor.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress)
                        .shadow(color: MooniColor.accent.opacity(0.7), radius: 14)

                    // Leading dot
                    Circle()
                        .fill(MooniColor.accentSoft)
                        .frame(width: 12, height: 12)
                        .shadow(color: MooniColor.accentSoft.opacity(0.8), radius: 8)

                    // Travelling dot at the tip of the gradient line
                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                        .shadow(color: MooniColor.accent, radius: 10)
                        .offset(x: geo.size.width * progress - 7)
                        .opacity(progress > 0 && progress < 1 ? 1 : 0.85)
                }
                .frame(height: 8)
            }
            .frame(height: 8)

            HStack {
                timeChip(icon: "moon.fill", text: startLabel, color: MooniColor.accentSoft)
                Spacer()
                timeChip(icon: "sunrise.fill", text: endLabel, color: MooniColor.warning)
            }
        }
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

// MARK: - FloatingSleepEvent

private struct FloatingSleepEvent: View {
    let label: String
    let icon: String
    let visible: Bool

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(MooniColor.accentSoft)
                .frame(width: 38, height: 38)
                .background(
                    Circle().fill(MooniColor.accent.opacity(0.20))
                )
                .overlay(
                    Circle().stroke(MooniColor.accent.opacity(0.55), lineWidth: 1)
                )
                .shadow(color: MooniColor.accent.opacity(0.6), radius: 10)

            Text(label)
                .font(MooniFont.caption(11))
                .foregroundColor(MooniColor.textSecondary)
                .lineLimit(1)
        }
        .opacity(visible ? 1 : 0)
        .scaleEffect(visible ? 1 : 0.55)
        .offset(y: visible ? 0 : 14)
    }
}

// MARK: - MarketingScoreRing

private struct MarketingScoreRing: View {
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
                        colors: [
                            MooniColor.accentSoft,
                            MooniColor.accent,
                            MooniColor.accentSoft
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: MooniColor.accent.opacity(0.55), radius: 18)

            VStack(spacing: 4) {
                Text("\(score)")
                    .font(MooniFont.display(78))
                    .foregroundColor(MooniColor.textPrimary)
                    .contentTransition(.numericText())
                    .monospacedDigit()
                Text("SLEEP SCORE")
                    .font(MooniFont.caption(11))
                    .tracking(2.4)
                    .foregroundColor(MooniColor.textSecondary)
            }
        }
    }
}

// MARK: - MarketingAnalysisCard

private struct MarketingAnalysisCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    let visible: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(title)
                .font(MooniFont.title(16))
                .foregroundColor(MooniColor.textPrimary)

            Spacer()

            Text(value)
                .font(MooniFont.title(17))
                .foregroundColor(color)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(color.opacity(0.32), lineWidth: 1)
                )
                .shadow(color: color.opacity(0.25), radius: 16)
        )
        .opacity(visible ? 1 : 0)
        .scaleEffect(visible ? 1 : 0.85)
        .offset(x: visible ? 0 : -30)
    }
}

// MARK: - MarketingResultCard

private struct MarketingResultCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SLEEP SCORE")
                        .font(MooniFont.caption(11))
                        .tracking(2)
                        .foregroundColor(MooniColor.textSecondary)
                    Text("82")
                        .font(MooniFont.display(56))
                        .foregroundColor(MooniColor.textPrimary)
                        .monospacedDigit()
                }
                Spacer()
                Text("Good Sleep")
                    .font(MooniFont.title(14))
                    .foregroundColor(MooniColor.success)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(MooniColor.success.opacity(0.16))
                    .clipShape(Capsule())
            }

            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(height: 1)

            VStack(spacing: 12) {
                MetricRow(icon: "bed.double.fill", label: "Asleep",  value: "7h 36m",  color: MooniColor.accent)
                MetricRow(icon: "moon.fill",       label: "Bedtime", value: "11:42 PM", color: MooniColor.accentSoft)
                MetricRow(icon: "sunrise.fill",    label: "Wake",    value: "7:18 AM",  color: MooniColor.warning)
                MetricRow(icon: "bolt.fill",       label: "Energy",  value: "74%",      color: MooniColor.success)
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(MooniColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: MooniColor.accent.opacity(0.35), radius: 30, y: 12)
        )
    }

    private struct MetricRow: View {
        let icon: String
        let label: String
        let value: String
        let color: Color

        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(label)
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textSecondary)
                Spacer()
                Text(value)
                    .font(MooniFont.title(16))
                    .foregroundColor(MooniColor.textPrimary)
                    .monospacedDigit()
            }
        }
    }
}

#Preview {
    MarketingVideoView()
}
