import SwiftUI
import UIKit

private extension LinearGradient {
    /// White → lavender wordmark sweep used wherever the "SleepOwl" name
    /// appears, so the brand reads consistently across every phase.
    static var sleepOwlBrand: LinearGradient {
        LinearGradient(
            colors: [MooniColor.textPrimary, MooniColor.accentSoft],
            startPoint: .leading, endPoint: .trailing)
    }
}

/// A small tile of random monochrome noise, generated once at launch. Overlaid
/// at a whisper of opacity with `.overlay` blending, it dithers the dark
/// gradients so they don't step into visible bands on real (OLED) displays —
/// gradients look smooth in the simulator but band on device, which grain fixes
/// the way film and pro video tools always have.
private enum GrainTexture {
    static let tile: Image = {
        let dim = 128
        var px = [UInt8](repeating: 255, count: dim * dim * 4) // alpha pre-filled
        for i in 0..<(dim * dim) {
            let v = UInt8.random(in: 0...255)
            px[i * 4] = v; px[i * 4 + 1] = v; px[i * 4 + 2] = v
        }
        let cg = px.withUnsafeMutableBytes { raw -> CGImage in
            let ctx = CGContext(
                data: raw.baseAddress, width: dim, height: dim,
                bitsPerComponent: 8, bytesPerRow: dim * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            return ctx.makeImage()!
        }
        return Image(decorative: cg, scale: 1, orientation: .up)
            .resizable(resizingMode: .tile)
    }()
}

/// Hidden auto-looping marketing animation used to record TikTok / Reels /
/// App-Store demo clips.
///
/// Design (v2 — a phone-mockup product demo, "deep night / premium"):
///  • A single floating iPhone is the fixed hero. It never jumps — only the
///    REAL app UI *inside* its screen cross-fades between beats, so viewers
///    see exactly what SleepOwl does: home → sleep score fills in → hypnogram
///    draws → 7-night trend grows → App Store.
///  • One short message line sits below the phone, one per beat.
///  • Restrained palette: near-black indigo, one soft lavender glow behind the
///    device, film-grain dither so the darks never band.
///
/// Surfaced from Profile → Dev Tools → "Start Marketing Video".
struct MarketingVideoView: View {
    @Environment(\.dismiss) private var dismiss

    private enum Phase: Int, CaseIterable {
        case intro, score, stages, trends, outro
    }
    @State private var phase: Phase = .intro

    // Per-phase animation drivers
    @State private var introIn = false
    @State private var ringProgress: CGFloat = 0
    @State private var scoreShown: Int = 0
    @State private var hypnoProgress: CGFloat = 0
    @State private var trendsProgress: CGFloat = 0
    @State private var outroIn = false

    // Ambient life
    @State private var phoneBob: CGFloat = 0
    @State private var glowPulse = false

    // Chrome / loop
    @State private var loopTask: Task<Void, Never>? = nil
    @State private var chromeTask: Task<Void, Never>? = nil
    @State private var showChrome = true

    // Phone geometry
    private let phoneW: CGFloat = 214
    private let phoneH: CGFloat = 442

    var body: some View {
        ZStack {
            // Deep-night background.
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.13),
                         Color(red: 0.02, green: 0.02, blue: 0.06)],
                startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            StarsBackground(count: 54).ignoresSafeArea()

            // One soft lavender glow behind the device — gently breathing.
            // endRadius reaches past the screen corner so the fade never
            // completes on-screen (no arc/seam), and the pulse only scales up.
            RadialGradient(
                colors: [MooniColor.accent.opacity(0.26),
                         MooniColor.accent.opacity(0.07), .clear],
                center: .center, startRadius: 0, endRadius: 560)
                .ignoresSafeArea()
                .scaleEffect(glowPulse ? 1.1 : 0.98)
                .allowsHitTesting(false)

            GrainTexture.tile
                .opacity(0.05)
                .blendMode(.overlay)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                MarketingWordmark()

                Spacer().frame(height: 22)

