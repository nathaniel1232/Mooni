import SwiftUI
import Combine

// MARK: - Reusable: playable audio sample button
//
// Defined here because both the prePaywall (Hear It Yourself stage) and the
// onboarding science screen (AudioInsightScreen) use it. Single source of
// truth for the visual treatment + haptic + tap → play mapping.
struct AudioSampleButton: View {
    let emoji: String
    let label: String
    let resource: String
    let tint: Color
    @ObservedObject private var player = SamplePlayer.shared
    @State private var pulse: CGFloat = 0

    private var isPlaying: Bool { player.currentlyPlaying == resource }
    private var isAvailable: Bool { SamplePlayer.isAvailable(resource) }

    var body: some View {
        Button(action: handleTap) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(isPlaying ? 0.32 : 0.18))
                        .frame(width: 60, height: 60)
                    Circle()
                        .stroke(tint.opacity(isPlaying ? 0.85 : 0.4), lineWidth: 1.5)
                        .frame(width: 60 + 6 * pulse, height: 60 + 6 * pulse)
                        .opacity(Double(1 - 0.6 * pulse))
                    EmojiIcon(emoji: emoji, size: 26, tint: tint)
                }
                Text(label)
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.textPrimary)
                    .lineLimit(1)
                Image(systemName: isPlaying ? "stop.circle.fill" : (isAvailable ? "play.circle.fill" : "speaker.slash"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isAvailable ? tint : MooniColor.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(white: 1, opacity: 0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(tint.opacity(isPlaying ? 0.55 : 0.18) as Color, lineWidth: 1)
            )
            .opacity(isAvailable ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .onChange(of: isPlaying) { _, playing in
            if playing {
                withAnimation(.easeOut(duration: 0.8).repeatForever(autoreverses: false)) { pulse = 1 }
            } else {
                withAnimation(.easeOut(duration: 0.25)) { pulse = 0 }
            }
        }
    }

    private func handleTap() {
        guard isAvailable else { return }
        Haptics.tap()
        player.toggle(resource)
    }
}

// MARK: - PrePaywall view
//
// Replaces the prior emotional-signature wizard with a science-backed
// conviction sequence. Every claim is sourced; every visual demonstrates
// real machinery the app uses. Drives the prospect from skeptical → "I get
// the science" → ready to see the plan / paywall.
struct PrePaywallView: View {
    let petName: String
    let species: PetSpecies
    let profile: OnboardingProfile
    let onContinue: () -> Void

    @State private var phase: Phase = .studies
    @State private var subStage: Int = 0

    // Signature stage state (preserved across the in-flow phases so the user
    // can scroll back to studies without losing their typed commitment).
    @State private var signatureStrokes: [SignatureStroke] = []
    @State private var typedCommitment: String = ""
    @State private var rating: Int = 0

    // Tap-driven reveal beat for the "Bad sleep burns muscle, not fat" study
    // (studies substage 1). Each Continue tap reveals the next animation step
    // (0 → 1 → 2 → 3 = fully revealed) instead of letting the chart auto-play
    // and overflow itself. Resets when the user leaves substage 1.
    @State private var dietBeat: Int = 0
    private static let dietBeatMax: Int = 3
    private var isDietStudy: Bool { phase == .studies && subStage == 1 }

    private enum Phase: Int, CaseIterable {
        case studies      // 4 substages — peer-reviewed findings
        case pipeline     // 3 substages — Listen → Stage → Score with visuals
        case hear         // 1 substage — playable sound demo
        case rate         // 1 substage — star-rating ask after the proof
        case commit       // 1 substage — typed phrase + signature
    }

    private static let studiesCount = 4
    private static let pipelineCount = 3

    var body: some View {
        ZStack {
            MooniColor.background.ignoresSafeArea()
            StarsBackground(count: 70)

            VStack(spacing: 0) {
                phaseProgressBar
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 22)

                Spacer(minLength: 0)

                Group {
                    switch phase {
                    case .studies:
                        StudiesStage(
                            subStage: subStage,
                            total: Self.studiesCount,
                            petName: petName,
                            dietBeat: $dietBeat,
                            dietBeatMax: Self.dietBeatMax
                        )
                    case .pipeline:
                        PipelineStage(subStage: subStage, total: Self.pipelineCount, petName: petName)
                    case .hear:
                        HearItYourselfStage(petName: petName)
                    case .rate:
                        RateAfterScienceStage(rating: $rating, petName: petName)
                    case .commit:
                        SignatureStage(
                            petName: petName,
                            typedCommitment: $typedCommitment,
                            strokes: $signatureStrokes
                        )
                    }
                }
                .id("\(phase.rawValue)-\(subStage)")
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal: .opacity.combined(with: .move(edge: .leading))
                ))

                Spacer(minLength: 0)

                footer
                    .padding(.horizontal, 24)
                    .padding(.bottom, 36)
            }
        }
    }

    // MARK: Progress bar — segments per phase

    /// Phases shown in the progress bar — drop `.rate` since the review prompt
    /// was removed; keep the rest in order so existing transitions stay valid.
    private static let visiblePhases: [Phase] = [.studies, .pipeline, .hear, .commit]

    private var phaseProgressBar: some View {
        HStack(spacing: 6) {
            ForEach(Self.visiblePhases, id: \.rawValue) { p in
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.22))
                        Capsule()
                            .fill(LinearGradient(
                                colors: [MooniColor.accent, MooniColor.accentSoft],
                                startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * progressFraction(for: p))
                            .animation(.spring(response: 0.4), value: phase)
                            .animation(.spring(response: 0.4), value: subStage)
                    }
                }
                .frame(height: 4)
            }
        }
    }

    private func progressFraction(for p: Phase) -> CGFloat {
        if p.rawValue < phase.rawValue { return 1 }
        if p.rawValue > phase.rawValue { return 0 }
        switch phase {
        case .studies:
            // While the diet study is mid-reveal, blend the beat progress into
            // the substage segment so the progress bar feels alive on each tap.
            if isDietStudy {
                let beatShare = CGFloat(dietBeat) / CGFloat(Self.dietBeatMax)
                let base = CGFloat(subStage) / CGFloat(Self.studiesCount)
                let span = 1.0 / CGFloat(Self.studiesCount)
                return base + span * beatShare
            }
            return CGFloat(subStage + 1) / CGFloat(Self.studiesCount)
        case .pipeline: return CGFloat(subStage + 1) / CGFloat(Self.pipelineCount)
        case .hear:     return 1
        case .rate:     return rating > 0 ? 1 : 0.5
        case .commit:
            let typed = typedCommitment.trimmingCharacters(in: .whitespacesAndNewlines)
            let typedDone: CGFloat = Self.isCommitmentPhraseMatched(typed)
                ? 0.5
                : CGFloat(min(typed.count, 14)) / 14 * 0.5
            let signed: CGFloat = signatureStrokes.isEmpty ? 0 : 0.5
            return min(typedDone + signed, 1)
        }
    }

    // MARK: Footer

    private var primaryTitle: String {
        switch phase {
        case .studies:
            if isDietStudy && dietBeat < Self.dietBeatMax {
                return "Continue"
            }
            return subStage < Self.studiesCount - 1 ? "Next finding" : "How it works"
        case .pipeline: return subStage < Self.pipelineCount - 1 ? "Next step" : "Hear it yourself"
        case .hear:     return "Continue"
        case .rate:     return rating > 0 ? "Continue" : "Skip for now"
        case .commit:   return "I'm in — show my plan"
        }
    }

    private var canAdvanceFromCurrent: Bool {
        switch phase {
        case .commit:
            return Self.isCommitmentPhraseMatched(typedCommitment) && !signatureStrokes.isEmpty
        default:
            return true
        }
    }

    @ViewBuilder
    private var footer: some View {
        // Stripped: previously rendered "Your plan unlocks…" hints under the
        // Continue button. Anything that resembles a paid-plan tease before
        // the paywall itself burns conversion, so the disclaimer is gone.
        PrimaryButton(title: primaryTitle, icon: phase == .commit ? "sparkles" : nil) {
            if canAdvanceFromCurrent { advance() }
        }
        .disabled(!canAdvanceFromCurrent)
        .opacity(canAdvanceFromCurrent ? 1 : 0.45)
    }

    // MARK: Navigation

    private func advance() {
        Haptics.medium()
        // Diet-study reveal: each Continue tap reveals the next beat. Only
        // after all beats are visible does Continue advance to the next finding.
        if isDietStudy && dietBeat < Self.dietBeatMax {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                dietBeat += 1
            }
            Haptics.tick()
            return
        }
        withAnimation(.easeInOut(duration: 0.45)) {
            switch phase {
            case .studies:
                if subStage < Self.studiesCount - 1 {
                    subStage += 1
                    dietBeat = 0
                }
                else { Haptics.success(); phase = .pipeline; subStage = 0; dietBeat = 0 }
            case .pipeline:
                if subStage < Self.pipelineCount - 1 { subStage += 1 }
                else { Haptics.success(); phase = .hear; subStage = 0 }
            case .hear:
                SamplePlayer.shared.stop()
                Haptics.success()
                // Rate stage is skipped entirely — review prompt moved post-purchase.
                phase = .commit
                subStage = 0
            case .rate:
                Haptics.success()
                phase = .commit
                subStage = 0
            case .commit:
                Haptics.success()
                onContinue()
            }
        }
    }

    // MARK: - Commitment phrase matcher (used by SignatureStage and progress)

    fileprivate static func isCommitmentPhraseMatched(_ text: String) -> Bool {
        let words = normalizedCommitmentWords(text)
        guard !words.isEmpty else { return false }

        let normalized = words.joined()
        let exactTargets = ["iamcommitted", "iamcommited", "imcommitted", "imcommited"]
        if exactTargets.contains(normalized) { return true }
        if exactTargets.contains(where: { editDistance(normalized, $0) <= 3 }) { return true }

        let selfWords = ["i", "im", "iam", "me", "my"]
        let commitmentWords = ["committed", "commited", "commit", "promise", "ready", "agree", "dedicated"]
        let hasSelfWord = words.contains { selfWords.contains($0) }
        let hasCommitmentWord = words.contains { word in
            commitmentWords.contains(word) ||
            editDistance(word, "committed") <= 2 ||
            editDistance(word, "commit") <= 1 ||
            editDistance(word, "promise") <= 2
        }
        return hasSelfWord && hasCommitmentWord
    }

    private static func normalizedCommitmentWords(_ text: String) -> [String] {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }
    }

    private static func editDistance(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs), b = Array(rhs)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var prev = Array(0...b.count)
        var cur = Array(repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            cur[0] = i
            for j in 1...b.count {
                let sub = prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, sub)
            }
            swap(&prev, &cur)
        }
        return prev[b.count]
    }
}

