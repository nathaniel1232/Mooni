import Foundation

/// Multi-day sleep programs unlocked by Premium.
/// Each program is a small piece of structured content the user can opt into.
struct SleepProgram: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var subtitle: String
    var icon: String
    var days: Int
    var isPremium: Bool

    static let catalog: [SleepProgram] = [
        .init(id: "reset_7",
              title: "7-Day Reset",
              subtitle: "Realign your schedule in a week.",
              icon: "arrow.clockwise.circle.fill",
              days: 7,
              isPremium: true),
        .init(id: "earlier_14",
              title: "14-Day Earlier Bedtime",
              subtitle: "Gently shift your bedtime earlier.",
              icon: "moon.fill",
              days: 14,
              isPremium: true),
        .init(id: "weekend",
              title: "Weekend Consistency Challenge",
              subtitle: "Stop ruining your rhythm on weekends.",
              icon: "calendar",
              days: 4,
              isPremium: true),
        .init(id: "rbp",
              title: "Revenge Bedtime Plan",
              subtitle: "Reclaim your evenings without losing sleep.",
              icon: "iphone.slash",
              days: 7,
              isPremium: true),
        .init(id: "exam",
              title: "Exam / Work Recovery",
              subtitle: "Survive a stressful stretch.",
              icon: "graduationcap.fill",
              days: 5,
              isPremium: true),
        .init(id: "jetlag",
              title: "Jet Lag Recovery",
              subtitle: "Beat travel jet lag fast.",
              icon: "airplane",
              days: 4,
              isPremium: true)
    ]
}

/// Guided wind-down content (premium).
struct WindDownContent: Identifiable, Hashable {
    var id: String
    var title: String
    var icon: String
    var minutes: Int

    static let library: [WindDownContent] = [
        .init(id: "breath_478",  title: "4-7-8 Breathing",       icon: "wind",                minutes: 5),
        .init(id: "story_forest", title: "Sleep Story: Forest",  icon: "book.fill",           minutes: 18),
        .init(id: "sound_rain",   title: "Calming Rain",         icon: "cloud.rain.fill",     minutes: 30),
        .init(id: "journal",      title: "Wind-down Journal",    icon: "square.and.pencil",   minutes: 5),
        .init(id: "body_scan",    title: "Body Scan",            icon: "figure.mind.and.body",minutes: 10),
        .init(id: "phone_down",   title: "Phone-Down Challenge", icon: "iphone.slash",        minutes: 30)
    ]
}