                phone
                    .opacity(introIn ? 1 : 0)
                    .scaleEffect(introIn ? 1 : 0.94)
                    .offset(y: (introIn ? 0 : 22) + phoneBob)

                Spacer().frame(height: 26)

                // Fixed-height message area below the phone — never reflows.
                ZStack {
                    introMessage.opacity(phase == .intro ? 1 : 0)
                    beatCaption.opacity(isBeat ? 1 : 0)
                    outroMessage.opacity(phase == .outro ? 1 : 0)
                }
                .frame(height: 118)
                .frame(maxWidth: .infinity)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 28)

            chrome
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .animation(.easeInOut(duration: 0.55), value: phase)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeIn(duration: 0.18)) { showChrome = true }
            scheduleChromeFade()
        }
        .onAppear {
            scheduleChromeFade()
            startLoop()
            withAnimation(.easeInOut(duration: 5.5).repeatForever(autoreverses: true)) {
                phoneBob = -7
            }
            withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
        .onDisappear { stopLoop() }
    }

    private var isBeat: Bool {
        switch phase { case .score, .stages, .trends: return true; default: return false }
    }

    private var captionText: String {
        switch phase {
        case .score:  return "Wake up to a real score."
        case .stages: return "Every stage, all night."
        case .trends: return "See every night add up."
        default:      return ""
        }
    }

    // MARK: - The phone

    private var phone: some View {
        ZStack {
            // Device body
            RoundedRectangle(cornerRadius: 52, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.12, green: 0.12, blue: 0.16),
                             Color(red: 0.02, green: 0.02, blue: 0.05)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: 52, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.35), .clear,
                                         MooniColor.accent.opacity(0.22)],
                                startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1.3))
                .frame(width: phoneW, height: phoneH)
                .shadow(color: MooniColor.accent.opacity(0.30), radius: 34, y: 16)
                .shadow(color: .black.opacity(0.55), radius: 22, y: 22)

            // Screen
            ZStack {
                screens
            }
            .frame(width: phoneW - 18, height: phoneH - 18)
            .clipShape(RoundedRectangle(cornerRadius: 43, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 43, style: .continuous)
                    .stroke(Color.black.opacity(0.6), lineWidth: 1))

            // Glass sheen
            RoundedRectangle(cornerRadius: 43, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color.white.opacity(0.10), .clear],
                    startPoint: .topLeading, endPoint: .center))
                .frame(width: phoneW - 18, height: phoneH - 18)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)

            // Dynamic Island
            Capsule()
                .fill(Color.black)
                .frame(width: 78, height: 23)
                .offset(y: -(phoneH / 2) + 9 + 16)
        }
        .frame(width: phoneW, height: phoneH)
    }

    /// All app screens stacked, cross-faded by phase. The device frame never
    /// moves — only this content swaps.
    private var screens: some View {
        ZStack {
            MooniGradient.night

            homeScreen.opacity(phase == .intro ? 1 : 0)
            scoreScreen.opacity(phase == .score ? 1 : 0)
            stagesScreen.opacity(phase == .stages ? 1 : 0)
            trendsScreen.opacity(phase == .trends ? 1 : 0)
            splashScreen.opacity(phase == .outro ? 1 : 0)
        }
    }

    // MARK: - In-phone screens

    private var phoneStatusBar: some View {
        HStack {
            Text("9:41")
                .font(MooniFont.title(11))
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "wifi").font(.system(size: 9, weight: .semibold))
                Image(systemName: "battery.75").font(.system(size: 11))
            }
        }
        .foregroundColor(MooniColor.textPrimary)
        .padding(.top, 2)
    }

    private var homeScreen: some View {
        VStack(alignment: .leading, spacing: 12) {
            phoneStatusBar

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 1) {
                Text("Good morning")
                    .font(MooniFont.display(20))
                    .foregroundColor(MooniColor.textPrimary)
                Text("Here's how you slept")
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.textSecondary)
            }

            screenCard {
                HStack(spacing: 14) {
                    MiniRing(progress: 0.82, score: 82, size: 66, lineWidth: 7)
                    VStack(alignment: .leading, spacing: 9) {
                        miniStat("bed.double.fill", "7h 36m", MooniColor.accent)
                        miniStat("moon.zzz.fill", "1h 04m", MooniColor.accentSoft)
                        miniStat("bolt.fill", "74%", MooniColor.warning)
                    }
                    Spacer(minLength: 0)
                }
            }

            HStack(spacing: 6) {
                Circle().fill(MooniColor.success).frame(width: 5, height: 5)
                Text("Tracked automatically")
                    .font(MooniFont.caption(10))
                    .foregroundColor(MooniColor.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
    }

    private var scoreScreen: some View {
        VStack(spacing: 14) {
            phoneStatusBar
            Spacer(minLength: 0)
            Text("SLEEP SCORE")
                .font(MooniFont.caption(10))
                .tracking(2.2)
                .foregroundColor(MooniColor.textMuted)
            MiniRing(progress: ringProgress, score: scoreShown, size: 150, lineWidth: 13)
            Text("You slept 7h 36m")
                .font(MooniFont.title(12))
                .foregroundColor(MooniColor.textSecondary)
            HStack(spacing: 8) {
                pill("Deep", "1h 04m", MooniColor.accentSoft)
                pill("Energy", "74%", MooniColor.warning)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
    }

    private var stagesScreen: some View {
        VStack(alignment: .leading, spacing: 12) {
            phoneStatusBar
            Text("Last night")
                .font(MooniFont.display(18))
                .foregroundColor(MooniColor.textPrimary)
            Text("Sleep stages")
                .font(MooniFont.caption(10))
                .tracking(1.5)
                .foregroundColor(MooniColor.textMuted)

            MiniHypnogram(progress: hypnoProgress)

            HStack(spacing: 10) {
                legendDot(MooniColor.accent, "Deep")
                legendDot(MooniColor.accentSoft, "Light")
                legendDot(MooniColor.warning, "REM")
                legendDot(MooniColor.danger, "Awake")
            }

            HStack {
                Text("11:42 PM")
                Spacer()
                Text("7:18 AM")
            }
            .font(MooniFont.caption(10))
            .foregroundColor(MooniColor.textMuted)

            Spacer(minLength: 0)
        }
        .padding(14)
    }

    private var trendsScreen: some View {
        VStack(alignment: .leading, spacing: 12) {
            phoneStatusBar
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline) {
                Text("7-night average")
                    .font(MooniFont.title(12))
                    .foregroundColor(MooniColor.textSecondary)
                Spacer()
                Text("7h 04m")
                    .font(MooniFont.display(18))
                    .foregroundColor(MooniColor.textPrimary)
            }
            MiniTrend(progress: trendsProgress)
            Spacer(minLength: 0)
        }
        .padding(14)
    }

    private var splashScreen: some View {
        VStack(spacing: 12) {
            Spacer()
            MarketingAppIcon(size: 92)
            Text("SleepOwl")
                .font(MooniFont.display(30))
                .foregroundStyle(LinearGradient.sleepOwlBrand)
            Text("Sleep better, automatically")
                .font(MooniFont.caption(11))
                .foregroundColor(MooniColor.textSecondary)
            Spacer()
        }
        .padding(14)
    }

    // MARK: - Messages below the phone

    private var introMessage: some View {
        VStack(spacing: 6) {
            Text("Your sleep,\ndecoded every morning.")
                .font(MooniFont.display(25))
                .foregroundStyle(LinearGradient.sleepOwlBrand)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .minimumScaleFactor(0.7)
        }
    }

    private var beatCaption: some View {
        Text(captionText)
            .font(MooniFont.display(27))
            .foregroundStyle(LinearGradient.sleepOwlBrand)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .id(captionText)
            .transition(.opacity)
    }

    private var outroMessage: some View {
        VStack(spacing: 11) {
            appStoreBadge
            Text("Search \u{201C}SleepOwl\u{201D} on the App Store")
                .font(MooniFont.caption(12))
                .foregroundColor(MooniColor.textSecondary)
        }
        .opacity(outroIn ? 1 : 0)
        .offset(y: outroIn ? 0 : 8)
    }

    private var appStoreBadge: some View {
        HStack(spacing: 10) {
            Image(systemName: "apple.logo")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white)
            VStack(alignment: .leading, spacing: -1) {
                Text("Download on the")
                    .font(MooniFont.caption(10))
                    .foregroundColor(.white.opacity(0.85))
                Text("App Store")
                    .font(MooniFont.display(19))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.black.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color.white.opacity(0.30), lineWidth: 1))
        )
    }

    // MARK: - Small in-phone building blocks

    private func screenCard<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        content()
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1))
            )
    }

    private func miniStat(_ icon: String, _ text: String, _ tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(tint)
                .frame(width: 20, height: 20)
                .background(tint.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            Text(text)
                .font(MooniFont.title(12))
                .foregroundColor(MooniColor.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private func pill(_ label: String, _ value: String, _ tint: Color) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(MooniFont.title(14))
                .foregroundColor(MooniColor.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(MooniFont.caption(9))
                .foregroundColor(MooniColor.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(tint.opacity(0.3), lineWidth: 1))
        )
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(MooniFont.caption(9))
                .foregroundColor(MooniColor.textSecondary)
        }
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
        // INTRO ─ phone rises in showing the home screen
        phase = .intro
        withAnimation(.spring(response: 0.8, dampingFraction: 0.82)) { introIn = true }
        await wait(2.6)

        // SCORE ─ the wow moment: ring fills + number counts up
        phase = .score
        await wait(0.55)
        withAnimation(.easeOut(duration: 1.5)) { ringProgress = 0.82 }
        await countUp(to: 82, over: 1.45)
        await wait(1.6)

        // STAGES ─ hypnogram draws across the night
        phase = .stages
        await wait(0.55)
        withAnimation(.easeInOut(duration: 1.7)) { hypnoProgress = 1 }
        await wait(2.5)

        // TRENDS ─ 7-night bars grow up
        phase = .trends
        await wait(0.55)
        withAnimation(.easeOut(duration: 1.25)) { trendsProgress = 1 }
        await wait(2.4)

        // OUTRO ─ splash + App Store CTA
        phase = .outro
        withAnimation(.easeOut(duration: 0.6)) { outroIn = true }
        await wait(2.6)
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
        ringProgress = 0
        scoreShown = 0
        hypnoProgress = 0
        trendsProgress = 0
        outroIn = false
    }
}

