import SwiftUI

// MARK: - Context

/// Everything the story needs, gathered once so the view stays pure.
struct SleepStoryContext {
    let entry: SleepEntry
    let pet: Pet
    let petName: String
    let history: [SleepEntry]
    let goalHours: Double
    let currentStreak: Int
    let longestStreak: Int
    let consistencyDays: Int
    let leveledUpTo: Int?

    /// Past nights, newest first, excluding today's entry.
    var past: [SleepEntry] {
        history
            .filter { $0.dayKey != entry.dayKey }
            .sorted { $0.wakeTime > $1.wakeTime }
    }

    var scoreDelta: Int? {
        guard let prev = past.first else { return nil }
        return entry.score - prev.score
    }

    /// Nights since the user last scored this high (record detection).
    var bestInDays: Int? {
        let p = past
        guard p.count >= 5 else { return nil }
        if let idx = p.firstIndex(where: { $0.score >= entry.score }) {
            return idx >= 5 ? idx : nil
        }
        return p.count
    }

    var isPersonalBest: Bool {
        let p = past
        return p.count >= 4 && entry.score > (p.map(\.score).max() ?? 0)
    }

    var newLongestStreak: Bool {
        currentStreak > 0 && currentStreak == longestStreak && longestStreak >= 3
    }
}

// MARK: - Card model

struct SleepStoryCard: Identifiable {
    enum Kind { case opener, metric, verdict, tonight }

    let id = UUID()
    let kind: Kind
    let eyebrow: String
    let emoji: String
    /// The pet speaking, first person, warm and plain.
    let petLine: String
    let bigValue: String
    let bigUnit: String
    /// One plain-English sentence: what this meant for *you*.
    let plain: String
    /// The nerdy layer — real sleep science, hidden until tapped.
    let science: String
    let tint: Color
}

// MARK: - Model

enum SleepStoryModel {

    static func cards(_ ctx: SleepStoryContext) -> [SleepStoryCard] {
        var cards: [SleepStoryCard] = []
        let name = ctx.petName

        // 1 — Sealed opener (curiosity gap).
        cards.append(.init(
            kind: .opener,
            eyebrow: "GOOD MORNING",
            emoji: "🌙",
            petLine: "I watched over you all night. Want to see what happened while you were gone?",
            bigValue: "",
            bigUnit: "",
            plain: "",
            science: "",
            tint: MooniColor.accent
        ))

        let total = ctx.entry.totalSleepDuration
        let hours = total / 3600
        let stages = ctx.entry.stages

        // 2 — Duration.
        cards.append(durationCard(hours: hours, total: total, name: name, goal: ctx.goalHours))

        // 3–5 — Stage narration (only when we have a breakdown).
        if let s = stages, s.totalSleep > 0 {
            cards.append(deepCard(s, total: s.totalSleep, name: name))
            cards.append(remCard(s, total: s.totalSleep, name: name))
            cards.append(restfulnessCard(s, name: name))
        }

        // 6 — Verdict.
        cards.append(verdictCard(ctx))

        // 7 — Tonight + anticipation seed.
        cards.append(tonightCard(ctx))

        return cards
    }

    // MARK: Duration

    private static func durationCard(hours: Double, total: TimeInterval,
                                     name: String, goal: Double) -> SleepStoryCard {
        let h = Int(total) / 3600
        let m = (Int(total) % 3600) / 60
        let plain: String
        let pet: String
        switch hours {
        case ..<4:
            pet = "That was a short one. I'll keep things gentle with you today."
            plain = "Well below the 7–9h adults need — today will feel heavy."
        case ..<6:
            pet = "We didn't get quite enough. Let's aim to turn in a little earlier."
            plain = "Under 6h. Enough to function, not enough to fully recover."
        case ..<7:
            pet = "Almost there — a touch more and you'd be in the sweet spot."
            plain = "Just shy of the optimal adult range."
        case 7...9:
            pet = "You gave your body a full, healthy night. I'm proud of us."
            plain = "Right inside the 7–9h zone where recovery actually happens."
        default:
            pet = "That was a long one. Sometimes the body just needs it."
            plain = "Longer than usual — fine occasionally, groggy if it's every night."
        }
        return .init(
            kind: .metric,
            eyebrow: "TIME ASLEEP",
            emoji: "🛏️",
            petLine: pet,
            bigValue: "\(h)h \(String(format: "%02d", m))m",
            bigUnit: "of real sleep",
            plain: plain,
            science: "The American Academy of Sleep Medicine and the National Sleep Foundation put the adult target at 7–9 hours. Sleep is when the brain runs its overnight maintenance: clearing metabolic waste, balancing hormones, and locking in the day's memories. Chronically dipping under 6h is linked by the CDC to higher cardiovascular and metabolic risk.",
            tint: MooniColor.accent
        )
    }

