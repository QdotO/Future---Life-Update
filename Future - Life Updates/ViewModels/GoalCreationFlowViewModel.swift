import Foundation
import SwiftData
import SwiftUI

private enum GoalCreationFlowViewModelConstants {
    static let suggestionLimit: Int = 3
}

@MainActor
@Observable
final class GoalCreationFlowViewModel {
    private struct SuggestionInput: Equatable {
        let title: String
        let description: String
        let limit: Int
    }

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
    private var suggestionService: GoalSuggestionServing?
    @ObservationIgnored private var suggestionTask: Task<Void, Never>?
    private var lastSuggestionInput: SuggestionInput?

    var draft: GoalDraft
    private(set) var appliedTemplateIDs: Set<String>
    private(set) var appliedSuggestionIDs: Set<UUID>
    var suggestions: [GoalSuggestion]
    var suggestionError: String?
    var isLoadingSuggestions: Bool
    var suggestionProviderName: String?
    var suggestionAvailability: GoalSuggestionAvailabilityStatus

    var conflictMessage: String? {
        syncLegacySchedule()
        return legacy.conflictDescription()
    }

    init(
        legacyViewModel: GoalCreationViewModel,
        calendar: Calendar = .current,
        dateProvider: @escaping () -> Date = Date.init,
        suggestionService: GoalSuggestionServing? = nil
    ) {
        self.legacy = legacyViewModel
        self.calendar = calendar
        self.dateProvider = dateProvider
    self.suggestionService = suggestionService
    let shouldCreateService = suggestionService == nil
        self.suggestionAvailability = .unknown
        self.appliedTemplateIDs = []
        self.appliedSuggestionIDs = []
        self.suggestions = []
        self.suggestionError = nil
        self.isLoadingSuggestions = false
        self.suggestionProviderName = nil

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
                    templateID: nil,
                    suggestionID: nil
                )
            }
        }

        syncAppliedQuestionSources()
        refreshSuggestionEnvironment(allowRecreation: shouldCreateService)
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

    func updateTitle(_ text: String) {
        guard draft.title != text else { return }
        draft.title = text
        resetSuggestionState()
    }

    func updateMotivation(_ text: String) {
        guard draft.motivation != text else { return }
        draft.motivation = text
        resetSuggestionState()
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
            templateID: template.id,
            suggestionID: nil
        )
        draft.questionDrafts.append(question)
        syncAppliedQuestionSources()
    }

    func addCustomQuestion(_ draftQuestion: GoalQuestionDraft) {
        draft.questionDrafts.append(draftQuestion)
        syncAppliedQuestionSources()
    }

    func updateQuestion(_ question: GoalQuestionDraft) {
        guard let index = draft.questionDrafts.firstIndex(where: { $0.id == question.id }) else { return }
        draft.questionDrafts[index] = question
        syncAppliedQuestionSources()
    }

    func removeQuestion(_ questionID: UUID) {
        draft.questionDrafts.removeAll { $0.id == questionID }
        syncAppliedQuestionSources()
    }

    func reorderQuestions(fromOffsets: IndexSet, toOffset: Int) {
        draft.questionDrafts.move(fromOffsets: fromOffsets, toOffset: toOffset)
        syncAppliedQuestionSources()
    }

    func selectCategory(_ category: TrackingCategory) {
        let previous = draft.category
        draft.category = category
        if category != .custom {
            draft.customCategoryLabel = ""
        }
        if previous != category {
            resetSuggestionState()
        }
    }

    func updateCustomCategoryLabel(_ text: String) {
        let previousLabel = draft.customCategoryLabel
        let previousCategory = draft.category
        draft.customCategoryLabel = text
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            draft.category = .custom
        }
        if previousLabel != text || previousCategory != draft.category {
            resetSuggestionState()
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
        appliedSuggestionIDs.removeAll()
        resetSuggestionState()
        refreshDraftSchedule()
        return goal
    }

    func resetDraft() {
        draft = GoalDraft()
        appliedTemplateIDs.removeAll()
        appliedSuggestionIDs.removeAll()
        resetSuggestionState()
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
        syncAppliedQuestionSources()
    }

    private func makeSuggestionContext(from description: String) -> String {
        var sections: [String] = []
        if !description.isEmpty {
            sections.append(description)
        }
        if let category = draft.category {
            sections.append("Category: \(category.displayName)")
        }
        let cadenceSummary: String = {
            switch draft.schedule.cadence {
            case .daily:
                return "Cadence: Daily"
            case .weekdays:
                return "Cadence: Weekdays"
            case .weekly(let weekday):
                return "Cadence: Weekly on \(weekday.displayName)"
            case .custom(let interval):
                return "Cadence: Every \(interval) days"
            }
        }()
        sections.append(cadenceSummary)

        if !draft.questionDrafts.isEmpty {
            let existing = draft.questionDrafts
                .map { "- \($0.trimmedText)" }
                .joined(separator: "\n")
            sections.append("Existing prompts:\n\(existing)")
        }

        return sections.joined(separator: "\n\n")
    }

    private func filterSuggestions(_ candidates: [GoalSuggestion]) -> [GoalSuggestion] {
        let existingPrompts = Set(draft.questionDrafts.map { $0.trimmedText.lowercased() })
        return candidates.filter { suggestion in
            let normalized = suggestion.prompt.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalized.isEmpty else { return false }
            return !existingPrompts.contains(normalized)
        }
    }

    private func resetSuggestionState() {
        suggestionTask?.cancel()
        suggestionTask = nil
        suggestions = []
        suggestionError = nil
        isLoadingSuggestions = false
        lastSuggestionInput = nil
        refreshSuggestionEnvironment(allowRecreation: true)
    }

    private func refreshSuggestionEnvironment(allowRecreation: Bool) {
        let status = GoalSuggestionAvailability.currentStatus()
        if allowRecreation, suggestionService == nil, case .available = status {
            suggestionService = GoalSuggestionServiceFactory.makeLive()
        }
        suggestionAvailability = status
        if let provider = suggestionService?.providerName {
            suggestionProviderName = provider
        } else if case .available(let provider) = status {
            suggestionProviderName = provider
        } else {
            suggestionProviderName = nil
        }
    }

    private func syncAppliedQuestionSources() {
        appliedTemplateIDs = Set(draft.questionDrafts.compactMap { $0.templateID })
        appliedSuggestionIDs = Set(draft.questionDrafts.compactMap { $0.suggestionID })
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

    deinit {
        suggestionTask?.cancel()
    }

    var supportsSuggestions: Bool {
        if case .available = suggestionAvailability, suggestionService != nil {
            return true
        }
        return false
    }

    var suggestionAvailabilityMessage: String? {
        if case .available = suggestionAvailability {
            return suggestionService == nil ? "Suggestions are unavailable right now." : nil
        }
        return GoalSuggestionAvailability.message(for: suggestionAvailability)
    }

    @MainActor
    func loadSuggestions(limit: Int = GoalCreationFlowViewModelConstants.suggestionLimit, force: Bool = false) {
        suggestionTask?.cancel()
        suggestionTask = Task { @MainActor [weak self] in
            await self?.refreshSuggestions(limit: limit, force: force)
        }
    }

    @MainActor
    func refreshSuggestions(limit: Int = GoalCreationFlowViewModelConstants.suggestionLimit, force: Bool = false) async {
        refreshSuggestionEnvironment(allowRecreation: true)

        guard let service = suggestionService else {
            suggestionError = suggestionAvailabilityMessage
            suggestions = []
            return
        }

        let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = draft.motivation.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty || !trimmedDescription.isEmpty else {
            suggestions = []
            suggestionError = GoalSuggestionError.missingInput.errorDescription
            lastSuggestionInput = nil
            return
        }

        let enrichedDescription = makeSuggestionContext(from: trimmedDescription)
        let input = SuggestionInput(title: trimmedTitle, description: enrichedDescription, limit: max(1, limit))

        if !force, input == lastSuggestionInput, !suggestions.isEmpty {
            return
        }

        isLoadingSuggestions = true
        suggestionError = nil

        do {
            let results = try await service.suggestions(title: input.title, description: input.description, limit: input.limit)
            let filtered = filterSuggestions(results)
            suggestions = Array(filtered.prefix(GoalCreationFlowViewModelConstants.suggestionLimit))
            lastSuggestionInput = input
            if suggestions.isEmpty {
                suggestionError = GoalSuggestionError.emptyPayload.errorDescription
            }
        } catch let error as GoalSuggestionError {
            suggestionError = error.errorDescription
            suggestions = []
            lastSuggestionInput = nil
        } catch {
            suggestionError = error.localizedDescription
            suggestions = []
            lastSuggestionInput = nil
        }

        isLoadingSuggestions = false
    }

    func applySuggestion(_ suggestion: GoalSuggestion) {
        let normalizedOptions = suggestion.options.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let question = GoalQuestionDraft(
            text: suggestion.prompt,
            responseType: suggestion.responseType,
            options: normalizedOptions,
            validationRules: suggestion.validationRules,
            isActive: true,
            templateID: nil,
            suggestionID: suggestion.id
        )
        draft.questionDrafts.append(question)
        suggestions.removeAll { $0.id == suggestion.id }
        syncAppliedQuestionSources()
    }
}