// MARK: - Phase 1: Studies (3 substages)

private struct StudiesStage: View {
    let subStage: Int
    let total: Int
    let petName: String
    /// Tap-driven reveal for the diet study (substage 1). Other studies still
    /// auto-play their visuals on appear.
    @Binding var dietBeat: Int
    let dietBeatMax: Int

    @State private var visible = false

    private struct Study {
        let badge: String
        let badgeIcon: String
        let badgeTint: Color
        let headline: String
        let visual: AnyView
        let takeaway: String
        let citation: String
        let isWarning: Bool
    }

    private var study: Study {
        switch subStage {
        case 0: return Study(
            badge: "META-ANALYSIS · 1.4M PEOPLE",
            badgeIcon: "exclamationmark.triangle.fill",
            badgeTint: MooniColor.danger,
            headline: "Short sleep is\na mortality signal.",
            visual: AnyView(MortalityChart()),
            takeaway: "People sleeping under 6 hours show **+12% higher all-cause mortality** versus 7-8 hour sleepers.",
            citation: "Cappuccio et al., Sleep, 2010 · 16-study meta-analysis · 1,382,999 participants",
            isWarning: true
        )
        case 1: return Study(
            badge: "RANDOMIZED CROSSOVER TRIAL",
            badgeIcon: "figure.strengthtraining.traditional",
            badgeTint: MooniColor.danger,
            headline: "Bad sleep burns muscle,\nnot fat.",
            visual: AnyView(DietingFatLossChart(beat: $dietBeat, maxBeat: dietBeatMax)),
            takeaway: "Same diet, same calories. Sleep-restricted dieters lost **55% less fat** and **60% more lean muscle**. *If sleep were a pill, they'd ban it for being a performance-enhancer.*",
            citation: "Nedeltcheva et al., Annals of Internal Medicine, 2010 · 8.5h vs 5.5h sleep · matched calorie deficit",
            isWarning: true
        )
        case 2: return Study(
            badge: "AASM SCORING MANUAL v3",
            badgeIcon: "waveform.path.ecg",
            badgeTint: MooniColor.accent,
            headline: "Your night isn't flat.\nIt's 4-6 cycles.",
            visual: AnyView(StudyHypnogramVisual()),
            takeaway: "**Memory consolidates in REM. Tissue repairs in N3 (deep).** Miss either and you wake worse than the score alone shows.",
            citation: "Berry et al., AASM Manual for the Scoring of Sleep, v3 · 2023",
            isWarning: false
        )
        default: return Study(
            badge: "AUDIOSET · GOOGLE RESEARCH",
            badgeIcon: "waveform",
            badgeTint: MooniColor.success,
            headline: "Sound + motion =\nthe full picture.",
            visual: AnyView(AudioConfidenceVisual()),
            takeaway: "**521 sound classes** detected with state-of-the-art accuracy on AudioSet — the same dataset cited by 1,000+ peer-reviewed papers.",
            citation: "Gemmeke et al., AudioSet · ICASSP 2017 · TensorFlow Hub",
            isWarning: false
        )
        }
    }

