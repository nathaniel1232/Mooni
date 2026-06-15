import SwiftUI

/// Full sleep history: a month calendar tinted by each night's score, plus a
/// reverse-chronological list of every night. Tapping a day opens that night's
/// detail — its times, the check-in answers you logged, and the full Night
/// Analytics read-out.
struct SleepHistoryView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionManager: SubscriptionManager

    @State private var month: Date = Date()
    @State private var selected: SleepEntry?
    @State private var showLogSheet = false
    @State private var showPaywall = false

    /// Free users get the newest 3 nights interactive; older nights are locked.
    private static let freeHistoryLimit = 3

    private var sorted: [SleepEntry] {
        appState.entries.sorted { $0.wakeTime > $1.wakeTime }
    }

    /// The set of dayKeys that are unlocked for a non-Pro user.
    private var unlockedDayKeys: Set<String> {
        guard !subscriptionManager.isPro else { return Set(sorted.map(\.dayKey)) }
        return Set(sorted.prefix(Self.freeHistoryLimit).map(\.dayKey))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MooniGradient.night.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        MonthCalendar(
                            month: $month,
                            entriesByDay: entriesByDay,
                            onTapDay: handleTap
                        )
                        logCTA
                        history
                    }
                    .padding(20)
                }
                .responsiveContainer()
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(item: $selected) { entry in
                NightDetailView(entry: entry)
            }
            .sheet(isPresented: $showLogSheet) { LogSleepSheet() }
            .mooniPaywall(isPresented: $showPaywall)
        }
    }

    private var entriesByDay: [String: SleepEntry] {
        // One entry per calendar day, keyed by wake-day (dayKey).
        Dictionary(sorted.map { ($0.dayKey, $0) }, uniquingKeysWith: { a, _ in a })
    }

    private func handleTap(_ entry: SleepEntry) {
        if unlockedDayKeys.contains(entry.dayKey) {
            Haptics.tap()
            selected = entry
        } else {
            showPaywall = true
        }
    }

    private var logCTA: some View {
        MooniCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "bed.double.fill").foregroundColor(MooniColor.accent)
                    Text("Log a night")
                        .font(MooniFont.title(18))
                        .foregroundColor(MooniColor.textPrimary)
                }
                Text("Missed a night? Add it by hand and \(appState.pet.name) will catch up.")
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                PrimaryButton(title: "Log sleep", icon: "plus") { showLogSheet = true }
            }
        }
    }

    @ViewBuilder
    private var history: some View {
        if sorted.isEmpty {
            MooniCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your nights")
                        .font(MooniFont.title(17))
                        .foregroundColor(MooniColor.textPrimary)
                    Text("No history yet — your first night will appear here.")
                        .font(MooniFont.body(14))
                        .foregroundColor(MooniColor.textSecondary)
                }
            }
        } else {
            let visible = subscriptionManager.isPro
                ? sorted
                : Array(sorted.prefix(Self.freeHistoryLimit))
            let hiddenCount = max(0, sorted.count - visible.count)

            VStack(alignment: .leading, spacing: 10) {
                Text("Your nights")
                    .font(MooniFont.title(17))
                    .foregroundColor(MooniColor.textPrimary)
                    .padding(.leading, 6)

                ForEach(visible) { entry in
                    Button { handleTap(entry) } label: { NightRow(entry: entry) }
                        .buttonStyle(.plain)
                }

                if hiddenCount > 0 {
                    historyUpsell(hiddenCount: hiddenCount)
                }
            }
        }
    }

    private func historyUpsell(hiddenCount: Int) -> some View {
        Button { showPaywall = true } label: {
            MooniCard {
                HStack(spacing: 14) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(MooniColor.warning)
                        .frame(width: 36, height: 36)
                        .background(MooniColor.warning.opacity(0.16))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(hiddenCount) more night\(hiddenCount == 1 ? "" : "s") locked")
                            .font(MooniFont.title(15))
                            .foregroundColor(MooniColor.textPrimary)
                        Text("Unlock full history with SleepOwl Pro")
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(MooniColor.accent)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Month calendar

struct MonthCalendar: View {
    @Binding var month: Date
    let entriesByDay: [String: SleepEntry]
    let onTapDay: (SleepEntry) -> Void

    private let cal = Calendar.current
    private let dayFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    var body: some View {
        MooniCard {
            VStack(spacing: 12) {
                header
                weekdayHeader
                grid
            }
        }
    }

    private var header: some View {
        HStack {
            navButton("chevron.left") { shiftMonth(-1) }
            Spacer()
            Text(month, format: .dateTime.month(.wide).year())
                .font(MooniFont.title(16))
                .foregroundColor(MooniColor.textPrimary)
            Spacer()
            navButton("chevron.right") { shiftMonth(1) }
        }
    }

    private func navButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            withAnimation(.easeInOut(duration: 0.2)) { action() }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(MooniColor.accent)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.06))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { s in
                Text(s)
                    .font(MooniFont.caption(10))
                    .foregroundColor(MooniColor.textMuted)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7),
                  spacing: 6) {
            ForEach(Array(gridDays.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 40)
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let key = dayFmt.string(from: day)
        let entry = entriesByDay[key]
        let isToday = cal.isDateInToday(day)
        return Button {
            if let entry { onTapDay(entry) }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(entry != nil
                          ? nightScoreTint(entry!.score).opacity(0.30)
                          : Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isToday ? MooniColor.accent : (entry != nil ? nightScoreTint(entry!.score).opacity(0.55) : .clear),
                                    lineWidth: isToday ? 1.6 : 1)
                    )
                VStack(spacing: 1) {
                    Text("\(cal.component(.day, from: day))")
                        .font(MooniFont.caption(12))
                        .foregroundColor(entry != nil ? MooniColor.textPrimary : MooniColor.textMuted)
                    if let entry {
                        Text("\(entry.score)")
                            .font(MooniFont.caption(9))
                            .foregroundColor(nightScoreTint(entry.score))
                    }
                }
            }
            .frame(height: 40)
        }
        .buttonStyle(.plain)
        .disabled(entry == nil)
    }

    // Calendar maths

    private var weekdaySymbols: [String] {
        let s = cal.veryShortStandaloneWeekdaySymbols
        let first = cal.firstWeekday - 1
        return Array(s[first...] + s[..<first])
    }

    /// Days of the visible month, padded with leading nils to align weekdays.
    private var gridDays: [Date?] {
        guard let interval = cal.dateInterval(of: .month, for: month),
              let range = cal.range(of: .day, in: .month, for: month) else { return [] }
        let firstWeekday = cal.component(.weekday, from: interval.start)
        let leading = (firstWeekday - cal.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for d in range {
            if let date = cal.date(byAdding: .day, value: d - 1, to: interval.start) {
                cells.append(date)
            }
        }
        return cells
    }

    private func shiftMonth(_ delta: Int) {
        if let m = cal.date(byAdding: .month, value: delta, to: month) { month = m }
    }
}

