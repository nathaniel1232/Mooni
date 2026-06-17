import SwiftUI

/// The Sleep Report tab — rebuilt as a visualization-first dashboard.
///
/// Layout (top → bottom):
///  • Hero: big sleep-score dual ring (left) · pet mood (right) · sleep
///    timing strip (bottom) — the user's requested hero.
///  • Stage timeline + legend (the hypnogram-style breakdown).
///  • Three circular metric rings (duration / recovery / consistency).
///  • 7-night stacked-stage trend with goal line + score sparkline.
///  • Pro insight tiles (sleep debt, variance, best window, lift, recovery)
///    or a single unlock teaser.
///
/// Free vs Pro gating is unchanged; only the presentation is new.
struct SleepReportView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Binding var showPaywall: Bool

    @State private var appeared = false
    @State private var showHistory = false
    @State private var analyticsEntry: SleepEntry?

    var body: some View {
        NavigationStack {
            ZStack {
                MooniGradient.night.ignoresSafeArea()
                StarsBackground(count: 32).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        sectionHeader
                        if let entry = appState.lastEntry {
                            heroCard(entry)
                            analyticsCTA(entry)
                            stageTimelineCard(entry)
                            if subscriptionManager.isPro {
                                stageQualityCard(entry)
                                metricRingsCard(entry)
                                energyTrendCard
                                trendCard
                                insightsGrid
                            } else {
                                proTeaser
                            }
                        } else {
                            emptyState
                        }
                    }
                    .padding(18)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                // iPad: cap content column; background stays full-bleed.
                .responsiveContainer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { appeared = true }
        }
        .sheet(isPresented: $showHistory) { SleepHistoryView() }
        .fullScreenCover(item: $analyticsEntry) { entry in
            NightAnalyticsView(entry: entry, onClose: { analyticsEntry = nil })
        }
    }

    // MARK: - Header + analytics entry points

    private var sectionHeader: some View {
        HStack(alignment: .center) {
            Text("Sleep")
                .font(MooniFont.display(30))
                .foregroundColor(MooniColor.textPrimary)
            Spacer()
            Button {
                Haptics.tap()
                showHistory = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12, weight: .bold))
                    Text("History")
                        .font(MooniFont.title(14))
                }
                .foregroundColor(MooniColor.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(MooniColor.accent.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private func analyticsCTA(_ entry: SleepEntry) -> some View {
        Button {
            Haptics.tap()
            analyticsEntry = entry
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(MooniColor.accentSoft)
                VStack(alignment: .leading, spacing: 2) {
                    Text("See your full night analysis")
                        .font(MooniFont.title(15))
                        .foregroundColor(MooniColor.textPrimary)
                    Text("Hormone windows · cycles · recovery")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(MooniColor.accent)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(MooniColor.surface)
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(MooniColor.accent.opacity(0.25), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Derived values

    private func readiness(_ e: SleepEntry) -> Int { e.readinessScore ?? e.score }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 85...:   return MooniColor.success
        case 70..<85: return MooniColor.accent
        case 50..<70: return MooniColor.warning
        default:      return MooniColor.danger
        }
    }

    private func moodForReadiness(_ r: Int) -> Pet.Mood {
        switch r {
        case 85...:   return .energized
        case 70..<85: return .rested
        case 55..<70: return .calm
        case 40..<55: return .groggy
        default:      return .tired
        }
    }

    private func stages(for entry: SleepEntry) -> SleepStagesEstimate {
        if let stages = entry.stages { return stages }
        let total = max(entry.totalSleepDuration, appState.goalHours * 3600, 8 * 3600)
        return SleepScoringManager.estimateStages(
            totalSleep: total,
            timeInBed: entry.timeInBed ?? entry.duration,
            bedtime: entry.bedtime,
            wakeTime: entry.wakeTime,
            quality: entry.quality,
            checkIn: appState.checkIn(for: entry),
            age: appState.profile.age
        )
    }

    // MARK: - Hero

    private func heroCard(_ entry: SleepEntry) -> some View {
        let r = readiness(entry)
        let energy = entry.energyLevel ?? SleepScoringManager.energyLevel(for: r)
        let goalSecs = max(appState.goalHours * 3600, 1)
        let durationPct = min(1, entry.totalSleepDuration / goalSecs)

        return MooniCard(padding: 22) {
            VStack(spacing: 20) {
                HStack {
                    Label("Last night", systemImage: "moon.stars.fill")
                        .font(MooniFont.title(14))
                        .foregroundColor(MooniColor.textSecondary)
                    Spacer()
                    Text(entry.wakeTime.shortDateString)
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textMuted)
                    if entry.isEstimated {
                        Text("MODELED")
                            .font(MooniFont.caption(9))
                            .tracking(1)
                            .foregroundColor(MooniColor.warning)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(MooniColor.warning.opacity(0.16))
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 8) {
                    // LEFT — single clean sleep-score ring
                    ScoreRing(
                        score: entry.score,
                        color: scoreColor(entry.score),
                        animate: appeared
                    )
                    .frame(width: 170, height: 170)

                    Spacer(minLength: 0)

                    // RIGHT — pet mood
                    VStack(spacing: 8) {
                        DreamSpiritView(pet: moodPet(entry), size: 104)
                            .shadow(color: MooniColor.petGlow.opacity(0.22), radius: 18, y: 8)
                        Text(moodForReadiness(r).label)
                            .font(MooniFont.title(14))
                            .foregroundColor(MooniColor.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(scoreColor(r).opacity(0.16))
                            .clipShape(Capsule())
                    }
                    .frame(width: 132)
                }

                // BOTTOM — timing strip
                timingStrip(entry, energy: energy, durationPct: durationPct)
            }
        }
    }

    private func moodPet(_ entry: SleepEntry) -> Pet {
        var p = appState.pet
        p.mood = moodForReadiness(readiness(entry))
        return p
    }

    private func timingStrip(_ entry: SleepEntry, energy: String, durationPct: Double) -> some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 0) {
                timePillar(icon: "bed.double.fill",
                           time: entry.bedtime.hourMinuteString,
                           label: "Asleep", tint: MooniColor.accentSoft)
                Rectangle()
                    .fill(MooniColor.accent.opacity(0.5))
                    .frame(height: 2)
                    .overlay(
                        Text(entry.formattedDuration)
                            .font(MooniFont.title(15))
                            .foregroundColor(MooniColor.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(MooniColor.surface)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                    )
                timePillar(icon: "sunrise.fill",
                           time: entry.wakeTime.hourMinuteString,
                           label: "Woke", tint: MooniColor.warning)
            }

            HStack(spacing: 10) {
                miniMeter(icon: "target", label: "Goal",
                          value: "\(Int(durationPct * 100))%",
                          progress: durationPct, tint: MooniColor.accent)
                miniMeter(icon: "bolt.fill", label: energy,
                          value: "\(readiness(entry))%",
                          progress: Double(readiness(entry)) / 100,
                          tint: MooniColor.success)
            }
        }
    }

    private func timePillar(icon: String, time: String, label: String, tint: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.16))
                .clipShape(Circle())
            Text(time)
                .font(MooniFont.title(15))
                .foregroundColor(MooniColor.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(MooniFont.caption(10))
                .foregroundColor(MooniColor.textMuted)
                .textCase(.uppercase)
        }
        .frame(width: 78)
    }

    private func miniMeter(icon: String, label: String, value: String,
                           progress: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(tint)
                Text(label)
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(value)
                    .font(MooniFont.title(13))
                    .foregroundColor(MooniColor.textPrimary)
            }
            MooniProgressBar(value: appeared ? min(max(progress, 0), 1) : 0,
                             height: 7, colors: [tint])
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Stage timeline (hypnogram-style)

    private func stageTimelineCard(_ entry: SleepEntry) -> some View {
        let s = stages(for: entry)
        let segs: [(name: String, secs: TimeInterval, color: Color)] = [
            ("Deep",  s.deepSleep,  StagePalette.deep),
            ("Light", s.lightSleep, StagePalette.light),
            ("REM",   s.remSleep,   StagePalette.rem),
            ("Awake", s.awakeTime,  StagePalette.awake)
        ]
        let total = max(segs.reduce(0) { $0 + $1.secs }, 1)

        return MooniCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Sleep stages", systemImage: "waveform.path.ecg")
                        .font(MooniFont.title(15))
                        .foregroundColor(MooniColor.textPrimary)
                    Spacer()
                    Text(entry.formattedDuration)
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                }

                // Proportional stacked stage bar
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(Array(segs.enumerated()), id: \.offset) { _, seg in
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(seg.color)
                                .frame(width: max(2, geo.size.width
                                        * CGFloat((appeared ? seg.secs : 0) / total)))
                        }
                        if !appeared { Spacer(minLength: 0) }
                    }
                }
                .frame(height: 26)
                .animation(.easeOut(duration: 0.9), value: appeared)

                // Legend with rings + durations
                HStack(spacing: 10) {
                    ForEach(Array(segs.enumerated()), id: \.offset) { _, seg in
                        stageLegend(name: seg.name, secs: seg.secs,
                                    pct: seg.secs / total, color: seg.color)
                    }
                }

                // Health-app disclaimer (Guideline 1.4.1). Kept small and muted
                // so it fits the existing footer-caption style without drawing
                // attention away from the stage breakdown above.
                Text("Modeled from motion & Health data — not a medical diagnosis.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 6)
            }
        }
    }

    private func stageLegend(name: String, secs: TimeInterval,
                             pct: Double, color: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.08), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: appeared ? pct : 0)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.0), value: appeared)
                Text("\(Int(pct * 100))")
                    .font(MooniFont.title(12))
                    .foregroundColor(MooniColor.textPrimary)
            }
            .frame(width: 44, height: 44)
            Text(name)
                .font(MooniFont.caption(11))
                .foregroundColor(MooniColor.textSecondary)
            Text(durationLabel(secs))
                .font(MooniFont.caption(10))
                .foregroundColor(MooniColor.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private func durationLabel(_ secs: TimeInterval) -> String {
        let m = Int(secs) / 60
        return m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m"
    }

    // MARK: - Stage quality (vs healthy targets)

    private func stageQualityCard(_ entry: SleepEntry) -> some View {
        let s = stages(for: entry)
        let sleepTotal = max(s.deepSleep + s.lightSleep + s.remSleep, 1)
        let inBed = max(sleepTotal + s.awakeTime, 1)

        let deepPct  = s.deepSleep  / sleepTotal
        let remPct   = s.remSleep   / sleepTotal
        let lightPct = s.lightSleep / sleepTotal
        let awakePct = s.awakeTime  / inBed

        // (name, value 0..1, ideal lo, ideal hi, higherIsBetter, color)
        let rows: [(String, Double, Double, Double, Bool, Color)] = [
            ("Deep",  deepPct,  0.13, 0.23, true,  StagePalette.deep),
            ("REM",   remPct,   0.20, 0.25, true,  StagePalette.rem),
            ("Light", lightPct, 0.45, 0.55, false, StagePalette.light),
            ("Awake", awakePct, 0.00, 0.08, false, StagePalette.awake)
        ]

        return MooniCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Stage quality", systemImage: "chart.bar.xaxis")
                        .font(MooniFont.title(15))
                        .foregroundColor(MooniColor.textPrimary)
                    Spacer()
                    Text("vs healthy range")
                        .font(MooniFont.caption(11))
                        .foregroundColor(MooniColor.textMuted)
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                    StageQualityRow(
                        name: r.0, value: r.1, idealLo: r.2, idealHi: r.3,
                        higherIsBetter: r.4, color: r.5, animate: appeared
                    )
                }
            }
        }
    }

    // MARK: - Energy trend

    private var energyTrendCard: some View {
        let recent = appState.recentEntries.sorted { $0.wakeTime < $1.wakeTime }
        let series = recent.map { Double($0.readinessScore ?? $0.score) }
        let labels = recent.map { $0.wakeTime.weekdayShort }
        let latest = recent.last.map { $0.readinessScore ?? $0.score } ?? 0
        let energyWord = appState.lastEntry?.energyLevel
            ?? SleepScoringManager.energyLevel(for: latest)
        let avg = series.isEmpty ? 0 : series.reduce(0, +) / Double(series.count)

        return MooniCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Label("Energy & recovery", systemImage: "bolt.fill")
                        .font(MooniFont.title(15))
                        .foregroundColor(MooniColor.textPrimary)
                    Spacer()
                    Text(energyWord)
                        .font(MooniFont.title(14))
                        .foregroundColor(MooniColor.success)
                }

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text("\(latest)")
                        .font(MooniFont.display(40))
                        .foregroundColor(MooniColor.textPrimary)
                    Text("/ 100 today")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textMuted)
                }

                if series.count > 1 {
                    LineChart(values: series, labels: labels, average: avg,
                              color: MooniColor.success, animate: appeared)
                        .frame(height: 132)
                } else {
                    Text("Track a few nights to see your energy trend.")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                }
            }
        }
    }

    // MARK: - Metric rings

    private func metricRingsCard(_ entry: SleepEntry) -> some View {
        let r = readiness(entry)
        let goalSecs = max(appState.goalHours * 3600, 1)
        let durationPct = min(1, entry.totalSleepDuration / goalSecs)
        let consistency = min(1.0, Double(appState.bedtimeConsistencyDays) / 7.0)

        return MooniCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("Tonight at a glance", systemImage: "chart.pie.fill")
                    .font(MooniFont.title(15))
                    .foregroundColor(MooniColor.textPrimary)

                HStack(spacing: 12) {
                    BigMetricRing(title: "Duration",
                                  value: entry.formattedDuration,
                                  progress: durationPct,
                                  color: scoreColor(entry.score),
                                  animate: appeared)
                    BigMetricRing(title: "Recovery",
                                  value: "\(r)%",
                                  progress: Double(r) / 100,
                                  color: MooniColor.success,
                                  animate: appeared)
                    BigMetricRing(title: "Consistency",
                                  value: "\(appState.bedtimeConsistencyDays)d",
                                  progress: consistency,
                                  color: MooniColor.accentSoft,
                                  animate: appeared)
                }
            }
        }
    }

    // MARK: - 7-night trend

    private var trendCard: some View {
        let recent = appState.recentEntries.sorted { $0.wakeTime < $1.wakeTime }
        let maxH = max(recent.map(\.hours).max() ?? 8, 9)
        let avg = recent.isEmpty ? 0 : recent.map(\.hours).reduce(0, +) / Double(recent.count)
        let scores = recent.map { $0.score }

        return MooniCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Last 7 nights", systemImage: "calendar")
                        .font(MooniFont.title(15))
                        .foregroundColor(MooniColor.textPrimary)
                    Spacer()
                    Text(String(format: "avg %.1fh", avg))
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                }

                // Stacked stage bars + goal line
                ZStack(alignment: .bottom) {
                    let goalFrac = min(1, appState.goalHours / maxH)
                    GeometryReader { geo in
                        let y = geo.size.height * (1 - CGFloat(goalFrac))
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: geo.size.width, y: y))
                        }
                        .stroke(MooniColor.textMuted.opacity(0.6),
                                style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                    .frame(height: 132)

                    HStack(alignment: .bottom, spacing: 7) {
                        ForEach(recent) { e in
                            VStack(spacing: 5) {
                                StageStackBar(
                                    stages: stages(for: e),
                                    maxHeight: CGFloat((appeared ? e.hours : 0) / maxH) * 120
                                )
                                Text(e.wakeTime.weekdayShort)
                                    .font(MooniFont.caption(10))
                                    .foregroundColor(MooniColor.textMuted)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        ForEach(0..<max(0, 7 - recent.count), id: \.self) { _ in
                            VStack(spacing: 5) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.05))
                                    .frame(height: 16)
                                Text("–")
                                    .font(MooniFont.caption(10))
                                    .foregroundColor(MooniColor.textMuted)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 140)
                    .animation(.easeOut(duration: 0.9), value: appeared)
                }

                if scores.count > 1 {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SCORE TREND")
                            .font(MooniFont.caption(9))
                            .tracking(1.5)
                            .foregroundColor(MooniColor.textMuted)
                        Sparkline(values: scores.map { Double($0) },
                                  color: MooniColor.accentSoft)
                            .frame(height: 38)
                    }
                }
            }
        }
    }

    // MARK: - Pro insights

    private var insightsGrid: some View {
        let debt = SleepInsights.sleepDebt(entries: appState.entries, goalHours: appState.goalHours)
        let variance = SleepInsights.wakeTimeVariance(entries: appState.entries)
        let vH = variance / 60, vM = variance % 60
        let varianceStr = vH > 0 ? "\(vH)h \(vM)m" : "\(vM)m"
        let win = SleepInsights.bestSleepWindow(entries: appState.entries)
        let winStr: String = {
            if let w = win { return "\(w.start.hourMinuteString)–\(w.end.hourMinuteString)" }
            let s = Calendar.current.date(byAdding: .minute, value: -30, to: appState.targetBedtime) ?? appState.targetBedtime
            let e = Calendar.current.date(byAdding: .minute, value: 30, to: appState.targetBedtime) ?? appState.targetBedtime
            return "\(s.hourMinuteString)–\(e.hourMinuteString)"
        }()
        let lift = SleepInsights.windDownLift(entries: appState.entries)
        let recovery = SleepInsights.recoveryPrediction(
            entries: appState.entries,
            goalHours: appState.goalHours,
            plannedHours: appState.goalHours)

        return VStack(spacing: 14) {
            HStack {
                Label("Pro insights", systemImage: "sparkles")
                    .font(MooniFont.title(15))
                    .foregroundColor(MooniColor.accent)
                Spacer()
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14),
                                GridItem(.flexible(), spacing: 14)], spacing: 14) {
                InsightTile(icon: "moon.zzz.fill", tint: MooniColor.danger,
                            title: "Sleep debt", value: SleepInsights.formatDebt(debt),
                            progress: min(1, abs(debt) / 10))
                InsightTile(icon: "calendar.badge.clock", tint: MooniColor.warning,
                            title: "Wake variance", value: varianceStr,
                            progress: min(1, Double(variance) / 120))
                InsightTile(icon: "target", tint: MooniColor.accent,
                            title: "Best window", value: winStr,
                            progress: 0.78)
                InsightTile(icon: "checklist", tint: MooniColor.success,
                            title: "Wind-down lift", value: lift > 0 ? "+\(lift)m" : "0m",
                            progress: min(1, Double(lift) / 60))
            }
            recoveryBanner(recovery)
        }
    }

    private func recoveryBanner(_ predicted: Int) -> some View {
        MooniCard(padding: 18) {
            HStack(spacing: 16) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.08), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: appeared ? Double(predicted) / 100 : 0)
                        .stroke(MooniColor.accentSoft,
                                style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 1.0), value: appeared)
                    Text("\(predicted)%")
                        .font(MooniFont.title(16))
                        .foregroundColor(MooniColor.textPrimary)
                }
                .frame(width: 62, height: 62)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Recovery forecast")
                        .font(MooniFont.title(14))
                        .foregroundColor(MooniColor.textPrimary)
                    Text("Hit your goal tonight and \(appState.pet.name) recovers to \(predicted)% energy tomorrow.")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var proTeaser: some View {
        Button { showPaywall = true } label: {
            MooniCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("Unlock Pro insights", systemImage: "sparkles")
                            .font(MooniFont.title(15))
                            .foregroundColor(MooniColor.accent)
                        Spacer()
                        Image(systemName: "lock.fill")
                            .foregroundColor(MooniColor.textMuted)
                    }
                    HStack(spacing: 10) {
                        ForEach(["moon.zzz.fill", "calendar.badge.clock",
                                 "target", "heart.fill"], id: \.self) { ic in
                            Image(systemName: ic)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(MooniColor.accentSoft)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.white.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .blur(radius: 1.2)
                        }
                    }
                    Text("Sleep debt · wake-time consistency · your best sleep window · habit lift · recovery forecast")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
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

    private var emptyState: some View {
        MooniCard {
            VStack(spacing: 12) {
                Image(systemName: "moon.zzz")
                    .font(.system(size: 40))
                    .foregroundColor(MooniColor.accentSoft)
                Text("No sleep yet")
                    .font(MooniFont.title(18))
                    .foregroundColor(MooniColor.textPrimary)
                Text("Track a night and your visual sleep report appears here.")
                    .font(MooniFont.caption(13))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
        }
    }
}

// MARK: - Dual score ring

/// One clean ring. Flat colour (no gradient → no seam at 12 o'clock),
/// generous room around the number so it never feels cramped.
private struct ScoreRing: View {
    let score: Int
    let color: Color
    let animate: Bool

    private var pct: CGFloat { CGFloat(min(max(score, 0), 100)) / 100 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: 13)
            Circle()
                .trim(from: 0, to: animate ? pct : 0)
                .stroke(color, style: StrokeStyle(lineWidth: 13, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 1.1), value: animate)

            VStack(spacing: 3) {
                Text("\(score)")
                    .font(MooniFont.display(56))
                    .foregroundColor(MooniColor.textPrimary)
                    .monospacedDigit()
                Text("SLEEP SCORE")
                    .font(MooniFont.caption(9))
                    .tracking(1.8)
                    .foregroundColor(MooniColor.textMuted)
            }
            .padding(28)
        }
    }
}