    private var studyEmoji: String {
        switch subStage {
        case 0:  return "⚠️"
        case 1:  return "💪"
        case 2:  return "🌙"
        default: return "🎧"
        }
    }

    private var simpleTakeaway: String {
        switch subStage {
        case 0:  return "Under 6 hours of sleep means +12% higher risk of early death."
        case 1:  return "Same diet — but bad sleep burned 55% less fat and 60% more muscle."
        case 2:  return "Your night isn't one block. It's 4–6 cycles. Miss any and you wake worse."
        default: return "We use the same audio standard as 1,000+ research papers."
        }
    }

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 4)

            // One emoji chip — no peer-reviewed pill + badge stack
            Text("\(studyEmoji) STUDY \(subStage + 1) OF \(total)")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundColor(study.badgeTint)
                .tracking(2)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(study.badgeTint.opacity(0.16))
                .clipShape(Capsule())

            Text(study.headline)
                .font(MooniFont.display(28))
                .foregroundColor(MooniColor.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 14)
                .fixedSize(horizontal: false, vertical: true)

            study.visual
                .frame(maxWidth: .infinity)
                .frame(minHeight: 200, maxHeight: 300)
                .padding(.horizontal, 8)

            Text(simpleTakeaway)
                .font(MooniFont.body(14))
                .foregroundColor(MooniColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .fixedSize(horizontal: false, vertical: true)

            // Sub-stage dots — same pattern as the widgets/sleep-circle screens
            HStack(spacing: 6) {
                ForEach(0..<total, id: \.self) { i in
                    Capsule()
                        .fill(i == subStage ? MooniColor.accent : Color.white.opacity(0.22))
                        .frame(width: i == subStage ? 22 : 7, height: 6)
                }
            }
            .padding(.top, 2)

            Spacer(minLength: 4)
        }
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 12)
        .padding(.horizontal, 6)
        .onAppear {
            visible = false
            withAnimation(.easeOut(duration: 0.45)) { visible = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                if study.isWarning { Haptics.warning() } else { Haptics.medium() }
            }
        }
        .onChange(of: subStage) { _, _ in
            visible = false
            withAnimation(.easeOut(duration: 0.4)) { visible = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                if study.isWarning { Haptics.warning() } else { Haptics.medium() }
            }
        }
    }
}

// MARK: - Study visuals

private struct MortalityChart: View {
    @State private var fill: CGFloat = 0
    private let bars: [(label: String, height: CGFloat, color: Color, callout: String?)] = [
        ("<6h",   1.00, MooniColor.danger,    "+12%"),
        ("6-7h",  0.65, MooniColor.warning,   nil),
        ("7-8h",  0.42, MooniColor.success,   "baseline"),
        ("8-9h",  0.55, MooniColor.warning,   nil),
        (">9h",   0.78, MooniColor.danger,    "+18%")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("RELATIVE MORTALITY RISK")
                    .font(MooniFont.caption(9))
                    .foregroundColor(MooniColor.textMuted)
                    .tracking(1.5)
                Spacer()
                Text("by sleep duration")
                    .font(MooniFont.caption(9))
                    .foregroundColor(MooniColor.textMuted)
            }

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(bars.indices, id: \.self) { i in
                    let b = bars[i]
                    VStack(spacing: 4) {
                        if let callout = b.callout {
                            Text(callout)
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundColor(b.color)
                                .opacity(fill > 0 ? 1 : 0)
                        } else {
                            Text(" ")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                        }
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(LinearGradient(
                                colors: [b.color.opacity(0.6), b.color],
                                startPoint: .top, endPoint: .bottom))
                            .frame(height: 100 * b.height * fill)
                            .frame(maxWidth: .infinity)
                            .animation(.spring(response: 0.8, dampingFraction: 0.85)
                                .delay(Double(i) * 0.08), value: fill)
                        Text(b.label)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(MooniColor.textSecondary)
                    }
                }
            }
            .frame(height: 130)
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .onAppear {
            fill = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { fill = 1 }
            // 5 bars, ~1.2s total — stagger ticks while bars rise
            for i in 0..<bars.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.20 + Double(i) * 0.12) {
                    Haptics.tick()
                }
            }
        }
    }
}

// Two-bar comparison: 8.5h sleep vs 5.5h sleep, matched calorie deficit.
// Each bar shows fat-lost (green, "good") + lean/muscle-lost (red, "bad")
// stacked. Animates fat first, then muscle, with the muscle column pulling
// dramatically taller for the sleep-restricted group.
// Story-mode visualization for Nedeltcheva et al. 2010. Auto-progresses
// through 4 beats while the user reads — each beat is one piece of the
// "two people, same diet, only sleep differs" narrative. Haptic on every
// beat advance so the storytelling feels physical.
/// Tap-driven reveal of the Nedeltcheva 2010 muscle/fat finding.
/// The parent owns `beat` so each Continue tap drives one reveal step:
///   0 — figures only (same calories, same workouts)
///   1 — sleep duration tags (8.5h vs 5.5h)
///   2 — bars rise to equal total weight loss
///   3 — callouts: fat-loss vs muscle-loss split
struct DietingFatLossChart: View {
    @Binding var beat: Int
    let maxBeat: Int

