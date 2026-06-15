import SwiftUI

/// The deep "Night Analytics" page — the body's overnight chemistry told as a
/// single night-timeline plus a stack of fact cards. Presented full-screen from
/// the morning reveal and the Sleep tab; its inner `NightAnalyticsContent` is
/// also embedded in the history per-night detail.
struct NightAnalyticsView: View {
    let entry: SleepEntry
    /// Provided when shown as a cover (gives the screen its own close button).
    var onClose: (() -> Void)? = nil

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            MooniGradient.night.ignoresSafeArea()
            StarsBackground(count: 34).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    header
                    NightAnalyticsContent(
                        entry: entry,
                        isPro: subscriptionManager.isPro,
                        onUnlock: { showPaywall = true }
                    )
                }
                .padding(18)
                .padding(.bottom, 24)
            }
            .responsiveContainer()
        }
        .mooniPaywall(isPresented: $showPaywall)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("NIGHT ANALYTICS")
                    .font(MooniFont.caption(11))
                    .tracking(1.8)
                    .foregroundColor(MooniColor.accentSoft)
                Text(entry.wakeTime, format: .dateTime.weekday(.wide).day().month())
                    .font(MooniFont.title(18))
                    .foregroundColor(MooniColor.textPrimary)
            }
            Spacer()
            if let onClose {
                Button {
                    Haptics.tap()
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.white.opacity(0.55))
                }
            }
        }
    }
}

// MARK: - Shared content (timeline + fact cards)

/// The analytics body, free of any background/navigation chrome so it can be
/// embedded both in the full-screen cover and the history detail screen.
struct NightAnalyticsContent: View {
    let entry: SleepEntry
    let isPro: Bool
    var onUnlock: () -> Void = {}

    @EnvironmentObject var appState: AppState
    @State private var appeared = false

    private var phys: NightPhysiology {
        SleepPhysiologyEngine.analyze(
            entry: entry,
            checkIn: appState.checkIn(for: entry),
            age: appState.profile.age,
            targetBedtime: appState.targetBedtime,
            targetWakeTime: appState.targetWakeTime,
            history: appState.entries
        )
    }

    var body: some View {
        let p = phys
        VStack(spacing: 16) {
            NightTimelineCard(entry: entry, phys: p, animate: appeared)

            hormoneCard(p)        // free
            recoveryCard(p)       // free

            if isPro {
                architectureCard(p)
                if !p.inputNotes.isEmpty { notesCard(p) }
            } else {
                proTeaser
            }

            aboutDisclosure
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { appeared = true }
        }
    }

    // MARK: Hormone windows (free)

    private func hormoneCard(_ p: NightPhysiology) -> some View {
        AnalyticsCard(title: "Hormone windows", icon: "waveform.path.ecg") {
            FactRow(
                eyebrow: "GROWTH HORMONE",
                plain: "Your deep-repair pulse rode the window from \(p.clockString(p.ghStart)) to \(p.clockString(p.ghEnd)).",
                value: p.ghVerdict.label,
                detail: "\(p.ghQuality)%",
                tone: p.ghVerdict.tone,
                science: "The night's biggest growth-hormone pulse rides your first slow-wave (deep N3) episode — the first one to two cycles after you fall asleep. That's when tissue and muscle rebuild and the body resets. Falling asleep earlier and dropping into deep sleep fast is what catches it; late caffeine, a late heavy meal, alcohol or a late workout all flatten that first pulse."
            )
            divider
            FactRow(
                eyebrow: "MORNING CORTISOL",
                plain: "Your cortisol rise peaked around \(p.clockString(p.cortisolPeak)).",
                value: p.cortisolGrade.label,
                detail: "\(p.cortisolQuality)%",
                tone: p.cortisolGrade.tone,
                science: "Cortisol climbs across the final hours of sleep and peaks about 30–45 minutes after you wake — the surge that makes you feel alert. A clean rise wants a consistent wake time and waking out of lighter sleep rather than deep sleep, which is why a steady schedule and an easy wake feed a stronger morning."
            )
            divider
            FactRow(
                eyebrow: "MELATONIN",
                plain: p.melatoninSuppressed
                    ? "Your melatonin built late and ran lighter than ideal, peaking near \(p.clockString(p.melatoninPeak))."
                    : "Your melatonin built from \(p.clockString(p.melatoninOnset)) and peaked near \(p.clockString(p.melatoninPeak)).",
                value: p.melatoninSuppressed ? "Delayed" : "On time",
                detail: nil,
                tone: p.melatoninSuppressed ? .caution : .positive,
                science: "Melatonin — the hormone that opens the gate to sleep — starts rising about two hours before your usual bedtime and peaks in the 3–4 AM range. Evening light, especially a screen in bed, and a very late bedtime push that rise later and lower, which delays sleep onset and shortens deep sleep."
            )
        }
    }

