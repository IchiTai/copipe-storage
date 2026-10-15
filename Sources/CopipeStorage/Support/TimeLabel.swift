import Foundation

enum TimeLabel {
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("HH:mm")
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("Md HH:mm")
        return formatter
    }()

    static func string(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 {
            return L10n.string("time.just_now")
        }
        if seconds < 3600 {
            return String(format: L10n.string("time.minutes_ago"), Int(seconds / 60))
        }
        if calendar.isDate(date, inSameDayAs: now) {
            return timeFormatter.string(from: date)
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return String(format: L10n.string("time.yesterday"), timeFormatter.string(from: date))
        }
        return dateTimeFormatter.string(from: date)
    }
}
