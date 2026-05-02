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
    }

    // MARK: - Published state
    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: Key.onboarded) }
    }

    @Published var pet: Pet { didSet { persistPet() } }
    @Published var routine: Routine { didSet { persistRoutine() } }
    @Published var entries: [SleepEntry] { didSet { persistEntries() } }

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

    // MARK: - Init
    init() {
        let defaults = UserDefaults.standard
        self.hasCompletedOnboarding = defaults.bool(forKey: Key.onboarded)

        // Pet
        if let data = defaults.data(forKey: Key.petData),
           let decoded = try? JSONDecoder().decode(Pet.self, from: data) {
            self.pet = decoded
        } else {
            self.pet = Pet()
        }

        // Routine
        if let data = defaults.data(forKey: Key.routineData),
           let decoded = try? JSONDecoder().decode(Routine.self, from: data) {
            self.routine = decoded
        } else {
            self.routine = Routine(habits: [
                RoutineHabit.library.first { $0.id == "no_phone" }!,
                RoutineHabit.library.first { $0.id == "breathing" }!,
                RoutineHabit.library.first { $0.id == "journal" }!
            ])
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

        // Reset routine completion if it's a new day
        rolloverRoutineIfNeeded()
        // Maybe surface morning check-in
        evaluateMorningPrompt()
    }

    // MARK: - Computed helpers
    var lastEntry: SleepEntry? { entries.sorted(by: { $0.wakeTime > $1.wakeTime }).first }

    var recentEntries: [SleepEntry] {
        Array(entries.sorted(by: { $0.wakeTime > $1.wakeTime }).prefix(7))
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

    // MARK: - Onboarding
    func completeOnboarding(name: String, goalHours: Double, bedtime: Date, wakeTime: Date) {
        var newPet = pet
        newPet.name = name.isEmpty ? "Lumi" : name
        self.pet = newPet
        self.goalHours = goalHours
        self.targetBedtime = bedtime
        self.targetWakeTime = wakeTime
        self.hasCompletedOnboarding = true
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
            routineCompleted: routineCompleted
        )

        let breakdown = SleepScoreCalculator.score(
            for: entry,
            goalHours: goalHours,
            targetBedtime: targetBedtime,
            targetWakeTime: targetWakeTime
        )
        entry.score = breakdown.total

        let energy = SleepScoreCalculator.energyReward(for: entry, score: entry.score)
        entry.energyEarned = energy

        // Replace any entry from same day, otherwise append
        if let idx = entries.firstIndex(where: { $0.dayKey == entry.dayKey }) {
            entries[idx] = entry
        } else {
            entries.append(entry)
        }

        applyReward(energy: energy, score: entry.score)
        UserDefaults.standard.set(entry.dayKey, forKey: Key.lastMorningPrompt)
        showMorningCheckIn = false
        return entry
    }

    // MARK: - Pet rewards
    private func applyReward(energy: Int, score: Int) {
        var p = pet
        p.dreamEnergy += energy
        p.lastSleepScore = score
        p.mood = Pet.Mood.from(score: score)

        // Level up
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

        self.pet = p
        self.lastEarnedEnergy = energy
        self.lastLevelUp = leveledTo
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
        r.habits = habits
        // prune completion
        r.completedToday = r.completedToday.intersection(Set(habits.map { $0.id }))
        self.routine = r
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
        if hour >= 5 && hour < 12 && lastPrompted != today && !entries.contains(where: { $0.dayKey == today }) {
            showMorningCheckIn = true
        }
    }

    func dismissMorningCheckIn() {
        UserDefaults.standard.set(Date().dayKey, forKey: Key.lastMorningPrompt)
        showMorningCheckIn = false
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
}

// MARK: - Preview helper
extension AppState {
    static var preview: AppState {
        let s = AppState()
        s.hasCompletedOnboarding = true
        var p = s.pet
        p.name = "Lumi"
        p.level = 4
        p.dreamEnergy = 240
        p.lastSleepScore = 84
        p.mood = .good
        p.unlockedItems = ["default_color", "color_lavender", "hat_nightcap", "bg_starfield"]
        s.pet = p
        return s
    }
}
