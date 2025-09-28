import Foundation

struct GoalDraft: Equatable {
    var title: String = ""
    var motivation: String = ""
    var category: TrackingCategory? = nil
    var customCategoryLabel: String = ""
    var questionDrafts: [GoalQuestionDraft] = []
    var schedule: GoalScheduleDraft = GoalScheduleDraft()
    var celebrationMessage: String = ""
    var accountabilityContact: AccountabilityContact? = nil

    var hasCustomCategory: Bool {
        category == .custom
    }

    var normalizedCustomCategoryLabel: String? {
        let trimmed = customCategoryLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct GoalQuestionDraft: Identifiable, Equatable {
    var id: UUID = UUID()
    var text: String = ""
    var responseType: ResponseType = .boolean
    var options: [String] = []
    var validationRules: ValidationRules? = nil
    var isActive: Bool = true
    var templateID: String? = nil

    var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasContent: Bool {
        !trimmedText.isEmpty
    }
}

struct GoalScheduleDraft: Equatable {
    var cadence: GoalCadence = .daily
    var reminderTimes: [ScheduleTime] = []
    var timezone: TimeZone = .current
    var startDate: Date = Date()

    mutating func reset(for cadence: GoalCadence) {
        self.cadence = cadence
        reminderTimes = []
    }
}

enum GoalCadence: Hashable, Identifiable {
    case daily
    case weekdays
    case weekly(Weekday)
    case custom(intervalDays: Int)

    var id: String {
        switch self {
        case .daily: return "daily"
        case .weekdays: return "weekdays"
        case .weekly(let weekday): return "weekly-\(weekday.rawValue)"
        case .custom(let interval): return "custom-\(interval)"
        }
    }

    var frequency: Frequency {
        switch self {
        case .daily: return .daily
        case .weekdays, .weekly: return .weekly
        case .custom: return .custom
        }
    }

    var selectedWeekdays: Set<Weekday> {
        switch self {
        case .daily:
            return []
        case .weekdays:
            return [.monday, .tuesday, .wednesday, .thursday, .friday]
        case .weekly(let weekday):
            return [weekday]
        case .custom:
            return []
        }
    }

    var intervalDayCount: Int? {
        if case let .custom(interval) = self {
            return interval
        }
        return nil
    }
}

struct PromptTemplate: Identifiable, Equatable {
    struct Blueprint: Equatable {
        let text: String
        let responseType: ResponseType
        let options: [String]?
        let validationRules: ValidationRules?
    }

    let id: String
    let title: String
    let subtitle: String
    let categories: Set<TrackingCategory>
    let blueprint: Blueprint
    let iconName: String

    init(
        id: String,
        title: String,
        subtitle: String,
        categories: Set<TrackingCategory>,
        iconName: String,
        blueprint: Blueprint
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.categories = categories
        self.iconName = iconName
        self.blueprint = blueprint
    }

    var isCategoryAgnostic: Bool {
        categories.isEmpty
    }
}

struct CadencePreset: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let iconName: String
    let cadence: GoalCadence

    init(id: String, title: String, subtitle: String, iconName: String, cadence: GoalCadence) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.cadence = cadence
    }
}

