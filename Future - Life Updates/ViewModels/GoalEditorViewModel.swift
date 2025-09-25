import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class GoalEditorViewModel {
    private enum Constants {
        static let minimumReminderSpacing: TimeInterval = 5 * 60
        static let defaultIntervalDays: Int = 3
    }
    enum UpdateError: LocalizedError {
        case missingTitle
        case missingQuestions

        var errorDescription: String? {
            switch self {
            case .missingTitle:
                return "Please enter a goal title before saving."
            case .missingQuestions:
                return "Keep at least one question active before saving."
            }
        }
    }

    struct QuestionDraft: Identifiable, Equatable {
        let id: UUID
        var question: Question?
        var text: String
        var responseType: ResponseType
        var isActive: Bool
        var options: [String]
        var validationRules: ValidationRules?

        init(question: Question) {
            self.id = question.id
            self.question = question
            self.text = question.text
            self.responseType = question.responseType
            self.isActive = question.isActive
            self.options = question.options ?? []
            self.validationRules = question.validationRules
        }

        init(text: String, responseType: ResponseType) {
            self.id = UUID()
            self.question = nil
            self.text = text
            self.responseType = responseType
            self.isActive = true
            self.options = []
            self.validationRules = nil
        }
    }

    struct ScheduleDraft: Sendable {
        var startDate: Date
        var frequency: Frequency
        var times: [ScheduleTime]
        var endDate: Date?
        var timezone: TimeZone
        var selectedWeekdays: Set<Weekday>
        var intervalDayCount: Int?
    }

    private let modelContext: ModelContext
    private let dateProvider: () -> Date
    private let calendar: Calendar

    private(set) var goal: TrackingGoal

    var title: String
    var goalDescription: String
    var selectedCategory: TrackingCategory
    var customCategoryLabel: String
    var questionDrafts: [QuestionDraft]
    var scheduleDraft: ScheduleDraft
    var recentCustomCategories: [String]

    private var normalizedCustomCategoryLabel: String? {
        let trimmed = customCategoryLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var primaryCategoryOptions: [GoalCreationViewModel.CategoryOption] {
        Array(allCategoryOptions.prefix(GoalCreationViewModel.primaryCategoryLimit))
    }

    var overflowCategoryOptions: [GoalCreationViewModel.CategoryOption] {
        Array(allCategoryOptions.dropFirst(GoalCreationViewModel.primaryCategoryLimit))
    }

    init(
        goal: TrackingGoal,
        modelContext: ModelContext,
        calendar: Calendar = .current,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.goal = goal
        self.modelContext = modelContext
        self.calendar = calendar
        self.dateProvider = dateProvider

        self.title = goal.title
        self.goalDescription = goal.goalDescription
        self.selectedCategory = goal.category
        self.customCategoryLabel = goal.customCategoryLabel ?? ""
        self.recentCustomCategories = GoalCreationViewModel.loadCustomCategories(from: modelContext)
        self.questionDrafts = goal.questions.map { QuestionDraft(question: $0) }

        let schedule = goal.schedule
        let timezone = schedule.timezone
        self.scheduleDraft = ScheduleDraft(
            startDate: schedule.startDate,
            frequency: schedule.frequency,
            times: schedule.times,
            endDate: schedule.endDate,
            timezone: timezone,
            selectedWeekdays: Set(schedule.selectedWeekdays),
            intervalDayCount: schedule.intervalDayCount
        )
    }

    func addQuestion(
        text: String,
        responseType: ResponseType,
        options: [String]? = nil,
        validationRules: ValidationRules? = nil
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var draft = QuestionDraft(text: trimmed, responseType: responseType)
        if let options, !options.isEmpty {
            draft.options = options
        }
        draft.validationRules = validationRules
        questionDrafts.append(draft)
    }

    func removeDraft(_ draft: QuestionDraft) {
        questionDrafts.removeAll { $0.id == draft.id }
    }

    @discardableResult
    func updateScheduleTime(at index: Int, to date: Date) -> Bool {
        guard scheduleDraft.times.indices.contains(index) else { return false }
        var components = calendar.dateComponents([.hour, .minute], from: date)
        components.second = 0
        guard let updatedTime = ScheduleTime(components: components).validated() else { return false }

        var times = scheduleDraft.times
        let removed = times.remove(at: index)

        if times.contains(where: { $0.isWithin(window: Constants.minimumReminderSpacing, of: updatedTime) }) {
            times.insert(removed, at: index)
            return false
        }

        times.append(updatedTime)
        scheduleDraft.times = times.sorted(by: { $0.totalMinutes < $1.totalMinutes })
        return true
    }

    func addScheduleTime(from date: Date) -> Bool {
        var components = calendar.dateComponents([.hour, .minute], from: date)
        components.second = 0
        guard let newTime = ScheduleTime(components: components).validated() else { return false }

        if scheduleDraft.times.contains(where: { $0.isWithin(window: Constants.minimumReminderSpacing, of: newTime) }) {
            return false
        }

        if !scheduleDraft.times.contains(newTime) {
            scheduleDraft.times.append(newTime)
            scheduleDraft.times.sort(by: { $0.totalMinutes < $1.totalMinutes })
        }
        return true
    }

    func removeScheduleTime(at index: Int) {
        guard scheduleDraft.times.indices.contains(index) else { return }
        scheduleDraft.times.remove(at: index)
    }

    func removeScheduleTime(_ time: ScheduleTime) {
        scheduleDraft.times.removeAll { $0 == time }
    }

    func selectCategory(_ option: GoalCreationViewModel.CategoryOption) {
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
        if !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            selectedCategory = .custom
        }
    }

    func setFrequency(_ frequency: Frequency) {
        scheduleDraft.frequency = frequency
        switch frequency {
        case .weekly:
            if scheduleDraft.selectedWeekdays.isEmpty {
                let weekdayValue = calendar.component(.weekday, from: dateProvider())
                if let weekday = Weekday(rawValue: weekdayValue) {
                    scheduleDraft.selectedWeekdays = [weekday]
                }
            }
            scheduleDraft.intervalDayCount = nil
        case .custom:
            scheduleDraft.selectedWeekdays.removeAll()
            if scheduleDraft.intervalDayCount == nil {
                scheduleDraft.intervalDayCount = Constants.defaultIntervalDays
            }
        default:
            scheduleDraft.selectedWeekdays.removeAll()
            scheduleDraft.intervalDayCount = nil
        }
    }

    func updateSelectedWeekdays(_ weekdays: Set<Weekday>) {
        scheduleDraft.selectedWeekdays = weekdays
    }

    func updateIntervalDayCount(_ interval: Int?) {
        guard let interval else {
            scheduleDraft.intervalDayCount = nil
            return
        }
        scheduleDraft.intervalDayCount = max(2, interval)
    }

    func setTimezone(_ timezone: TimeZone) {
        scheduleDraft.timezone = timezone
    }

    func conflictDescription(window: TimeInterval = Constants.minimumReminderSpacing) -> String? {
        guard !scheduleDraft.times.isEmpty else { return nil }

        let currentGoalID = goal.id
        let descriptor = FetchDescriptor<TrackingGoal>(predicate: #Predicate { candidate in
            candidate.isActive && candidate.id != currentGoalID
        })

        let activeGoals = (try? modelContext.fetch(descriptor)) ?? []
        for candidateGoal in activeGoals {
            guard candidateGoal.schedule.timezoneIdentifier == scheduleDraft.timezone.identifier else { continue }
            for existingTime in candidateGoal.schedule.times {
                for newTime in scheduleDraft.times where existingTime.isWithin(window: window, of: newTime) {
                    return "Clashes with \(candidateGoal.title) near \(existingTime.formattedTime(in: scheduleDraft.timezone))."
                }
            }
        }
        return nil
    }

    func reminderDate(for scheduleTime: ScheduleTime) -> Date {
        var components = scheduleTime.dateComponents
        components.year = 2000
        components.month = 1
        components.day = 1
        var calendar = self.calendar
        calendar.timeZone = scheduleDraft.timezone
        return calendar.date(from: components) ?? dateProvider()
    }

    @discardableResult
    func saveChanges() throws -> TrackingGoal {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { throw UpdateError.missingTitle }

        let activeDrafts = questionDrafts.filter { draft in
            let text = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return draft.isActive && !text.isEmpty
        }
        guard !activeDrafts.isEmpty else { throw UpdateError.missingQuestions }

        goal.title = trimmedTitle
        goal.goalDescription = goalDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        goal.category = selectedCategory
        if selectedCategory == .custom {
            let trimmedLabel = customCategoryLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            goal.customCategoryLabel = trimmedLabel.isEmpty ? nil : trimmedLabel
        } else {
            goal.customCategoryLabel = nil
        }

        goal.schedule.startDate = scheduleDraft.startDate
        goal.schedule.frequency = scheduleDraft.frequency
    goal.schedule.times = scheduleDraft.times.sorted(by: { $0.totalMinutes < $1.totalMinutes })
        goal.schedule.endDate = scheduleDraft.endDate
        goal.schedule.timezoneIdentifier = scheduleDraft.timezone.identifier
    goal.schedule.selectedWeekdays = scheduleDraft.selectedWeekdays.sorted { $0.rawValue < $1.rawValue }
    goal.schedule.intervalDayCount = scheduleDraft.intervalDayCount

        let draftIDs = Set(questionDrafts.map { $0.id })
        for question in goal.questions where !draftIDs.contains(question.id) {
            modelContext.delete(question)
        }

        var updatedQuestions: [Question] = []
        for var draft in questionDrafts {
            let trimmedText = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty else { continue }

            if let question = draft.question {
                question.text = trimmedText
                question.responseType = draft.responseType
                question.isActive = draft.isActive
                question.options = draft.options.isEmpty ? nil : draft.options
                question.validationRules = draft.validationRules
                updatedQuestions.append(question)
            } else {
                let newQuestion = Question(
                    text: trimmedText,
                    responseType: draft.responseType,
                    isActive: draft.isActive,
                    options: draft.options.isEmpty ? nil : draft.options,
                    validationRules: draft.validationRules
                )
                newQuestion.goal = goal
                updatedQuestions.append(newQuestion)
                modelContext.insert(newQuestion)
            }
        }

        goal.questions = updatedQuestions
        goal.bumpUpdatedAt(to: dateProvider())
        recentCustomCategories = GoalCreationViewModel.loadCustomCategories(from: modelContext)

        try modelContext.save()
        return goal
    }
}

private extension GoalEditorViewModel {
    var normalizedCustomCategories: [String] {
        var categories = recentCustomCategories
        if let active = normalizedCustomCategoryLabel,
            !categories.contains(where: { $0.caseInsensitiveCompare(active) == .orderedSame }) {
            categories.insert(active, at: 0)
        }
        return categories
    }

    var allCategoryOptions: [GoalCreationViewModel.CategoryOption] {
        var systemOptions = TrackingCategory.allCases
            .filter { $0 != .custom }
            .map { GoalCreationViewModel.CategoryOption.system($0) }
        let customOptions = normalizedCustomCategories.map { GoalCreationViewModel.CategoryOption.custom($0) }
        systemOptions.append(contentsOf: customOptions)
        return systemOptions
    }
}
