import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class GoalEditorViewModel {
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
    }

    private let modelContext: ModelContext
    private let dateProvider: () -> Date
    private let calendar: Calendar

    private(set) var goal: TrackingGoal

    var title: String
    var goalDescription: String
    var selectedCategory: TrackingCategory
    var questionDrafts: [QuestionDraft]
    var scheduleDraft: ScheduleDraft

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
        self.questionDrafts = goal.questions.map { QuestionDraft(question: $0) }

        let schedule = goal.schedule
        let timezone = schedule.timezone
        self.scheduleDraft = ScheduleDraft(
            startDate: schedule.startDate,
            frequency: schedule.frequency,
            times: schedule.times,
            endDate: schedule.endDate,
            timezone: timezone
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

    func updateScheduleTime(at index: Int, to date: Date) {
        guard scheduleDraft.times.indices.contains(index) else { return }
        let components = calendar.dateComponents([.hour, .minute], from: date)
        scheduleDraft.times[index] = ScheduleTime(components: components)
    }

    func addScheduleTime(from date: Date) {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let scheduleTime = ScheduleTime(components: components)
        if !scheduleDraft.times.contains(scheduleTime) {
            scheduleDraft.times.append(scheduleTime)
        }
    }

    func removeScheduleTime(at index: Int) {
        guard scheduleDraft.times.indices.contains(index) else { return }
        scheduleDraft.times.remove(at: index)
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

        goal.schedule.startDate = scheduleDraft.startDate
        goal.schedule.frequency = scheduleDraft.frequency
        goal.schedule.times = scheduleDraft.times
        goal.schedule.endDate = scheduleDraft.endDate
        goal.schedule.timezoneIdentifier = scheduleDraft.timezone.identifier

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

        try modelContext.save()
        return goal
    }
}
