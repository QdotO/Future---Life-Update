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

enum Frequency: String, CaseIterable, Codable, Sendable {
    case once
    case daily
    case weekly
    case monthly
    case custom
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

struct ValidationRules: Codable, Sendable {
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

    init(
        startDate: Date = Date(),
        frequency: Frequency = .daily,
    times: [ScheduleTime] = [],
        endDate: Date? = nil,
        timezoneIdentifier: String = TimeZone.current.identifier
    ) {
        self.id = UUID()
        self.startDate = startDate
        self.frequency = frequency
        self.times = times
        self.endDate = endDate
        self.timezoneIdentifier = timezoneIdentifier
    }

    var timezone: TimeZone {
        TimeZone(identifier: timezoneIdentifier) ?? .current
    }
}

@Model
final class TrackingGoal {
    @Attribute(.unique) var id: UUID
    var title: String
    var goalDescription: String
    var category: TrackingCategory
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
        schedule: Schedule = Schedule(),
        isActive: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = UUID()
        self.title = title
        self.goalDescription = description
        self.category = category
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
    var textValue: String?
    var boolValue: Bool?
    var selectedOptions: [String]?
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
        textValue: String? = nil,
        boolValue: Bool? = nil,
        selectedOptions: [String]? = nil,
        mood: Int? = nil,
        location: String? = nil
    ) {
        self.id = UUID()
        self.goal = goal
        self.question = question
        self.timestamp = timestamp
        self.numericValue = numericValue
        self.textValue = textValue
        self.boolValue = boolValue
        self.selectedOptions = selectedOptions
        self.mood = mood
        self.location = location
    }
}
