import AppIntents
import Foundation
import SwiftData
import Testing
@testable import Future___Life_Updates

@MainActor
struct PhaseThreeShortcutsTests {
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

    @Test("Quick log intent saves numeric data point")
    func quickLogIntentSavesDataPoint() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let goal = TrackingGoal(
            title: "Hydration",
            description: "Drink more water",
            category: .health
        )
        let question = Question(text: "Glasses consumed", responseType: .numeric)
        goal.questions = [question]
        goal.schedule = Schedule()
        question.goal = goal

        context.insert(goal)
        try context.save()

        let entity = GoalShortcutEntity(model: goal)
        let timestamp = Date(timeIntervalSince1970: 1_741_000_000)

        try await AppEnvironment.shared.withModelContext(context) {
            let intent = QuickLogGoalIntent(goal: entity, value: 16.5, entryDate: timestamp)
            _ = try await intent.perform()
        }

        let dataPoints = try context.fetch(FetchDescriptor<DataPoint>())

        #expect(dataPoints.count == 1)
        #expect(dataPoints.first?.numericValue == 16.5)
        #expect(dataPoints.first?.timestamp == timestamp)
        #expect(dataPoints.first?.goal?.id == goal.id)
        #expect(goal.updatedAt == timestamp)
    }

    @Test("Quick log intent errors when no numeric question exists")
    func quickLogIntentErrorsWithoutNumericQuestion() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let goal = TrackingGoal(
            title: "Journal",
            description: "Daily reflection",
            category: .habits
        )
        let question = Question(text: "What stood out today?", responseType: .text)
        goal.questions = [question]
        goal.schedule = Schedule()
        question.goal = goal

        context.insert(goal)
        try context.save()

        let entity = GoalShortcutEntity(model: goal)

        try await AppEnvironment.shared.withModelContext(context) {
            let intent = QuickLogGoalIntent(goal: entity, value: 2, entryDate: Date())
            await #expect(throws: QuickLogIntentError.missingNumericQuestion) {
                _ = try await intent.perform()
            }
        }

        let allPoints = try context.fetch(FetchDescriptor<DataPoint>())
        #expect(allPoints.isEmpty)
    }

    @Test("Goal shortcut query returns only active goals")
    func goalShortcutQueryReturnsActiveGoals() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let activeGoal = TrackingGoal(
            title: "Mindfulness",
            description: "Meditate",
            category: .mood
        )
        activeGoal.isActive = true

        let inactiveGoal = TrackingGoal(
            title: "Archery",
            description: "Practice",
            category: .fitness,
            isActive: false
        )

        context.insert(activeGoal)
        context.insert(inactiveGoal)
        try context.save()

        let query = GoalShortcutQuery()

        let suggested = try await AppEnvironment.shared.withModelContext(context) {
            try await query.suggestedEntities()
        }

        #expect(suggested.count == 1)
        #expect(suggested.first?.id == activeGoal.id)
        #expect(suggested.first?.title == activeGoal.title)
    }
}