    // Real values (kg, Nedeltcheva 2010, ~14-day matched calorie deficit):
    //   8.5h: 1.4 kg fat lost, 1.5 kg lean lost   (~3 kg total)
    //   5.5h: 0.6 kg fat lost, 2.4 kg lean lost   (~3 kg total)
    private let goodFatHeight: CGFloat  = 62
    private let goodLeanHeight: CGFloat = 28
    private let badFatHeight: CGFloat   = 26
    private let badLeanHeight: CGFloat  = 74

    private var goodFatFill: CGFloat  { beat >= 2 ? 1 : 0 }
    private var goodLeanFill: CGFloat { beat >= 2 ? 1 : 0 }
    private var badFatFill: CGFloat   { beat >= 2 ? 1 : 0 }
    private var badLeanFill: CGFloat  { beat >= 2 ? 1 : 0 }
    private var showCallouts: Bool    { beat >= 3 }

    var body: some View {
        VStack(spacing: 10) {
            Text(captionText)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundColor(captionColor)
                .tracking(0.6)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(captionColor.opacity(0.14))
                .clipShape(Capsule())
                .frame(height: 32)
                .id("caption-\(beat)")
                .transition(.opacity.combined(with: .move(edge: .top)))

            HStack(alignment: .bottom, spacing: 22) {
                personColumn(
                    figureColor: MooniColor.success,
                    sleepLabel: "8.5h sleep",
                    sleepLabelColor: MooniColor.success,
                    fatHeight: goodFatHeight,
                    leanHeight: goodLeanHeight,
                    fatFill: goodFatFill,
                    leanFill: goodLeanFill,
                    showCallout: showCallouts,
                    callout: "1.4 kg fat ↓",
                    calloutTint: MooniColor.success
                )

                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(MooniColor.textMuted)
                    .padding(.bottom, 52)

                personColumn(
                    figureColor: MooniColor.danger,
                    sleepLabel: "5.5h sleep",
                    sleepLabelColor: MooniColor.danger,
                    fatHeight: badFatHeight,
                    leanHeight: badLeanHeight,
                    fatFill: badFatFill,
                    leanFill: badLeanFill,
                    showCallout: showCallouts,
                    callout: "2.4 kg muscle ↓",
                    calloutTint: MooniColor.danger
                )
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 6) {
                Image(systemName: "scalemass.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(MooniColor.accentSoft)
                Text("Both lost ~3 kg total")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(MooniColor.textSecondary)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(MooniColor.accent.opacity(0.10))
            .clipShape(Capsule())
            .frame(height: 18)
            .opacity(beat >= 2 ? 1 : 0)
            .scaleEffect(beat >= 2 ? 1 : 0.6)

            HStack(spacing: 14) {
                legendDot(color: MooniColor.success, label: "fat lost")
                legendDot(color: MooniColor.danger, label: "muscle lost")
                Spacer(minLength: 8)
                progressDots
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .animation(.spring(response: 0.55, dampingFraction: 0.82), value: beat)
        .onAppear {
            // Reset reveal whenever the diet study reappears.
            if beat > maxBeat { beat = 0 }
            Haptics.tick()
        }
        .onChange(of: beat) { _, newBeat in
            switch newBeat {
            case 1: Haptics.tick()
            case 2: Haptics.medium()
            case 3: Haptics.warning()
            default: break
            }
        }
    }

    private var captionText: String {
        switch beat {
        case 0: return "TWO PEOPLE · SAME CALORIES · SAME WORKOUTS"
        case 1: return "ONLY DIFFERENCE: SLEEP"
        case 2: return "AFTER 14 DAYS — SAME TOTAL WEIGHT LOST"
        default: return "BUT THE TYPE OF WEIGHT? COMPLETELY DIFFERENT."
        }
    }

    private var captionColor: Color {
        switch beat {
        case 0: return MooniColor.textSecondary
        case 1: return MooniColor.accentSoft
        case 2: return MooniColor.warning
        default: return MooniColor.danger
        }
    }

    /// Tiny reveal-progress indicator (4 dots) inside the chart so the user
    /// knows there's more to see before Continue advances to the next study.
    private var progressDots: some View {
        HStack(spacing: 4) {
            ForEach(0...maxBeat, id: \.self) { i in
                Capsule()
                    .fill(i <= beat ? MooniColor.accent : Color.white.opacity(0.22))
                    .frame(width: i == beat ? 12 : 5, height: 4)
                    .animation(.spring(response: 0.4), value: beat)
            }
        }
    }

    private func personColumn(
        figureColor: Color,
        sleepLabel: String,
        sleepLabelColor: Color,
        fatHeight: CGFloat,
        leanHeight: CGFloat,
        fatFill: CGFloat,
        leanFill: CGFloat,
        showCallout: Bool,
        callout: String,
        calloutTint: Color
    ) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "figure.stand")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(figureColor.opacity(0.9))
                .frame(width: 40, height: 32)
                .background(figureColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack(spacing: 3) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 8, weight: .bold))
                Text(sleepLabel)
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
            }
            .foregroundColor(sleepLabelColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(sleepLabelColor.opacity(0.16))
            .clipShape(Capsule())
            .frame(height: 18)
            .opacity(beat >= 1 ? 1 : 0)
            .scaleEffect(beat >= 1 ? 1 : 0.7)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 46, height: 110)
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [MooniColor.danger.opacity(0.7), MooniColor.danger],
                            startPoint: .top, endPoint: .bottom))
                        .frame(width: 46, height: leanHeight * leanFill)
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [MooniColor.success.opacity(0.7), MooniColor.success],
                            startPoint: .top, endPoint: .bottom))
                        .frame(width: 46, height: fatHeight * fatFill)
                }
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .frame(width: 46, height: 110)

            Text(callout)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundColor(calloutTint)
                .frame(height: 14)
                .opacity(showCallout ? 1 : 0)
                .scaleEffect(showCallout ? 1 : 0.7)
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundColor(MooniColor.textMuted)
        }
    }
}

