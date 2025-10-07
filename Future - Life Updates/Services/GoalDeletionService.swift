import Foundation
import SwiftData
import os

@MainActor
final class GoalDeletionService {
    private let modelContext: ModelContext
    private let notificationScheduler: NotificationScheduling
    private let logger = Logger(
        subsystem: "com.quincy.Future-Life-Updates", category: "GoalDeletion")

    init(
        modelContext: ModelContext,
        notificationScheduler: (any NotificationScheduling)? = nil
    ) {
        self.modelContext = modelContext
        if let scheduler = notificationScheduler {
            self.notificationScheduler = scheduler
        } else {
            self.notificationScheduler = NotificationScheduler.shared
        }
    }

    /// Soft-delete a goal by archiving it to trash before removing from the database
    func moveToTrash(_ goal: TrackingGoal, userNote: String? = nil) throws {
        // Bump updatedAt before archiving to maintain consistency
        goal.bumpUpdatedAt()

        // Create snapshot using BackupPayload format
        let goalSnapshot = BackupPayload.Goal(
            id: goal.id,
            title: goal.title,
            goalDescription: goal.goalDescription,
            category: goal.category,
            customCategoryLabel: goal.customCategoryLabel,
            isActive: goal.isActive,
            createdAt: goal.createdAt,
            updatedAt: goal.updatedAt,
            schedule: BackupPayload.Schedule(
                id: goal.schedule.id,
                startDate: goal.schedule.startDate,
                frequency: goal.schedule.frequency,
                times: goal.schedule.times,
                endDate: goal.schedule.endDate,
                timezoneIdentifier: goal.schedule.timezoneIdentifier,
                selectedWeekdays: goal.schedule.normalizedWeekdays(),
                intervalDayCount: goal.schedule.intervalDayCount
            ),
            questions: goal.questions.map { question in
                BackupPayload.Question(
                    id: question.id,
                    text: question.text,
                    responseType: question.responseType,
                    isActive: question.isActive,
                    options: question.options,
                    validationRules: question.validationRules
                )
            },
            dataPoints: goal.dataPoints.sorted(by: { $0.timestamp < $1.timestamp }).map {
                dataPoint in
                BackupPayload.DataPoint(
                    id: dataPoint.id,
                    goalID: goal.id,
                    questionID: dataPoint.question?.id,
                    timestamp: dataPoint.timestamp,
                    numericValue: dataPoint.numericValue,
                    numericDelta: dataPoint.numericDelta,
                    textValue: dataPoint.textValue,
                    boolValue: dataPoint.boolValue,
                    selectedOptions: dataPoint.selectedOptions,
                    timeValue: dataPoint.timeValue,
                    mood: dataPoint.mood,
                    location: dataPoint.location
                )
            }
        )

        // Serialize the snapshot
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let snapshotData = try encoder.encode(goalSnapshot)

        // Create trash item
        let trashItem = GoalTrashItem(
            goalSnapshot: snapshotData,
            originalGoalID: goal.id,
            goalTitle: goal.title,
            deletedAt: Date(),
            userNote: userNote
        )

        modelContext.insert(trashItem)

        // Cancel all notifications for this goal
        notificationScheduler.cancelNotifications(forGoalID: goal.id)

        // Delete the goal (cascade will handle related entities)
        modelContext.delete(goal)

        // Save changes
        try modelContext.save()

        logger.info(
            "Goal '\(goal.title, privacy: .public)' moved to trash with ID: \(trashItem.id.uuidString, privacy: .public)"
        )
    }

    /// Restore a goal from trash
    func restoreFromTrash(_ trashItem: GoalTrashItem, reactivate: Bool = true) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let goalSnapshot = try decoder.decode(BackupPayload.Goal.self, from: trashItem.goalSnapshot)

        // Check if a goal with this ID already exists
        let existingDescriptor = FetchDescriptor<TrackingGoal>(
            predicate: #Predicate { $0.id == goalSnapshot.id }
        )
        let existing = try modelContext.fetch(existingDescriptor)
        guard existing.isEmpty else {
            throw GoalDeletionError.goalAlreadyExists(goalSnapshot.id)
        }

