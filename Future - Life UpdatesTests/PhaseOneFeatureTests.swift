import Foundation
import Testing
import SwiftData
import Observation
@testable import Future___Life_Updates

@MainActor
struct PhaseOneFeatureTests {
    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([
            TrackingGoal.self,
            Question.self,
            Schedule.self,
            DataPoint.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    @Test("TrackingGoal initializes with expected defaults")
    func trackingGoalInitializationDefaults() throws {
        let goal = TrackingGoal(title: "Hydration", description: "Drink more water", category: .health)

        #expect(goal.isActive)
        #expect(goal.questions.isEmpty)
        #expect(goal.schedule.frequency == .daily)
        #expect(goal.schedule.times.isEmpty)
        #expect(goal.createdAt <= goal.updatedAt)
    }

    @Test("GoalCreationViewModel persists configured goal")
    func goalCreationPersistsGoalWithQuestions() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let fixedStartDate = Date(timeIntervalSince1970: 1000)
        let viewModel = GoalCreationViewModel(modelContext: context, dateProvider: { fixedStartDate })

        viewModel.title = "Hydration"
        viewModel.goalDescription = "Drink eight glasses"
        viewModel.selectedCategory = .health

        let question = viewModel.addManualQuestion(text: "How many glasses did you drink today?", responseType: .numeric)
        #expect(question.text == "How many glasses did you drink today?")

        viewModel.updateSchedule(
            frequency: .daily,
            times: [DateComponents(hour: 9, minute: 0)],
            timezone: TimeZone(identifier: "America/Los_Angeles")!
        )

        let persistedGoal = try viewModel.createGoal()
        try context.save()

        let persistedGoalID = persistedGoal.id
        let descriptor = FetchDescriptor<TrackingGoal>(predicate: #Predicate<TrackingGoal> { goal in
            goal.id == persistedGoalID
        }, sortBy: [SortDescriptor(\.createdAt)])
        let fetchedGoals = try context.fetch(descriptor)
        #expect(fetchedGoals.count == 1)

        guard let fetchedGoal = fetchedGoals.first else {
            Issue.record("Expected to fetch the created goal")
            return
        }

        #expect(fetchedGoal.questions.count == 1)
        #expect(fetchedGoal.schedule.times.count == 1)
        #expect(fetchedGoal.schedule.times.first?.hour == 9)
        #expect(fetchedGoal.schedule.timezoneIdentifier == "America/Los_Angeles")
        #expect(fetchedGoal.title == "Hydration")
        #expect(fetchedGoal.schedule.startDate == fixedStartDate)
    }

    @Test("DataEntryViewModel overwrites same-day responses")
    func dataEntryViewModelOverwritesSameDayResponses() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let fixedDate = Date(timeIntervalSince1970: 2000)

        let goal = TrackingGoal(title: "Hydration", description: "Daily water intake", category: .health)
        let question = Question(text: "How many glasses?", responseType: .numeric)
        goal.questions = [question]
        goal.schedule = Schedule()
        context.insert(goal)
        try context.save()

        let viewModel = DataEntryViewModel(goal: goal, modelContext: context, dateProvider: { fixedDate })
        viewModel.setNumericResponse(8, for: question)
        try viewModel.saveEntries()

        viewModel.setNumericResponse(10, for: question)
        try viewModel.saveEntries()
        let goalIdentifier = goal.persistentModelID
        let questionIdentifier = question.persistentModelID

        let descriptor = FetchDescriptor<DataPoint>(predicate: #Predicate<DataPoint> { dataPoint in
            dataPoint.goal?.persistentModelID == goalIdentifier &&
            dataPoint.question?.persistentModelID == questionIdentifier
        })
        let points = try context.fetch(descriptor)

        #expect(points.count == 1)
        #expect(points.first?.numericValue == 10)
        #expect(Calendar.current.isDate(points.first?.timestamp ?? .distantPast, inSameDayAs: fixedDate))
    }
}