private struct StudyHypnogramVisual: View {
    @State private var phase: CGFloat = 0
    @State private var labelsIn = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            HypnogramCurve()
                .trim(from: 0, to: phase)
                .stroke(LinearGradient(
                    colors: [MooniColor.accent, MooniColor.success, MooniColor.accentSoft],
                    startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                .padding(.horizontal, 14)
                .padding(.vertical, 22)

            VStack {
                HStack {
                    cycleTag(text: "Cycle 1", color: MooniColor.accent)
                    Spacer()
                    cycleTag(text: "Cycle 3", color: MooniColor.success)
                    Spacer()
                    cycleTag(text: "Cycle 5", color: MooniColor.accentSoft)
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .opacity(labelsIn ? 1 : 0)
                Spacer()
                HStack {
                    Text("11pm").font(.system(size: 9)).foregroundColor(MooniColor.textMuted)
                    Spacer()
                    Text("3am").font(.system(size: 9)).foregroundColor(MooniColor.textMuted)
                    Spacer()
                    Text("7am").font(.system(size: 9)).foregroundColor(MooniColor.textMuted)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            }
        }
        .onAppear {
            phase = 0
            labelsIn = false
            withAnimation(.easeOut(duration: 1.6)) { phase = 1 }
            withAnimation(.easeOut(duration: 0.4).delay(0.5)) { labelsIn = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { Haptics.success() }
        }
    }

    private func cycleTag(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.18))
            .clipShape(Capsule())
    }
}

private struct HypnogramCurve: Shape {
    func path(in rect: CGRect) -> Path {
        let pts: [CGPoint] = [
            .init(x: 0.00, y: 0.00),
            .init(x: 0.05, y: 0.45),
            .init(x: 0.10, y: 0.85),
            .init(x: 0.18, y: 0.85),
            .init(x: 0.22, y: 0.45),
            .init(x: 0.26, y: 0.15),
            .init(x: 0.30, y: 0.50),
            .init(x: 0.36, y: 0.65),
            .init(x: 0.44, y: 0.55),
            .init(x: 0.48, y: 0.15),
            .init(x: 0.54, y: 0.50),
            .init(x: 0.62, y: 0.55),
            .init(x: 0.68, y: 0.45),
            .init(x: 0.74, y: 0.15),
            .init(x: 0.80, y: 0.45),
            .init(x: 0.88, y: 0.45),
            .init(x: 0.94, y: 0.15),
            .init(x: 1.00, y: 0.00)
        ]
        var path = Path()
        for (i, p) in pts.enumerated() {
            let pt = CGPoint(x: rect.minX + p.x * rect.width,
                             y: rect.minY + p.y * rect.height)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        return path
    }
}

// Story-mode YAMNet visual. Three beats:
//   1) Big number "0" → ticks up to 8,000,000 (clips trained on)
//   2) Drops 521 below it (sound classes)
//   3) Reveals the 5 sleep-relevant labels with their confidence bars
private struct AudioConfidenceVisual: View {
    @State private var beat: Int = 0
    @State private var clipsCount: Int = 0
    @State private var classesIn = false
    @State private var fillCount: Int = 0

    private let labels: [(name: String, score: Double, color: Color)] = [
        ("Snore",      0.94, Color.pink),
        ("Speech",     0.91, MooniColor.warning),
        ("Breath",     0.86, MooniColor.success),
        ("Silence",    0.97, MooniColor.accentSoft),
        ("Movement",   0.83, MooniColor.accent)
    ]

    var body: some View {
        VStack(spacing: 10) {
            // Caption ribbon — narrative beats
            Text(captionText)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundColor(MooniColor.success)
                .tracking(0.6)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(MooniColor.success.opacity(0.14))
                .clipShape(Capsule())

            // Big number — first the 8M clips, then 521 classes
            HStack(spacing: 16) {
                bigStat(
                    value: clipsCount >= 8_000_000 ? "8M" : "\(formatBig(clipsCount))",
                    label: "clips trained",
                    tint: MooniColor.accent
                )
                .opacity(beat >= 0 ? 1 : 0)
                .scaleEffect(beat >= 0 ? 1 : 0.85)

                bigStat(
                    value: "521",
                    label: "sound classes",
                    tint: MooniColor.success
                )
                .opacity(classesIn ? 1 : 0)
                .scaleEffect(classesIn ? 1 : 0.85)
            }
            .frame(maxWidth: .infinity)

            // Confidence bars for sleep-relevant labels
            if beat >= 2 {
                VStack(spacing: 5) {
                    ForEach(labels.indices, id: \.self) { i in
                        let l = labels[i]
                        HStack(spacing: 8) {
                            Text(l.name)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(MooniColor.textPrimary)
                                .frame(width: 58, alignment: .leading)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.08))
                                    Capsule()
                                        .fill(LinearGradient(
                                            colors: [l.color.opacity(0.7), l.color],
                                            startPoint: .leading, endPoint: .trailing))
                                        .frame(width: i < fillCount ? geo.size.width * CGFloat(l.score) : 0)
                                }
                            }
                            .frame(height: 7)
                            Text("\(Int(l.score * 100))%")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundColor(l.color)
                                .frame(width: 32, alignment: .trailing)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .onAppear { runStory() }
    }

    private var captionText: String {
        switch beat {
        case 0: return "GOOGLE TRAINED IT ON 8 MILLION CLIPS"
        case 1: return "521 SOUND CLASSES — INCLUDING SLEEP EVENTS"
        default: return "SO YOUR PHONE CAN TELL THESE APART"
        }
    }

    private func bigStat(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(LinearGradient(
                    colors: [tint, MooniColor.accentSoft],
                    startPoint: .top, endPoint: .bottom))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundColor(MooniColor.textMuted)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func formatBig(_ n: Int) -> String {
        if n >= 1_000_000 {
            return String(format: "%.1fM", Double(n) / 1_000_000)
        } else if n >= 1_000 {
            return "\(n / 1_000)K"
        }
        return "\(n)"
    }

    private func runStory() {
        beat = 0
        classesIn = false
        fillCount = 0
        clipsCount = 0
        Haptics.tick()

        // Tick the clips counter up to 8M over ~1.0s
        let totalSteps = 18
        for s in 1...totalSteps {
            let delay = 0.05 + Double(s) * (1.0 / Double(totalSteps))
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                clipsCount = Int(Double(8_000_000) * (Double(s) / Double(totalSteps)))
                if s % 4 == 0 { Haptics.tick() }
            }
        }

        // Beat 1 — drop 521 classes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                classesIn = true
                beat = 1
            }
            Haptics.medium()
        }

