import Foundation
import Testing
import SwiftData
@testable import Future___Life_Updates

@MainActor
struct SettingsBackupTests {
    @Test("Backup export and import round trip restores goals")
    func backupRoundTripRestoresGoals() throws {
        let exportContainer = try makeInMemoryContainer()
        let exportContext = exportContainer.mainContext

        let schedule = Schedule(
            startDate: Date(timeIntervalSince1970: 1000),
            frequency: .daily,
            times: [ScheduleTime(hour: 8, minute: 30)],
            timezoneIdentifier: "America/New_York"
        )
        let goal = TrackingGoal(
            title: "Hydration",
            description: "Drink water",
            category: .health,
            schedule: schedule,
            createdAt: Date(timeIntervalSince1970: 1000),
            updatedAt: Date(timeIntervalSince1970: 2000)
        )
        schedule.goal = goal

        let question = Question(
            text: "How many glasses?",
            responseType: .numeric,
            isActive: true,
            options: nil,
            validationRules: ValidationRules(minimumValue: 0, maximumValue: 12, allowsEmpty: false)
        )
        question.goal = goal
        goal.questions = [question]

        let dataPoint = DataPoint(
            goal: goal,
            question: question,
            timestamp: Date(timeIntervalSince1970: 3000),
            numericValue: 5,
            numericDelta: 5,
            textValue: "Feeling good",
            boolValue: true,
            selectedOptions: ["Water"],
            timeValue: Date(timeIntervalSince1970: 3600),
            mood: 4,
            location: "Home"
        )
        goal.dataPoints = [dataPoint]

        exportContext.insert(goal)
        try exportContext.save()

        let exportScheduler = StubNotificationScheduler()
        let exportManager = DataBackupManager(
            modelContext: exportContext,
            dateProvider: { Date(timeIntervalSince1970: 4000) },
            notificationScheduler: exportScheduler
        )
        let document = try exportManager.makeBackupDocument()
        #expect(!document.data.isEmpty)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(BackupPayload.self, from: document.data)
        #expect(payload.goals.count == 1)
        #expect(payload.goals.first?.questions.count == 1)
        #expect(payload.goals.first?.dataPoints.count == 1)

        let importContainer = try makeInMemoryContainer()
        let importContext = importContainer.mainContext
        let importScheduler = StubNotificationScheduler()
        let importManager = DataBackupManager(
            modelContext: importContext,
            notificationScheduler: importScheduler
        )

        let summary = try importManager.importBackup(from: document.data)
        #expect(summary.goalsImported == 1)
        #expect(summary.dataPointsImported == 1)
        #expect(importScheduler.scheduledGoalIDs.count == 1)

        var descriptor = FetchDescriptor<TrackingGoal>()
        descriptor.includePendingChanges = true
        let importedGoals = try importContext.fetch(descriptor)
        #expect(importedGoals.count == 1)

        guard let restoredGoal = importedGoals.first else {
            Issue.record("Expected restored goal")
            return
        }

        #expect(restoredGoal.title == "Hydration")
        #expect(restoredGoal.goalDescription == "Drink water")
        #expect(restoredGoal.schedule.times.first?.hour == 8)
        #expect(restoredGoal.schedule.timezoneIdentifier == "America/New_York")
        #expect(restoredGoal.questions.count == 1)
        #expect(restoredGoal.dataPoints.count == 1)
        #expect(restoredGoal.dataPoints.first?.numericValue == 5)
    }

    @Test("Import replaces any existing goals in the store")
    func importReplacesExistingData() throws {
        let exportContainer = try makeInMemoryContainer()
        let exportContext = exportContainer.mainContext

        let replacementGoal = TrackingGoal(
            title: "Focus",
            description: "Deep work sessions",
            category: .productivity
        )
        exportContext.insert(replacementGoal)
        try exportContext.save()

        let exportManager = DataBackupManager(modelContext: exportContext, notificationScheduler: StubNotificationScheduler())
        let document = try exportManager.makeBackupDocument()

        let importContainer = try makeInMemoryContainer()
        let importContext = importContainer.mainContext

        let existingGoal = TrackingGoal(title: "Old Goal", description: "To remove", category: .health)
        importContext.insert(existingGoal)
        try importContext.save()

        let scheduler = StubNotificationScheduler()
        let importManager = DataBackupManager(modelContext: importContext, notificationScheduler: scheduler)
        let summary = try importManager.importBackup(from: document.data)
        #expect(summary.goalsImported == 1)

        var descriptor = FetchDescriptor<TrackingGoal>()
        descriptor.includePendingChanges = true
        let goals = try importContext.fetch(descriptor)
        #expect(goals.count == 1)
        #expect(goals.first?.title == "Focus")
    }

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
}

private final class StubNotificationScheduler: NotificationScheduling {
    private(set) var scheduledGoalIDs: [UUID] = []
    private(set) var cancelledGoalIDs: [UUID] = []

    func scheduleNotifications(for goal: TrackingGoal) {
        scheduledGoalIDs.append(goal.id)
    }

    func cancelNotifications(forGoalID goalID: UUID) {
        cancelledGoalIDs.append(goalID)
    }
}