    // MARK: Recovery rings (free)

    private func recoveryCard(_ p: NightPhysiology) -> some View {
        AnalyticsCard(title: "Recovery", icon: "bolt.heart.fill") {
            HStack(spacing: 14) {
                StatRing(title: "Muscle recovery",
                         value: "\(p.muscleRestfulness)%",
                         progress: Double(p.muscleRestfulness) / 100,
                         color: MooniColor.success, animate: appeared)
                StatRing(title: "Sleep pressure cleared",
                         value: "\(p.adenosineCleared)%",
                         progress: Double(p.adenosineCleared) / 100,
                         color: MooniColor.accent, animate: appeared)
            }
            Text("Deep sleep rebuilds muscle while a full night flushes the adenosine that built up all day — clear it and you wake without that heavy, foggy pull back to bed.")
                .font(MooniFont.caption(12))
                .foregroundColor(MooniColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
    }

    // MARK: Night architecture (Pro)

    private func architectureCard(_ p: NightPhysiology) -> some View {
        AnalyticsCard(title: "Night architecture", icon: "chart.bar.xaxis") {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("SLEEP CYCLES")
                        .font(MooniFont.caption(10))
                        .tracking(1.4)
                        .foregroundColor(MooniColor.textMuted)
                    Spacer()
                    Text("\(p.completeCycles) complete")
                        .font(MooniFont.title(15))
                        .foregroundColor(MooniColor.textPrimary)
                }
                CycleRibbon(count: p.completeCycles, animate: appeared)
                    .frame(height: 16)
                Text("Adult sleep moves through roughly 90-minute cycles, each cresting from deep sleep up into a longer dream phase toward morning.")
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            divider
            FactRow(
                eyebrow: "REM · DREAM SLEEP",
                plain: "Your first dream phase opened at \(p.clockString(p.remOnset)) — REM made up \(Int((p.remShare * 100).rounded()))% of your night.",
                value: "\(p.remMinutes) min",
                detail: nil,
                tone: p.remShare >= 0.20 ? .positive : (p.remShare >= 0.15 ? .neutral : .caution),
                science: "REM — the dreaming, memory-filing stage — first appears about 90 minutes after you fall asleep and stacks toward morning, with each cycle's REM block getting longer. Because it's back-loaded, cutting sleep short or an early alarm strips REM first; pushing wake 20–30 minutes later often recovers a whole REM block."
            )
            divider
            FactRow(
                eyebrow: "BODY TEMPERATURE",
                plain: tempPlain(p),
                value: p.wakeEase.label,
                detail: nil,
                tone: p.wakeEase.tone,
                science: "Your core body temperature bottoms out about two hours before your usual wake time, then climbs to push you toward morning. Waking after that low — on the warming, rising edge — feels light and natural; waking before it, while you're still cooling, is the groggy, dragged-out kind."
            )
        }
    }

    private func tempPlain(_ p: NightPhysiology) -> String {
        let m = abs(p.minutesWokeAfterTempMin)
        let dir = p.minutesWokeAfterTempMin >= 0 ? "after" : "before"
        return "Your temperature low sat at \(p.clockString(p.tempMin)) — you woke \(m) min \(dir) it, on the \(p.minutesWokeAfterTempMin >= 0 ? "rising" : "cooling") edge."
    }

    // MARK: Input tie-ins (Pro)

    private func notesCard(_ p: NightPhysiology) -> some View {
        AnalyticsCard(title: "What shaped your night", icon: "sparkles") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(p.inputNotes.enumerated()), id: \.offset) { _, note in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(MooniColor.accentSoft)
                            .padding(.top, 1)
                        Text(note)
                            .font(MooniFont.body(14))
                            .foregroundColor(MooniColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    // MARK: Pro teaser

    private var proTeaser: some View {
        Button { onUnlock() } label: {
            MooniCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Unlock the full read-out", systemImage: "sparkles")
                            .font(MooniFont.title(15))
                            .foregroundColor(MooniColor.accent)
                        Spacer()
                        Image(systemName: "lock.fill")
                            .foregroundColor(MooniColor.textMuted)
                    }
                    Text("Sleep cycles · REM onset · core-temperature wake window · and exactly what your day did to last night.")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        Text("Unlock")
                        Image(systemName: "arrow.right")
                    }
                    .font(MooniFont.title(14))
                    .foregroundColor(MooniColor.background)
                    .padding(.vertical, 11)
                    .frame(maxWidth: .infinity)
                    .background(Capsule().fill(MooniColor.accent))
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: About (compliance line, no "estimate" wording)

    private var aboutDisclosure: some View {
        DisclosureGroup {
            Text("These readings are modeled from your sleep timing and stage balance using established sleep-science relationships. They describe how your night was structured — they're insight, not a medical measurement or diagnosis.")
                .font(MooniFont.caption(12))
                .foregroundColor(MooniColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
        } label: {
            Text("About these numbers")
                .font(MooniFont.caption(12))
                .foregroundColor(MooniColor.textMuted)
        }
        .tint(MooniColor.textMuted)
        .padding(.horizontal, 4)
    }

    private var divider: some View {
        Divider().background(Color.white.opacity(0.06)).padding(.vertical, 2)
    }
}

// MARK: - Night timeline (hero)

/// A multi-lane night timeline: a shared time axis (bedtime → wake) with the
/// stage strip on top and one translucent lane per overnight signal, so the
/// user sees *when* each thing happened across the night.
struct NightTimelineCard: View {
    let entry: SleepEntry
    let phys: NightPhysiology
    let animate: Bool

    private var inBed: Date { phys.inBed }
    private var wake: Date { phys.wakeTime }

    private func frac(_ d: Date) -> CGFloat {
        let span = wake.timeIntervalSince(inBed)
        guard span > 0 else { return 0 }
        return CGFloat(min(1, max(0, d.timeIntervalSince(inBed) / span)))
    }

    private var stageSegs: [(secs: TimeInterval, color: Color)] {
        guard let s = entry.stages, s.totalSleep > 0 else { return [] }
        return [
            (s.deepSleep,  StagePalette.deep),
            (s.lightSleep, StagePalette.light),
            (s.remSleep,   StagePalette.rem),
            (s.awakeTime,  StagePalette.awake)
        ].filter { $0.secs > 0 }
    }

    /// REM density concentrates in the final third of the night.
    private var remBandStart: Date {
        let span = wake.timeIntervalSince(phys.sleepOnset)
        return phys.sleepOnset.addingTimeInterval(span * 0.66)
    }

    var body: some View {
        MooniCard(padding: 16, cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("YOUR NIGHT")
                        .font(MooniFont.caption(11))
                        .tracking(1.8)
                        .foregroundColor(MooniColor.textMuted)
                    Spacer()
                    Text("\(inBed.hourMinuteString) → \(wake.hourMinuteString) · \(entry.formattedDuration)")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                }

                // Stage strip (proportional hypnogram).
                if !stageSegs.isEmpty {
                    let total = max(stageSegs.reduce(0) { $0 + $1.secs }, 1)
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            ForEach(Array(stageSegs.enumerated()), id: \.offset) { _, seg in
                                seg.color
                                    .frame(width: max(2, geo.size.width
                                            * CGFloat((animate ? seg.secs : 0) / total)))
                            }
                            if !animate { Spacer(minLength: 0) }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .frame(height: 20)
                    .animation(.easeOut(duration: 0.9), value: animate)
                }

                // Signal lanes on the shared time axis.
                VStack(spacing: 9) {
                    lane("Repair (GH)", start: frac(phys.ghStart), end: frac(phys.ghEnd),
                         color: MooniColor.success)
                    lane("Melatonin",
                         start: frac(phys.melatoninPeak.addingTimeInterval(-60 * 60)),
                         end: frac(phys.melatoninPeak.addingTimeInterval(60 * 60)),
                         color: MooniColor.accent)
                    markerLane("Core temp ▼", at: frac(phys.tempMin), color: MooniColor.accentSoft)
                    lane("Cortisol", start: frac(phys.cortisolRiseStart), end: 1.0,
                         color: MooniColor.warning)
                    lane("REM", start: frac(remBandStart), end: 1.0, color: StagePalette.rem)
                }

                // x-axis
                HStack {
                    Text(inBed.hourMinuteString)
                    Spacer()
                    Text("Bedtime → Wake")
                        .foregroundColor(MooniColor.textMuted)
                    Spacer()
                    Text(wake.hourMinuteString)
                }
                .font(MooniFont.caption(10))
                .foregroundColor(MooniColor.textSecondary)
            }
        }
    }

    private func lane(_ label: String, start: CGFloat, end: CGFloat, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(MooniFont.caption(10))
                .foregroundColor(MooniColor.textMuted)
                .frame(width: 84, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            GeometryReader { geo in
                let w = geo.size.width
                let bandW = max(4, w * (animate ? max(0, end - start) : 0))
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06)).frame(height: 13)
                    Capsule()
                        .fill(color.opacity(0.85))
                        .frame(width: bandW, height: 13)
                        .offset(x: w * start)
                }
                .animation(.easeOut(duration: 0.9), value: animate)
            }
            .frame(height: 14)
        }
    }

    private func markerLane(_ label: String, at frac: CGFloat, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(MooniFont.caption(10))
                .foregroundColor(MooniColor.textMuted)
                .frame(width: 84, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06)).frame(height: 13)
                    Circle()
                        .fill(color)
                        .frame(width: 11, height: 11)
                        .shadow(color: color.opacity(0.7), radius: 5)
                        .offset(x: max(0, w * frac - 5.5))
                        .opacity(animate ? 1 : 0)
                }
                .animation(.easeOut(duration: 0.9), value: animate)
            }
            .frame(height: 14)
        }
    }
}