        // Beat 2 — reveal the bars
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.85) {
            withAnimation(.easeOut(duration: 0.4)) { beat = 2 }
            for i in 0..<labels.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.10) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                        fillCount = i + 1
                    }
                    Haptics.tick()
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { Haptics.success() }
        }
    }
}

// MARK: - Phase 2: Pipeline (3 substages)

private struct PipelineStage: View {
    let subStage: Int
    let total: Int
    let petName: String

    @State private var visible = false

    private struct Step {
        let stepLabel: String
        let title: String
        let visual: AnyView
        let body: String
        let citation: String
        let stepNumber: Int
    }

    private var step: Step {
        switch subStage {
        case 0: return Step(
            stepLabel: "STEP 1 OF 3 · LISTEN",
            title: "Listen, in real time.",
            visual: AnyView(ListenVisual()),
            body: "Your phone runs **YAMNet** continuously, classifying every minute of audio into one of 521 sound categories. Snore? Talk? Breath? It knows.",
            citation: "Audio kept ≤ 30s in a rolling buffer · never written to disk · never uploaded",
            stepNumber: 1
        )
        case 1: return Step(
            stepLabel: "STEP 2 OF 3 · STAGE",
            title: "Stage your night.",
            visual: AnyView(StageVisual()),
            body: "Audio events + motion data feed into **AASM scoring rules** — the same algorithm certified labs use to label REM, Light, Deep, and Wake.",
            citation: "Berry et al., AASM Manual for the Scoring of Sleep, v3 · 2023",
            stepNumber: 2
        )
        default: return Step(
            stepLabel: "STEP 3 OF 3 · SCORE",
            title: "Score, like a sleep lab.",
            visual: AnyView(ScoreVisual()),
            body: "Your night is reduced to a 0-100 score using the **Sleep Efficiency formula** plus clinical bands — the same math powering every accredited sleep study.",
            citation: "SE = (Total Sleep Time / Time in Bed) × 100 · clinical standard since 1972",
            stepNumber: 3
        )
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "atom")
                        .font(.system(size: 9, weight: .bold))
                    Text("METHODOLOGY · HOW MOONI WORKS")
                        .font(MooniFont.caption(9))
                        .tracking(1.5)
                }
                .foregroundColor(MooniColor.accentSoft)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())

                HStack(spacing: 6) {
                    Image(systemName: "gearshape.2.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(step.stepLabel)
                        .font(MooniFont.caption(10))
                        .tracking(1.6)
                }
                .foregroundColor(MooniColor.accentSoft)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(MooniColor.accent.opacity(0.14))
                .clipShape(Capsule())
            }

            Text(step.title)
                .font(MooniFont.display(26))
                .foregroundColor(MooniColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            step.visual
                .frame(maxWidth: .infinity)
                .frame(minHeight: 180, maxHeight: 200)
                .padding(.horizontal, 14)

            Text(step.body)
                .font(MooniFont.body(14))
                .foregroundColor(MooniColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 22)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(MooniColor.accentSoft)
                Text(step.citation)
                    .font(MooniFont.caption(9))
                    .foregroundColor(MooniColor.textMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)

            // Step indicator
            HStack(spacing: 8) {
                ForEach(0..<total, id: \.self) { i in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(i <= subStage ? MooniColor.success : Color.white.opacity(0.2))
                            .frame(width: 16, height: 16)
                            .overlay(
                                Text("\(i + 1)")
                                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                                    .foregroundColor(i <= subStage ? Color.white : MooniColor.textMuted)
                            )
                        if i < total - 1 {
                            Rectangle()
                                .fill(i < subStage ? MooniColor.success : Color.white.opacity(0.2))
                                .frame(width: 28, height: 2)
                        }
                    }
                }
            }
            .padding(.top, 4)
        }
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 12)
        .padding(.horizontal, 6)
        .onAppear {
            visible = false
            withAnimation(.easeOut(duration: 0.45)) { visible = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { Haptics.medium() }
        }
        .onChange(of: subStage) { _, _ in
            visible = false
            withAnimation(.easeOut(duration: 0.4)) { visible = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { Haptics.medium() }
        }
    }
}

// MARK: - Pipeline visuals

private struct ListenVisual: View {
    @State private var pulse = false
    @State private var eventsIn = 0
    private let events: [(label: String, color: Color)] = [
        ("snore", Color.pink),
        ("speech", MooniColor.warning),
        ("breath", MooniColor.success)
    ]

    var body: some View {
        VStack(spacing: 12) {
            // Animated waveform
            HStack(spacing: 3) {
                ForEach(0..<28, id: \.self) { i in
                    Capsule()
                        .fill(LinearGradient(
                            colors: [MooniColor.accent.opacity(0.7), MooniColor.accentSoft],
                            startPoint: .top, endPoint: .bottom))
                        .frame(width: 4, height: barHeight(i))
                        .animation(.easeInOut(duration: 0.8 + Double(i % 4) * 0.1)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.04), value: pulse)
                }
            }
            .frame(height: 60)

            Image(systemName: "arrow.down")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(MooniColor.accentSoft.opacity(0.6))

            HStack(spacing: 8) {
                ForEach(events.indices, id: \.self) { i in
                    let e = events[i]
                    Text(e.label)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(MooniColor.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(e.color.opacity(0.18))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(e.color.opacity(0.4), lineWidth: 1))
                        .opacity(i < eventsIn ? 1 : 0)
                        .scaleEffect(i < eventsIn ? 1 : 0.85)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .onAppear {
            pulse = true
            for i in 0..<events.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 + Double(i) * 0.18) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                        eventsIn = i + 1
                    }
                    Haptics.tick()
                }
            }
        }
    }

    private func barHeight(_ i: Int) -> CGFloat {
        let pattern: [CGFloat] = [12, 28, 44, 60, 50, 28, 22, 38, 56, 40, 22, 16, 30, 48]
        return pattern[i % pattern.count]
    }
}