// MARK: - Night row (list)

struct NightRow: View {
    let entry: SleepEntry

    var body: some View {
        MooniCard(padding: 16) {
            HStack(spacing: 16) {
                SleepScoreRing(score: entry.score, size: 64, lineWidth: 7)
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.wakeTime, format: .dateTime.weekday(.wide).day().month())
                        .font(MooniFont.title(15))
                        .foregroundColor(MooniColor.textPrimary)
                    Text(entry.formattedDuration)
                        .font(MooniFont.caption(13))
                        .foregroundColor(MooniColor.textSecondary)
                    HStack(spacing: 8) {
                        Text("\(entry.bedtime.hourMinuteString) → \(entry.wakeTime.hourMinuteString)")
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.textMuted)
                        Text("• \(entry.quality.emoji) \(entry.quality.label)")
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.textMuted)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(MooniColor.textMuted)
            }
        }
    }
}

func nightScoreTint(_ score: Int) -> Color {
    switch score {
    case 85...:   return MooniColor.success
    case 70..<85: return MooniColor.accent
    case 50..<70: return MooniColor.warning
    default:      return MooniColor.danger
    }
}

// MARK: - Per-night detail

/// A single night's full page: times + score, the check-in answers the user
/// logged that morning, and the complete Night Analytics read-out.
struct NightDetailView: View {
    let entry: SleepEntry

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            MooniGradient.night.ignoresSafeArea()
            StarsBackground(count: 30).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    timesHeader
                    if let checkIn = appState.checkIn(for: entry) {
                        checkInCard(checkIn)
                    }
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
        .navigationTitle(entry.wakeTime.formatted(.dateTime.weekday(.abbreviated).day().month()))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .mooniPaywall(isPresented: $showPaywall)
    }

    private var timesHeader: some View {
        MooniCard(padding: 20) {
            HStack(spacing: 18) {
                SleepScoreRing(score: entry.score, size: 84, lineWidth: 9)
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.formattedDuration)
                        .font(MooniFont.display(28))
                        .foregroundColor(MooniColor.textPrimary)
                    HStack(spacing: 8) {
                        Label(entry.bedtime.hourMinuteString, systemImage: "moon.fill")
                        Image(systemName: "arrow.right").font(.system(size: 10, weight: .bold))
                        Label(entry.wakeTime.hourMinuteString, systemImage: "sun.max.fill")
                    }
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textSecondary)
                    Text("Readiness \(entry.readinessScore ?? entry.score)")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textMuted)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func checkInCard(_ c: MorningCheckIn) -> some View {
        AnalyticsCard(title: "Your check-in", icon: "checklist") {
            let items = checkInItems(c)
            if items.isEmpty {
                Text("No extra details were logged for this night.")
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textSecondary)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                    GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        answerChip(icon: item.icon, label: item.label, value: item.value)
                    }
                }
            }
        }
    }

    private func answerChip(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(MooniColor.accentSoft)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(MooniFont.caption(10))
                    .foregroundColor(MooniColor.textMuted)
                Text(value)
                    .font(MooniFont.caption(13))
                    .foregroundColor(MooniColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// Turns the logged check-in into a list of (icon, label, value) chips,
    /// skipping anything the user didn't answer.
    private func checkInItems(_ c: MorningCheckIn) -> [(icon: String, label: String, value: String)] {
        var out: [(String, String, String)] = []
        out.append(("face.smiling", "Felt", c.feeling.label))
        out.append(("bed.double", "Out of bed", c.getOutOfBedDifficulty.label))
        out.append(("waveform.path", "Wake-ups", c.wakeUps.label))
        out.append(("cloud.moon", "Dreams", c.dreams.label))
        if let m = c.minutesToFallAsleep {
            out.append(("hourglass", "To fall asleep", "\(m) min"))
        }
        if let r = c.roomFeel { out.append(("thermometer.medium", "Room", r.label)) }
        if let count = c.caffeineCount {
            let t = c.lastCaffeineTime.map { " · \($0.hourMinuteString)" } ?? ""
            out.append(("cup.and.saucer", "Caffeine", count == 0 ? "None" : "\(count)\(t)"))
        }
        if let meal = c.lastMealTime {
            let late = c.lateHeavyMeal == true ? " · heavy" : ""
            out.append(("fork.knife", "Last meal", "\(meal.hourMinuteString)\(late)"))
        }
        if let a = c.alcoholDrinks {
            out.append(("wineglass", "Alcohol", a == 0 ? "None" : (a >= 3 ? "3+" : "\(a)")))
        }
        if let e = c.exerciseTime { out.append(("figure.run", "Movement", e.label)) }
        if let nap = c.napMinutes {
            out.append(("powersleep", "Nap", nap == 0 ? "None" : "\(nap) min"))
        }
        if let s = c.stressLevel { out.append(("brain.head.profile", "Stress", s.label)) }
        return out.map { (icon: $0.0, label: $0.1, value: $0.2) }
    }
}

// MARK: - Manual log sheet (folded in from the retired SleepLogView)

struct LogSleepSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var bedtime: Date = Date.todayAt(hour: 23, minute: 0).addingTimeInterval(-86400)
    @State private var wakeTime: Date = Date.todayAt(hour: 7, minute: 0)
    @State private var quality: SleepEntry.Quality = .good
    @State private var mood: SleepEntry.Mood = .okay
    @State private var notes: String = ""
    @State private var routineCompleted: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                MooniGradient.night.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        timeSection
                        qualitySection
                        moodSection
                        routineSection
                        notesSection

                        PrimaryButton(title: "Save", icon: "checkmark") {
                            appState.logSleep(
                                bedtime: bedtime,
                                wakeTime: wakeTime,
                                quality: quality,
                                mood: mood,
                                notes: notes,
                                routineCompleted: routineCompleted || appState.routine.isFullyCompleted
                            )
                            dismiss()
                        }
                        .padding(.top, 8)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Log sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(MooniColor.accent)
                }
            }
            .onAppear {
                normalizeOrder()
                routineCompleted = appState.routine.isFullyCompleted
            }
            .onChange(of: bedtime) { _, _ in normalizeOrder() }
            .onChange(of: wakeTime) { _, _ in normalizeOrder() }
        }
    }

    private var timeSection: some View {
        MooniCard {
            VStack(spacing: 14) {
                timeRow(title: "Bedtime",  icon: "moon.fill",    selection: $bedtime)
                Divider().background(Color.white.opacity(0.1))
                timeRow(title: "Wake up",  icon: "sun.max.fill", selection: $wakeTime)

                HStack {
                    Image(systemName: "clock").foregroundColor(MooniColor.textSecondary)
                    Text("Duration: \(durationString)")
                        .font(MooniFont.caption(13))
                        .foregroundColor(MooniColor.textSecondary)
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
    }

    private func timeRow(title: String, icon: String, selection: Binding<Date>) -> some View {
        HStack {
            Image(systemName: icon).foregroundColor(MooniColor.accent).frame(width: 24)
            Text(title)
                .font(MooniFont.title(15))
                .foregroundColor(MooniColor.textPrimary)
            Spacer()
            DatePicker("", selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden().colorScheme(.dark)
        }
    }

    private var qualitySection: some View {
        MooniCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Quality")
                    .font(MooniFont.title(15))
                    .foregroundColor(MooniColor.textPrimary)
                HStack(spacing: 8) {
                    ForEach(SleepEntry.Quality.allCases) { q in
                        chip(label: "\(q.emoji) \(q.label)", selected: quality == q) { quality = q }
                    }
                }
            }
        }
    }

    private var moodSection: some View {
        MooniCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Mood after waking")
                    .font(MooniFont.title(15))
                    .foregroundColor(MooniColor.textPrimary)
                HStack(spacing: 8) {
                    ForEach(SleepEntry.Mood.allCases) { m in
                        chip(label: "\(m.emoji) \(m.label)", selected: mood == m) { mood = m }
                    }
                }
            }
        }
    }

    private var routineSection: some View {
        MooniCard {
            Toggle(isOn: $routineCompleted) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Completed wind-down")
                        .font(MooniFont.title(15))
                        .foregroundColor(MooniColor.textPrimary)
                    Text("Bonus growth if you completed a wind-down")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                }
            }
            .tint(MooniColor.accent)
        }
    }

    private var notesSection: some View {
        MooniCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes (optional)")
                    .font(MooniFont.caption(13))
                    .foregroundColor(MooniColor.textSecondary)
                TextField("", text: $notes, prompt: Text("Anything to remember about this night?")
                    .foregroundColor(MooniColor.textMuted), axis: .vertical)
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textPrimary)
                    .lineLimit(2...4)
                    .padding(10)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private func chip(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(MooniFont.caption(13))
                .foregroundColor(selected ? MooniColor.background : MooniColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.vertical, 10)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity)
                .background(selected ? MooniColor.accent : Color.white.opacity(0.07))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var durationString: String {
        let interval = max(0, wakeTime.timeIntervalSince(bedtime))
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        return "\(h)h \(String(format: "%02d", m))m"
    }

    private func normalizeOrder() {
        guard bedtime >= wakeTime else { return }
        let cal = Calendar.current
        bedtime = cal.date(byAdding: .day, value: -1, to: bedtime) ?? bedtime
    }
}

#Preview {
    SleepHistoryView()
        .environmentObject(AppState.preview)
        .environmentObject(SubscriptionManager.shared)
}
