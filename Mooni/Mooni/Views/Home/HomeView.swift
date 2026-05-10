import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Binding var showPaywall: Bool

    @StateObject private var healthKit = HealthKitManager.shared
    @State private var showWindDown = false
    @State private var showStartSleep = false
    @State private var showWhy = false
    @State private var showRecoveryPlan = false
    /// Day key (yyyy-MM-dd) currently selected in the week strip. Nil = the
    /// most-recent night's entry. Drives the day-detail card and insight.
    @State private var selectedDayKey: String? = nil

    private enum HomeMode {
        case firstNight
        case evening
        case morning(SleepEntry)
        case recovery(SleepEntry)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            MooniGradient.night.ignoresSafeArea()
            StarsBackground(count: 48)

            ScrollView {
                LazyVStack(spacing: 22) {
                    headerBar

                    heroCard

                    tonightPlanCard

                    if !appState.entries.isEmpty {
                        weekStripSection

                        if let entry = displayEntry {
                            dayDetailCard(entry)
                            insightCard(entry)
                        }

                        if appState.entries.count > 1 {
                            historySection
                        }
                    }

                    growthFooter

                    Color.clear.frame(height: 24)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 96)
            }
        }
        .sheet(isPresented: $showWindDown, onDismiss: {
            if !appState.isSleeping {
                WindDownDimController.shared.end()
            }
        }) {
            WindDownSheet()
                .onAppear { WindDownDimController.shared.begin() }
        }
        .sheet(isPresented: $showStartSleep) {
            StartSleepSheet()
        }
        .sheet(isPresented: $showWhy) {
            if let entry = appState.lastEntry {
                MorningWhySheet(entry: entry, showPaywall: $showPaywall)
            }
        }
        .sheet(isPresented: $showRecoveryPlan) {
            RecoveryPlanSheet(showPaywall: $showPaywall)
        }
    }

    // MARK: - Mode

    private var mode: HomeMode {
        guard let entry = appState.lastEntry else { return .firstNight }

        let now = Date()
        let isRecentMorningResult = Calendar.current.isDateInToday(entry.wakeTime)
            && Calendar.current.component(.hour, from: now) < 17

        if isRecentMorningResult {
            return entry.score < 60 ? .recovery(entry) : .morning(entry)
        }

        if TimeOfDay.current == .evening || TimeOfDay.current == .night {
            return .evening
        }

        return entry.score < 60 ? .recovery(entry) : .morning(entry)
    }

    private var morningBriefing: HomeIntelligence.Briefing? {
        switch mode {
        case .morning(let entry), .recovery(let entry):
            return HomeIntelligence.briefing(
                for: entry,
                all: appState.entries,
                targetBedtime: appState.targetBedtime,
                targetWakeTime: appState.targetWakeTime,
                goalHours: appState.goalHours,
                petName: appState.pet.name
            )
        default:
            return nil
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                SleepOwlBrandMark(size: .standard)
                Spacer(minLength: 8)
                if !subscriptionManager.isPro {
                    upgradeButton
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(greeting.uppercased())
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.accentSoft.opacity(0.85))
                    .tracking(1.4)
                Text(appState.pet.name)
                    .font(MooniFont.display(28))
                    .foregroundColor(MooniColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 6)
    }

    private var upgradeButton: some View {
        Button { showPaywall = true } label: {
            HStack(spacing: 6) {
                Image(systemName: subscriptionManager.isPro ? "sparkles" : "crown.fill")
                    .font(.system(size: 12, weight: .bold))
                Text(subscriptionManager.isPro ? "Pro" : "Upgrade")
                    .font(MooniFont.caption(12))
            }
            .foregroundColor(MooniColor.background)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: [MooniColor.accentSoft, MooniColor.accent],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            )
            .shadow(color: MooniColor.accent.opacity(0.35), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hero card (varies by mode)

    @ViewBuilder
    private var heroCard: some View {
        switch mode {
        case .firstNight:
            firstNightHero
        case .evening:
            eveningHero
        case .morning(let entry):
            morningHero(entry, isRecovery: false)
        case .recovery(let entry):
            morningHero(entry, isRecovery: true)
        }
    }

    private func morningHero(_ entry: SleepEntry, isRecovery: Bool) -> some View {
        let scoreTint = scoreColor(entry.score)

        return MooniCard(padding: 26, cornerRadius: 32) {
            VStack(spacing: 20) {
                // Pet glow + score ring
                ZStack {
                    // Aura halo
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [scoreTint.opacity(0.34), scoreTint.opacity(0.05), .clear],
                                center: .center,
                                startRadius: 4,
                                endRadius: 160
                            )
                        )
                        .frame(width: 320, height: 320)
                        .blur(radius: 4)

                    // Tiny pet badge floating above the ring
                    DreamSpiritView(pet: petForMood(Pet.Mood.from(score: entry.score)), size: 64)
                        .offset(y: -120)
                        .shadow(color: MooniColor.petGlow.opacity(0.35), radius: 18, y: 8)

                    SleepScoreRing(score: entry.score, size: 200, lineWidth: 14)
                }
                .frame(height: 230)

                // Headline
                VStack(spacing: 6) {
                    Text(entry.formattedDuration)
                        .font(MooniFont.display(36))
                        .foregroundColor(MooniColor.textPrimary)

                    Text(heroHeadline(entry, isRecovery: isRecovery))
                        .font(MooniFont.body(14))
                        .foregroundColor(MooniColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)
                }

                // Stat chips
                HStack(spacing: 8) {
                    heroChip(icon: "bed.double.fill",
                             value: entry.bedtime.hourMinuteString,
                             label: "Bed",
                             color: MooniColor.accent)
                    heroChip(icon: "sunrise.fill",
                             value: entry.wakeTime.hourMinuteString,
                             label: "Wake",
                             color: MooniColor.warning)
                    heroChip(icon: "bolt.heart.fill",
                             value: "\(entry.readinessScore ?? entry.score)",
                             label: "Ready",
                             color: scoreTint)
                }

                // See why pill
                Button { showWhy = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "text.magnifyingglass")
                            .font(.system(size: 11, weight: .bold))
                        Text("See why")
                            .font(MooniFont.caption(13))
                    }
                    .foregroundColor(MooniColor.accentSoft)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(
                        Capsule().fill(MooniColor.accent.opacity(0.18))
                    )
                    .overlay(
                        Capsule().stroke(MooniColor.accentSoft.opacity(0.30), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var firstNightHero: some View {
        MooniCard(padding: 26, cornerRadius: 32) {
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [MooniColor.accent.opacity(0.30), .clear],
                                center: .center, startRadius: 4, endRadius: 160
                            )
                        )
                        .frame(width: 280, height: 280)
                        .blur(radius: 6)

                    DreamSpiritView(pet: petForMood(.cozy), size: 170)
                        .shadow(color: MooniColor.petGlow.opacity(0.4), radius: 26, y: 12)
                }
                .frame(height: 200)

                VStack(spacing: 6) {
                    Text("Your first night")
                        .font(MooniFont.display(28))
                        .foregroundColor(MooniColor.textPrimary)
                    Text("Help \(appState.pet.name) settle in. Tomorrow you'll see your sleep score.")
                        .font(MooniFont.body(14))
                        .foregroundColor(MooniColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 12)
                }

                HStack(spacing: 8) {
                    heroChip(icon: "moon.zzz.fill", value: windDownTime.hourMinuteString, label: "Wind down", color: MooniColor.success)
                    heroChip(icon: "bed.double.fill", value: appState.targetBedtime.hourMinuteString, label: "Bed", color: MooniColor.accent)
                    heroChip(icon: "sunrise.fill", value: appState.targetWakeTime.hourMinuteString, label: "Wake", color: MooniColor.warning)
                }
            }
        }
    }

    private var eveningHero: some View {
        MooniCard(padding: 26, cornerRadius: 32) {
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [MooniColor.accent.opacity(0.32), .clear],
                                center: .center, startRadius: 4, endRadius: 150
                            )
                        )
                        .frame(width: 260, height: 260)
                        .blur(radius: 5)

                    DreamSpiritView(pet: petForMood(.sleepy), size: 150)
                        .shadow(color: MooniColor.petGlow.opacity(0.35), radius: 22, y: 10)
                }
                .frame(height: 180)

                VStack(spacing: 6) {
                    Text("Tonight")
                        .font(MooniFont.caption(11))
                        .foregroundColor(MooniColor.accentSoft)
                        .tracking(1.5)
                        .textCase(.uppercase)
                    Text("\(appState.pet.name) is getting sleepy")
                        .font(MooniFont.display(24))
                        .foregroundColor(MooniColor.textPrimary)
                        .multilineTextAlignment(.center)
                    Text(eveningSubline)
                        .font(MooniFont.body(13))
                        .foregroundColor(MooniColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)
                }

                // Quest progress
                VStack(spacing: 8) {
                    HStack {
                        Text("Tonight's quest")
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.textSecondary)
                        Spacer()
                        Text("\(questDone)/3 done")
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.accentSoft)
                    }
                    MooniProgressBar(value: Double(questDone) / 3.0, height: 9)
                }
            }
        }
    }

    private func heroChip(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.16))
                .clipShape(Circle())
            Text(value)
                .font(MooniFont.title(15))
                .foregroundColor(MooniColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(MooniFont.caption(10))
                .foregroundColor(MooniColor.textMuted)
                .textCase(.uppercase)
                .tracking(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Tonight plan

    private var tonightPlanCard: some View {
        MooniCard(padding: 18, cornerRadius: 26) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Tonight's plan")
                            .font(MooniFont.title(18))
                            .foregroundColor(MooniColor.textPrimary)
                        Text("Wind down at \(windDownTime.hourMinuteString) · sleep at \(appState.targetBedtime.hourMinuteString)")
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "moon.stars.fill")
                        .foregroundColor(MooniColor.accentSoft)
                        .font(.system(size: 17, weight: .semibold))
                }

                VStack(spacing: 10) {
                    PrimaryButton(title: "Start wind-down", icon: "moon.zzz.fill") {
                        showWindDown = true
                    }
                    SecondaryButton(title: "Going to bed now", icon: "bed.double.fill") {
                        showStartSleep = true
                    }
                }

                if !isHealthConnected {
                    Button { connectAppleHealth() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.text.square.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text("Connect Apple Health")
                                .font(MooniFont.caption(12))
                        }
                        .foregroundColor(MooniColor.accentSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Week strip

    private var weekStripSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("This week")
                    .font(MooniFont.title(17))
                    .foregroundColor(MooniColor.textPrimary)
                Spacer()
                if let entry = displayEntry {
                    Text(formattedSelectedDate(entry))
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textMuted)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(last7Days, id: \.self) { day in
                        weekDayChip(day)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private func weekDayChip(_ day: Date) -> some View {
        let key = day.dayKey
        let entry = appState.entries.first(where: { $0.dayKey == key })
        let isSelected = (selectedDayKey ?? appState.lastEntry?.dayKey) == key
        let isToday = Calendar.current.isDateInToday(day)
        let scoreTint: Color = entry.map { scoreColor($0.score) } ?? Color.white.opacity(0.18)

        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                if entry != nil {
                    selectedDayKey = key
                }
            }
        } label: {
            VStack(spacing: 6) {
                Text(weekdayLetter(day))
                    .font(MooniFont.caption(10))
                    .foregroundColor(isSelected ? MooniColor.background : MooniColor.textMuted)
                    .tracking(0.7)

                Text("\(Calendar.current.component(.day, from: day))")
                    .font(MooniFont.title(16))
                    .foregroundColor(isSelected ? MooniColor.background : MooniColor.textPrimary)

                if let entry {
                    Text("\(entry.score)")
                        .font(MooniFont.caption(10))
                        .foregroundColor(isSelected ? MooniColor.background.opacity(0.8) : scoreTint)
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 4, height: 4)
                }
            }
            .frame(width: 44, height: 70)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? scoreTint : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isToday && !isSelected ? MooniColor.accentSoft.opacity(0.5) : Color.clear, lineWidth: 1.2)
            )
            .opacity(entry == nil ? 0.6 : 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Day detail

    private func dayDetailCard(_ entry: SleepEntry) -> some View {
        MooniCard(padding: 18, cornerRadius: 26) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.formattedDuration)
                            .font(MooniFont.display(26))
                            .foregroundColor(MooniColor.textPrimary)
                        Text("\(entry.bedtime.hourMinuteString) → \(entry.wakeTime.hourMinuteString)")
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.textSecondary)
                    }
                    Spacer()
                    scoreBadge(entry.score)
                }

                Divider().background(Color.white.opacity(0.06))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    detailMetric(icon: "bolt.heart.fill",
                                 title: "Readiness",
                                 value: "\(entry.readinessScore ?? entry.score)",
                                 tint: scoreColor(entry.readinessScore ?? entry.score))
                    detailMetric(icon: "battery.100.bolt",
                                 title: "Energy",
                                 value: entry.energyLevel ?? "Steady",
                                 tint: MooniColor.warning)
                    detailMetric(icon: "sparkles",
                                 title: "Quality",
                                 value: entry.quality.label,
                                 tint: MooniColor.accent)
                    detailMetric(icon: "checkmark.circle.fill",
                                 title: "Routine",
                                 value: entry.routineCompleted ? "Done" : "Skipped",
                                 tint: entry.routineCompleted ? MooniColor.success : MooniColor.textMuted)
                }
            }
        }
    }

    private func detailMetric(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(MooniFont.title(14))
                    .foregroundColor(MooniColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(title)
                    .font(MooniFont.caption(10))
                    .foregroundColor(MooniColor.textMuted)
                    .tracking(0.5)
                    .textCase(.uppercase)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func scoreBadge(_ score: Int) -> some View {
        let tint = scoreColor(score)
        return Text("\(score)")
            .font(MooniFont.title(18))
            .foregroundColor(tint)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(tint.opacity(0.18))
            )
            .overlay(
                Capsule().stroke(tint.opacity(0.4), lineWidth: 1)
            )
    }

    // MARK: - Insight card

    private func insightCard(_ entry: SleepEntry) -> some View {
        let copy = entry.insight ?? insightText(for: entry)
        return MooniCard(padding: 16, cornerRadius: 22) {
            HStack(spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(MooniColor.warning)
                    .frame(width: 36, height: 36)
                    .background(MooniColor.warning.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Insight")
                        .font(MooniFont.caption(10))
                        .foregroundColor(MooniColor.warning)
                        .tracking(0.6)
                        .textCase(.uppercase)
                    Text(copy)
                        .font(MooniFont.body(14))
                        .foregroundColor(MooniColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - History

    private var historySection: some View {
        let recent = Array(appState.entries
            .sorted(by: { $0.wakeTime > $1.wakeTime })
            .prefix(8))

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent nights")
                    .font(MooniFont.title(17))
                    .foregroundColor(MooniColor.textPrimary)
                Spacer()
                Text("\(appState.entries.count) tracked")
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textMuted)
            }

            VStack(spacing: 8) {
                ForEach(recent) { entry in
                    historyRow(entry)
                }
            }
        }
    }

    private func historyRow(_ entry: SleepEntry) -> some View {
        let tint = scoreColor(entry.score)
        let isSelected = displayEntry?.id == entry.id

        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                selectedDayKey = entry.dayKey
            }
        } label: {
            HStack(spacing: 14) {
                // Mini score indicator
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: CGFloat(min(max(entry.score, 0), 100)) / 100)
                        .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(entry.score)")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textPrimary)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(historyDateLabel(entry.wakeTime))
                        .font(MooniFont.title(14))
                        .foregroundColor(MooniColor.textPrimary)
                    Text("\(entry.formattedDuration) · \(entry.bedtime.hourMinuteString)–\(entry.wakeTime.hourMinuteString)")
                        .font(MooniFont.caption(11))
                        .foregroundColor(MooniColor.textMuted)
                        .lineLimit(1)
                }

                Spacer()

                Text(scoreLabel(entry.score))
                    .font(MooniFont.caption(11))
                    .foregroundColor(tint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(tint.opacity(0.16)))

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(MooniColor.textMuted)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(isSelected ? 0.10 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? tint.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Growth footer

    private var growthFooter: some View {
        MooniCard(padding: 16, cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Growth")
                            .font(MooniFont.caption(10))
                            .foregroundColor(MooniColor.accentSoft)
                            .tracking(0.6)
                            .textCase(.uppercase)
                        Text("Next: \(appState.pet.name) becomes \(nextStageName)")
                            .font(MooniFont.title(16))
                            .foregroundColor(MooniColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(growthCopy)
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(MooniColor.warning)
                        .frame(width: 36, height: 36)
                        .background(MooniColor.warning.opacity(0.16))
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                }

                MooniProgressBar(value: appState.growthProgress, height: 9)

                HStack {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(MooniColor.warning)
                    Text("\(appState.dreamStars) dream stars")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                    Spacer()
                    if !subscriptionManager.isPro {
                        Button { showPaywall = true } label: {
                            Text("See full path")
                                .font(MooniFont.caption(12))
                                .foregroundColor(MooniColor.accentSoft)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Computed data

    private var last7Days: [Date] {
        let cal = Calendar.current
        return (0..<7).reversed().compactMap {
            cal.date(byAdding: .day, value: -$0, to: Date())
        }
    }

    private var displayEntry: SleepEntry? {
        if let key = selectedDayKey,
           let match = appState.entries.first(where: { $0.dayKey == key }) {
            return match
        }
        return appState.lastEntry
    }

    private func petForMood(_ mood: Pet.Mood) -> Pet {
        var p = appState.pet
        p.mood = mood
        return p
    }

    // MARK: - Copy

    private func heroHeadline(_ entry: SleepEntry, isRecovery: Bool) -> String {
        if isRecovery {
            return "Gentle recovery tonight will help \(appState.pet.name) bounce back."
        }
        if let briefing = morningBriefing {
            return briefing.heroSubline
        }
        switch entry.score {
        case 85...:    return "Great rhythm — \(appState.pet.name) feels fully charged."
        case 70..<85:  return "Solid night. Today is a good day for focused work."
        case 60..<70:  return "An okay night. A steadier bedtime tonight will help."
        default:       return "Rough night. Keep things light and gentle today."
        }
    }

    private var eveningSubline: String {
        HomeIntelligence.eveningAnticipation(
            bedtimeConsistencyDays: appState.bedtimeConsistencyDays,
            targetBedtime: appState.targetBedtime,
            petName: appState.pet.name
        )
    }

    private var growthCopy: String {
        guard let next = appState.nextEvolutionStage else {
            return "\(appState.pet.name) is fully grown"
        }
        let nights = appState.nightsUntilNextEvolution
        if nights == 0 {
            return "\(appState.pet.name) is ready to grow into \(next.label)"
        }
        return "\(nights) calm night\(nights == 1 ? "" : "s") to go"
    }

    private var nextStageName: String {
        appState.nextEvolutionStage?.label ?? "Dream form"
    }

    private var greeting: String {
        switch TimeOfDay.current {
        case .morning: return "Good morning"
        case .day: return "Good afternoon"
        case .evening: return "Good evening"
        case .night: return "Good evening"
        }
    }

    private func scoreLabel(_ score: Int) -> String {
        switch score {
        case 85...:    return "Great"
        case 70..<85:  return "Good"
        case 50..<70:  return "Okay"
        default:       return "Low"
        }
    }

    private func weekdayLetter(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date).uppercased()
    }

    private func formattedSelectedDate(_ entry: SleepEntry) -> String {
        let f = DateFormatter()
        let cal = Calendar.current
        if cal.isDateInToday(entry.wakeTime) { return "Last night" }
        if cal.isDateInYesterday(entry.wakeTime) { return "Yesterday" }
        f.dateFormat = "EEE, MMM d"
        return f.string(from: entry.wakeTime)
    }

    private func historyDateLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Last night" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: date)
    }

    // MARK: - Helpers

    private var windDownTime: Date {
        Calendar.current.date(byAdding: .minute, value: -30, to: appState.targetBedtime) ?? appState.targetBedtime
    }

    private var questDone: Int {
        min(appState.routine.completedToday.intersection(Set(["breathing", "journal", "no_phone"])).count, 3)
    }

    private var isHealthConnected: Bool { healthKit.isConnected }

    private func connectAppleHealth() {
        Task {
            _ = await healthKit.requestAuthorization()
            await appState.importHealthKitSleep()
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 85...:    return MooniColor.success
        case 70..<85:  return MooniColor.accent
        case 50..<70:  return MooniColor.warning
        default:       return MooniColor.danger
        }
    }

    private func insightText(for entry: SleepEntry) -> String {
        if appState.bedtimeConsistencyDays > 0 {
            return "You sleep better when bedtime stays within 30 minutes of \(appState.targetBedtime.hourMinuteString)."
        }
        if entry.score < 60 {
            return "A shorter recovery quest tonight can help \(appState.pet.name) bounce back without pressure."
        }
        return "Keeping bedtime close to \(appState.targetBedtime.hourMinuteString) helps \(appState.pet.name) wake up cozier."
    }
}

// MARK: - Sheets

private struct WindDownSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var systemTask: WindDownSystemTask?

    private var questHabits: [RoutineHabit] {
        ["breathing", "journal", "no_phone"].compactMap { id in
            RoutineHabit.library.first { $0.id == id }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MooniGradient.night.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        LunaMoodHero(
                            pet: appState.pet,
                            mood: .sleepy,
                            size: 150,
                            caption: "Screen is dimmed. \(appState.pet.name) is settling in with you."
                        )
                        .padding(.top, 8)

                        if let task = systemTask {
                            WindDownSystemTaskCard(task: task)
                        }

                        MooniCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Tonight's Quest")
                                    .font(MooniFont.title(18))
                                    .foregroundColor(MooniColor.textPrimary)

                                ForEach(Array(questHabits.enumerated()), id: \.element.id) { index, habit in
                                    HabitRow(habit: habit, index: index)
                                }
                            }
                        }

                        PrimaryButton(title: "I'm ready for sleep", icon: "moon.fill") {
                            appState.enterSleepMode()
                            dismiss()
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Wind-down")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(MooniColor.accent)
                }
            }
            .onAppear {
                if systemTask == nil, let task = WindDownSystemTaskStore.shared.taskForTonight {
                    systemTask = task
                    WindDownSystemTaskStore.shared.markShown(task)
                }
            }
        }
    }
}

private struct HabitRow: View {
    @EnvironmentObject var appState: AppState
    let habit: RoutineHabit
    let index: Int

    private var isDone: Bool {
        appState.routine.completedToday.contains(habit.id)
    }

    var body: some View {
        Button {
            let wasDone = isDone
            withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) {
                appState.toggleHabitCompletion(habit)
            }
            if !wasDone {
                appState.awardDreamStarsForQuestStep(habit, amount: index == 2 ? 10 : 5)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } else {
                UISelectionFeedbackGenerator().selectionChanged()
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "\(index + 1).circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(isDone ? MooniColor.success : MooniColor.accent)

                VStack(alignment: .leading, spacing: 3) {
                    Text(habit.title)
                        .font(MooniFont.title(15))
                        .foregroundColor(MooniColor.textPrimary)
                    Text(isDone ? lunaMicrocopy(index: index) : stepHint(index: index))
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(14)
            .background(Color.white.opacity(isDone ? 0.11 : 0.055))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func stepHint(index: Int) -> String {
        switch index {
        case 0: return "A few slow breaths soften bedtime."
        case 1: return "Clear one thought before sleep."
        default: return "Phone away — last step before bed."
        }
    }

    private func lunaMicrocopy(index: Int) -> String {
        switch index {
        case 0: return "Almost ready for sleep."
        case 1: return "That helped me feel calmer."
        default: return "I feel cozy now."
        }
    }
}

private struct StartSleepSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var bedtime: Date = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                MooniGradient.night.ignoresSafeArea()
                VStack(spacing: 24) {
                    LunaMoodHero(
                        pet: appState.pet,
                        mood: .sleepy,
                        size: 150,
                        caption: "Sleep well. \(appState.pet.name) is settling in with you."
                    )

                    MooniCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tonight's bedtime")
                                .font(MooniFont.caption(13))
                                .foregroundColor(MooniColor.textSecondary)
                            DatePicker("", selection: $bedtime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .colorScheme(.dark)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 4)

                    PrimaryButton(title: "Good night", icon: "moon.stars.fill") {
                        ActivitySleepEstimator.shared.recordSleepStart(at: normalizedBedtime)
                        appState.enterSleepMode(startedAt: normalizedBedtime)
                        dismiss()
                    }

                    #if DEBUG
                    SecondaryButton(title: "DEV: Simulate morning now", icon: "forward.end.fill") {
                        appState.simulateCompletedNightEndingNow()
                        dismiss()
                    }
                    #endif

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Going to bed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(MooniColor.accent)
                }
            }
        }
    }

    private var normalizedBedtime: Date {
        let now = Date()
        let calendar = Calendar.current
        let picked = calendar.dateComponents([.hour, .minute], from: bedtime)
        var today = calendar.dateComponents([.year, .month, .day], from: now)
        today.hour = picked.hour
        today.minute = picked.minute

        guard let selectedToday = calendar.date(from: today) else { return now }
        if selectedToday > now.addingTimeInterval(30 * 60) {
            return calendar.date(byAdding: .day, value: -1, to: selectedToday) ?? now
        }
        return min(selectedToday, now)
    }
}

