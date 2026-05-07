import Foundation

enum MorningCheckInStore {
    private static let key = "mooni.morningCheckIns"

    static func checkIn(for dayKey: String) -> MorningCheckIn? {
        all()[dayKey]
    }

    static func checkIn(for date: Date) -> MorningCheckIn? {
        checkIn(for: date.dayKey)
    }

    static func save(_ checkIn: MorningCheckIn) {
        var values = all()
        values[checkIn.date.dayKey] = checkIn
        if let data = try? JSONEncoder().encode(values) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func all() -> [String: MorningCheckIn] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: MorningCheckIn].self, from: data) else {
            return [:]
        }
        return decoded
    }
}
