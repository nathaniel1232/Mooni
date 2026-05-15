import Foundation
import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    // MARK: - Persistence keys
    private enum Key {
        static let onboarded = "mooni.onboarded"
        static let petData = "mooni.pet"
        static let routineData = "mooni.routine"
        static let entriesData = "mooni.entries"
        static let goalHours = "mooni.goalHours"
        static let targetBedHour = "mooni.targetBedHour"
        static let targetBedMinute = "mooni.targetBedMinute"
        static let targetWakeHour = "mooni.targetWakeHour"
        static let targetWakeMinute = "mooni.targetWakeMinute"
        static let lastMorningPrompt = "mooni.lastMorningPrompt"
        static let sleepGoal = "mooni.sleepGoal"
        static let weekendWakeHour = "mooni.weekendWakeHour"
        static let weekendWakeMinute = "mooni.weekendWakeMinute"
        static let dreamStars = "mooni.dreamStars"
        static let profileData = "mooni.profile"
        static let questRewardDay = "mooni.questRewardDay"
        static let questRewardedSteps = "mooni.questRewardedSteps"
        static let isSleeping = "mooni.isSleeping"
        static let sleepStartedAt = "mooni.sleepStartedAt"
        static let wakeTappedAt = "mooni.wakeTappedAt"
        static let appOpenedAfterWakeAt = "mooni.appOpenedAfterWakeAt"
        static let lastSystemTaskShown = "mooni.lastSystemTaskShownAt"
        static let lastSystemTaskIndex = "mooni.lastSystemTaskIndex"
        static let devForcePro = "mooni.devForcePro"
    }

    // MARK: - Published state
    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: Key.onboarded) }
    }

    @Published var pet: Pet { didSet { persistPet() } }
    @Published var routine: Routine { didSet { persistRoutine() } }
    @Published var entries: [SleepEntry] {
        didSet {
            persistEntries()
            if let latest = entries.sorted(by: { $0.wakeTime > $1.wakeTime }).first {
                WidgetSnapshotPublisher.publish(latest)
            }
        }
    }

    @Published var goalHours: Double { didSet { UserDefaults.standard.set(goalHours, forKey: Key.goalHours) } }
    @Published var targetBedtime: Date {
        didSet {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: targetBedtime)
            UserDefaults.standard.set(comps.hour ?? 22, forKey: Key.targetBedHour)
            UserDefaults.standard.set(comps.minute ?? 30, forKey: Key.targetBedMinute)
        }
    }
    @Published var targetWakeTime: Date {
        didSet {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: targetWakeTime)
            UserDefaults.standard.set(comps.hour ?? 7, forKey: Key.targetWakeHour)
            UserDefaults.standard.set(comps.minute ?? 0, forKey: Key.targetWakeMinute)
        }
    }

    @Published var showMorningCheckIn: Bool = false
    @Published var lastEarnedEnergy: Int? = nil
    @Published var lastLevelUp: Int? = nil

    /// True while the user has tapped "Going to bed now" / "Ready for sleep"
    /// and hasn't completed the morning check-in. The app shows a sleep-lock
    /// overlay so the pet (and the user) actually rests.
    @Published var isSleeping: Bool {
        didSet {
            UserDefaults.standard.set(isSleeping, forKey: Key.isSleeping)
            if isSleeping && UserDefaults.standard.object(forKey: Key.sleepStartedAt) == nil {
                UserDefaults.standard.set(Date(), forKey: Key.sleepStartedAt)
            }
        }
    }
    var sleepStartedAt: Date? {
        UserDefaults.standard.object(forKey: Key.sleepStartedAt) as? Date
    }

    /// Primary goal the user picked during onboarding. Drives personalized copy.
    @Published var sleepGoal: SleepGoal? {
        didSet { UserDefaults.standard.set(sleepGoal?.rawValue, forKey: Key.sleepGoal) }
    }

    /// Optional separate weekend wake time (defaults to weekday wake time if nil).
    @Published var weekendWakeTime: Date? {
        didSet {
            if let t = weekendWakeTime {
                let comps = Calendar.current.dateComponents([.hour, .minute], from: t)
                UserDefaults.standard.set(comps.hour ?? 8, forKey: Key.weekendWakeHour)
                UserDefaults.standard.set(comps.minute ?? 0, forKey: Key.weekendWakeMinute)
            }
        }
    }

    /// Currency earned by completing nightly bedtime quests.
    @Published var dreamStars: Int {
        didSet { UserDefaults.standard.set(dreamStars, forKey: Key.dreamStars) }
    }

    /// Personalization captured during onboarding (age/height/weight/behaviors).
    @Published var profile: OnboardingProfile {
        didSet { persistProfile() }
    }

    // MARK: - Init
    init() {
        let defaults = UserDefaults.standard
        self.hasCompletedOnboarding = defaults.bool(forKey: Key.onboarded)

        // Pet
        if let data = defaults.data(forKey: Key.petData),
           let decoded = try? JSONDecoder().decode(Pet.self, from: data) {
            var migrated = decoded
            // Hats / cosmetics aren't shipping yet — strip any equipped
            // accessories so the owl_base appears bare for everyone.
            migrated.equippedHat = nil
            self.pet = migrated
        } else {
            self.pet = Pet()
        }

        // Routine
        if let data = defaults.data(forKey: Key.routineData),
           let decoded = try? JSONDecoder().decode(Routine.self, from: data) {
            self.routine = decoded
        } else {
            // Pull defaults from the library by id; if any id is ever
            // renamed in the library, fall back to whatever's available
            // rather than crashing on launch.
            let defaultIds = ["no_phone", "breathing", "journal"]
            let defaultHabits = defaultIds.compactMap { id in
                RoutineHabit.library.first { $0.id == id }
            }
            self.routine = Routine(
                habits: defaultHabits.isEmpty
                    ? Array(RoutineHabit.library.prefix(3))
                    : defaultHabits
            )
        }

        // Entries
        if let data = defaults.data(forKey: Key.entriesData),
           let decoded = try? JSONDecoder().decode([SleepEntry].self, from: data) {
            self.entries = decoded
        } else {
            self.entries = []
        }

        // Targets
        let savedGoal = defaults.double(forKey: Key.goalHours)
        self.goalHours = savedGoal > 0 ? savedGoal : 8.0

        let bedHour = defaults.object(forKey: Key.targetBedHour) as? Int ?? 22
        let bedMin  = defaults.object(forKey: Key.targetBedMinute) as? Int ?? 30
        let wakeHour = defaults.object(forKey: Key.targetWakeHour) as? Int ?? 7
        let wakeMin  = defaults.object(forKey: Key.targetWakeMinute) as? Int ?? 0
        self.targetBedtime = Date.todayAt(hour: bedHour, minute: bedMin)
        self.targetWakeTime = Date.todayAt(hour: wakeHour, minute: wakeMin)

        // Sleep goal
        if let raw = defaults.string(forKey: Key.sleepGoal) {
            self.sleepGoal = SleepGoal(rawValue: raw)
        } else {
            self.sleepGoal = nil
        }

        // Weekend wake (optional)
        if let wh = defaults.object(forKey: Key.weekendWakeHour) as? Int,
           let wm = defaults.object(forKey: Key.weekendWakeMinute) as? Int {
            self.weekendWakeTime = Date.todayAt(hour: wh, minute: wm)
        } else {
            self.weekendWakeTime = nil
        }

        self.dreamStars = defaults.integer(forKey: Key.dreamStars)
        self.isSleeping = defaults.bool(forKey: Key.isSleeping)

        if let data = defaults.data(forKey: Key.profileData),
           let decoded = try? JSONDecoder().decode(OnboardingProfile.self, from: data) {
            self.profile = decoded
        } else {
            self.profile = OnboardingProfile()
        }

        backfillDerivedSleepData()
        // Reset routine completion if it's a new day
        rolloverRoutineIfNeeded()
        // Evaluate streak decay (spends freezes or breaks streak if days missed).
        StreakManager.shared.evaluateOnLaunch()
        StreakManager.shared.reconcileFreezes(forLevel: self.pet.level)
        // Maybe surface morning check-in
        evaluateMorningPrompt()

        // Wake-probe notification taps push us into the morning check-in.
        // Capture self weakly in BOTH the outer observer block and the
        // inner Task so Swift 6 strict concurrency doesn't flag the hop.
        NotificationCenter.default.addObserver(
            forName: NotificationManager.didConfirmWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleConfirmedWake()
            }
        }

        // Re-import sleep data whenever HealthKit notifies us of new samples
        // (fires when the Watch syncs, or any other sleep source writes to Health).
        NotificationCenter.default.addObserver(
            forName: HealthKitManager.sleepDataUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.importHealthKitSleep()
            }
        }
    }

    private func handleConfirmedWake() {
        guard isSleeping else { return }
        let wakeTime = wakeTappedAt ?? Date()
        // First-app-open delay starts from this moment.
        if UserDefaults.standard.object(forKey: Key.appOpenedAfterWakeAt) == nil {
            UserDefaults.standard.set(Date(), forKey: Key.appOpenedAfterWakeAt)
        }
        seedSleepModeEntry(
            wakeTime: wakeTime,
            notes: "Logged from wake notification"
        )
        WindDownDimController.shared.end()
        NotificationManager.shared.cancelWakeProbes()
        NotificationManager.shared.cancelOnsetProbes()
        isSleeping = false
        showMorningCheckIn = true
    }

    // MARK: - Computed helpers
    var lastEntry: SleepEntry? { entries.sorted(by: { $0.wakeTime > $1.wakeTime }).first }

    var recentEntries: [SleepEntry] {
        Array(entries.sorted(by: { $0.wakeTime > $1.wakeTime }).prefix(7))
    }

    var entryNeedingMorningCheckIn: SleepEntry? {
        let today = Date().dayKey
        return entries
            .filter {
                $0.dayKey == today &&
                !$0.didCompleteMorningCheckIn &&
                MorningCheckInStore.checkIn(for: $0.dayKey) == nil
            }
            .sorted(by: { $0.wakeTime > $1.wakeTime })
            .first
    }

    /// Sleep debt (last 7 days, in hours).
    var currentSleepDebt: Double {
        SleepInsights.sleepDebt(entries: entries, goalHours: goalHours, days: 7)
    }

    /// Derived personality based on sleep behavior.
    var petPersonality: Personality {
        Personality.derive(
            entries: entries,
            targetBedtime: targetBedtime,
            consistencyDays: bedtimeConsistencyDays,
            debt: currentSleepDebt
        )
    }

    var bedtimeConsistencyDays: Int {
        // Number of consecutive recent days within 30min of target bedtime
        let sorted = entries.sorted(by: { $0.wakeTime > $1.wakeTime })
        var count = 0
        for entry in sorted {
            let cal = Calendar.current
            let a = cal.dateComponents([.hour, .minute], from: entry.bedtime)
            let b = cal.dateComponents([.hour, .minute], from: targetBedtime)
            let aMin = (a.hour ?? 0) * 60 + (a.minute ?? 0)
            let bMin = (b.hour ?? 0) * 60 + (b.minute ?? 0)
            let diff = min(abs(aMin - bMin), 1440 - abs(aMin - bMin))
            if diff <= 30 { count += 1 } else { break }
        }
        return count
    }

    /// Recommended bedtime tonight based on target wake & goal.
    var recommendedBedtime: Date { targetBedtime }
    var recommendedWakeTime: Date { targetWakeTime }

    var nextEvolutionStage: Pet.EvolutionStage? {
        let stages = Pet.EvolutionStage.allCases
        guard let currentIndex = stages.firstIndex(of: pet.stage),
              currentIndex + 1 < stages.count else {
            return nil
        }
        return stages[currentIndex + 1]
    }

    var nightsUntilNextEvolution: Int {
        guard let nextEvolutionStage else { return 0 }
        return max(0, nextEvolutionStage.consistencyRequired - bedtimeConsistencyDays)
    }

    var growthProgress: Double {
        guard let nextEvolutionStage else { return 1 }
        let currentRequirement = pet.stage.consistencyRequired
        let nextRequirement = nextEvolutionStage.consistencyRequired
        let span = max(1, nextRequirement - currentRequirement)
        return Double(bedtimeConsistencyDays - currentRequirement) / Double(span)
    }

    // MARK: - Onboarding
    func completeOnboarding(name: String, goalHours: Double, bedtime: Date, wakeTime: Date) {
        var newPet = pet
        newPet.name = name.isEmpty ? "SleepOwl" : name
        self.pet = newPet
        self.goalHours = goalHours
        self.targetBedtime = bedtime
        self.targetWakeTime = wakeTime
        self.hasCompletedOnboarding = true
    }

    /// Full onboarding completion used by the new 14-screen flow.
    func completeOnboarding(
        species: PetSpecies,
        name: String,
        goal: SleepGoal,
        goalHours: Double,
        bedtime: Date,
        wakeTime: Date,
        weekendWake: Date?,
        room: PetRoom
    ) {
        var newPet = pet
        newPet.species = species
        newPet.room = room
        newPet.name = name.trimmingCharacters(in: .whitespaces).isEmpty ? species.defaultName : name
        newPet.mood = .calm
        newPet.stage = .baby
        self.pet = newPet
        self.sleepGoal = goal
        self.goalHours = goalHours
        self.targetBedtime = bedtime
        self.targetWakeTime = wakeTime
        self.weekendWakeTime = weekendWake
        self.hasCompletedOnboarding = true
    }

    /// Extended onboarding completion that also stores the personalization profile.
    func completeOnboarding(
        species: PetSpecies,
        name: String,
        goal: SleepGoal,
        goalHours: Double,
        bedtime: Date,
        wakeTime: Date,
        weekendWake: Date?,
        room: PetRoom,
        profile: OnboardingProfile
    ) {
        self.profile = profile
        completeOnboarding(
            species: species, name: name, goal: goal,
            goalHours: goalHours, bedtime: bedtime, wakeTime: wakeTime,
            weekendWake: weekendWake, room: room
        )
    }

    /// Awards Dream Stars (the lightweight nightly currency).
    func addDreamStars(_ amount: Int) {
        dreamStars = max(0, dreamStars + amount)
    }

    @discardableResult
    func spendDreamStars(_ amount: Int) -> Bool {
        guard dreamStars >= amount else { return false }
        dreamStars -= amount
        return true
    }

    func unlock(_ item: UnlockableItem) {
        var p = pet
        p.unlockedItems.insert(item.id)
        self.pet = p
    }

    /// Awards each nightly quest step only once per day, so dream stars stay legible.
    func awardDreamStarsForQuestStep(_ habit: RoutineHabit, amount: Int) {
        rolloverQuestRewardsIfNeeded()
        var rewarded = Set(UserDefaults.standard.stringArray(forKey: Key.questRewardedSteps) ?? [])
        guard !rewarded.contains(habit.id) else { return }
        rewarded.insert(habit.id)
        UserDefaults.standard.set(Array(rewarded), forKey: Key.questRewardedSteps)
        addDreamStars(amount)
    }

    // MARK: - Logging
    @discardableResult
    func logSleep(
        bedtime: Date,
        wakeTime: Date,
        quality: SleepEntry.Quality,
        mood: SleepEntry.Mood,
        notes: String,
        routineCompleted: Bool
    ) -> SleepEntry {
            var entry = SleepEntry(
                bedtime: bedtime,
                wakeTime: wakeTime,
                quality: quality,
                mood: mood,
                notes: notes,
                routineCompleted: routineCompleted,
                isEstimated: false,
                timeInBed: max(0, wakeTime.timeIntervalSince(bedtime)),
                source: .userAdjusted
            )

        SleepScoringManager.update(
            entry: &entry,
            goalHours: goalHours,
            targetBedtime: targetBedtime,
            consistencyDays: bedtimeConsistencyDays,
            checkIn: MorningCheckInStore.checkIn(for: entry.dayKey),
            age: profile.age
        )

        // Replace any entry from same day, otherwise append
        let previousEnergy: Int
        if let idx = entries.firstIndex(where: { $0.dayKey == entry.dayKey }) {
            previousEnergy = entries[idx].energyEarned
            entries[idx] = entry
        } else {
            previousEnergy = 0
            entries.append(entry)
        }

        applyReward(energy: max(0, entry.energyEarned - previousEnergy), score: entry.score)
        StreakManager.shared.registerSleepLogged(on: entry.wakeTime, durationHours: entry.hours)
        UserDefaults.standard.set(entry.dayKey, forKey: Key.lastMorningPrompt)
        showMorningCheckIn = false
        return entry
    }

    // MARK: - Pet rewards
    private func applyReward(energy: Int, score: Int) {
        var p = pet
        p.dreamEnergy += max(0, energy)
        p.lastSleepScore = score
        p.mood = Pet.Mood.from(score: score)

        // Advance hidden growth inventory.
        var leveledTo: Int? = nil
        while p.dreamEnergy >= p.energyForNextLevel {
            p.dreamEnergy -= p.energyForNextLevel
            p.level += 1
            leveledTo = p.level
        }

        // Auto-add newly unlocked items to inventory
        for item in UnlockableItem.catalog where item.requiredLevel <= p.level {
            p.unlockedItems.insert(item.id)
        }

        // Recompute evolution stage based on consistency days, capped at `young`
        // for free users (Adult / Dream / Legendary are Pro-only) and never regressing.
        var nextStage = Pet.stage(forConsistencyDays: bedtimeConsistencyDays)
        let order = Pet.EvolutionStage.allCases
        if !SubscriptionManager.shared.isPro {
            let cap: Pet.EvolutionStage = .young
            if let nextIdx = order.firstIndex(of: nextStage),
               let capIdx = order.firstIndex(of: cap),
               nextIdx > capIdx {
                nextStage = cap
            }
        }
        if let nextIdx = order.firstIndex(of: nextStage),
           let curIdx = order.firstIndex(of: p.stage),
           nextIdx > curIdx {
            p.stage = nextStage
        }

        self.pet = p
        self.lastEarnedEnergy = energy > 0 ? energy : nil
        self.lastLevelUp = leveledTo
        if leveledTo != nil {
            StreakManager.shared.reconcileFreezes(forLevel: p.level)
        }
    }

    func addRoutineEnergy(_ amount: Int = 5) {
        var p = pet
        p.dreamEnergy += amount
        var leveledTo: Int? = nil
        while p.dreamEnergy >= p.energyForNextLevel {
            p.dreamEnergy -= p.energyForNextLevel
            p.level += 1
            leveledTo = p.level
        }
        for item in UnlockableItem.catalog where item.requiredLevel <= p.level {
            p.unlockedItems.insert(item.id)
        }
        self.pet = p
        self.lastEarnedEnergy = amount
        self.lastLevelUp = leveledTo
    }

    func clearRewardBanner() {
        lastEarnedEnergy = nil
        lastLevelUp = nil
    }

    // MARK: - Routine
    func toggleHabitCompletion(_ habit: RoutineHabit) {
        rolloverRoutineIfNeeded()
        var r = routine
        if r.completedToday.contains(habit.id) {
            r.completedToday.remove(habit.id)
        } else {
            r.completedToday.insert(habit.id)
            addRoutineEnergy(2)
        }
        r.lastCompletedDay = Date().dayKey
        self.routine = r
    }

    func setHabits(_ habits: [RoutineHabit]) {
        var r = routine
        // Free users are capped to 4 habits per night; Pro users are unlimited.
        let capped = SubscriptionManager.shared.isPro ? habits : Array(habits.prefix(4))
        r.habits = capped
        r.completedToday = r.completedToday.intersection(Set(capped.map { $0.id }))
        self.routine = r
    }

    /// Maximum habits the current user is allowed to have in their nightly routine.
    var maxHabits: Int {
        SubscriptionManager.shared.isPro ? Int.max : 4
    }

    private func rolloverRoutineIfNeeded() {
        let today = Date().dayKey
        if routine.lastCompletedDay != today {
            var r = routine
            r.completedToday.removeAll()
            r.lastCompletedDay = today
            self.routine = r
        }
    }

    private func rolloverQuestRewardsIfNeeded() {
        let today = Date().dayKey
        if UserDefaults.standard.string(forKey: Key.questRewardDay) != today {
            UserDefaults.standard.set(today, forKey: Key.questRewardDay)
            UserDefaults.standard.set([String](), forKey: Key.questRewardedSteps)
        }
    }

    // MARK: - Equipping
    func equip(_ item: UnlockableItem) {
        guard pet.unlockedItems.contains(item.id) else { return }
        var p = pet
        switch item.kind {
        case .hat:        p.equippedHat = item.id
        case .color:      p.equippedColor = item.id
        case .background: p.equippedBackground = item.id
        case .animation:  break
        }
        self.pet = p
    }

    func unequipHat() {
        var p = pet
        p.equippedHat = nil
        self.pet = p
    }

    // MARK: - Morning prompt
    private func evaluateMorningPrompt() {
        let lastPrompted = UserDefaults.standard.string(forKey: Key.lastMorningPrompt)
        let today = Date().dayKey
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 4 && hour < 12 && lastPrompted != today && entryNeedingMorningCheckIn != nil {
            showMorningCheckIn = true
        }
    }

    func dismissMorningCheckIn() {
        UserDefaults.standard.set(Date().dayKey, forKey: Key.lastMorningPrompt)
        showMorningCheckIn = false
        isSleeping = false
    }

    /// Enter sleep mode. The app locks itself until morning, and the pet sleeps.
    func enterSleepMode(startedAt: Date = Date()) {
        UserDefaults.standard.set(startedAt, forKey: Key.sleepStartedAt)
        isSleeping = true
        var p = pet
        p.mood = .sleepy
        self.pet = p
        // Clear stale wake-up timestamps from any prior night.
        UserDefaults.standard.removeObject(forKey: Key.wakeTappedAt)
        UserDefaults.standard.removeObject(forKey: Key.appOpenedAfterWakeAt)
        // Schedule the "are you awake?" probes for tomorrow's wake target.
        NotificationManager.shared.scheduleWakeProbes(
            wakeTime: nextWakeProbeAnchor,
            petName: pet.name
        )
        // Schedule onset probes ("still awake?") at +15/30/45 min — taps
        // narrow the lower bound on real sleep onset for tonight's entry.
        UserDefaults.standard.removeObject(forKey: "mooni.lastStillAwakeAt")
        NotificationManager.shared.scheduleOnsetProbes(
            sleepStart: startedAt,
            petName: pet.name
        )
    }

    /// The next anchor date used to schedule "are you awake?" probes.
    /// Always strictly in the future (rolls forward to tomorrow if the
    /// target wake time has already passed today).
    var nextWakeProbeAnchor: Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: targetWakeTime)
        let now = Date()
        var anchor = cal.date(bySettingHour: comps.hour ?? 7,
                              minute: comps.minute ?? 0,
                              second: 0,
                              of: now) ?? now
        if anchor <= now.addingTimeInterval(15 * 60) {
            anchor = cal.date(byAdding: .day, value: 1, to: anchor) ?? anchor
        }
        return anchor
    }

    /// Time the user tapped "I'm awake" (notification or sleep-lock screen).
    var wakeTappedAt: Date? {
        UserDefaults.standard.object(forKey: Key.wakeTappedAt) as? Date
    }

    /// Time the user first opened the morning check-in after waking.
    var appOpenedAfterWakeAt: Date? {
        UserDefaults.standard.object(forKey: Key.appOpenedAfterWakeAt) as? Date
    }

    /// Recovers from the "forgot to tap I'm awake" failure mode. If the user
    /// entered sleep mode but never confirmed waking, and we're now well past
    /// their target wake time (or have slept beyond goal + 1h), end sleep
    /// mode automatically so the home screen isn't stuck behind the overlay.
    /// Called on app launch / foreground.
    func autoEndStaleSleepIfNeeded() {
        guard isSleeping else { return }
        let now = Date()
        // Past target wake by at least 30 min?
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: targetWakeTime)
        let todayWake = cal.date(bySettingHour: comps.hour ?? 7,
                                 minute: comps.minute ?? 0,
                                 second: 0,
                                 of: now) ?? now
        let pastWake = now.timeIntervalSince(todayWake) >= 30 * 60

        // Or: slept longer than (goal + 1h) since we recorded sleep start?
        var pastDuration = false
        if let started = sleepStartedAt {
            let cap = (goalHours + 1.0) * 3600
            pastDuration = now.timeIntervalSince(started) >= cap
        }

        guard pastWake || pastDuration else { return }
        wakeUpFromSleepMode()
    }

    /// Wake-up tap from the sleep-lock screen. Surfaces the morning check-in.
    func wakeUpFromSleepMode() {
        let now = Date()
        UserDefaults.standard.set(now, forKey: Key.wakeTappedAt)
        // First app-open after wake = wake-tap time itself.
        UserDefaults.standard.set(now, forKey: Key.appOpenedAfterWakeAt)
        seedSleepModeEntry(
            wakeTime: now,
            notes: "Logged from sleep mode"
        )
        WindDownDimController.shared.end()
        NotificationManager.shared.cancelWakeProbes()
        NotificationManager.shared.cancelOnsetProbes()
        isSleeping = false
        showMorningCheckIn = true
    }

    private func seedSleepModeEntry(wakeTime: Date, notes: String) {
        // Create a SleepEntry from the captured sleep window so morning
        // check-in has something to refine. The check-in step can shift
        // bedtime by "minutes to fall asleep" and wakeTime by wake/open delay.
        guard let started = sleepStartedAt,
              !entries.contains(where: { $0.dayKey == wakeTime.dayKey }) else {
            return
        }

        // If the user tapped "still awake" on an onset probe, we have a
        // hard lower bound on real sleep onset: they were demonstrably
        // awake at that moment. Add a typical 8-min buffer (mean onset
        // latency from awake state) and use it as the bedtime estimate.
        // This narrows the window without needing the morning question.
        let stillAwakeAt = UserDefaults.standard.object(forKey: "mooni.lastStillAwakeAt") as? Date
        let estimatedBedtime: Date = {
            guard let lastAwake = stillAwakeAt else { return started }
            let candidate = lastAwake.addingTimeInterval(8 * 60)
            // Don't push past the wake time or earlier than the original start.
            return min(max(candidate, started), wakeTime.addingTimeInterval(-30 * 60))
        }()

        var entry = SleepEntry(
            bedtime: estimatedBedtime,
            wakeTime: wakeTime,
            quality: .good,
            mood: .okay,
            notes: notes,
            routineCompleted: !routine.completedToday.isEmpty,
            isEstimated: false,
            timeInBed: max(0, wakeTime.timeIntervalSince(started)),
            source: .userAdjusted
        )
        SleepScoringManager.update(
            entry: &entry,
            goalHours: goalHours,
            targetBedtime: targetBedtime,
            consistencyDays: bedtimeConsistencyDays,
            checkIn: nil,
            age: profile.age
        )
        entries.append(entry)
    }

    func checkIn(for entry: SleepEntry) -> MorningCheckIn? {
        MorningCheckInStore.checkIn(for: entry.dayKey)
    }

    @discardableResult
    func completeMorningCheckIn(_ checkIn: MorningCheckIn) -> SleepEntry? {
        MorningCheckInStore.save(checkIn)
        let dayKey = checkIn.date.dayKey
        guard let idx = entries.firstIndex(where: { $0.dayKey == dayKey }) else {
            UserDefaults.standard.set(dayKey, forKey: Key.lastMorningPrompt)
            showMorningCheckIn = false
            return nil
        }

        var entry = entries[idx]
        let previousEnergy = entry.energyEarned

        // User-corrected times win outright — they just told us the
        // auto-detected window was wrong. Mark the entry as user-adjusted
        // so the UI shows it.
        if let bed = checkIn.correctedBedtime, let wake = checkIn.correctedWakeTime, wake > bed {
            entry.bedtime = bed
            entry.wakeTime = wake
            entry.source = .userAdjusted
            entry.isEstimated = false
        } else {
            // Refine bedtime / wake based on the user's self-reported timing:
            //   real bedtime    = sleepStartedAt + "minutes to fall asleep"
            //   real wake time  = wake-tap time − "minutes from waking to opening app"
            // Both bound to keep duration sane.
            if let asleepMins = checkIn.minutesToFallAsleep, asleepMins > 0 {
                let shifted = entry.bedtime.addingTimeInterval(TimeInterval(asleepMins) * 60)
                if shifted < entry.wakeTime { entry.bedtime = shifted }
            }
            if let openDelay = checkIn.minutesFromWakeToAppOpen, openDelay > 0 {
                let shifted = entry.wakeTime.addingTimeInterval(-TimeInterval(openDelay) * 60)
                if shifted > entry.bedtime { entry.wakeTime = shifted }
            }
        }
        entry.timeInBed = max(0, entry.wakeTime.timeIntervalSince(entry.bedtime))
        entry.totalSleep = entry.timeInBed
        entry.didCompleteMorningCheckIn = true

        SleepScoringManager.update(
            entry: &entry,
            goalHours: goalHours,
            targetBedtime: targetBedtime,
            consistencyDays: bedtimeConsistencyDays,
            checkIn: checkIn,
            age: profile.age
        )
        entries[idx] = entry
        applyReward(energy: max(0, entry.energyEarned - previousEnergy), score: entry.score)
        UserDefaults.standard.set(dayKey, forKey: Key.lastMorningPrompt)
        showMorningCheckIn = false
        WidgetSnapshotPublisher.publish(entry)
        return entry
    }

    // MARK: - Passive sleep detection

    /// Last-resort fallback: if no sleep entry exists for last night AND the
    /// app is opening during morning hours, seed an estimated entry from the
    /// user's target schedule. Marks it as an activity-estimate so HealthKit
    /// data can still replace it later. Never overwrites existing entries.
    func autoSeedLastNightIfMissing() {
        let now = Date()
        let cal = Calendar.current
        let hour = cal.component(.hour, from: now)
        // Only attempt during morning open (4 AM – 2 PM local time).
        guard hour >= 4 && hour < 14 else { return }

        let todayKey = now.dayKey
        guard !entries.contains(where: { $0.dayKey == todayKey }) else { return }

        // Build an estimated bed/wake from the user's target times.
        let bedComps  = cal.dateComponents([.hour, .minute], from: targetBedtime)
        let wakeComps = cal.dateComponents([.hour, .minute], from: targetWakeTime)
        guard let bH = bedComps.hour, let bM = bedComps.minute,
              let wH = wakeComps.hour, let wM = wakeComps.minute else { return }

        var estimatedBed = cal.date(bySettingHour: bH, minute: bM, second: 0, of: now) ?? now
        if estimatedBed > now {
            estimatedBed = cal.date(byAdding: .day, value: -1, to: estimatedBed) ?? estimatedBed
        }
        var estimatedWake = cal.date(bySettingHour: wH, minute: wM, second: 0, of: now) ?? now
        if estimatedWake <= estimatedBed {
            estimatedWake = cal.date(byAdding: .day, value: 1, to: estimatedWake) ?? estimatedWake
        }

        let duration = estimatedWake.timeIntervalSince(estimatedBed)
        // Sanity: 2 h – 14 h and wake must already be in the past.
        guard duration >= 2 * 3600, duration <= 14 * 3600,
              estimatedWake <= now.addingTimeInterval(2 * 3600) else { return }

        insertImportedIntervals(
            [SleepInterval(start: estimatedBed, end: estimatedWake)],
            source: .appActivityEstimate,
            sourceLabel: "Auto-estimated from your schedule"
        )
    }

    // MARK: - HealthKit import

    /// Pulls recent sleep samples from HealthKit. Falls back to activity-based
    /// estimation when HealthKit is unavailable, denied, or simply empty.
    func importHealthKitSleep() async {
        let healthIntervals = await HealthKitManager.shared.fetchNightlySleep(days: 14)
        if !healthIntervals.isEmpty {
            insertImportedIntervals(
                healthIntervals,
                source: .healthKit,
                sourceLabel: "Imported from Health"
            )
            return
        }

        let estimated = ActivitySleepEstimator.shared.recentIntervals(days: 14)
        guard !estimated.isEmpty else { return }
        insertImportedIntervals(
            estimated,
            source: .appActivityEstimate,
            sourceLabel: "Auto logged from app activity"
        )
    }

    private func insertImportedIntervals(
        _ intervals: [SleepInterval],
        source: SleepDataSource,
        sourceLabel: String
    ) {
        for interval in intervals {
            let dayKey = interval.end.dayKey
            var previousEnergy = 0

            // If we already have an entry for this wake-day, only replace it
            // when real HealthKit data trumps an existing estimate.
            if let idx = entries.firstIndex(where: { $0.dayKey == dayKey }) {
                let existing = entries[idx]
                if existing.resolvedSource == .userAdjusted {
                    continue
                }
                if existing.resolvedSource == .appActivityEstimate && source == .healthKit {
                    previousEnergy = existing.energyEarned
                    entries.remove(at: idx)
                } else {
                    continue
                }
            }

            var entry = SleepEntry(
                bedtime: interval.start,
                wakeTime: interval.end,
                quality: .good,
                mood: .okay,
                notes: sourceLabel,
                isEstimated: source == .appActivityEstimate,
                totalSleep: interval.totalSleep,
                timeInBed: interval.timeInBed ?? (source == .appActivityEstimate ? interval.duration : nil),
                stages: interval.stages,
                source: source
            )
            SleepScoringManager.update(
                entry: &entry,
                goalHours: goalHours,
                targetBedtime: targetBedtime,
                consistencyDays: bedtimeConsistencyDays,
                checkIn: MorningCheckInStore.checkIn(for: dayKey),
                age: profile.age
            )
            entries.append(entry)
            StreakManager.shared.registerSleepLogged(on: entry.wakeTime, durationHours: entry.hours)

            if dayKey == Date().dayKey {
                applyReward(energy: max(0, entry.energyEarned - previousEnergy), score: entry.score)
                evaluateMorningPrompt()
            }
        }
    }

    private func backfillDerivedSleepData() {
        guard !entries.isEmpty else { return }

        for idx in entries.indices {
            guard entries[idx].stages == nil ||
                  entries[idx].readinessScore == nil ||
                  entries[idx].energyLevel == nil ||
                  entries[idx].insight == nil else {
                continue
            }

            var entry = entries[idx]
            SleepScoringManager.update(
                entry: &entry,
                goalHours: goalHours,
                targetBedtime: targetBedtime,
                consistencyDays: bedtimeConsistencyDays,
                checkIn: MorningCheckInStore.checkIn(for: entry.dayKey),
                age: profile.age
            )
            entries[idx] = entry
        }
    }

    // MARK: - Persistence
    private func persistPet() {
        if let data = try? JSONEncoder().encode(pet) {
            UserDefaults.standard.set(data, forKey: Key.petData)
        }
    }
    private func persistRoutine() {
        if let data = try? JSONEncoder().encode(routine) {
            UserDefaults.standard.set(data, forKey: Key.routineData)
        }
    }
    private func persistEntries() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: Key.entriesData)
        }
    }
    private func persistProfile() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: Key.profileData)
        }
        Task { await ProfileSync.shared.upsertProfile(profile) }
    }

    /// Wipes every key this app writes to UserDefaults plus in-memory state.
    /// Backs the in-app "Delete account & data" action required by App Store
    /// Review Guideline 5.1.1(v) for apps that support account creation.
    func eraseAllUserData() {
        let defaults = UserDefaults.standard
        let knownKeys: [String] = [
            Key.onboarded, Key.petData, Key.routineData, Key.entriesData,
            Key.goalHours, Key.targetBedHour, Key.targetBedMinute,
            Key.targetWakeHour, Key.targetWakeMinute, Key.lastMorningPrompt,
            Key.sleepGoal, Key.weekendWakeHour, Key.weekendWakeMinute,
            Key.dreamStars, Key.profileData, Key.questRewardDay,
            Key.questRewardedSteps, Key.isSleeping, Key.sleepStartedAt,
            Key.wakeTappedAt, Key.appOpenedAfterWakeAt,
            Key.lastSystemTaskShown, Key.lastSystemTaskIndex,
            // Auxiliary state owned by other services
            "mooni.health.didConnect", "mooni.lastStillAwakeAt",
            "mooni.estimator.lastBackground", "mooni.estimator.lastWakeDay",
            "mooni.estimator.intervals"
        ]
        for key in knownKeys { defaults.removeObject(forKey: key) }
        StreakManager.shared.resetAll()
        defaults.synchronize()

        // Reset in-memory state so the UI immediately reflects the wipe.
        entries = []
        pet = Pet()
        routine = Routine(habits: Array(RoutineHabit.library.prefix(3)))
        profile = OnboardingProfile()
        dreamStars = 0
        isSleeping = false
        sleepGoal = nil
        hasCompletedOnboarding = false
    }
}

// MARK: - Preview helper
extension AppState {
    static var preview: AppState {
        let s = AppState()
        s.hasCompletedOnboarding = true
        var p = s.pet
        p.name = "SleepOwl"
        p.level = 4
        p.dreamEnergy = 240
        p.lastSleepScore = 84
        p.mood = .good
        p.unlockedItems = ["default_color", "color_lavender", "hat_nightcap", "bg_starfield"]
        s.pet = p
        return s
    }
}

#if DEBUG
extension AppState {
    @discardableResult
    func simulateCompletedNightEndingNow() -> SleepEntry {
        let wakeTime = Date()
        let testHours = min(max(goalHours, 2), 10)
        let bedtime = wakeTime.addingTimeInterval(-testHours * 3600)

        return logSleep(
            bedtime: bedtime,
            wakeTime: wakeTime,
            quality: .good,
            mood: .energized,
            notes: "Developer test: simulated night",
            routineCompleted: !routine.completedToday.isEmpty
        )
    }
}
#endif