private struct MorningWhySheet: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    let entry: SleepEntry
    @Binding var showPaywall: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                MooniGradient.night.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        LunaMoodHero(
                            pet: appState.pet,
                            mood: Pet.Mood.from(score: entry.score),
                            size: 140,
                            caption: "Here is the simple version."
                        )
                        .padding(.top, 4)

                        MooniCard(padding: 18, cornerRadius: 22) {
                            VStack(alignment: .leading, spacing: 14) {
                                Text(explanation)
                                    .font(MooniFont.body(16))
                                    .foregroundColor(MooniColor.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)

                                MooniInfoRow(icon: "bed.double.fill", title: "Bedtime", value: bedtimeDetail)
                                MooniInfoRow(icon: "sunrise.fill", title: "Wake time", value: wakeDetail, color: MooniColor.warning)
                                MooniInfoRow(icon: "moon.zzz.fill", title: "Wind-down", value: entry.routineCompleted ? "Completed" : "Try tonight", color: MooniColor.success)
                            }
                        }

                        if !subscriptionManager.isPro && !appState.entries.isEmpty {
                            MooniPremiumLockCard(
                                icon: "sparkles",
                                title: "Deeper sleep insight",
                                subtitle: "Unlock sleep debt, best sleep window, and recovery prediction.",
                                actionTitle: "See your full pattern"
                            ) {
                                showPaywall = true
                                dismiss()
                            }
                            .padding(.top, 2)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Why")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(MooniColor.accent)
                }
            }
        }
    }

    private var explanation: String {
        let name = appState.pet.name
        if entry.score >= 80 {
            return "\(name) woke up cozy because your sleep duration and timing were close to your goal."
        }
        if entry.score >= 60 {
            return "\(name) had an okay night. A steadier bedtime tonight should make tomorrow feel softer."
        }
        return "Rough night. A small recovery quest tonight is enough to help \(name) start bouncing back."
    }

    private var bedtimeDetail: String {
        "\(entry.bedtime.hourMinuteString) target \(appState.targetBedtime.hourMinuteString)"
    }

    private var wakeDetail: String {
        "\(entry.wakeTime.hourMinuteString) target \(appState.targetWakeTime.hourMinuteString)"
    }
}