// MARK: - Big metric ring

private struct BigMetricRing: View {
    let title: String
    let value: String
    let progress: Double
    let color: Color
    let animate: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.07), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: animate ? min(max(progress, 0), 1) : 0)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.0), value: animate)
                Text(value)
                    .font(MooniFont.title(15))
                    .foregroundColor(MooniColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(6)
            }
            .frame(height: 78)
            Text(title)
                .font(MooniFont.caption(11))
                .foregroundColor(MooniColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Stacked stage bar (trend)

private struct StageStackBar: View {
    let stages: SleepStagesEstimate
    let maxHeight: CGFloat

    private var segments: [(TimeInterval, Color)] {
        [
            (stages.deepSleep,  StagePalette.deep),
            (stages.lightSleep, StagePalette.light),
            (stages.remSleep,   StagePalette.rem),
            (stages.awakeTime,  StagePalette.awake)
        ].filter { $0.0 > 0 }
    }

    private var total: TimeInterval {
        max(segments.reduce(0) { $0 + $1.0 }, 1)
    }

    var body: some View {
        VStack(spacing: 2) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(seg.1)
                    .frame(height: max(4, maxHeight * CGFloat(seg.0 / total)))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: max(20, maxHeight), alignment: .bottom)
    }
}

// MARK: - Sparkline

