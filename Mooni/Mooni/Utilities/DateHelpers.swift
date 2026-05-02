import Foundation

extension Date {
    func setting(hour: Int, minute: Int) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: self)
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps) ?? self
    }

    var hourMinuteString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
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
