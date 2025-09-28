import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class GoalCreationFlowViewModel {
    enum FlowError: LocalizedError {
        case missingTitle
        case missingCategory
        case missingQuestions
        case missingReminder

        var errorDescription: String? {
            switch self {
            case .missingTitle:
                return "Give your goal a title before continuing."
            case .missingCategory:
                return "Choose a category so we can tailor prompts and reminders."
            case .missingQuestions:
                return "Add at least one question to track your progress."
            case .missingReminder:
                return "Pick at least one reminder time to stay on track."
            }
        }
    }

    private let legacy: GoalCreationViewModel
    private let calendar: Calendar
    private let dateProvider: () -> Date

    var draft: GoalDraft
    private(set) var appliedTemplateIDs: Set<String>

    var conflictMessage: String? {
        syncLegacySchedule()
        return legacy.conflictDescription()
    }

    init(
        legacyViewModel: GoalCreationViewModel,
        calendar: Calendar = .current,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.legacy = legacyViewModel
        self.calendar = calendar
        self.dateProvider = dateProvider
        self.appliedTemplateIDs = []

    let cadence = Self.cadence(from: legacyViewModel.scheduleDraft, calendar: calendar, nowProvider: dateProvider)
        let initialSchedule = GoalScheduleDraft(
            cadence: cadence,
            reminderTimes: legacyViewModel.scheduleDraft.times,
            timezone: legacyViewModel.scheduleDraft.timezone,
            startDate: legacyViewModel.scheduleDraft.startDate
        )

        self.draft = GoalDraft(
            title: legacyViewModel.title,
            motivation: legacyViewModel.goalDescription,
            category: legacyViewModel.selectedCategory,
            customCategoryLabel: legacyViewModel.customCategoryLabel,
            questionDrafts: [],
            schedule: initialSchedule,
            celebrationMessage: "",
            accountabilityContact: nil
        )

        if !legacyViewModel.draftQuestions.isEmpty {
            draft.questionDrafts = legacyViewModel.draftQuestions.map { question in
                GoalQuestionDraft(
                    id: question.id,
                    text: question.text,
                    responseType: question.responseType,
                    options: question.options ?? [],
                    validationRules: question.validationRules,
                    isActive: question.isActive,
                    templateID: nil
                )
            }
            rebuildAppliedTemplateIDs()
        }
    }

    func recommendedTemplates(limit: Int = 3) -> [PromptTemplate] {
        let available = GoalCreationCatalog.templates(for: draft.category)
        let filtered = available.filter { !appliedTemplateIDs.contains($0.id) }
        return Array(filtered.prefix(limit))
    }

    func additionalTemplates(excluding ids: Set<String>) -> [PromptTemplate] {
        GoalCreationCatalog.additionalTemplates(for: draft.category, excluding: ids.union(appliedTemplateIDs))
    }

    func cadencePresets() -> [CadencePreset] {
        GoalCreationCatalog.cadencePresets
    }

    func applyTemplate(_ template: PromptTemplate) {
        guard !appliedTemplateIDs.contains(template.id) else { return }
        let blueprint = template.blueprint
        let question = GoalQuestionDraft(
            text: blueprint.text,
            responseType: blueprint.responseType,
            options: blueprint.options ?? [],
            validationRules: blueprint.validationRules,
            isActive: true,
            templateID: template.id
        )
        draft.questionDrafts.append(question)
        rebuildAppliedTemplateIDs()
    }

    func addCustomQuestion(_ draftQuestion: GoalQuestionDraft) {
        draft.questionDrafts.append(draftQuestion)
        rebuildAppliedTemplateIDs()
    }

    func updateQuestion(_ question: GoalQuestionDraft) {
        guard let index = draft.questionDrafts.firstIndex(where: { $0.id == question.id }) else { return }
        draft.questionDrafts[index] = question
        rebuildAppliedTemplateIDs()
    }

    func removeQuestion(_ questionID: UUID) {
        draft.questionDrafts.removeAll { $0.id == questionID }
        rebuildAppliedTemplateIDs()
    }

    func reorderQuestions(fromOffsets: IndexSet, toOffset: Int) {
        draft.questionDrafts.move(fromOffsets: fromOffsets, toOffset: toOffset)
        rebuildAppliedTemplateIDs()
    }

    func selectCategory(_ category: TrackingCategory) {
        draft.category = category
        if category != .custom {
            draft.customCategoryLabel = ""
        }
    }

    func updateCustomCategoryLabel(_ text: String) {
        draft.customCategoryLabel = text
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft.category = .custom
        }
    }

    func selectCadence(_ cadence: GoalCadence) {
        draft.schedule.cadence = cadence
        syncLegacySchedule()
        refreshDraftSchedule()
    }

    func updateCustomInterval(days: Int) {
        draft.schedule.cadence = .custom(intervalDays: max(2, days))
        syncLegacySchedule()
        refreshDraftSchedule()
    }

    func recommendedReminderTimes() -> [ScheduleTime] {
        GoalCreationCatalog.recommendedTimes(for: draft.schedule.cadence, timezone: draft.schedule.timezone, now: dateProvider())
    }

    @discardableResult
    func toggleReminderTime(_ time: ScheduleTime) -> Bool {
        if draft.schedule.reminderTimes.contains(time) {
            removeReminderTime(time)
            return true
        } else {
            return addReminderTime(time)
        }
    }

    @discardableResult
    func addReminderTime(_ time: ScheduleTime) -> Bool {
        if draft.schedule.reminderTimes.count >= 3, !draft.schedule.reminderTimes.contains(time) {
            return false
        }
        guard let date = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: dateProvider()) else {
            return false
        }
        syncLegacySchedule()
        let succeeded = legacy.addScheduleTime(from: date, calendar: calendar)
        refreshDraftSchedule()
        return succeeded
    }

    func addReminderDate(_ date: Date) -> Bool {
        syncLegacySchedule()
        let succeeded = legacy.addScheduleTime(from: date, calendar: calendar)
        refreshDraftSchedule()
        return succeeded
    }

    func removeReminderTime(_ time: ScheduleTime) {
        syncLegacySchedule()
        legacy.removeScheduleTime(time)
        refreshDraftSchedule()
    }

    func updateTimezone(_ timezone: TimeZone) {
        draft.schedule.timezone = timezone
        syncLegacySchedule()
        refreshDraftSchedule()
    }

    func suggestedReminderDate(startingAt date: Date? = nil) -> Date {
        syncLegacySchedule()
        return legacy.suggestedReminderDate(startingAt: date)
    }

    func canAdvanceFromDetails() -> Bool {
        let trimmed = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard let category = draft.category else { return false }
        if category == .custom {
            return draft.normalizedCustomCategoryLabel != nil
        }
        return true
    }

    func canAdvanceFromQuestions() -> Bool {
        draft.questionDrafts.contains(where: { $0.hasContent })
    }

    func canAdvanceFromSchedule() -> Bool {
        !draft.schedule.reminderTimes.isEmpty
    }

    func saveGoal() throws -> TrackingGoal {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw FlowError.missingTitle }
        guard let category = draft.category else { throw FlowError.missingCategory }
        guard draft.questionDrafts.contains(where: { $0.hasContent }) else { throw FlowError.missingQuestions }
        guard !draft.schedule.reminderTimes.isEmpty else { throw FlowError.missingReminder }

        legacy.title = title
        let motivation = draft.motivation.trimmingCharacters(in: .whitespacesAndNewlines)
        let celebration = draft.celebrationMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptionParts = [motivation, celebration].filter { !$0.isEmpty }
        legacy.goalDescription = descriptionParts.joined(separator: "\n\n")
        legacy.selectedCategory = category
        legacy.customCategoryLabel = draft.customCategoryLabel

        legacy.replaceDraftQuestions(with: draft.questionDrafts.map { question in
            Question(
                text: question.trimmedText,
                responseType: question.responseType,
                isActive: question.isActive,
                options: question.options.isEmpty ? nil : question.options,
                validationRules: question.validationRules
            )
        })

        syncLegacySchedule()
        let goal = try legacy.createGoal()

        draft = GoalDraft()
        appliedTemplateIDs.removeAll()
        refreshDraftSchedule()
        return goal
    }

    func resetDraft() {
        draft = GoalDraft()
        appliedTemplateIDs.removeAll()
        legacy.replaceDraftQuestions(with: [])
        legacy.replaceTimes([])
        legacy.setFrequency(.daily)
        legacy.updateSelectedWeekdays([])
        legacy.updateIntervalDayCount(nil)
        legacy.setTimezone(TimeZone.current)
        legacy.setStartDate(dateProvider())
        refreshDraftSchedule()
    }

    private func syncLegacySchedule() {
        legacy.setTimezone(draft.schedule.timezone)
        legacy.setStartDate(draft.schedule.startDate)
        legacy.setFrequency(draft.schedule.cadence.frequency)
        legacy.updateSelectedWeekdays(draft.schedule.cadence.selectedWeekdays)
        legacy.updateIntervalDayCount(draft.schedule.cadence.intervalDayCount)
        legacy.replaceTimes(draft.schedule.reminderTimes)
    }

    private func refreshDraftSchedule() {
    let cadence = Self.cadence(from: legacy.scheduleDraft, calendar: calendar, nowProvider: dateProvider)
        draft.schedule = GoalScheduleDraft(
            cadence: cadence,
            reminderTimes: legacy.scheduleDraft.times,
            timezone: legacy.scheduleDraft.timezone,
            startDate: legacy.scheduleDraft.startDate
        )
        rebuildAppliedTemplateIDs()
    }

    private func rebuildAppliedTemplateIDs() {
        appliedTemplateIDs = Set(draft.questionDrafts.compactMap { $0.templateID })
    }

    private static func cadence(
        from scheduleDraft: GoalCreationViewModel.ScheduleDraft,
        calendar: Calendar,
        nowProvider: () -> Date
    ) -> GoalCadence {
        switch scheduleDraft.frequency {
        case .custom:
            let interval = scheduleDraft.intervalDayCount ?? 3
            return .custom(intervalDays: max(2, interval))
        case .weekly:
            let weekdays = scheduleDraft.selectedWeekdays
            let weekdaySet = Set(weekdays)
            let workweek: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
            if weekdaySet == workweek {
                return .weekdays
            } else if let first = weekdays.first {
                return .weekly(first)
            } else {
                let todayValue = calendar.component(.weekday, from: nowProvider())
                let fallback = Weekday(rawValue: todayValue) ?? .sunday
                return .weekly(fallback)
            }
        default:
            return .daily
        }
    }
}
