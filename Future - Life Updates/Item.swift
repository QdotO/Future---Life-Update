import Foundation
import SwiftData

enum ResponseType: String, CaseIterable, Codable, Sendable {
    case numeric
    case scale
    case boolean
    case multipleChoice
    case text
    case time
    case slider
}

extension TrackingGoal {
    var categoryDisplayName: String {
        if category == .custom,
            let label = customCategoryLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
            !label.isEmpty {
            return label
        }
        return category.displayName
    }
}

enum Frequency: String, CaseIterable, Codable, Sendable {
    case once
    case daily
    case weekly
    case monthly
    case custom
}

enum Weekday: Int, CaseIterable, Codable, Identifiable, Sendable {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    var id: Int { rawValue }

    var displayName: String {
        Self.dateFormatter.weekdaySymbols[rawValue - 1]
    }

    var shortDisplayName: String {
        Self.dateFormatter.shortWeekdaySymbols[rawValue - 1]
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        return formatter
    }()
}

enum TrackingCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case health
    case fitness
    case productivity
    case habits
    case mood
    case learning
    case social
    case finance
    case custom

    var id: String { rawValue }
    var displayName: String {
        rawValue.capitalized
    }
}

struct ValidationRules: Codable, Sendable, Equatable {
    var minimumValue: Double?
    var maximumValue: Double?
    var allowsEmpty: Bool

    init(minimumValue: Double? = nil, maximumValue: Double? = nil, allowsEmpty: Bool = true) {
        self.minimumValue = minimumValue
        self.maximumValue = maximumValue
        self.allowsEmpty = allowsEmpty
    }
}

struct ScheduleTime: Codable, Hashable, Sendable {
    var hour: Int
    var minute: Int

    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    init(components: DateComponents) {
        self.hour = components.hour ?? 0
        self.minute = components.minute ?? 0
    }

    var dateComponents: DateComponents {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return components
    }

    var totalMinutes: Int {
        max(0, min(23, hour)) * 60 + max(0, min(59, minute))
    }

    func isWithin(window: TimeInterval, of other: ScheduleTime) -> Bool {
        let difference = abs(totalMinutes - other.totalMinutes)
        return Double(difference * 60) < window
    }

    func validated() -> ScheduleTime? {
        guard hour >= 0, hour < 24, minute >= 0, minute < 60 else { return nil }
        return self
    }

    func formattedTime(in timezone: TimeZone, locale: Locale = .current) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        components.year = 2024
        components.month = 1
        components.day = 1

        let date = calendar.date(from: components) ?? Date()
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeStyle = .short
        formatter.timeZone = timezone
        return formatter.string(from: date)
    }

    func date(on day: Date, calendar: Calendar) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)
    }
}

@Model
final class Schedule {
    @Attribute(.unique) var id: UUID
    var startDate: Date
    var frequency: Frequency
    var times: [ScheduleTime]
    var endDate: Date?
    var timezoneIdentifier: String
    var goal: TrackingGoal?
    var selectedWeekdays: [Weekday] = []
    var intervalDayCount: Int?

    init(
        startDate: Date = Date(),
        frequency: Frequency = .daily,
        times: [ScheduleTime] = [],
        endDate: Date? = nil,
        timezoneIdentifier: String = TimeZone.current.identifier,
        selectedWeekdays: [Weekday] = [],
        intervalDayCount: Int? = nil
    ) {
        self.id = UUID()
        self.startDate = startDate
        self.frequency = frequency
        self.times = times.sorted { $0.totalMinutes < $1.totalMinutes }
        self.endDate = endDate
        self.timezoneIdentifier = timezoneIdentifier
        self.selectedWeekdays = Array(Set(selectedWeekdays)).sorted { $0.rawValue < $1.rawValue }
        self.intervalDayCount = intervalDayCount
    }

    var timezone: TimeZone {
        TimeZone(identifier: timezoneIdentifier) ?? .current
    }

    func normalizedWeekdays() -> [Weekday] {
        Array(Set(selectedWeekdays)).sorted { $0.rawValue < $1.rawValue }
    }

    func matches(weekday: Weekday) -> Bool {
        selectedWeekdays.contains(weekday)
    }

    func hasConflicts(with scheduleTime: ScheduleTime, window: TimeInterval) -> Bool {
        times.contains { $0.isWithin(window: window, of: scheduleTime) }
    }
}

@Model
final class TrackingGoal {
    @Attribute(.unique) var id: UUID
    var title: String
    var goalDescription: String
    var category: TrackingCategory
    var customCategoryLabel: String?
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade) var questions: [Question]
    @Relationship(deleteRule: .cascade) var dataPoints: [DataPoint]
    var schedule: Schedule

    init(
        title: String,
        description: String,
        category: TrackingCategory,
        customCategoryLabel: String? = nil,
        schedule: Schedule = Schedule(),
        isActive: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = UUID()
        self.title = title
        self.goalDescription = description
        self.category = category
        self.customCategoryLabel = customCategoryLabel
        self.schedule = schedule
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.questions = []
        self.dataPoints = []
    }

    func bumpUpdatedAt(to date: Date = Date()) {
        updatedAt = date
    }
}

@Model
final class Question {
    @Attribute(.unique) var id: UUID
    var text: String
    var responseType: ResponseType
    var isActive: Bool
    var options: [String]?
    var validationRules: ValidationRules?

    var goal: TrackingGoal?
    var dataPoints: [DataPoint]

    init(
        text: String,
        responseType: ResponseType,
        isActive: Bool = true,
        options: [String]? = nil,
        validationRules: ValidationRules? = nil
    ) {
        self.id = UUID()
        self.text = text
        self.responseType = responseType
        self.isActive = isActive
        self.options = options
        self.validationRules = validationRules
        self.dataPoints = []
    }
}

@Model
final class DataPoint {
    @Attribute(.unique) var id: UUID
    var numericValue: Double?
    var numericDelta: Double?
    var textValue: String?
    var boolValue: Bool?
    var selectedOptions: [String]?
    var timeValue: Date?
    var timestamp: Date
    var mood: Int?
    var location: String?

    var goal: TrackingGoal?
    var question: Question?

    init(
        goal: TrackingGoal?,
        question: Question?,
        timestamp: Date = Date(),
    numericValue: Double? = nil,
    numericDelta: Double? = nil,
        textValue: String? = nil,
        boolValue: Bool? = nil,
        selectedOptions: [String]? = nil,
        timeValue: Date? = nil,
        mood: Int? = nil,
        location: String? = nil
    ) {
        self.id = UUID()
        self.goal = goal
        self.question = question
        self.timestamp = timestamp
    self.numericValue = numericValue
    self.numericDelta = numericDelta
        self.textValue = textValue
        self.boolValue = boolValue
        self.selectedOptions = selectedOptions
        self.timeValue = timeValue
        self.mood = mood
        self.location = location
    }
}
