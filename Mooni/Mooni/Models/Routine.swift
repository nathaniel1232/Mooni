import Foundation

struct RoutineHabit: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var icon: String
    var minutesBeforeBed: Int

    static let library: [RoutineHabit] = [
        .init(id: "dim_lights",  title: "Dim the lights",  icon: "lightbulb.fill",      minutesBeforeBed: 60),
        .init(id: "no_phone",    title: "Put phone away",  icon: "iphone.slash",        minutesBeforeBed: 30),
        .init(id: "read",        title: "Read a few pages",icon: "book.fill",           minutesBeforeBed: 25),
        .init(id: "stretch",     title: "Light stretch",   icon: "figure.flexibility",  minutesBeforeBed: 20),
        .init(id: "breathing",   title: "Breathing",       icon: "wind",                minutesBeforeBed: 15),
        .init(id: "journal",     title: "Quick journal",   icon: "square.and.pencil",   minutesBeforeBed: 10),
        .init(id: "water",       title: "Drink water",     icon: "drop.fill",           minutesBeforeBed: 35),
        .init(id: "alarm",       title: "Set alarm",       icon: "alarm.fill",          minutesBeforeBed: 5)
    ]
}

struct Routine: Codable {
    var habits: [RoutineHabit] = []
    var completedToday: Set<String> = []
    var lastCompletedDay: String? = nil

    var completion: Double {
        guard !habits.isEmpty else { return 0 }
        return Double(completedToday.count) / Double(habits.count)
    }

    var isFullyCompleted: Bool {
        !habits.isEmpty && completedToday.count == habits.count
    }
}