    // MARK: Deep

    private static func deepCard(_ s: SleepStagesEstimate, total: TimeInterval,
                                 name: String) -> SleepStoryCard {
        let pct = Int((s.deepSleep / total * 100).rounded())
        let m = Int(s.deepSleep / 60)
        let plain: String
        let pet: String
        switch pct {
        case ..<10:
            pet = "Your deep-repair phase ran short. Your body had less time to rebuild."
            plain = "Low deep sleep — physical recovery took a hit."
        case 10..<13:
            pet = "You got some real repair work in, though there was room for more."
            plain = "A little under the ideal deep-sleep band."
        case 13...23:
            pet = "While you were out cold, your body quietly rebuilt itself. Textbook."
            plain = "Right in the healthy deep-sleep range — strong physical recovery."
        default:
            pet = "You sank into a lot of deep sleep — your body clearly needed the repair."
            plain = "High deep sleep — often the body catching up on a deficit."
        }
        return .init(
            kind: .metric,
            eyebrow: "DEEP SLEEP",
            emoji: "🧱",
            petLine: pet,
            bigValue: "\(m) min",
            bigUnit: "≈ \(pct)% of your night",
            plain: plain,
            science: "Deep sleep (slow-wave / N3) is front-loaded into your first two cycles. It's when growth hormone is released, tissue and muscle repair, and the immune system resets. The glymphatic system also flushes metabolic byproducts — including beta-amyloid — out of the brain. Healthy adults spend roughly 13–23% of the night here; it shrinks naturally with age and with late, warm, or alcohol-affected sleep.",
            tint: MooniColor.success
        )
    }

    // MARK: REM

    private static func remCard(_ s: SleepStagesEstimate, total: TimeInterval,
                                name: String) -> SleepStoryCard {
        let pct = Int((s.remSleep / total * 100).rounded())
        let m = Int(s.remSleep / 60)
        let plain: String
        let pet: String
        switch pct {
        case ..<15:
            pet = "Your dreaming brain got cut short. Memories had less time to settle."
            plain = "Low REM — often from waking early or a late bedtime."
        case 15..<20:
            pet = "Your mind did some filing, with a bit more it could've done."
            plain = "Slightly under the ideal dreaming range."
        case 20...25:
            pet = "While you dreamed, your brain replayed yesterday and filed it away."
            plain = "Healthy REM — strong memory and emotional processing."
        default:
            pet = "Lots of dreaming last night — your mind had plenty to process."
            plain = "High REM — common after stress or learning-heavy days."
        }
        return .init(
            kind: .metric,
            eyebrow: "REM · DREAM SLEEP",
            emoji: "💭",
            petLine: pet,
            bigValue: "\(m) min",
            bigUnit: "≈ \(pct)% of your night",
            plain: plain,
            science: "REM is the dreaming stage, concentrated in the final third of the night — each cycle's REM block gets longer toward morning. It consolidates procedural and emotional memory and recalibrates mood by processing the day's emotional charge. Because it's back-loaded, cutting sleep short or waking early strips REM first — pushing your wake time 20–30 minutes later often recovers an entire REM cycle. Adults typically spend 20–25% of the night in REM.",
            tint: MooniColor.accent
        )
    }

    // MARK: Restfulness

