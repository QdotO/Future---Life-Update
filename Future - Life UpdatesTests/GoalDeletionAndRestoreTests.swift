import Foundation
import SwiftData
import Testing

@testable import Future___Life_Updates

@MainActor
struct GoalDeletionAndRestoreTests {

    func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([
            TrackingGoal.self,
            Question.self,
            Schedule.self,
            DataPoint.self,
            GoalTrashItem.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    @Test("Goal deletion creates trash item")
    func testGoalDeletionCreatesTrash() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        // Create a goal
        let schedule = Schedule(
            startDate: Date(),
            frequency: .daily,
            times: [ScheduleTime(hour: 9, minute: 0)]
        )
        let goal = TrackingGoal(
            title: "Test Goal",
            description: "Test Description",
            category: .fitness,
            schedule: schedule
        )
        context.insert(goal)
        try context.save()

        let goalID = goal.id

        // Delete the goal using the service
        let mockScheduler = MockNotificationScheduler()
        let deletionService = GoalDeletionService(
            modelContext: context,
            notificationScheduler: mockScheduler
        )

        try deletionService.moveToTrash(goal)

        // Verify goal is deleted
        let goalDescriptor = FetchDescriptor<TrackingGoal>(
            predicate: #Predicate { $0.id == goalID }
        )
        let goals = try context.fetch(goalDescriptor)
        #expect(goals.isEmpty)

        // Verify trash item exists
        let trashDescriptor = FetchDescriptor<GoalTrashItem>(
            predicate: #Predicate { $0.originalGoalID == goalID }
        )
        let trashItems = try context.fetch(trashDescriptor)
        #expect(trashItems.count == 1)
        #expect(trashItems.first?.goalTitle == "Test Goal")

        // Verify notification was cancelled
        #expect(mockScheduler.cancelledGoalIDs.contains(goalID))
    }

    @Test("Goal restoration recreates goal with data")
    func testGoalRestorationRecreatesGoal() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        // Create a goal with questions and data
        let schedule = Schedule(
            startDate: Date(),
            frequency: .daily,
            times: [ScheduleTime(hour: 9, minute: 0)]
        )
        let goal = TrackingGoal(
            title: "Restore Test",
            description: "Test restore functionality",
            category: .health,
            schedule: schedule
        )

        let question = Question(
            text: "How are you feeling?",
            responseType: .scale,
            isActive: true
        )
        question.goal = goal
        goal.questions = [question]

        let dataPoint = DataPoint(
            goal: goal,
            question: question,
            timestamp: Date(),
            numericValue: 8.0
        )
        goal.dataPoints = [dataPoint]

        context.insert(goal)
        try context.save()

        let goalID = goal.id

        // Delete the goal
        let mockScheduler = MockNotificationScheduler()
        let deletionService = GoalDeletionService(
            modelContext: context,
            notificationScheduler: mockScheduler
        )

        try deletionService.moveToTrash(goal)

        // Verify goal is deleted
        var goalDescriptor = FetchDescriptor<TrackingGoal>(
            predicate: #Predicate { $0.id == goalID }
        )
        var goals = try context.fetch(goalDescriptor)
        #expect(goals.isEmpty)

        // Get trash item
        let trashDescriptor = FetchDescriptor<GoalTrashItem>(
            predicate: #Predicate { $0.originalGoalID == goalID }
        )
        let trashItems = try context.fetch(trashDescriptor)
        let trashItem = try #require(trashItems.first)

        // Restore the goal
        try deletionService.restoreFromTrash(trashItem, reactivate: true)

        // Verify goal is restored
        goalDescriptor = FetchDescriptor<TrackingGoal>(
            predicate: #Predicate { $0.id == goalID }
        )
        goals = try context.fetch(goalDescriptor)
        #expect(goals.count == 1)

        let restoredGoal = try #require(goals.first)
        #expect(restoredGoal.title == "Restore Test")
        #expect(restoredGoal.questions.count == 1)
        #expect(restoredGoal.dataPoints.count == 1)
        #expect(restoredGoal.isActive == true)

        // Verify trash item is deleted
        let remainingTrash = try context.fetch(trashDescriptor)
        #expect(remainingTrash.isEmpty)

        // Verify notification was rescheduled
        #expect(mockScheduler.scheduledGoals.contains(where: { $0.id == goalID }))
    }

    @Test("Trash purge removes old items")
    func testTrashPurgeRemovesOldItems() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        // Create an old trash item (31 days ago)
        let oldDate = Calendar.current.date(byAdding: .day, value: -31, to: Date())!
        let oldSnapshot = Data()
        let oldTrash = GoalTrashItem(
            goalSnapshot: oldSnapshot,
            originalGoalID: UUID(),
            goalTitle: "Old Goal",
            deletedAt: oldDate
        )
        context.insert(oldTrash)

        // Create a recent trash item
        let recentSnapshot = Data()
        let recentTrash = GoalTrashItem(
            goalSnapshot: recentSnapshot,
            originalGoalID: UUID(),
            goalTitle: "Recent Goal",
            deletedAt: Date()
        )
        context.insert(recentTrash)

        try context.save()

        // Purge old items
        let mockScheduler = MockNotificationScheduler()
        let deletionService = GoalDeletionService(
            modelContext: context,
            notificationScheduler: mockScheduler
        )

        try deletionService.purgeOldTrashItems(olderThanDays: 30)

        // Verify old item is deleted
        let descriptor = FetchDescriptor<GoalTrashItem>()
        let remainingTrash = try context.fetch(descriptor)
        #expect(remainingTrash.count == 1)
        #expect(remainingTrash.first?.goalTitle == "Recent Goal")
    }
}

// Mock notification scheduler for testing
class MockNotificationScheduler: NotificationScheduling {
    var scheduledGoals: [TrackingGoal] = []
    var cancelledGoalIDs: [UUID] = []

    func scheduleNotifications(for goal: TrackingGoal) {
        scheduledGoals.append(goal)
    }

    func cancelNotifications(forGoalID goalID: UUID) {
        cancelledGoalIDs.append(goalID)
    }
}
