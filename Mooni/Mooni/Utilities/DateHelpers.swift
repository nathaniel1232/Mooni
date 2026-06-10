import Foundation

extension Date {
    func setting(hour: Int, minute: Int) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: self)
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps) ?? self
    }

    /// Locale-aware clock string: "11:42 PM" in 12-hour locales, "23:42" in
    /// 24-hour locales. Uses the user's device setting rather than a hardcoded
    /// 24-hour format so times read naturally everywhere (and match the widget,
    /// which formats with the same locale-aware convention).
    var hourMinuteString: String {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("jmm")
        return f.string(from: self)
    }

    var dayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: self)
    }

    static func todayAt(hour: Int, minute: Int) -> Date {
        Date().setting(hour: hour, minute: minute)
    }
}

enum TimeOfDay {
    case morning, day, evening, night

    static var current: TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11:  return .morning
        case 11..<17: return .day
        case 17..<21: return .evening
        default:      return .night
        }
    }
}