private struct Sparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let lo = values.min() ?? 0
            let hi = values.max() ?? 1
            let span = max(hi - lo, 1)
            let pts: [CGPoint] = values.enumerated().map { i, v in
                let x = values.count > 1
                    ? geo.size.width * CGFloat(i) / CGFloat(values.count - 1) : 0
                let y = geo.size.height * (1 - CGFloat((v - lo) / span))
                return CGPoint(x: x, y: y)
            }
            ZStack {
                Path { p in
                    guard let first = pts.first else { return }
                    p.move(to: CGPoint(x: first.x, y: geo.size.height))
                    pts.forEach { p.addLine(to: $0) }
                    p.addLine(to: CGPoint(x: pts.last?.x ?? 0, y: geo.size.height))
                    p.closeSubpath()
                }
                .fill(color.opacity(0.16))
                Path { p in
                    guard let first = pts.first else { return }
                    p.move(to: first)
                    pts.dropFirst().forEach { p.addLine(to: $0) }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2.5,
                                                  lineCap: .round, lineJoin: .round))
                if let last = pts.last {
                    Circle().fill(color).frame(width: 7, height: 7)
                        .position(last)
                        .shadow(color: color, radius: 4)
                }
            }
        }
    }
}

// MARK: - Insight tile

private struct InsightTile: View {
    let icon: String
    let tint: Color
    let title: String
    let value: String
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Spacer()
            }
            Text(value)
                .font(MooniFont.display(22))
                .foregroundColor(MooniColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(MooniFont.caption(12))
                .foregroundColor(MooniColor.textSecondary)
            MooniProgressBar(value: min(max(progress, 0), 1), height: 5, colors: [tint])
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(MooniColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(tint.opacity(0.22), lineWidth: 1))
        )
    }
}