    private static func restfulnessCard(_ s: SleepStagesEstimate,
                                        name: String) -> SleepStoryCard {
        let denom = s.totalSleep + s.awakeTime
        let eff = denom > 0 ? s.totalSleep / denom : 1
        let effPct = Int((eff * 100).rounded())
        let awakeMin = Int(s.awakeTime / 60)
        let plain: String
        let pet: String
        switch effPct {
        case 92...:
            pet = "You barely stirred — I hardly had to settle you once."
            plain = "Excellent sleep efficiency — deeply restorative."
        case 85..<92:
            pet = "Just a little tossing, nothing that broke your recovery."
            plain = "Healthy efficiency — solid, mostly unbroken sleep."
        case 75..<85:
            pet = "You surfaced a few times. I tucked you back in each one."
            plain = "Some fragmentation — recovery took a small hit."
        default:
            pet = "It was a restless one. I stayed close the whole time."
            plain = "Broken sleep blunts deep recovery even when hours look fine."
        }
        return .init(
            kind: .metric,
            eyebrow: "RESTFULNESS",
            emoji: "🪶",
            petLine: pet,
            bigValue: "\(effPct)%",
            bigUnit: "efficient · \(awakeMin) min awake",
            plain: plain,
            science: "Sleep efficiency is time asleep ÷ time in bed. The clinical benchmark for healthy sleep is ≥85%, with ≥90% considered excellent. The flip side is WASO — wake-after-sleep-onset — the minutes you're awake after first falling asleep. Under ~30 min is restorative; repeated awakenings fragment sleep cycles and blunt deep N3 even when total hours look fine, which is why a 'full' night can still leave you flat.",
            tint: MooniColor.accentSoft
        )
    }

    // MARK: Verdict

    private static func verdictCard(_ ctx: SleepStoryContext) -> SleepStoryCard {
        let s = ctx.entry.score
        let name = ctx.petName
        let tint: Color
        switch s {
        case 85...:  tint = MooniColor.success
        case 70..<85: tint = MooniColor.accent
        case 50..<70: tint = MooniColor.warning
        default:      tint = MooniColor.danger
        }

        var pet: String
        if ctx.leveledUpTo != nil {
            pet = "We grew last night — I leveled up. Keep this rhythm going."
        } else if ctx.newLongestStreak {
            pet = "\(ctx.currentStreak) nights in a row — our longest ever. Please don't break it tonight!"
        } else if ctx.isPersonalBest {
            pet = "This is the best I've ever felt. Whatever you did — do it again."
        } else if let n = ctx.bestInDays, n >= 7 {
            pet = "I haven't felt this rested in \(n) nights. That was a good one."
        } else if s >= 85 {
            pet = "I feel fully charged. Today's going to feel light for both of us."
        } else if s >= 70 {
            pet = "Solid night. I'm steady and ready — let's make it count."
        } else if s >= 50 {
            pet = "I'm running a little low. A kinder night tonight and I'll bounce back."
        } else {
            pet = "I'm worn out and I need you tonight. Go easy on me — I'll recover with you."
        }

        let plain: String
        switch s {
        case 85...:  plain = "Top-tier recovery. Duration, depth and rest all landed."
        case 70..<85: plain = "A genuinely good night — most of the pieces lined up."
        case 50..<70: plain = "A mixed night. One change tonight moves this a lot."
        default:     plain = "A rough night. Not a verdict on you — just a signal to be kind today."
        }

        return .init(
            kind: .verdict,
            eyebrow: "LAST NIGHT, IN ONE NUMBER",
            emoji: "✨",
            petLine: pet,
            bigValue: "\(s)",
            bigUnit: "readiness \(ctx.entry.readinessScore ?? s)",
            plain: plain,
            science: ctx.entry.insight ?? "Your score blends five clinical signals — duration, efficiency, restfulness, deep/REM balance and bedtime consistency — weighted the way modern sleep labs weigh them.",
            tint: tint
        )
    }

    // MARK: Tonight

    private static func tonightCard(_ ctx: SleepStoryContext) -> SleepStoryCard {
        let name = ctx.petName
        let s = ctx.entry.score
        let action: String
        if s < 55 {
            action = "Let's wind down 30 minutes earlier and keep screens out of bed."
        } else if let stages = ctx.entry.stages, stages.totalSleep > 0,
                  stages.remSleep / stages.totalSleep < 0.15 {
            action = "Try waking 20–30 min later tomorrow — that's usually a whole extra REM cycle."
        } else if ctx.entry.totalSleepDuration / 3600 < 7 {
            action = "Aim for lights-out 20 minutes earlier and we land in the healthy zone."
        } else {
            action = "Keep tonight's bedtime exactly where it was — consistency is doing the work."
        }
        return .init(
            kind: .tonight,
            eyebrow: "TONIGHT",
            emoji: "🌅",
            petLine: "I'll be watching over you again. There's a fresh story waiting for you the moment you wake up.",
            bigValue: "",
            bigUnit: "",
            plain: action,
            science: "Consistency is the single strongest lever in sleep science: a stable sleep–wake time anchors your circadian rhythm, which in turn sharpens deep and REM timing. Going to bed and waking within the same ~30-minute window every day — yes, weekends too — compounds faster than any single perfect night.",
            tint: MooniColor.warning
        )
    }
}