// MARK: - Brand wordmark (top)

private struct MarketingWordmark: View {
    var body: some View {
        HStack(spacing: 9) {
            MarketingAppIcon(size: 28)
            Text("SleepOwl")
                .font(MooniFont.display(18))
                .foregroundStyle(LinearGradient.sleepOwlBrand)
                .tracking(0.3)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.05))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.09), lineWidth: 1))
    }
}

/// The real App Store icon, clipped to an iOS squircle with a hairline edge.
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
                            colors: [Color.white.opacity(0.30), .clear,
                                     MooniColor.accent.opacity(0.30)],
                            startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1))
            .shadow(color: MooniColor.accent.opacity(0.40),
                    radius: size * 0.16, y: size * 0.06)
    }
}

// MARK: - Compact score ring

private struct MiniRing: View {
    let progress: CGFloat
    let score: Int
    var size: CGFloat = 150
    var lineWidth: CGFloat = 13

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.09), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [MooniColor.accentSoft, MooniColor.accent,
                                 MooniColor.success, MooniColor.accentSoft],
                        center: .center),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: MooniColor.accent.opacity(0.5), radius: 10)
            VStack(spacing: 0) {
                Text("\(score)")
                    .font(MooniFont.display(size * 0.36))
                    .foregroundColor(MooniColor.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("/ 100")
                    .font(MooniFont.title(size * 0.085))
                    .foregroundColor(MooniColor.textMuted)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Compact hypnogram

private struct MiniHypnogram: View {
    let progress: CGFloat

    private enum Stage: Int { case awake = 0, rem, light, deep
        var color: Color {
            switch self {
            case .awake: return MooniColor.danger
            case .rem:   return MooniColor.warning
            case .light: return MooniColor.accentSoft
            case .deep:  return MooniColor.accent
            }
        }
    }

    private let stages: [(end: CGFloat, stage: Stage)] = [
        (0.05, .awake), (0.13, .light), (0.26, .deep), (0.34, .light),
        (0.40, .rem),   (0.52, .deep),  (0.60, .light), (0.66, .rem),
        (0.78, .deep),  (0.85, .light), (0.92, .rem),   (0.97, .light),
        (1.00, .awake)
    ]

    private struct Seg { let start: CGFloat; let end: CGFloat; let stage: Stage }
    private var segments: [Seg] {
        var out: [Seg] = []; var prev: CGFloat = 0
        for s in stages { out.append(Seg(start: prev, end: s.end, stage: s.stage)); prev = s.end }
        return out
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let laneH = geo.size.height / 4
            ZStack(alignment: .leading) {
                VStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.white.opacity(0.04))
                            .frame(height: 1)
                            .frame(height: laneH, alignment: .center)
                    }
                }

                ZStack(alignment: .leading) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                        let x0 = seg.start * w
                        let x1 = seg.end * w
                        Capsule()
                            .fill(seg.stage.color)
                            .frame(width: max(3, x1 - x0), height: 9)
                            .position(x: (x0 + x1) / 2,
                                      y: laneH * (CGFloat(seg.stage.rawValue) + 0.5))
                            .shadow(color: seg.stage.color.opacity(0.5), radius: 4)
                    }
                }
                .mask(
                    Rectangle()
                        .frame(width: w * progress)
                        .frame(maxWidth: .infinity, alignment: .leading)
                )

                Rectangle()
                    .fill(LinearGradient(colors: [.clear, MooniColor.accentSoft],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: 2, height: geo.size.height)
                    .position(x: max(1, w * progress), y: geo.size.height / 2)
                    .opacity(progress > 0.01 && progress < 0.99 ? 1 : 0)
                    .shadow(color: MooniColor.accentSoft, radius: 6)
            }
        }
        .frame(height: 150)
    }
}