private struct StageVisual: View {
    @State private var fillIn = 0
    private let stages: [(label: String, color: Color, share: Double)] = [
        ("Awake", MooniColor.warning,    0.04),
        ("REM",   MooniColor.accent,     0.22),
        ("Light", MooniColor.accentSoft, 0.50),
        ("Deep",  MooniColor.success,    0.24)
    ]

    var body: some View {
        VStack(spacing: 10) {
            // Stacked bar
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(stages.indices, id: \.self) { i in
                        let s = stages[i]
                        Rectangle()
                            .fill(s.color)
                            .frame(width: i < fillIn ? geo.size.width * CGFloat(s.share) : 0)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .frame(height: 18)
            .background(Color.white.opacity(0.06).clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous)))

            // Legend
            VStack(spacing: 4) {
                ForEach(stages.indices, id: \.self) { i in
                    let s = stages[i]
                    HStack {
                        Circle().fill(s.color).frame(width: 7, height: 7)
                        Text(s.label)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(MooniColor.textPrimary)
                        Spacer()
                        Text("\(Int(s.share * 100))%")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundColor(s.color)
                    }
                    .opacity(i < fillIn ? 1 : 0.3)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .onAppear {
            fillIn = 0
            for i in 0..<stages.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 + Double(i) * 0.16) {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                        fillIn = i + 1
                    }
                    Haptics.tick()
                }
            }
        }
    }
}

private struct ScoreVisual: View {
    @State private var ringProgress: Double = 0
    @State private var displayScore: Int = 0

    var body: some View {
        VStack(spacing: 10) {
            Text("YOUR SLEEP SCORE")
                .font(MooniFont.caption(9))
                .foregroundColor(MooniColor.textMuted)
                .tracking(1.6)

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(
                        AngularGradient(
                            colors: [MooniColor.success.opacity(0.7), MooniColor.success, MooniColor.accentSoft],
                            center: .center),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 1) {
                    Text("\(displayScore)")
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundColor(MooniColor.textPrimary)
                    Text("of 100")
                        .font(MooniFont.caption(10))
                        .foregroundColor(MooniColor.textMuted)
                }
            }
            .frame(width: 110, height: 110)

            Text("87 ≈ Top 18% of nights")
                .font(MooniFont.caption(11))
                .foregroundColor(MooniColor.success)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(MooniColor.success.opacity(0.14))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .onAppear {
            ringProgress = 0
            displayScore = 0
            withAnimation(.easeOut(duration: 1.2)) { ringProgress = 0.87 }
            // Tick the score upward with light haptics
            for i in 1...87 where i % 12 == 0 {
                let delay = 0.05 + Double(i) * 0.011
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    displayScore = min(i, 87)
                    if i % 24 == 0 { Haptics.tick() }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) {
                displayScore = 87
                Haptics.success()
            }
        }
    }
}

// MARK: - Phase 3: Hear It Yourself

private struct HearItYourselfStage: View {
    let petName: String
    @State private var visible = false

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 6) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("DEMO · TAP TO PLAY")
                    .font(MooniFont.caption(10))
                    .tracking(1.6)
            }
            .foregroundColor(MooniColor.success)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(MooniColor.success.opacity(0.14))
            .clipShape(Capsule())

            Text("Hear what SleepOwl\ncatches at night.")
                .font(MooniFont.display(28))
                .foregroundColor(MooniColor.textPrimary)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                AudioSampleButton(emoji: "😴", label: "Snore",      resource: "sample_snore",     tint: Color.pink)
                AudioSampleButton(emoji: "💬", label: "Sleep talk", resource: "sample_sleeptalk", tint: MooniColor.warning)
                AudioSampleButton(emoji: "🌬️", label: "Breath",     resource: "sample_breath",    tint: MooniColor.success)
            }
            .padding(.horizontal, 4)

            Text("These are just three of **521** sound classes SleepOwl recognizes — automatically, every night, on your phone.")
                .font(MooniFont.body(14))
                .foregroundColor(MooniColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .fixedSize(horizontal: false, vertical: true)

            // Final trust strip
            HStack(spacing: 8) {
                trustChip(icon: "lock.shield.fill", text: "On-device")
                trustChip(icon: "function",         text: "Cited formula")
                trustChip(icon: "leaf.fill",        text: "Open-source AI")
            }

            Text("YAMNet · Google Research · TensorFlow Hub · AASM Manual v3")
                .font(MooniFont.caption(9))
                .foregroundColor(MooniColor.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 12)
        .padding(.horizontal, 18)
        .onAppear {
            visible = false
            withAnimation(.easeOut(duration: 0.45)) { visible = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { Haptics.success() }
        }
    }

    private func trustChip(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(MooniColor.accentSoft)
            Text(text)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(MooniColor.textSecondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(MooniColor.accent.opacity(0.10))
        .clipShape(Capsule())
    }
}

// MARK: - Phase 4: Rate after the science

/// Star rating ask shown right after the user has been through every study,
/// the pipeline, and the audio demo — peak conviction, lowest friction.
/// Doesn't trigger the App Store review prompt (that lives in `.rateApp`
/// earlier in onboarding); this is a softer "tell us how we did" beat that
/// adds momentum into the commit phase.
private struct RateAfterScienceStage: View {
    @Binding var rating: Int
    let petName: String
    @State private var visible = false
    @State private var glow = false

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "hand.thumbsup.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("ONE QUICK ASK")
                    .font(MooniFont.caption(10))
                    .tracking(1.6)
            }
            .foregroundColor(MooniColor.accentSoft)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(MooniColor.accent.opacity(0.14))
            .clipShape(Capsule())

            ZStack {
                Circle()
                    .fill(MooniColor.warning.opacity(glow ? 0.30 : 0.16))
                    .frame(width: 130, height: 130)
                    .blur(radius: 26)
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(LinearGradient(
                        colors: [MooniColor.warning, MooniColor.accentSoft],
                        startPoint: .top, endPoint: .bottom))
            }
            .frame(height: 140)

            VStack(spacing: 8) {
                Text("Did the science land?")
                    .font(MooniFont.display(26))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Tap a star — it helps us know which studies hit hardest.")
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Stars
            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { i in
                    Button {
                        Haptics.tap()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            rating = i
                        }
                        if i == 5 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                Haptics.success()
                            }
                        }
                    } label: {
                        Image(systemName: i <= rating ? "star.fill" : "star")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundColor(i <= rating ? MooniColor.warning : MooniColor.textMuted.opacity(0.45))
                            .scaleEffect(i <= rating ? 1.0 : 0.92)
                            .shadow(color: i <= rating ? MooniColor.warning.opacity(0.5) : .clear, radius: 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)

            if rating > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.pink)
                    Text(rating >= 4 ? "Thank you — that means the world." : "Got it. We'll keep tightening.")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())
                .transition(.opacity.combined(with: .scale))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 12)
        .onAppear {
            visible = false
            withAnimation(.easeOut(duration: 0.45)) { visible = true }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { glow = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { Haptics.medium() }
        }
    }
}