        // Reconstruct the goal using the same logic as import
        let schedule = Schedule(
            startDate: goalSnapshot.schedule.startDate,
            frequency: goalSnapshot.schedule.frequency,
            times: goalSnapshot.schedule.times,
            endDate: goalSnapshot.schedule.endDate,
            timezoneIdentifier: goalSnapshot.schedule.timezoneIdentifier,
            selectedWeekdays: goalSnapshot.schedule.selectedWeekdays,
            intervalDayCount: goalSnapshot.schedule.intervalDayCount
        )
        schedule.id = goalSnapshot.schedule.id

        let goal = TrackingGoal(
            title: goalSnapshot.title,
            description: goalSnapshot.goalDescription,
            category: goalSnapshot.category,
            customCategoryLabel: goalSnapshot.customCategoryLabel,
            schedule: schedule,
            isActive: reactivate ? true : goalSnapshot.isActive,
            createdAt: goalSnapshot.createdAt,
            updatedAt: Date()  // Update to now since we're restoring
        )
        goal.id = goalSnapshot.id
        schedule.goal = goal

        let questions = goalSnapshot.questions.map { questionPayload -> Question in
            let question = Question(
                text: questionPayload.text,
                responseType: questionPayload.responseType,
                isActive: questionPayload.isActive,
                options: questionPayload.options,
                validationRules: questionPayload.validationRules
            )
            question.id = questionPayload.id
            question.goal = goal
            return question
        }
        goal.questions = questions

        let questionLookup = Dictionary(uniqueKeysWithValues: questions.map { ($0.id, $0) })

        let dataPoints = goalSnapshot.dataPoints.map { pointPayload -> DataPoint in
            let question = pointPayload.questionID.flatMap { questionLookup[$0] }
            let dataPoint = DataPoint(
                goal: goal,
                question: question,
                timestamp: pointPayload.timestamp,
                numericValue: pointPayload.numericValue,
                numericDelta: pointPayload.numericDelta,
                textValue: pointPayload.textValue,
                boolValue: pointPayload.boolValue,
                selectedOptions: pointPayload.selectedOptions,
                timeValue: pointPayload.timeValue,
                mood: pointPayload.mood,
                location: pointPayload.location
            )
            dataPoint.id = pointPayload.id
            return dataPoint
        }
        goal.dataPoints = dataPoints

        modelContext.insert(goal)

        // Remove from trash
        modelContext.delete(trashItem)

        try modelContext.save()

        // Reschedule notifications if active
        if goal.isActive {
            notificationScheduler.scheduleNotifications(for: goal)
        }

        logger.info("Goal '\(goal.title, privacy: .public)' restored from trash")
    }

    /// Permanently delete a trash item
    func permanentlyDelete(_ trashItem: GoalTrashItem) throws {
        modelContext.delete(trashItem)
        try modelContext.save()
        logger.info(
            "Trash item for goal '\(trashItem.goalTitle, privacy: .public)' permanently deleted")
    }

    /// Purge trash items older than the specified number of days
    func purgeOldTrashItems(olderThanDays days: Int = 30) throws {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        let descriptor = FetchDescriptor<GoalTrashItem>(
            predicate: #Predicate { $0.deletedAt < cutoffDate }
        )

        let oldItems = try modelContext.fetch(descriptor)

        for item in oldItems {
            modelContext.delete(item)
        }

        if !oldItems.isEmpty {
            try modelContext.save()
            logger.info("Purged \(oldItems.count) trash items older than \(days) days")
        }
    }
}

enum GoalDeletionError: LocalizedError {
    case goalAlreadyExists(UUID)

    var errorDescription: String? {
        switch self {
        case .goalAlreadyExists(let id):
            return "A goal with ID \(id.uuidString) already exists in the database."
        }
    }
}
