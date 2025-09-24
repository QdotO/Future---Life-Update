import Foundation

extension DateComponents {
    func formattedTime(in timezone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        guard let date = calendar.date(from: self) else { return "—" }

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        formatter.timeZone = timezone
        return formatter.string(from: date)
    }
}

extension ScheduleTime {
    func formattedTime(in timezone: TimeZone) -> String {
        dateComponents.formattedTime(in: timezone)
    }
}