// MARK: - Compact 7-night trend

private struct MiniTrend: View {
    let progress: CGFloat

    private let values: [CGFloat] = [6.1, 5.4, 7.0, 6.6, 7.7, 7.1, 7.6]
    private let days = ["M", "T", "W", "T", "F", "S", "S"]
    private let goal: CGFloat = 8.0
    private let maxScale: CGFloat = 9.0

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let slot = w / CGFloat(values.count)
                let barW = slot * 0.5

                ZStack(alignment: .bottomLeading) {
                    let goalY = h - (goal / maxScale) * h
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: goalY))
                        p.addLine(to: CGPoint(x: w, y: goalY))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundColor(MooniColor.textMuted.opacity(0.6))

                    ForEach(values.indices, id: \.self) { i in
                        let isToday = i == values.count - 1
                        let full = (values[i] / maxScale) * h
                        let local = max(0, min(1, (progress - CGFloat(i) * 0.05) / 0.6))
                        let barH = full * local
                        let cx = slot * CGFloat(i) + slot / 2

                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(LinearGradient(
                                colors: isToday
                                    ? [MooniColor.accentSoft, MooniColor.accent]
                                    : [MooniColor.accent.opacity(0.35),
                                       MooniColor.accent.opacity(0.18)],
                                startPoint: .top, endPoint: .bottom))
                            .frame(width: barW, height: max(3, barH))
                            .shadow(color: isToday ? MooniColor.accent.opacity(0.6) : .clear,
                                    radius: 6)
                            .position(x: cx, y: h - max(3, barH) / 2)
                    }
                }
            }
            .frame(height: 150)

            HStack(spacing: 0) {
                ForEach(days.indices, id: \.self) { i in
                    Text(days[i])
                        .font(MooniFont.caption(10))
                        .foregroundColor(i == days.count - 1
                                         ? MooniColor.accentSoft : MooniColor.textMuted)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

#Preview {
    MarketingVideoView()
}