// MARK: - Reusable pieces

/// A titled analytics card matching the app's card chrome.
struct AnalyticsCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        MooniCard(padding: 18, cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Label(title, systemImage: icon)
                    .font(MooniFont.title(15))
                    .foregroundColor(MooniColor.textPrimary)
                content()
            }
        }
    }
}

/// A calm fact row: eyebrow + plain line + a headline value, with the science
/// one tap away. Mirrors the MetricDisclosure pattern used in the Sleep Story.
struct FactRow: View {
    let eyebrow: String
    let plain: String
    let value: String
    var detail: String? = nil
    var tone: NightPhysiology.Tone = .neutral
    let science: String

    @State private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                Haptics.tap()
                withAnimation(.easeInOut(duration: 0.24)) { open.toggle() }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(eyebrow)
                            .font(MooniFont.caption(10))
                            .tracking(1.4)
                            .foregroundColor(MooniColor.textMuted)
                        Text(plain)
                            .font(MooniFont.body(14))
                            .foregroundColor(MooniColor.textPrimary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(value)
                            .font(MooniFont.title(16))
                            .foregroundColor(NightAnalyticsTone.color(tone))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if let detail {
                            Text(detail)
                                .font(MooniFont.caption(11))
                                .foregroundColor(MooniColor.textMuted)
                        }
                    }
                    Image(systemName: open ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(MooniColor.textMuted)
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 8)

