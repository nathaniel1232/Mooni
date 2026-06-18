import Foundation

struct RoutineHabit: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var icon: String
    var minutesBeforeBed: Int

    static let library: [RoutineHabit] = [
        // Earlier in the night first; phone-away is the very last step before bed
        // since once your phone is away you can't tap habits inside the app.
        .init(id: "dim_lights",  title: "Dim the lights",  icon: "lightbulb.fill",      minutesBeforeBed: 60),
        .init(id: "water",       title: "Drink water",     icon: "drop.fill",           minutesBeforeBed: 45),
        .init(id: "read",        title: "Read a few pages",icon: "book.fill",           minutesBeforeBed: 35),
        .init(id: "stretch",     title: "Light stretch",   icon: "figure.flexibility",  minutesBeforeBed: 25),
        .init(id: "journal",     title: "Quick journal",   icon: "square.and.pencil",   minutesBeforeBed: 20),
        .init(id: "breathing",   title: "Breathing",       icon: "wind",                minutesBeforeBed: 15),
        .init(id: "alarm",       title: "Set alarm",       icon: "alarm.fill",          minutesBeforeBed: 10),
        .init(id: "no_phone",    title: "Put phone away",  icon: "iphone.slash",        minutesBeforeBed: 5)
    ]
}

struct Routine: Codable {
    var habits: [RoutineHabit] = []
    var completedToday: Set<String> = []
    var lastCompletedDay: String? = nil
    /// Habits already granted XP today — stops users farming XP by toggling the
    /// same habit off and on. Reset on day rollover.
    var rewardedToday: Set<String> = []

    var completion: Double {
        guard !habits.isEmpty else { return 0 }
        return Double(completedToday.count) / Double(habits.count)
    }

    var isFullyCompleted: Bool {
        !habits.isEmpty && completedToday.count == habits.count
    }
}

extension Routine {
    private enum CodingKeys: String, CodingKey {
        case habits, completedToday, lastCompletedDay, rewardedToday
    }

    // Lenient decode so adding `rewardedToday` doesn't wipe a returning user's
    // saved routine (synthesized Codable would throw on the missing key).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        habits = try c.decodeIfPresent([RoutineHabit].self, forKey: .habits) ?? []
        completedToday = try c.decodeIfPresent(Set<String>.self, forKey: .completedToday) ?? []
        lastCompletedDay = try c.decodeIfPresent(String.self, forKey: .lastCompletedDay)
        rewardedToday = try c.decodeIfPresent(Set<String>.self, forKey: .rewardedToday) ?? []
    }
}