private struct RecoveryPlanSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Binding var showPaywall: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                MooniGradient.night.ignoresSafeArea()

                VStack(spacing: 18) {
                    LunaMoodHero(
                        pet: appState.pet,
                        mood: .recovering,
                        size: 150,
                        caption: "Tonight is a fresh start."
                    )

                    MooniCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Gentle recovery")
                                .font(MooniFont.title(18))
                                .foregroundColor(MooniColor.textPrimary)

                            MooniInfoRow(icon: "iphone.slash", title: "Phone away", value: "10 min earlier")
                            MooniInfoRow(icon: "wind", title: "Breathing", value: "2 minutes", color: MooniColor.success)
                            MooniInfoRow(icon: "moon.fill", title: "Bedtime", value: appState.targetBedtime.hourMinuteString)
                        }
                    }

                    MooniPremiumLockCard(
                        icon: "heart.text.square.fill",
                        title: "Personal recovery plan",
                        subtitle: "Premium adapts recovery nights to sleep debt, schedule, and wake-up patterns."
                    ) {
                        showPaywall = true
                    }

                    PrimaryButton(title: "Start wind-down", icon: "moon.zzz.fill") {
                        dismiss()
                    }

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Recovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(MooniColor.accent)
                }
            }
        }
    }
}

#Preview {
    HomeView(showPaywall: .constant(false))
        .environmentObject(AppState.preview)
        .environmentObject(SubscriptionManager.shared)
}