// MARK: - View

/// Full-screen, swipeable "Sleep Story" — the emotional reveal that plays
/// the moment the user wakes. Leads with the pet's voice and one feeling per
/// card; the clinical detail is one tap away for the curious.
struct SleepStoryView: View {
    let context: SleepStoryContext
    /// Called when the story finishes — host pushes the full dashboard.
    var onFinished: () -> Void

    @State private var index = 0
    @State private var opened = false
    @State private var scienceShown = false
    @State private var celebrate = false
    @State private var cards: [SleepStoryCard] = []
    @State private var sharePreview: Image?

    var body: some View {
        ZStack {
            backdrop
            StarsBackground(count: 70).allowsHitTesting(false)

            VStack(spacing: 0) {
                segmentBar
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                HStack {
                    Spacer()
                    skipButton
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)

                ZStack {
                    if let card = cards[safe: index] {
                        cardView(card)
                            .id(index)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.97)),
                                removal: .opacity))
                    }
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { goNext() }
                .gesture(
                    DragGesture(minimumDistance: 24)
                        .onEnded { v in
                            if v.translation.width < -40 { goNext() }
                            else if v.translation.width > 40 { goBack() }
                        }
                )
            }
            // iPad: cap the column; backdrop stays full-bleed.
            .responsiveContainer()

            if celebrate {
                ConfettiBurst()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .onChange(of: index) { _, _ in onCardChange() }
        .onAppear {
            if cards.isEmpty { cards = SleepStoryModel.cards(context) }
            onCardChange()
        }
    }

    // MARK: Backdrop

    private var backdrop: some View {
        let tint = cards[safe: index]?.tint ?? MooniColor.accent
        return ZStack {
            MooniGradient.night.ignoresSafeArea()
            RadialGradient(
                colors: [tint.opacity(0.34), .clear],
                center: .top, startRadius: 8, endRadius: 520
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.7), value: index)
        }
    }

    // MARK: Segment progress

    private var segmentBar: some View {
        HStack(spacing: 5) {
            ForEach(cards.indices, id: \.self) { i in
                Capsule()
                    .fill(i <= index ? MooniColor.accent : MooniColor.hairline)
                    .frame(height: 3)
                    .frame(maxWidth: .infinity)
                    .animation(.easeInOut(duration: 0.3), value: index)
            }
        }
    }

    private var skipButton: some View {
        Button {
            Haptics.tap()
            onFinished()
        } label: {
            Text("Skip")
                .font(MooniFont.caption(13))
                .foregroundColor(MooniColor.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(MooniColor.hairline)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Card router

    @ViewBuilder
    private func cardView(_ card: SleepStoryCard) -> some View {
        switch card.kind {
        case .opener:  openerCard(card)
        case .metric:  metricCard(card)
        case .verdict: verdictCardView(card)
        case .tonight: tonightCardView(card)
        }
    }

    // MARK: Opener (sealed → unwrap)

    private func openerCard(_ card: SleepStoryCard) -> some View {
        VStack(spacing: 26) {
            Spacer()
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [MooniColor.accent.opacity(opened ? 0.6 : 0.32), .clear],
                        center: .center, startRadius: 6,
                        endRadius: opened ? 230 : 130))
                    .frame(width: 360, height: 360)
                    .blur(radius: 8)
                    .scaleEffect(opened ? 1.08 : 0.92)

                DreamSpiritView(pet: context.pet, size: opened ? 168 : 128)
                    .shadow(color: MooniColor.accent.opacity(0.5), radius: 28)
                    .scaleEffect(opened ? 1 : 0.96)
            }
            .animation(.spring(response: 1.0, dampingFraction: 0.62), value: opened)

            VStack(spacing: 10) {
                Text("GOOD MORNING")
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.accentText)
                    .tracking(3)
                Text(context.petName)
                    .font(MooniFont.display(30))
                    .foregroundColor(MooniColor.textPrimary)
                Text(card.petLine)
                    .font(MooniFont.body(16))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 34)
                    .opacity(opened ? 1 : 0.85)
            }
            Spacer()
            tapHint(opened ? "Tap to begin" : "Tap to open your night")
                .padding(.bottom, 30)
        }
        .padding(.horizontal, 24)
    }

    // MARK: Metric card (emotion first, science on tap)

    private func metricCard(_ card: SleepStoryCard) -> some View {
        VStack(spacing: 0) {
            Spacer()
            Text(card.emoji).font(.system(size: 52))
            Text(card.eyebrow)
                .font(MooniFont.caption(12))
                .foregroundColor(card.tint)
                .tracking(2.5)
                .padding(.top, 14)

            Text(card.bigValue)
                .font(MooniFont.display(56))
                .foregroundColor(MooniColor.textPrimary)
                .padding(.top, 8)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(card.bigUnit)
                .font(MooniFont.body(15))
                .foregroundColor(MooniColor.textMuted)

            Text(card.petLine)
                .font(MooniFont.title(20))
                .foregroundColor(MooniColor.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .fixedSize(horizontal: false, vertical: true)

            Text(card.plain)
                .font(MooniFont.body(14))
                .foregroundColor(MooniColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 34)
                .padding(.top, 10)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 22)
            scienceDisclosure(card)
                .padding(.bottom, 20)
            tapHint("Tap to continue").padding(.bottom, 26)
        }
        .padding(.horizontal, 22)
    }

    // MARK: Verdict

    private func verdictCardView(_ card: SleepStoryCard) -> some View {
        VStack(spacing: 0) {
            Spacer()
            Text(card.eyebrow)
                .font(MooniFont.caption(12))
                .foregroundColor(card.tint)
                .tracking(2.5)

            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [card.tint.opacity(0.34), .clear],
                        center: .center, startRadius: 4, endRadius: 180))
                    .frame(width: 320, height: 320)
                    .blur(radius: 8)
                SleepScoreRing(score: context.entry.score, size: 200, lineWidth: 14)
                DreamSpiritView(pet: context.pet, size: 60).offset(y: -118)
            }
            .frame(height: 230)
            .padding(.top, 6)

            Text(card.bigUnit.uppercased())
                .font(MooniFont.caption(12))
                .foregroundColor(MooniColor.textMuted)
                .tracking(1.5)

            Text(card.petLine)
                .font(MooniFont.title(20))
                .foregroundColor(MooniColor.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 26)
                .padding(.top, 18)
                .fixedSize(horizontal: false, vertical: true)

            Text(card.plain)
                .font(MooniFont.body(14))
                .foregroundColor(MooniColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 10)

            Spacer(minLength: 22)
            scienceDisclosure(card, label: "Why this score")
                .padding(.bottom, 20)
            tapHint("Tap to continue").padding(.bottom, 26)
        }
        .padding(.horizontal, 22)
    }

    // MARK: Tonight + share + finish

    private func tonightCardView(_ card: SleepStoryCard) -> some View {
        VStack(spacing: 0) {
            Spacer()
            Text(card.emoji).font(.system(size: 50))
            Text("TONIGHT")
                .font(MooniFont.caption(12))
                .foregroundColor(card.tint)
                .tracking(2.5)
                .padding(.top, 12)

            Text(card.plain)
                .font(MooniFont.title(21))
                .foregroundColor(MooniColor.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 26)
                .padding(.top, 18)
                .fixedSize(horizontal: false, vertical: true)

            Text(card.petLine)
                .font(MooniFont.body(15))
                .foregroundColor(MooniColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 14)
                .fixedSize(horizontal: false, vertical: true)

            scienceDisclosure(card, label: "The science of consistency")
                .padding(.top, 24)
                .padding(.bottom, 6)

            Spacer(minLength: 18)

            VStack(spacing: 12) {
                if let img = sharePreview {
                    ShareLink(
                        item: img,
                        preview: SharePreview("My night with \(context.petName)", image: img)
                    ) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share my night")
                        }
                        .font(MooniFont.title(15))
                        .foregroundColor(MooniColor.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(MooniColor.hairline)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(MooniColor.hairline, lineWidth: 1))
                    }
                    .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
                }
                PrimaryButton(title: "See the full breakdown", icon: "chart.bar.fill") {
                    onFinished()
                }
            }
            .padding(.bottom, 26)
        }
        .padding(.horizontal, 22)
    }

    // MARK: Science disclosure

    private func scienceDisclosure(_ card: SleepStoryCard,
                                   label: String = "The science") -> some View {
        VStack(spacing: 10) {
            Button {
                Haptics.tap()
                withAnimation(.easeInOut(duration: 0.28)) { scienceShown.toggle() }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "flask.fill").font(.system(size: 11, weight: .bold))
                    Text(label).font(MooniFont.caption(12)).tracking(0.5)
                    Image(systemName: scienceShown ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(card.tint)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(card.tint.opacity(0.14))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(card.tint.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)

            if scienceShown {
                Text(card.science)
                    .font(MooniFont.body(13))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .background(MooniColor.hairline)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.horizontal, 4)
    }

    private func tapHint(_ text: String) -> some View {
        Text(text)
            .font(MooniFont.caption(12))
            .foregroundColor(MooniColor.textMuted)
            .opacity(0.8)
    }

    // MARK: Navigation

    private func goNext() {
        if cards[safe: index]?.kind == .opener && !opened {
            withAnimation { opened = true }
            Haptics.soft()
            return
        }
        guard index < cards.count - 1 else { onFinished(); return }
        withAnimation(.easeInOut(duration: 0.35)) { index += 1 }
        Haptics.tap()
    }

    private func goBack() {
        guard index > 0 else { return }
        withAnimation(.easeInOut(duration: 0.35)) { index -= 1 }
        Haptics.tap()
    }

    private func onCardChange() {
        scienceShown = false
        guard let card = cards[safe: index] else { return }
        if card.kind == .tonight, sharePreview == nil {
            sharePreview = shareImage()
        }
        if card.kind == .verdict {
            let good = context.entry.score >= 80
                || context.isPersonalBest
                || context.newLongestStreak
                || context.leveledUpTo != nil
            if good {
                Haptics.celebrate()
                withAnimation { celebrate = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                    withAnimation { celebrate = false }
                }
            } else {
                Haptics.soft()
            }
        }
    }

    // MARK: Share image

    @MainActor
    private func shareImage() -> Image? {
        let renderer = ImageRenderer(content: ShareCard(context: context))
        renderer.scale = 3
        if let ui = renderer.uiImage {
            return Image(uiImage: ui)
        }
        return nil
    }
}

// MARK: - Share card

/// Compact, branded card rendered to an image for sharing.
private struct ShareCard: View {
    let context: SleepStoryContext

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                EmojiIcon(emoji: "🦉", size: 18)
                Text("SleepOwl").font(MooniFont.title(16)).foregroundColor(.white)
            }
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [MooniColor.accent.opacity(0.4), .clear],
                                         center: .center, startRadius: 4, endRadius: 150))
                    .frame(width: 230, height: 230)
                SleepScoreRing(score: context.entry.score, size: 170, lineWidth: 13)
            }
            Text("Slept \(context.entry.formattedDuration)")
                .font(MooniFont.title(20)).foregroundColor(.white)
            Text("Readiness \(context.entry.readinessScore ?? context.entry.score) · \(context.petName) is watching over me")
                .font(MooniFont.caption(13))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(width: 420, height: 520)
        // A shared image must look the same no matter the user's current
        // theme — pin it to the dark brand gradient (the .white text above is
        // correct on this fixed-dark card), never the adaptive gradient which
        // would render cream-on-white when shared during the day.
        .background(
            LinearGradient(colors: [MooniColor.bgTop, MooniColor.bgBottom],
                           startPoint: .top, endPoint: .bottom)
        )
    }
}

// MARK: - Confetti

/// Lightweight, dependency-free celebratory burst.
private struct ConfettiBurst: View {
    @State private var go = false
    private let pieces = (0..<26).map { _ in ConfettiPiece() }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { p in
                    Circle()
                        .fill(p.color)
                        .frame(width: p.size, height: p.size)
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.32)
                        .offset(x: go ? p.dx : 0, y: go ? p.dy : 0)
                        .opacity(go ? 0 : 1)
                        .scaleEffect(go ? 0.4 : 1)
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 1.9)) { go = true }
            }
        }
    }
}

private struct ConfettiPiece: Identifiable {
    let id = UUID()
    let dx = CGFloat.random(in: -180...180)
    let dy = CGFloat.random(in: -320 ... -120)
    let size = CGFloat.random(in: 6...12)
    let color: Color = [MooniColor.warning, MooniColor.accent,
                        MooniColor.success, MooniColor.accentSoft].randomElement()!
}

// MARK: - Safe index

private extension Array {
    subscript(safe i: Int) -> Element? {
        indices.contains(i) ? self[i] : nil
    }
}