// MARK: - Stage quality row

private struct StageQualityRow: View {
    let name: String
    let value: Double          // 0…1 (share)
    let idealLo: Double
    let idealHi: Double
    let higherIsBetter: Bool
    let color: Color
    let animate: Bool

    /// Bar scale — give headroom above the ideal band so it reads well.
    private var scale: Double { max(idealHi * 1.8, 0.6) }

    private enum Verdict { case good, low, high
        var label: String { self == .good ? "Healthy" : (self == .low ? "Low" : "High") }
        var color: Color {
            switch self {
            case .good: return MooniColor.success
            case .low:  return MooniColor.warning
            case .high: return MooniColor.warning
            }
        }
    }

    private var verdict: Verdict {
        if value < idealLo { return .low }
        if value > idealHi { return .high }
        return .good
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(name)
                    .font(MooniFont.title(14))
                    .foregroundColor(MooniColor.textPrimary)
                Spacer()
                Text("\(Int((value * 100).rounded()))%")
                    .font(MooniFont.title(14))
                    .foregroundColor(MooniColor.textPrimary)
                    .monospacedDigit()
                Text(verdict.label)
                    .font(MooniFont.caption(10))
                    .foregroundColor(verdict.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(verdict.color.opacity(0.16))
                    .clipShape(Capsule())
            }

            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    // Ideal band
                    Capsule()
                        .fill(MooniColor.success.opacity(0.18))
                        .frame(width: max(2, w * CGFloat((idealHi - idealLo) / scale)))
                        .offset(x: w * CGFloat(idealLo / scale))
                    // Value fill
                    Capsule()
                        .fill(color)
                        .frame(width: max(3, w * CGFloat((animate ? value : 0) / scale)))
                        .animation(.easeOut(duration: 0.9), value: animate)
                }
            }
            .frame(height: 12)
        }
    }
}