enum GoalCreationCatalog {
    private static let baseTemplates: [PromptTemplate] = [
        PromptTemplate(
            id: "fitness-workout",
            title: "Did you move today?",
            subtitle: "Track whether you completed your planned workout.",
            categories: [.fitness, .health, .habits],
            iconName: "figure.run",
            blueprint: .init(
                text: "Did you complete your planned workout?",
                responseType: .boolean,
                options: nil,
                validationRules: ValidationRules(allowsEmpty: false)
            )
        ),
        PromptTemplate(
            id: "fitness-minutes",
            title: "Active minutes",
            subtitle: "Log how long you were active to see trends over time.",
            categories: [.fitness, .health],
            iconName: "timer",
            blueprint: .init(
                text: "How many active minutes did you get?",
                responseType: .numeric,
                options: nil,
                validationRules: ValidationRules(minimumValue: 0, maximumValue: 180, allowsEmpty: false)
            )
        ),
        PromptTemplate(
            id: "mood-check-in",
            title: "Mood check-in",
            subtitle: "Capture how you feel on a simple scale.",
            categories: [.mood, .habits, .health],
            iconName: "face.smiling",
            blueprint: .init(
                text: "How did you feel overall today?",
                responseType: .scale,
                options: nil,
                validationRules: ValidationRules(minimumValue: 1, maximumValue: 5, allowsEmpty: false)
            )
        ),
        PromptTemplate(
            id: "productivity-focus",
            title: "Focus review",
            subtitle: "Reflect on how focused you felt.",
            categories: [.productivity, .learning],
            iconName: "brain.head.profile",
            blueprint: .init(
                text: "How focused did you feel today?",
                responseType: .scale,
                options: nil,
                validationRules: ValidationRules(minimumValue: 1, maximumValue: 5, allowsEmpty: false)
            )
        ),
        PromptTemplate(
            id: "productivity-progress",
            title: "Progress log",
            subtitle: "Capture a quick note on what moved forward.",
            categories: [.productivity, .learning],
            iconName: "text.badge.checkmark",
            blueprint: .init(
                text: "What did you make progress on today?",
                responseType: .text,
                options: nil,
                validationRules: ValidationRules(allowsEmpty: false)
            )
        ),
        PromptTemplate(
            id: "finance-spending",
            title: "Spending check",
            subtitle: "Track discretionary spending to stay mindful.",
            categories: [.finance],
            iconName: "creditcard",
            blueprint: .init(
                text: "How much did you spend on wants today?",
                responseType: .numeric,
                options: nil,
                validationRules: ValidationRules(minimumValue: 0, maximumValue: 500, allowsEmpty: false)
            )
        ),
        PromptTemplate(
            id: "social-connection",
            title: "Reach out",
            subtitle: "Remind yourself to connect with someone.",
            categories: [.social, .habits],
            iconName: "bubble.left.and.text.bubble.right",
            blueprint: .init(
                text: "Did you connect with someone you care about today?",
                responseType: .boolean,
                options: nil,
                validationRules: ValidationRules(allowsEmpty: false)
            )
        ),
        PromptTemplate(
            id: "custom-celebration",
            title: "Celebrate a win",
            subtitle: "Capture a highlight to reinforce progress.",
            categories: [],
            iconName: "sparkles",
            blueprint: .init(
                text: "What win are you celebrating today?",
                responseType: .text,
                options: nil,
                validationRules: ValidationRules(allowsEmpty: true)
            )
        )
    ]

    private static let baseCadencePresets: [CadencePreset] = [
        CadencePreset(
            id: "daily-morning",
            title: "Daily",
            subtitle: "Check in once every day.",
            iconName: "sun.max",
            cadence: .daily
        ),
        CadencePreset(
            id: "weekdays",
            title: "Weekdays",
            subtitle: "Stay accountable Monday through Friday.",
            iconName: "calendar",
            cadence: .weekdays
        ),
        CadencePreset(
            id: "weekly",
            title: "Weekly",
            subtitle: "Pick a day for a deeper reflection.",
            iconName: "calendar.badge.clock",
            cadence: .weekly(.sunday)
        ),
        CadencePreset(
            id: "custom",
            title: "Custom rhythm",
            subtitle: "Choose an every X days interval.",
            iconName: "dial.medium",
            cadence: .custom(intervalDays: 3)
        )
    ]

    static func templates(for category: TrackingCategory?) -> [PromptTemplate] {
        guard let category else { return baseTemplates }
        let filtered = baseTemplates.filter { template in
            template.isCategoryAgnostic || template.categories.contains(category)
        }
        return filtered.isEmpty ? baseTemplates : filtered
    }

    static func topTemplates(for category: TrackingCategory?, limit: Int = 3) -> [PromptTemplate] {
        Array(templates(for: category).prefix(limit))
    }

    static func additionalTemplates(for category: TrackingCategory?, excluding ids: Set<String>) -> [PromptTemplate] {
        templates(for: category).filter { !ids.contains($0.id) }
    }

    static var cadencePresets: [CadencePreset] {
        baseCadencePresets
    }

    static func recommendedTimes(for cadence: GoalCadence, timezone: TimeZone, now: Date = Date()) -> [ScheduleTime] {
        let anchors: [Int] = [8 * 60 + 30, 12 * 60 + 30, 20 * 60]
        switch cadence {
        case .daily, .weekdays, .weekly:
            return anchors.map { minutes in
                ScheduleTime(hour: minutes / 60, minute: minutes % 60)
            }
        case .custom:
            return anchors.map { minutes in
                ScheduleTime(hour: minutes / 60, minute: minutes % 60)
            }
        }
    }
}

struct AccountabilityContact: Equatable {
    var name: String
    var channel: ContactChannel

    enum ContactChannel: Equatable {
        case sms(String)
        case email(String)
        case other(String)
    }
}
