import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class GoalCreationViewModel {
    enum CreationError: LocalizedError {
        case missingTitle
        case missingQuestions

        var errorDescription: String? {
            switch self {
            case .missingTitle:
                return "Please provide a goal title before saving."
            case .missingQuestions:
                return "Add at least one question to track before creating this goal."
            }
        }
    }

    struct ScheduleDraft {
        var startDate: Date
        var frequency: Frequency
        var times: [ScheduleTime]
        var timezone: TimeZone

        init(
            startDate: Date = Date(),
            frequency: Frequency = .daily,
            times: [ScheduleTime] = [],
            timezone: TimeZone = .current
        ) {
            self.startDate = startDate
            self.frequency = frequency
            self.times = times
            self.timezone = timezone
        }
    }

    private let modelContext: ModelContext
    private let dateProvider: () -> Date

    var title: String = ""
    var goalDescription: String = ""
    var selectedCategory: TrackingCategory = .custom
    private(set) var draftQuestions: [Question] = []
    private(set) var scheduleDraft: ScheduleDraft

    init(modelContext: ModelContext, dateProvider: @escaping () -> Date = Date.init) {
        self.modelContext = modelContext
        self.dateProvider = dateProvider
        self.scheduleDraft = ScheduleDraft(startDate: dateProvider())
    }

    @discardableResult
    func addManualQuestion(
        text: String,
        responseType: ResponseType,
        options: [String]? = nil,
        validationRules: ValidationRules? = nil
    ) -> Question {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let question = Question(
            text: trimmed,
            responseType: responseType,
            options: options?.isEmpty == true ? nil : options,
            validationRules: validationRules
        )
        draftQuestions.append(question)
        return question
    }

    func removeQuestion(_ question: Question) {
        draftQuestions.removeAll { $0.id == question.id }
    }

    func updateSchedule(
        frequency: Frequency,
        times: [DateComponents],
        timezone: TimeZone,
        startDate: Date? = nil
    ) {
        scheduleDraft = ScheduleDraft(
            startDate: startDate ?? dateProvider(),
            frequency: frequency,
            times: times.map { ScheduleTime(components: $0) },
            timezone: timezone
        )
    }

    func createGoal() throws -> TrackingGoal {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { throw CreationError.missingTitle }
        guard !draftQuestions.isEmpty else { throw CreationError.missingQuestions }

        let now = dateProvider()
        let scheduleModel = Schedule(
            startDate: scheduleDraft.startDate,
            frequency: scheduleDraft.frequency,
            times: scheduleDraft.times,
            endDate: nil,
            timezoneIdentifier: scheduleDraft.timezone.identifier
        )

        let goal = TrackingGoal(
            title: trimmedTitle,
            description: goalDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            category: selectedCategory,
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
        draftQuestions.removeAll()
        scheduleDraft = ScheduleDraft(startDate: dateProvider())
        title = ""
        goalDescription = ""
        selectedCategory = .custom
        return goal
    }
}