// MARK: - Line chart (energy trend)

private struct LineChart: View {
    let values: [Double]      // 0…100
    let labels: [String]
    let average: Double
    let color: Color
    let animate: Bool

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let lo = 0.0, hi = 100.0
                let span = hi - lo
                let pts: [CGPoint] = values.enumerated().map { i, v in
                    let x = values.count > 1
                        ? w * CGFloat(i) / CGFloat(values.count - 1) : w / 2
                    let y = h * (1 - CGFloat((v - lo) / span))
                    return CGPoint(x: x, y: y)
                }
                let avgY = h * (1 - CGFloat((average - lo) / span))

                ZStack {
                    // Average baseline
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: avgY))
                        p.addLine(to: CGPoint(x: w, y: avgY))
                    }
                    .stroke(MooniColor.textMuted.opacity(0.5),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                    // Area
                    Path { p in
                        guard let f = pts.first else { return }
                        p.move(to: CGPoint(x: f.x, y: h))
                        pts.forEach { p.addLine(to: $0) }
                        p.addLine(to: CGPoint(x: pts.last?.x ?? 0, y: h))
                        p.closeSubpath()
                    }
                    .fill(color.opacity(0.16))

                    // Line
                    Path { p in
                        guard let f = pts.first else { return }
                        p.move(to: f)
                        pts.dropFirst().forEach { p.addLine(to: $0) }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 2.5,
                                                      lineCap: .round, lineJoin: .round))

                    // Points
                    ForEach(Array(pts.enumerated()), id: \.offset) { i, pt in
                        Circle()
                            .fill(i == pts.count - 1 ? color : MooniColor.surface)
                            .frame(width: i == pts.count - 1 ? 9 : 6,
                                   height: i == pts.count - 1 ? 9 : 6)
                            .overlay(Circle().stroke(color, lineWidth: 1.5))
                            .position(pt)
                    }
                }
                .opacity(animate ? 1 : 0)
                .animation(.easeOut(duration: 0.8), value: animate)
            }

            HStack(spacing: 0) {
                ForEach(Array(labels.enumerated()), id: \.offset) { i, l in
                    Text(l)
                        .font(MooniFont.caption(10))
                        .foregroundColor(i == labels.count - 1
                                         ? MooniColor.textSecondary : MooniColor.textMuted)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - Date helpers

private extension Date {
    var weekdayShort: String {
        let f = DateFormatter(); f.dateFormat = "EEE"
        return f.string(from: self)
    }
    var shortDateString: String {
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return f.string(from: self)
    }
}

#Preview {
    SleepReportView(showPaywall: .constant(false))
        .environmentObject(AppState.preview)
        .environmentObject(SubscriptionManager.shared)
}
