import Foundation

/// Generates the "daily message from pet" shown on the Home tab.
/// Free users see a small pool of simple messages.
/// Pro users get a personalized message based on actual sleep patterns.
enum PetMessageGenerator {

    static func dailyMessage(
        for pet: Pet,
        entries: [SleepEntry],
        targetBedtime: Date,
        consistencyDays: Int,
        debt: Double,
        isPro: Bool
    ) -> String {
        if let last = entries.sorted(by: { $0.wakeTime > $1.wakeTime }).first,
           Calendar.current.isDateInToday(last.wakeTime),
           let recoveryMessage = last.recoveryMessage {
            return recoveryMessage
        }
        if isPro {
            return personalized(pet: pet, entries: entries,
                                targetBedtime: targetBedtime,
                                consistencyDays: consistencyDays, debt: debt)
        }
        return simple(for: pet)
    }

    // MARK: - Free (small pool)
    private static func simple(for pet: Pet) -> String {
        let pool: [String]
        switch pet.mood.legacyBucket {
        case .rested:
            pool = [
                "I feel so cozy after last night.",
                "Today's a good day to grow!",
                "Thank you for resting well."
            ]
        case .good:
            pool = [
                "I'm feeling steady today.",
                "A calm night helps everything."
            ]
        case .tired:
            pool = [
                "I'm a little sleepy today.",
                "Can we wind down earlier tonight?"
            ]
        default:
            pool = [
                "I missed some sleep — let's recover.",
                "A gentle night would help me a lot."
            ]
        }
        let idx = abs(pet.name.hashValue ^ Calendar.current.component(.day, from: Date())) % pool.count
        return pool[idx]
    }

    // MARK: - Premium (personalized)
    private static func personalized(
        pet: Pet, entries: [SleepEntry], targetBedtime: Date,
        consistencyDays: Int, debt: Double
    ) -> String {
        if consistencyDays >= 5 {
            return "I love this rhythm — \(consistencyDays) consistent nights in a row."
        }
        if debt >= 4 {
            let formatted = SleepInsights.formatDebt(debt)
            return "I'm carrying \(formatted) of sleep debt. A long night would help."
        }
        if let last = entries.sorted(by: { $0.wakeTime > $1.wakeTime }).first {
            let cal = Calendar.current
            let lastBed = cal.dateComponents([.hour, .minute], from: last.bedtime)
            let target = cal.dateComponents([.hour, .minute], from: targetBedtime)
            let lateMinutes = ((lastBed.hour ?? 0) * 60 + (lastBed.minute ?? 0))
                            - ((target.hour ?? 0) * 60 + (target.minute ?? 0))
            if lateMinutes > 30 {
                return "Last night was \(lateMinutes) min later than your target. Tonight let's catch up."
            }
            if last.score >= 85 {
                return "Last night was great — score \(last.score). Let's keep it going."
            }
        }
        return "Ready for a calm night?"
    }
}
