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
        static let trackingStartedAt = "mooni.trackingStartedAt"
        static let lastSeenDayKey = "mooni.lastSeenDayKey"
        static let lastBrainRunAt = "mooni.lastBrainRunAt"
        // Win-back discount paywall (shown once, days after the user declines
        // the onboarding paywall, once they've used the app a bit).
        static let firstPaywallDeclinedAt = "mooni.firstPaywallDeclinedAt"
        static let discountPaywallShown = "mooni.discountPaywallShown"
        static let discountPaywallTargetNights = "mooni.discountPaywallTargetNights"
        // Home-screen re-ask for Motion & Fitness when it was declined — last
        // time we surfaced the nudge, so it resurfaces a few days in but never
        // nags day after day.
        static let motionReaskLastShownAt = "mooni.motionReaskLastShownAt"
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
            // Coalesce widget reloads. The didSet fires on EVERY mutation, and
            // backfill / HealthKit-import loops append entries one at a time —
            // firing a WidgetCenter reload per element caused a reload storm.
            // Debounce so a batch collapses into a single refresh, while a
            // lone mutation still reloads ~promptly.
            scheduleWidgetSync()
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

    /// True while the maintenance pass is actively fusing last night's
    /// signals (HealthKit import + sleep brain). The home screen shows a
    /// "reading your night" state instead of stale or empty data, so a user
    /// who opens the app mid-calculation always knows something is happening.
    @Published var isResolvingNight: Bool = false

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

    /// The moment onboarding completed. The brain never fabricates, backfills
    /// or auto-detects a night that ended before tracking actually began —
    /// this is what keeps a brand-new user from seeing a made-up "last night".
    var trackingStartedAt: Date? {
        UserDefaults.standard.object(forKey: Key.trackingStartedAt) as? Date
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
            } else {
                // Turning off the separate weekend wake must actually forget
                // the persisted value — otherwise init() reads the stale
                // hour/minute back on the next launch and it silently returns.
                UserDefaults.standard.removeObject(forKey: Key.weekendWakeHour)
                UserDefaults.standard.removeObject(forKey: Key.weekendWakeMinute)
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

    /// Combine subscriptions kept alive for the lifetime of AppState.
    /// Currently used to watch SubscriptionManager.isPro so newly-Pro users
    /// get auto-tracking enabled immediately, not on next launch.
    private var cancellables = Set<AnyCancellable>()

    /// Debounce handle for coalescing widget reloads triggered by `entries`
    /// mutations (see `scheduleWidgetSync`). Cancelled and replaced on each
    /// mutation so a batch of appends collapses into a single refresh.
    private var widgetSyncTask: Task<Void, Never>?

    // MARK: - Init
    init() {
        let defaults = UserDefaults.standard
        // Treat the user as onboarded if the flag is set OR they clearly have
        // prior data (saved pet, sleep schedule, or logged nights). This stops
        // a cold launch — e.g. tapping a wake-probe notification after iOS has
        // terminated the app overnight — from throwing a returning user back
        // into onboarding if the flag was ever lost. A fresh install has none
        // of these, so new users still see onboarding. (Onboarding commits the
        // pet + schedule only at completion, so this never misfires mid-flow.)
        let onboardedFlag = defaults.bool(forKey: Key.onboarded)
        let hasPriorData = defaults.data(forKey: Key.petData) != nil
            || defaults.data(forKey: Key.entriesData) != nil
            || defaults.object(forKey: Key.targetBedHour) != nil
        self.hasCompletedOnboarding = onboardedFlag || hasPriorData
        if hasPriorData && !onboardedFlag {
            // Self-heal the persisted flag (didSet doesn't fire during init).
            defaults.set(true, forKey: Key.onboarded)
        }

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

        // Migration: installs that predate trackingStartedAt get anchored to
        // their earliest real data (or now). Backfill keeps working for them
        // without ever inventing pre-install nights.
        if self.hasCompletedOnboarding,
           defaults.object(forKey: Key.trackingStartedAt) == nil {
            let anchor = self.entries.map(\.bedtime).min() ?? Date()
            defaults.set(anchor, forKey: Key.trackingStartedAt)
        }

        backfillDerivedSleepData()
        // Reset routine completion if it's a new day
        rolloverRoutineIfNeeded()
        // Evaluate streak decay (spends freezes or breaks streak if days missed).
        StreakManager.shared.evaluateOnLaunch()
        StreakManager.shared.reconcileFreezes(forLevel: self.pet.level)
        // Maybe surface morning check-in immediately…
        evaluateMorningPrompt()
        // …then run the full safety-net maintenance pass on launch.
        Task { [weak self] in
            await self?.runAutomationMaintenance(reason: "app launch")
        }

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
                // SAFETY NET (mechanism 9): new Health/Watch data arrived
                // (possibly while backgrounded) — run the full pass so the
                // entry is imported AND the check-in surfaces at any hour.
                await self?.runAutomationMaintenance(reason: "HealthKit observer")
            }
        }

        // When the user upgrades to Pro mid-session, kick off the automation
        // pass immediately so auto-tracking starts working without requiring
        // an app restart. Skip the initial value (drop the first emission)
        // so we don't double-run on launch.
        SubscriptionManager.shared.$isPro
            .removeDuplicates()
            .dropFirst()
            .filter { $0 }
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.runAutomationMaintenance(reason: "subscription upgraded")
                }
            }
            .store(in: &cancellables)
    }

    private func handleConfirmedWake() {
        let wakeTime = wakeTappedAt ?? Date()
        // First-app-open delay starts from this moment.
        if UserDefaults.standard.object(forKey: Key.appOpenedAfterWakeAt) == nil {
            UserDefaults.standard.set(Date(), forKey: Key.appOpenedAfterWakeAt)
        }

        if isSleeping {
            // Normal path: user was in sleep mode, seed from the captured
            // sleep window so the check-in can refine it.
            seedSleepModeEntry(wakeTime: wakeTime, notes: "Logged from wake notification")
            WindDownDimController.shared.end()
            NotificationManager.shared.cancelWakeProbes()
            NotificationManager.shared.cancelOnsetProbes()
            isSleeping = false
        } else {
            // SAFETY NET (mechanism 2 companion): the user tapped a daily
            // safety-net probe but never entered sleep mode (the exact
            // "didn't touch the app" failure). Let the sleep brain resolve
            // the night from real signals first; only fall back to a
            // schedule-shaped editable entry when it can't.
            SleepAutomationLog.shared.log("Wake confirmed via safety-net probe (was not in sleep mode)")
            Task { @MainActor [weak self] in
                guard let self else { return }
                let resolved = await self.runSleepBrainEstimate(reason: "wake probe tap")
                if !resolved,
                   !self.entries.contains(where: { $0.dayKey == Date().dayKey }) {
                    self.seedMissedNightEntry()
                }
                self.showMorningCheckIn = true
            }
            return
        }
        showMorningCheckIn = true
    }

    // MARK: - Computed helpers
    var lastEntry: SleepEntry? { entries.sorted(by: { $0.wakeTime > $1.wakeTime }).first }

    /// Most recent night backed by real evidence — schedule backfills are
    /// excluded. Anything user-facing that presents "last night" (home hero,
    /// sleep story, share cards) must use this, so a placeholder night is
    /// never shown as if it were tracked.
    var lastRealEntry: SleepEntry? {
        entries
            .filter { !$0.isScheduleBackfill }
            .sorted(by: { $0.wakeTime > $1.wakeTime })
            .first
    }

    var recentEntries: [SleepEntry] {
        Array(entries.sorted(by: { $0.wakeTime > $1.wakeTime }).prefix(7))
    }

    var entryNeedingMorningCheckIn: SleepEntry? {
        let today = Date().dayKey
        return entries
            .filter {
                $0.dayKey == today &&
                !$0.didCompleteMorningCheckIn &&
                // Schedule backfills are placeholders, not tracked nights —
                // never ambush the user with a check-in for a night the app
                // only invented from their target times.
                !$0.isScheduleBackfill &&
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
        UserDefaults.standard.set(Date(), forKey: Key.trackingStartedAt)
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
        UserDefaults.standard.set(Date(), forKey: Key.trackingStartedAt)
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

    // MARK: - Win-back discount paywall

    /// Records that the user dismissed the FIRST (onboarding) paywall without
    /// buying. This anchors the delayed win-back discount offer. No-op if the
    /// user is already Pro or a decline was already recorded — we only track
    /// the first decline.
    func recordFirstPaywallDeclined() {
        guard !SubscriptionManager.shared.isPro else { return }
        let d = UserDefaults.standard
        guard d.object(forKey: Key.firstPaywallDeclinedAt) == nil else { return }
        d.set(Date(), forKey: Key.firstPaywallDeclinedAt)
        // Pick a random number of real nights the user must log before the
        // win-back offer surfaces, so it appears at a non-deterministic point
        // rather than always after the same fixed action.
        d.set(Int.random(in: 2...4), forKey: Key.discountPaywallTargetNights)
    }

    /// Whether the delayed win-back discount paywall should be presented now.
    /// True only when ALL hold: not Pro, the onboarding paywall was declined,
    /// the offer hasn't already been shown, the user has used the app a bit
    /// (≥1 day since the decline AND has logged at least the randomly-chosen
    /// number of real nights), and a coin-flip passes so the exact moment of
    /// appearance feels organic rather than mechanical. Checked on every
    /// launch/foreground, so it reliably surfaces within a few app opens once
    /// eligible. The caller is responsible for confirming a genuine discount
    /// package exists before presenting — we never show a fake "special offer".
    func shouldPresentDiscountPaywall() -> Bool {
        guard !SubscriptionManager.shared.isPro else { return false }
        let d = UserDefaults.standard
        guard !d.bool(forKey: Key.discountPaywallShown) else { return false }
        guard let declinedAt = d.object(forKey: Key.firstPaywallDeclinedAt) as? Date else { return false }

        let daysSince = Date().timeIntervalSince(declinedAt) / 86_400
        guard daysSince >= 1 else { return false }

        let target = max(1, d.integer(forKey: Key.discountPaywallTargetNights))
        let realNights = entries.filter { !$0.isScheduleBackfill }.count
        guard realNights >= target else { return false }

        return Int.random(in: 0..<2) == 0
    }

    /// Marks the win-back offer as shown so it is presented at most once.
    func markDiscountPaywallShown() {
        UserDefaults.standard.set(true, forKey: Key.discountPaywallShown)
    }

    /// Whether to surface the home-screen "make tracking more accurate" nudge
    /// that re-asks for Motion & Fitness. The caller passes the current
    /// permission state (CoreMotion lives in `MotionSleepAnalyzer`); this owns
    /// only the timing so the ask waits until the user has lived in the app a
    /// few days, and backs off for a week after each appearance so it never
    /// nags. Pro-gated like all auto-tracking.
    func shouldOfferMotionReask(canReask: Bool, now: Date = Date()) -> Bool {
        guard canReask, SubscriptionManager.shared.isPro else { return false }
        // Give the user some real time in the app before re-asking.
        guard let started = trackingStartedAt,
              now.timeIntervalSince(started) >= 3 * 86_400 else { return false }
        // Back off for a week after the last time the nudge was surfaced.
        if let last = UserDefaults.standard.object(forKey: Key.motionReaskLastShownAt) as? Date,
           now.timeIntervalSince(last) < 7 * 86_400 {
            return false
        }
        return true
    }

    /// Records that the motion re-ask was just surfaced (or dismissed), so the
    /// week-long cooldown in `shouldOfferMotionReask` starts now.
    func markMotionReaskShown() {
        UserDefaults.standard.set(Date(), forKey: Key.motionReaskLastShownAt)
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
    /// SAFETY NET (mechanism 3). The morning check-in used to be hard-gated to
    /// 04:00–12:00 — open the app at midday and it silently did nothing, with
    /// no way to log the night. That gate is removed: ANY time there is a
    /// night without a completed check-in, we surface it. The once-per-day
    /// guard (`lastMorningPrompt`) still prevents nagging after the user has
    /// already been shown / dismissed it today.
    func evaluateMorningPrompt() {
        let lastPrompted = UserDefaults.standard.string(forKey: Key.lastMorningPrompt)
        let today = Date().dayKey
        guard lastPrompted != today, entryNeedingMorningCheckIn != nil else { return }
        showMorningCheckIn = true
        SleepAutomationLog.shared.log("Surfaced morning check-in (no time gate)")
    }

    /// True when there is a logged night the user still hasn't confirmed via
    /// the morning check-in. Drives the always-available in-app "log last
    /// night" surface (mechanism 10) so the user can never be stuck unable
    /// to input their sleep.
    var hasUnconfirmedNight: Bool { entryNeedingMorningCheckIn != nil }

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

    /// Always-available escape hatch from the sleep-lock overlay. If the user
    /// armed the night by accident (including during the day), this exits
    /// sleep mode cleanly WITHOUT recording anything: no phantom SleepEntry,
    /// no morning check-in. It only clears the armed/sleeping state and
    /// cancels the pending wake/onset probes so the user is never trapped
    /// behind the overlay waiting for `canWake`.
    func cancelSleepMode() {
        isSleeping = false
        // Forget this (false) night entirely so nothing downstream treats it
        // as real sleep or a missed wake.
        UserDefaults.standard.removeObject(forKey: Key.sleepStartedAt)
        UserDefaults.standard.removeObject(forKey: Key.wakeTappedAt)
        UserDefaults.standard.removeObject(forKey: Key.appOpenedAfterWakeAt)
        UserDefaults.standard.removeObject(forKey: "mooni.lastStillAwakeAt")
        WindDownDimController.shared.end()
        NotificationManager.shared.cancelWakeProbes()
        NotificationManager.shared.cancelOnsetProbes()
        var p = pet
        p.mood = .calm
        self.pet = p
        // Explicitly do NOT seed an entry and do NOT open the morning check-in.
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

    /// Seeds a placeholder entry for a missed night (no auto-detection, no
    /// HealthKit sample) using the user's target schedule, then returns it
    /// so the morning check-in can be re-launched in edit-times mode for
    /// the user to enter the actual bed/wake times. If an entry already
    /// exists for the target wake-day, that entry is returned untouched.
    @discardableResult
    func seedMissedNightEntry(for referenceDate: Date = Date(),
                              autoBackfilled: Bool = false) -> SleepEntry? {
        let cal = Calendar.current
        let dayKey = referenceDate.dayKey
        if let existing = entries.first(where: { $0.dayKey == dayKey }) {
            return existing
        }

        let bedComps  = cal.dateComponents([.hour, .minute], from: targetBedtime)
        let wakeComps = cal.dateComponents([.hour, .minute], from: targetWakeTime)
        guard let bH = bedComps.hour, let bM = bedComps.minute,
              let wH = wakeComps.hour, let wM = wakeComps.minute else { return nil }

        var bed = cal.date(bySettingHour: bH, minute: bM, second: 0, of: referenceDate) ?? referenceDate
        if bed > referenceDate {
            bed = cal.date(byAdding: .day, value: -1, to: bed) ?? bed
        }
        var wake = cal.date(bySettingHour: wH, minute: wM, second: 0, of: referenceDate) ?? referenceDate
        if wake <= bed {
            wake = cal.date(byAdding: .day, value: 1, to: wake) ?? wake
        }

        var entry = SleepEntry(
            bedtime: bed,
            wakeTime: wake,
            quality: .good,
            mood: .okay,
            notes: autoBackfilled
                ? "No check-in — filled from your target schedule"
                : "Added by you",
            isEstimated: true,
            totalSleep: wake.timeIntervalSince(bed),
            timeInBed: wake.timeIntervalSince(bed),
            stages: nil,
            // Auto-backfilled nights are NOT user-adjusted — keep them
            // flagged as an estimate so the UI can explain why and HealthKit
            // can still replace them later if data arrives.
            source: autoBackfilled ? .appActivityEstimate : .userAdjusted,
            // Backfills are pure schedule fabrications: editable placeholders
            // that must never trigger the morning check-in or read as real.
            isScheduleBackfill: autoBackfilled
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
        return entry
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
        // The user just vouched for this night — whatever placeholder it
        // started as, it's confirmed data now.
        entry.isScheduleBackfill = false

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
        // Advance the nightly streak from the canonical bed → sleep mode →
        // wake → check-in flow. Without this the flame only moved on the
        // manual logSleep / Pro HealthKit-import paths, so the intended
        // (sleep-mode) user stayed stuck at 0. registerSleepLogged dedups
        // per wake-day, so this never double-counts with logSleep.
        StreakManager.shared.registerSleepLogged(on: entry.wakeTime, durationHours: entry.hours)
        UserDefaults.standard.set(dayKey, forKey: Key.lastMorningPrompt)
        showMorningCheckIn = false
        WidgetSnapshotPublisher.publish(entry)
        return entry
    }

    // MARK: - Passive sleep detection (the sleep brain)

    /// Tracks the last day the app was active. The first activity on a new
    /// day (≥ 4 AM) means the user is demonstrably up and using the phone —
    /// the maintenance pass that follows resolves the night and surfaces the
    /// morning flow immediately instead of waiting for a probe.
    private func noteDayRollover(now: Date = Date()) {
        let today = now.dayKey
        let previous = UserDefaults.standard.string(forKey: Key.lastSeenDayKey)
        guard previous != today else { return }
        UserDefaults.standard.set(today, forKey: Key.lastSeenDayKey)
        guard let previous,
              Calendar.current.component(.hour, from: now) >= 4 else { return }
        SleepAutomationLog.shared.log("Day rollover (\(previous) → \(today)) — resolving last night")
    }

    /// SAFETY NET (mechanism 11) — the sleep brain. Fuses screen, motion,
    /// lock-state and tap signals (`SleepSessionEngine`) into last night's
    /// entry: creates it when none exists, refines schedule backfills and raw
    /// activity estimates, and never touches HealthKit or user-confirmed
    /// nights. Pro-only, like all auto-tracking. Returns true when an entry
    /// was created or refined.
    @discardableResult
    func runSleepBrainEstimate(reason: String) async -> Bool {
        guard SubscriptionManager.shared.isPro else { return false }
        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)
        // Only resolve a night during plausible post-wake hours.
        guard hour >= 4 && hour < 16 else { return false }
        // A night can only exist if tracking began before it — this is what
        // keeps day-one users from ever seeing an invented "last night".
        guard let started = trackingStartedAt,
              now.timeIntervalSince(started) >= 4 * 3600 else { return false }

        let todayKey = now.dayKey
        let existingIdx = entries.firstIndex(where: { $0.dayKey == todayKey })
        if let idx = existingIdx {
            let existing = entries[idx]
            // Real data wins: only refine placeholders and raw estimates.
            guard existing.isScheduleBackfill
                    || existing.resolvedSource == .appActivityEstimate else { return false }
            // Throttle: signals barely change minute-to-minute. Once a
            // non-placeholder estimate exists, re-fuse at most every 30 min
            // (motion + pedometer queries aren't free).
            if !existing.isScheduleBackfill,
               let last = UserDefaults.standard.object(forKey: Key.lastBrainRunAt) as? Date,
               now.timeIntervalSince(last) < 30 * 60 {
                return false
            }
        }
        UserDefaults.standard.set(now, forKey: Key.lastBrainRunAt)

        guard let estimate = await SleepSessionEngine.shared.estimateNight(
            now: now,
            armedSleepStart: sleepStartedAt,
            stillAwakeAt: UserDefaults.standard.object(forKey: "mooni.lastStillAwakeAt") as? Date,
            wakeTappedAt: wakeTappedAt
        ), estimate.bedtime >= started else { return false }

        if let idx = existingIdx {
            var entry = entries[idx]
            // Avoid churn: a non-placeholder entry that already matches the
            // estimate within 10 minutes doesn't need rewriting.
            if !entry.isScheduleBackfill,
               abs(entry.bedtime.timeIntervalSince(estimate.bedtime)) < 10 * 60,
               abs(entry.wakeTime.timeIntervalSince(estimate.wakeTime)) < 10 * 60 {
                return false
            }
            let previousEnergy = entry.energyEarned
            entry.bedtime = estimate.bedtime
            entry.wakeTime = estimate.wakeTime
            entry.totalSleep = estimate.duration
            entry.timeInBed = estimate.duration
            entry.isEstimated = true
            entry.isScheduleBackfill = false
            entry.confidence = estimate.confidence
            entry.source = .appActivityEstimate
            entry.notes = "Auto-tracked (\(estimate.sourceSummary))"
            SleepScoringManager.update(
                entry: &entry,
                goalHours: goalHours,
                targetBedtime: targetBedtime,
                consistencyDays: bedtimeConsistencyDays,
                checkIn: MorningCheckInStore.checkIn(for: todayKey),
                age: profile.age
            )
            entries[idx] = entry
            applyReward(energy: max(0, entry.energyEarned - previousEnergy), score: entry.score)
            StreakManager.shared.registerSleepLogged(on: entry.wakeTime, durationHours: entry.hours)
            WidgetSnapshotPublisher.publish(entry)
            SleepAutomationLog.shared.log(
                "Brain refined tonight (\(reason)): \(estimate.sourceSummary), confidence \(Int(estimate.confidence * 100))%")
        } else {
            var entry = SleepEntry(
                bedtime: estimate.bedtime,
                wakeTime: estimate.wakeTime,
                quality: .good,
                mood: .okay,
                notes: "Auto-tracked (\(estimate.sourceSummary))",
                isEstimated: true,
                totalSleep: estimate.duration,
                timeInBed: estimate.duration,
                source: .appActivityEstimate,
                confidence: estimate.confidence
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
            applyReward(energy: entry.energyEarned, score: entry.score)
            StreakManager.shared.registerSleepLogged(on: entry.wakeTime, durationHours: entry.hours)
            WidgetSnapshotPublisher.publish(entry)
            SleepAutomationLog.shared.log(
                "Brain created tonight (\(reason)): \(estimate.sourceSummary), confidence \(Int(estimate.confidence * 100))%")
        }
        return true
    }

    // MARK: - Safety net automation

    /// SAFETY NET (mechanism 5). Single maintenance pass that runs on every
    /// app launch, every foreground, and from the background-refresh task.
    /// Each step is independently idempotent. This is what guarantees the
    /// app *always* makes forward progress even with zero user interaction —
    /// the failure the user hit ("opened at midday, nothing happened") is
    /// structurally impossible once every entry point calls this.
    func runAutomationMaintenance(reason: String) async {
        SleepAutomationLog.shared.log("Maintenance start — \(reason)")
        // Brain: notice when a new day has started (the activity itself is a
        // wake signal — the steps below resolve the night right away).
        noteDayRollover()
        // M1/M6/M7: ensure the full notification safety net is scheduled.
        NotificationManager.shared.reconcileSafetyNetNotifications(
            petName: pet.name, bedtime: targetBedtime, wakeTime: targetWakeTime
        )
        // Recover a stuck sleep-lock if the user forgot to tap "I'm awake".
        autoEndStaleSleepIfNeeded()
        // M9: pull HealthKit / activity data, always re-register the observer.
        // Auto-tracking (HealthKit import + background observer) is a Pro
        // feature — free users keep manual logging, sleep score, and 3-night
        // history. Gating here ensures non-Pro users don't get auto-detected
        // sleep updates without subscribing.
        if SubscriptionManager.shared.isPro {
            // Surface the "reading your night" state only when this pass
            // could plausibly produce tonight's entry — morning hours with
            // no real night resolved yet. Otherwise the flag would flash on
            // every foreground.
            let hour = Calendar.current.component(.hour, from: Date())
            let todayKey = Date().dayKey
            let mightResolve = hour >= 4 && hour < 16
                && !entries.contains { $0.dayKey == todayKey && !$0.isScheduleBackfill }
            if mightResolve { isResolvingNight = true }
            defer { isResolvingNight = false }

            await importHealthKitSleep()
            HealthKitManager.shared.startSleepObserverIfNeeded()
            // M11: the sleep brain — fuse motion / screen / lock / tap
            // signals into tonight's entry (creates or refines; never
            // invents a night from the schedule alone).
            await runSleepBrainEstimate(reason: reason)
        }
        // M4: make sure every elapsed night exists as an editable entry.
        backfillMissedNights()
        // M3: surface the morning check-in if a night is unconfirmed (any hour).
        evaluateMorningPrompt()
        SleepAutomationLog.shared.log("Maintenance done — entries=\(entries.count)")
    }

    /// SAFETY NET (mechanism 4). Fills EVERY elapsed night between the
    /// earliest known data and today with an editable estimated entry, so
    /// sleep data can never silently show "same as yesterday" again. Bounded
    /// to real history AND to `trackingStartedAt`, so it never fabricates
    /// pre-install nights — a brand-new user gets NO invented "last night"
    /// right after onboarding. Never overwrites real or user-adjusted data.
    func backfillMissedNights() {
        guard hasCompletedOnboarding else { return }
        let cal = Calendar.current
        let now = Date()

        let trackingStart = trackingStartedAt ?? now
        let earliest: Date = entries.map { $0.wakeTime }.min() ?? trackingStart
        let startDay = cal.startOfDay(for: earliest)

        let wakeComps = cal.dateComponents([.hour, .minute], from: targetWakeTime)
        guard let wH = wakeComps.hour, let wM = wakeComps.minute else { return }

        var seeded = 0
        var cursor = startDay
        while cursor <= now {
            defer { cursor = cal.date(byAdding: .day, value: 1, to: cursor) ?? now.addingTimeInterval(86_400) }
            let key = cursor.dayKey
            if entries.contains(where: { $0.dayKey == key }) { continue }
            // Only backfill a night whose wake time has fully passed — and
            // never one from before tracking began (the night must have
            // elapsed entirely on the app's watch).
            guard let wake = cal.date(bySettingHour: wH, minute: wM, second: 0, of: cursor),
                  wake <= now, wake >= trackingStart else { continue }
            if seedMissedNightEntry(for: cursor, autoBackfilled: true) != nil { seeded += 1 }
        }
        if seeded > 0 {
            SleepAutomationLog.shared.log("Backfilled \(seeded) missed night(s)")
        }
    }

    /// SAFETY NET (mechanism 2). Arms the night automatically when the phone
    /// is put down in the evening/overnight window — schedules the onset and
    /// wake probes and records an estimated sleep-start WITHOUT flipping the
    /// full screen-lock sleep mode (auto-locking the UI on every evening
    /// backgrounding would be hostile). The morning flow then has an accurate
    /// `sleepStartedAt` and the probes fire even though the user never tapped
    /// "going to bed". Called on background transitions.
    func autoArmNightIfDue(at date: Date = Date()) {
        guard hasCompletedOnboarding, !isSleeping else { return }
        // Auto-tracking (activity-based sleep detection) is a Pro feature.
        // Free users must tap "going to bed" / "I'm awake" manually.
        guard SubscriptionManager.shared.isPro else { return }
        let hour = Calendar.current.component(.hour, from: date)
        guard hour >= 19 || hour < 4 else { return }

        let alreadyArmed = sleepStartedAt.map { date.timeIntervalSince($0) < 12 * 3600 } ?? false
        if !alreadyArmed {
            let start = ActivitySleepEstimator.shared.pendingEstimatedSleepStart ?? date
            UserDefaults.standard.set(start, forKey: Key.sleepStartedAt)
            UserDefaults.standard.removeObject(forKey: Key.wakeTappedAt)
            UserDefaults.standard.removeObject(forKey: Key.appOpenedAfterWakeAt)
            UserDefaults.standard.removeObject(forKey: "mooni.lastStillAwakeAt")
            SleepAutomationLog.shared.log("Auto-armed night at \(start.hourMinuteString) (no tap)")
        }
        let anchor = sleepStartedAt ?? date
        NotificationManager.shared.scheduleOnsetProbes(sleepStart: anchor, petName: pet.name)
        NotificationManager.shared.scheduleWakeProbes(wakeTime: nextWakeProbeAnchor, petName: pet.name)
    }

    // MARK: - HealthKit import

    /// Pulls recent sleep samples from HealthKit. Falls back to activity-based
    /// estimation when HealthKit is unavailable, denied, or simply empty.
    ///
    /// Auto-tracking (both HealthKit import and activity-based estimation) is
    /// a Pro feature. Free users log nights manually — this no-ops for them.
    func importHealthKitSleep() async {
        let isPro = await MainActor.run { SubscriptionManager.shared.isPro }
        guard isPro else { return }

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

    /// Debounced widget refresh. Coalesces the bursts of `entries` mutations
    /// from backfill / import loops into a single WidgetCenter reload instead
    /// of one per element. A short delay keeps a single user-driven log
    /// responsive while collapsing batches.
    private func scheduleWidgetSync() {
        widgetSyncTask?.cancel()
        widgetSyncTask = Task { [weak self] in
            // ~0.4s window: long enough to swallow a tight append loop, short
            // enough that a normal single log still updates the widget fast.
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled, let self else { return }
            guard let latest = self.entries.sorted(by: { $0.wakeTime > $1.wakeTime }).first else { return }
            WidgetSnapshotPublisher.publish(latest)
            // Keep the FriendsSleepWidget in step with the user's latest night
            // so the "You" slot updates the same day the score is logged.
            // Friends' rows refresh only when the friends list mutates
            // (handled in FriendsManager).
            FriendsManager.shared.syncToWidget(
                myLatest: latest,
                petName: self.pet.name
            )
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

        // App Group suite shared with the widget extension (snapshot + friends
        // data live here). Keep this in sync with WidgetSnapshotPublisher /
        // FriendsManager / the widget's WidgetDataStore.
        let appGroupSuite = "group.com.nathanielfiskaa.sleepowl"

        // Robust wipe: blow away the WHOLE persistent domain for both the app
        // and the shared App Group, instead of hand-listing keys (which had
        // already drifted — it missed morning check-in history and the App
        // Group entirely, leaving user data behind after "delete account").
        if let appDomain = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: appDomain)
        }
        if let groupDefaults = UserDefaults(suiteName: appGroupSuite) {
            groupDefaults.removePersistentDomain(forName: appGroupSuite)
            groupDefaults.synchronize()
        }

        // Morning check-in history persists under its own key — clear it
        // explicitly so nothing survives even if the domain wipe is partial.
        MorningCheckInStore.clear()
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