// MARK: - Phase 5: Commitment (typed phrase + signature)

struct SignatureStroke: Identifiable {
    let id = UUID()
    var points: [CGPoint]
}

private struct SignatureStage: View {
    let petName: String
    @Binding var typedCommitment: String
    @Binding var strokes: [SignatureStroke]

    @FocusState private var fieldFocused: Bool
    @State private var current: [CGPoint] = []
    @State private var visible = false

    private var matched: Bool {
        PrePaywallView.isCommitmentPhraseMatched(typedCommitment)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack(spacing: 6) {
                    Image(systemName: "signature")
                        .font(.system(size: 11, weight: .bold))
                    Text("YOUR SLEEP CONTRACT")
                        .font(MooniFont.caption(10))
                        .tracking(1.6)
                }
                .foregroundColor(MooniColor.accentSoft)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(MooniColor.accent.opacity(0.14))
                .clipShape(Capsule())

                VStack(spacing: 6) {
                    Text("Sign your commitment")
                        .font(MooniFont.display(26))
                        .foregroundColor(MooniColor.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("Type the words and sign with your finger.\nThis is between you and \(petName).")
                        .font(MooniFont.body(13))
                        .foregroundColor(MooniColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Typed commitment
                VStack(alignment: .leading, spacing: 6) {
                    Text("Type: \"I am committed\"")
                        .font(MooniFont.caption(11))
                        .foregroundColor(MooniColor.textMuted)
                    ZStack(alignment: .leading) {
                        if typedCommitment.isEmpty {
                            Text("I am committed")
                                .font(MooniFont.title(18))
                                .foregroundColor(MooniColor.textMuted.opacity(0.45))
                                .padding(.leading, 14)
                        }
                        TextField("", text: $typedCommitment)
                            .font(MooniFont.title(18))
                            .foregroundColor(MooniColor.textPrimary)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 14)
                            .focused($fieldFocused)
                            .submitLabel(.done)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .onChange(of: typedCommitment) { old, new in
                                // Tap haptic per char while typing — gentle but tactile.
                                if new.count > old.count { Haptics.tap() }
                                if !old.isEmpty && PrePaywallView.isCommitmentPhraseMatched(new)
                                    && !PrePaywallView.isCommitmentPhraseMatched(old) {
                                    Haptics.success()
                                }
                            }
                    }
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(matched ? MooniColor.success.opacity(0.6) : Color.white.opacity(0.12), lineWidth: 1)
                    )
                    if matched {
                        Label("Verified", systemImage: "checkmark.seal.fill")
                            .font(MooniFont.caption(11))
                            .foregroundColor(MooniColor.success)
                    }
                }
                .padding(.horizontal, 16)

                // Signature canvas
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Sign here")
                            .font(MooniFont.caption(11))
                            .foregroundColor(MooniColor.textMuted)
                        Spacer()
                        if !strokes.isEmpty {
                            Button {
                                Haptics.tap()
                                strokes.removeAll()
                                current.removeAll()
                            } label: {
                                Label("Clear", systemImage: "trash")
                                    .font(MooniFont.caption(11))
                                    .foregroundColor(MooniColor.textSecondary)
                            }
                        }
                    }

                    SignatureCanvas(strokes: $strokes, current: $current)
                        .frame(height: 130)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(strokes.isEmpty ? Color.white.opacity(0.12) : MooniColor.accent.opacity(0.5), lineWidth: 1)
                        )
                        .overlay(
                            Group {
                                if strokes.isEmpty && current.isEmpty {
                                    HStack(spacing: 6) {
                                        Image(systemName: "hand.draw.fill")
                                            .foregroundColor(MooniColor.textMuted)
                                        Text("Draw your signature")
                                            .font(MooniFont.caption(13))
                                            .foregroundColor(MooniColor.textMuted)
                                    }
                                }
                            }
                        )
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 4)
        }
        .scrollDismissesKeyboard(.immediately)
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 12)
        .onAppear {
            visible = false
            withAnimation(.easeOut(duration: 0.45)) { visible = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { Haptics.medium() }
        }
    }
}

private struct SignatureCanvas: View {
    @Binding var strokes: [SignatureStroke]
    @Binding var current: [CGPoint]

    var body: some View {
        Canvas { context, _ in
            for stroke in strokes {
                drawStroke(stroke.points, context: context)
            }
            if !current.isEmpty {
                drawStroke(current, context: context)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if current.isEmpty { Haptics.tick() }
                    current.append(value.location)
                }
                .onEnded { _ in
                    if !current.isEmpty {
                        strokes.append(SignatureStroke(points: current))
                        current = []
                        Haptics.soft()
                    }
                }
        )
    }

    private func drawStroke(_ points: [CGPoint], context: GraphicsContext) {
        guard points.count > 1 else { return }
        var path = Path()
        path.move(to: points[0])
        for p in points.dropFirst() { path.addLine(to: p) }
        context.stroke(
            path,
            with: .color(MooniColor.accentSoft),
            style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
        )
    }
}

#Preview {
    PrePaywallView(
        petName: "Nova",
        species: .owl,
        profile: OnboardingProfile(),
        onContinue: {}
    )
}
