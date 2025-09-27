import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class GoalCreationViewModel {
    private enum Constants {
        static let minimumReminderSpacing: TimeInterval = 5 * 60
        static let defaultIntervalDays: Int = 3
        static let primaryCategoryLimit: Int = 6
        static let defaultReminderHour: Int = 9
        static let defaultReminderMinute: Int = 0
        static let reminderSearchStepMinutes: Int = 5
    }

    static var primaryCategoryLimit: Int { Constants.primaryCategoryLimit }

    enum CategoryOption: Hashable, Identifiable, Sendable {
        case system(TrackingCategory)
        case custom(String)

        var id: String {
            switch self {
            case .system(let category):
                return "system-\(category.rawValue)"
            case .custom(let label):
                return "custom-\(label.lowercased())"
            }
        }

        var title: String {
            switch self {
            case .system(let category):
                return category.displayName
            case .custom(let label):
                return label
            }
        }

        var isCustom: Bool {
            if case .custom = self { return true }
            return false
        }
    }
    enum CreationError: LocalizedError {
        case missingTitle
        case missingQuestions
        case missingCategory

        var errorDescription: String? {
            switch self {
            case .missingTitle:
                return "Please provide a goal title before saving."
            case .missingQuestions:
                return "Add at least one question to track before creating this goal."
            case .missingCategory:
                return "Choose a category or name your custom category before creating your goal."
            }
        }
    }

    struct ScheduleDraft {
        var startDate: Date
        var frequency: Frequency
        var times: [ScheduleTime]
        var timezone: TimeZone
        var selectedWeekdays: Set<Weekday>
        var intervalDayCount: Int?

        init(
            startDate: Date = Date(),
            frequency: Frequency = .daily,
            times: [ScheduleTime] = [],
            timezone: TimeZone = .current,
            selectedWeekdays: Set<Weekday> = [],
            intervalDayCount: Int? = nil
        ) {
            self.startDate = startDate
            self.frequency = frequency
            self.times = times
            self.timezone = timezone
            self.selectedWeekdays = selectedWeekdays
            self.intervalDayCount = intervalDayCount
        }
    }

    private let modelContext: ModelContext
    private let dateProvider: () -> Date
    private let calendar: Calendar
    private static let scheduleCacheTTL: TimeInterval = 30

    var title: String = ""
    var goalDescription: String = ""
    var selectedCategory: TrackingCategory? = nil
    var customCategoryLabel: String = ""
    private(set) var draftQuestions: [Question] = []
    private(set) var scheduleDraft: ScheduleDraft
    private(set) var recentCustomCategories: [String]
    private var cachedSchedules: ScheduleCache?

    var hasDraftQuestions: Bool {
        !draftQuestions.isEmpty
    }

    init(
        modelContext: ModelContext,
        calendar: Calendar = .current,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.modelContext = modelContext
        self.calendar = calendar
        self.dateProvider = dateProvider
        self.scheduleDraft = ScheduleDraft(startDate: dateProvider())
        self.recentCustomCategories = GoalCreationViewModel.loadCustomCategories(from: modelContext)
    }

    var primaryCategoryOptions: [CategoryOption] {
        Array(allCategoryOptions.prefix(Constants.primaryCategoryLimit))
    }

    var overflowCategoryOptions: [CategoryOption] {
        Array(allCategoryOptions.dropFirst(Constants.primaryCategoryLimit))
    }

    var hasOverflowCategories: Bool {
        !overflowCategoryOptions.isEmpty
    }

    private var allCategoryOptions: [CategoryOption] {
        var systemOptions = TrackingCategory.allCases
            .filter { $0 != .custom }
            .map { CategoryOption.system($0) }

        let customOptions = normalizedCustomCategories.map { CategoryOption.custom($0) }
        systemOptions.append(contentsOf: customOptions)
        return systemOptions
    }

    private var normalizedCustomCategories: [String] {
        var categories = recentCustomCategories
        if let activeCustomLabel = normalizedCustomCategoryLabel,
           !categories.contains(where: { $0.caseInsensitiveCompare(activeCustomLabel) == .orderedSame }) {
            categories.insert(activeCustomLabel, at: 0)
        }
        return categories
    }

    private var normalizedCustomCategoryLabel: String? {
        let trimmed = customCategoryLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func selectCategory(_ option: CategoryOption) {
        switch option {
        case .system(let category):
            selectedCategory = category
            customCategoryLabel = ""
        case .custom(let label):
            selectedCategory = .custom
            customCategoryLabel = label
        }
    }

    func updateCustomCategoryLabel(_ label: String) {
        customCategoryLabel = label
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            selectedCategory = .custom
        }
    }

    @discardableResult
    func upsertQuestion(
        id: UUID? = nil,
        text: String,
        responseType: ResponseType,
        options: [String]? = nil,
        validationRules: ValidationRules? = nil
    ) -> Question {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedOptions = options?
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let normalizedOptions = cleanedOptions?.isEmpty == false ? cleanedOptions : nil

        if let id, let index = draftQuestions.firstIndex(where: { $0.id == id }) {
            let existing = draftQuestions[index]
            existing.text = trimmedText
            existing.responseType = responseType
            existing.options = normalizedOptions
            existing.validationRules = validationRules
            draftQuestions[index] = existing
            return existing
        } else {
            let question = Question(
                text: trimmedText,
                responseType: responseType,
                options: normalizedOptions,
                validationRules: validationRules
            )
            draftQuestions.append(question)
            return question
        }
    }

    @discardableResult
    func addManualQuestion(
        text: String,
        responseType: ResponseType,
        options: [String]? = nil,
        validationRules: ValidationRules? = nil
    ) -> Question {
        upsertQuestion(
            id: nil,
            text: text,
            responseType: responseType,
            options: options,
            validationRules: validationRules
        )
    }

    func questionDraft(with id: UUID) -> Question? {
        draftQuestions.first { $0.id == id }
    }

    func removeQuestion(_ question: Question) {
        draftQuestions.removeAll { $0.id == question.id }
    }

    func updateSelectedWeekdays(_ weekdays: Set<Weekday>) {
        // Reassign the whole draft so Observation publishes changes
        var draft = scheduleDraft
        draft.selectedWeekdays = weekdays
        scheduleDraft = draft
    }

    func updateSchedule(
        frequency: Frequency,
        times: [DateComponents],
        timezone: TimeZone,
        startDate: Date? = nil,
        selectedWeekdays: Set<Weekday>? = nil,
        intervalDayCount: Int? = nil
    ) {
        scheduleDraft.startDate = startDate ?? dateProvider()
        setFrequency(frequency)
        let sanitizedTimes = times.compactMap { ScheduleTime(components: $0).validated() }
        replaceTimes(sanitizedTimes)
        scheduleDraft.timezone = timezone
        if let selectedWeekdays {
            scheduleDraft.selectedWeekdays = selectedWeekdays
        }
        if let intervalDayCount {
            updateIntervalDayCount(intervalDayCount)
        }
    }

    func updateIntervalDayCount(_ interval: Int?) {
        var draft = scheduleDraft
        if let interval {
            draft.intervalDayCount = max(2, interval)
        } else {
            draft.intervalDayCount = nil
        }
        scheduleDraft = draft
    }

    func setFrequency(_ frequency: Frequency) {
        var draft = scheduleDraft
        draft.frequency = frequency
        switch frequency {
        case .weekly:
            if draft.selectedWeekdays.isEmpty {
                let weekdayValue = calendar.component(.weekday, from: dateProvider())
                if let weekday = Weekday(rawValue: weekdayValue) {
                    draft.selectedWeekdays = [weekday]
                }
            }
            draft.intervalDayCount = nil
        case .custom:
            draft.selectedWeekdays.removeAll()
            if draft.intervalDayCount == nil {
                draft.intervalDayCount = Constants.defaultIntervalDays
            }
        default:
            draft.selectedWeekdays.removeAll()
            draft.intervalDayCount = nil
        }
        scheduleDraft = draft
    }

    func setTimezone(_ timezone: TimeZone) {
        var draft = scheduleDraft
        draft.timezone = timezone
        scheduleDraft = draft
    }

    func setStartDate(_ date: Date) {
        var draft = scheduleDraft
        draft.startDate = date
        scheduleDraft = draft
    }

    func suggestedReminderDate(
        startingAt referenceDate: Date? = nil,
        stepMinutes: Int = Constants.reminderSearchStepMinutes
    ) -> Date {
        let timezone = scheduleDraft.timezone
        var workingCalendar = calendar
        workingCalendar.timeZone = timezone

        let trace = PerformanceMetrics.trace("GoalCreation.suggestReminder", metadata: [
            "timezone": timezone.identifier,
            "existingTimes": "\(scheduleDraft.times.count)"
        ])

        let minutesInDay = 24 * 60
        let searchStep = max(1, stepMinutes)
        let now = dateProvider()

        let baselineDate = referenceDate ?? workingCalendar.date(
            bySettingHour: Constants.defaultReminderHour,
            minute: Constants.defaultReminderMinute,
            second: 0,
            of: now
        ) ?? now

        let baselineComponents = workingCalendar.dateComponents([.hour, .minute], from: baselineDate)
        let baselineMinutes = ((baselineComponents.hour ?? Constants.defaultReminderHour) * 60)
            + (baselineComponents.minute ?? Constants.defaultReminderMinute)

        let existingDraftTimes = scheduleDraft.times
        let externalSchedules = activeSchedules(in: timezone)
        let externalTimes = externalSchedules.flatMap(\.times)

        let iterations = max(1, minutesInDay / searchStep)
        var attempts = 0
        var suggestion: Date?

        for offset in 0..<iterations {
            attempts += 1
            let candidateMinutes = (baselineMinutes + offset * searchStep) % minutesInDay
            let candidate = ScheduleTime(
                hour: candidateMinutes / 60,
                minute: candidateMinutes % 60
            )

            guard candidate.validated() != nil else { continue }

            if existingDraftTimes.contains(where: { $0.isWithin(window: Constants.minimumReminderSpacing, of: candidate) }) {
                continue
            }

            if externalTimes.contains(where: { $0.isWithin(window: Constants.minimumReminderSpacing, of: candidate) }) {
                continue
            }

            if let suggested = workingCalendar.date(
                bySettingHour: candidate.hour,
                minute: candidate.minute,
                second: 0,
                of: now
            ) {
                suggestion = suggested
                break
            }
        }

        let fallback = workingCalendar.date(
            bySettingHour: baselineComponents.hour ?? Constants.defaultReminderHour,
            minute: baselineComponents.minute ?? Constants.defaultReminderMinute,
            second: 0,
            of: now
        ) ?? now

        let result = suggestion ?? fallback
        let resultComponents = workingCalendar.dateComponents([.hour, .minute], from: result)
        let formattedResult = String(
            format: "%02d:%02d",
            resultComponents.hour ?? Constants.defaultReminderHour,
            resultComponents.minute ?? Constants.defaultReminderMinute
        )

        trace.end(extraMetadata: [
            "attempts": "\(attempts)",
            "externalSchedules": "\(externalSchedules.count)",
            "result": formattedResult
        ])
        return result
    }

    func replaceTimes(_ times: [ScheduleTime]) {
        // Always assign through the draft to trigger observation updates
        var draft = scheduleDraft
        draft.times = times.sorted(by: { $0.totalMinutes < $1.totalMinutes })
        scheduleDraft = draft
    }

    @discardableResult
    func addScheduleTime(from date: Date, calendar: Calendar? = nil) -> Bool {
        let calendar = calendar ?? self.calendar
        var components = calendar.dateComponents([.hour, .minute], from: date)
        components.second = 0
        guard let newTime = ScheduleTime(components: components).validated() else { return false }

        guard !hasConflict(with: newTime, window: Constants.minimumReminderSpacing) else { return false }

        if !scheduleDraft.times.contains(newTime) {
            var newTimes = scheduleDraft.times
            newTimes.append(newTime)
            replaceTimes(newTimes)
        }
        return true
    }

    func removeScheduleTime(_ scheduleTime: ScheduleTime) {
        let newTimes = scheduleDraft.times.filter { $0 != scheduleTime }
        replaceTimes(newTimes)
    }

    func hasConflict(with scheduleTime: ScheduleTime, window: TimeInterval = Constants.minimumReminderSpacing) -> Bool {
        scheduleDraft.times.contains { $0.isWithin(window: window, of: scheduleTime) }
    }

    var hasScheduleTimes: Bool {
        !scheduleDraft.times.isEmpty
    }

    var normalizedInterval: Int? {
        guard let value = scheduleDraft.intervalDayCount else { return nil }
        return max(2, value)
    }

    func resetIntervalIfNeeded() {
        if scheduleDraft.frequency != .custom {
            scheduleDraft.intervalDayCount = nil
        }
    }

    func conflictDescription(window: TimeInterval = Constants.minimumReminderSpacing) -> String? {
        guard !scheduleDraft.times.isEmpty else { return nil }

        for schedule in activeSchedules(in: scheduleDraft.timezone) {
            for existingTime in schedule.times {
                for newTime in scheduleDraft.times where existingTime.isWithin(window: window, of: newTime) {
                    return "Clashes with \(schedule.title) near \(existingTime.formattedTime(in: scheduleDraft.timezone))."
                }
            }
        }

        return nil
    }

    func createGoal() throws -> TrackingGoal {
        let trace = PerformanceMetrics.trace("GoalCreation.createGoal")
        var metadata: [String: String] = [:]
        defer { trace.end(extraMetadata: metadata) }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { throw CreationError.missingTitle }
        guard !draftQuestions.isEmpty else { throw CreationError.missingQuestions }

        let now = dateProvider()
        let sortedTimes = scheduleDraft.times.sorted(by: { $0.totalMinutes < $1.totalMinutes })
        let scheduleModel = Schedule(
            startDate: scheduleDraft.startDate,
            frequency: scheduleDraft.frequency,
            times: sortedTimes,
            endDate: nil,
            timezoneIdentifier: scheduleDraft.timezone.identifier,
            selectedWeekdays: scheduleDraft.selectedWeekdays.sorted(by: { $0.rawValue < $1.rawValue }),
            intervalDayCount: normalizedInterval
        )

        guard let category = selectedCategory else {
            throw CreationError.missingCategory
        }
        let normalizedCustomLabel = normalizedCustomCategoryLabel
        if category == .custom, normalizedCustomLabel == nil {
            throw CreationError.missingCategory
        }

        let goal = TrackingGoal(
            title: trimmedTitle,
            description: goalDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            customCategoryLabel: category == .custom ? normalizedCustomLabel : nil,
            schedule: scheduleModel,
            createdAt: now,
            updatedAt: now
        )

        scheduleModel.goal = goal

        goal.questions = draftQuestions.map { question in
            question.goal = goal
            return question
        }

        modelContext.insert(goal)
        try modelContext.save()
        invalidateScheduleCache()
        metadata = [
            "questions": "\(goal.questions.count)",
            "times": "\(goal.schedule.times.count)",
            "category": goal.categoryDisplayName
        ]
        recentCustomCategories = GoalCreationViewModel.loadCustomCategories(from: modelContext)
        draftQuestions.removeAll()
        scheduleDraft = ScheduleDraft(startDate: dateProvider())
        title = ""
        goalDescription = ""
        selectedCategory = nil
        customCategoryLabel = ""
        return goal
    }

    private func activeSchedules(in timezone: TimeZone) -> [ScheduleSnapshot] {
        let trace = PerformanceMetrics.trace("GoalCreation.activeSchedules", metadata: ["timezone": timezone.identifier])
        let now = dateProvider()
        if let cache = cachedSchedules,
           now.timeIntervalSince(cache.timestamp) < Self.scheduleCacheTTL,
           let snapshots = cache.schedulesByTimezone[timezone.identifier] {
            trace.end(extraMetadata: [
                "source": "cache",
                "count": "\(snapshots.count)"
            ])
            return snapshots
        }

        var descriptor = FetchDescriptor<TrackingGoal>(predicate: #Predicate { goal in
            goal.isActive
        })
        descriptor.includePendingChanges = true
        let fetchedGoals = (try? modelContext.fetch(descriptor)) ?? []
        let snapshots = fetchedGoals
            .filter { !$0.schedule.times.isEmpty }
            .map { goal in
                ScheduleSnapshot(
                    goalID: goal.id,
                    title: goal.title,
                    timezoneIdentifier: goal.schedule.timezoneIdentifier,
                    times: goal.schedule.times
                )
            }

        let grouped = Dictionary(grouping: snapshots, by: \.timezoneIdentifier)
        cachedSchedules = ScheduleCache(timestamp: now, schedulesByTimezone: grouped)
        let result = grouped[timezone.identifier] ?? []
        trace.end(extraMetadata: [
            "source": "fetch",
            "count": "\(result.count)",
            "fetchedGoals": "\(fetchedGoals.count)"
        ])
        return result
    }

    private func invalidateScheduleCache() {
        cachedSchedules = nil
    }
}

extension GoalCreationViewModel {
    static func loadCustomCategories(from context: ModelContext) -> [String] {
        let descriptor = FetchDescriptor<TrackingGoal>(predicate: #Predicate { goal in
            goal.customCategoryLabel != nil && goal.customCategoryLabel != ""
        })
        let goals = (try? context.fetch(descriptor)) ?? []
        let sorted = goals.sorted { $0.updatedAt > $1.updatedAt }
        var seen: Set<String> = []
        var labels: [String] = []
        for goal in sorted {
            guard let raw = goal.customCategoryLabel?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { continue }
            let key = raw.lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                labels.append(raw)
            }
        }
        return labels
    }
}

private struct ScheduleSnapshot: Sendable {
    let goalID: UUID
    let title: String
    let timezoneIdentifier: String
    let times: [ScheduleTime]
}

private struct ScheduleCache {
    let timestamp: Date
    let schedulesByTimezone: [String: [ScheduleSnapshot]]
}