            if open {
                Text(science)
                    .font(MooniFont.body(13))
                    .foregroundColor(MooniColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.045))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.bottom, 8)
                    .transition(.opacity)
            }
        }
    }
}

/// Tone → colour mapping kept out of the model so `NightPhysiology` stays pure.
enum NightAnalyticsTone {
    static func color(_ tone: NightPhysiology.Tone) -> Color {
        switch tone {
        case .positive: return MooniColor.success
        case .neutral:  return MooniColor.accentSoft
        case .caution:  return MooniColor.warning
        }
    }
}

/// A labelled progress ring used by the Recovery card.
struct StatRing: View {
    let title: String
    let value: String
    let progress: Double
    let color: Color
    let animate: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.07), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: animate ? min(max(progress, 0), 1) : 0)
                    .stroke(color, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.0), value: animate)
                Text(value)
                    .font(MooniFont.title(17))
                    .foregroundColor(MooniColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(6)
            }
            .frame(height: 92)
            Text(title)
                .font(MooniFont.caption(11))
                .foregroundColor(MooniColor.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
    }
}

/// A row of cycle segments — one filled capsule per complete ~90-min cycle.
struct CycleRibbon: View {
    let count: Int
    let animate: Bool

    var body: some View {
        let shown = max(count, 1)
        HStack(spacing: 5) {
            ForEach(0..<shown, id: \.self) { i in
                Capsule()
                    .fill(i < count
                          ? LinearGradient(colors: [MooniColor.accent, MooniColor.accentSoft],
                                           startPoint: .leading, endPoint: .trailing)
                          : LinearGradient(colors: [Color.white.opacity(0.08)],
                                           startPoint: .leading, endPoint: .trailing))
                    .frame(maxWidth: .infinity)
                    .scaleEffect(x: animate ? 1 : 0.2, anchor: .leading)
                    .animation(.easeOut(duration: 0.6).delay(Double(i) * 0.06), value: animate)
            }
        }
    }
}

#Preview {
    NightAnalyticsView(entry: AppState.preview.entries.first
                       ?? SleepEntry(bedtime: .now.addingTimeInterval(-28800),
                                     wakeTime: .now, quality: .good, mood: .okay))
        .environmentObject(AppState.preview)
        .environmentObject(SubscriptionManager.shared)
}
