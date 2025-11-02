import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class SettingsViewModel {
    private let backupManager: DataBackupManager
    private let modelContext: ModelContext
    private let filenameFormatter: DateFormatter

    init(modelContext: ModelContext, dateProvider: @escaping () -> Date = Date.init) {
        self.modelContext = modelContext
        self.backupManager = DataBackupManager(
            modelContext: modelContext, dateProvider: dateProvider)
        self.filenameFormatter = SettingsViewModel.makeFilenameFormatter()
    }

    func makeDefaultFilename() -> String {
        let timestamp = filenameFormatter.string(from: Date())
        return "FutureLifeBackup-\(timestamp)"
    }

    func createBackupDocument() throws -> BackupDocument {
        try backupManager.makeBackupDocument()
    }

    func importBackup(from data: Data, replaceExisting: Bool = true) throws
        -> DataBackupManager.ImportSummary
    {
        try backupManager.importBackup(from: data, replaceExisting: replaceExisting)
    }

    func hasExistingData() throws -> Bool {
        var descriptor = FetchDescriptor<TrackingGoal>()
        descriptor.fetchLimit = 1
        descriptor.includePendingChanges = true
        return try modelContext.fetch(descriptor).isEmpty == false
    }

    func populateDummyData() throws {
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .day, value: -45, to: now) ?? now

        // Create sample goals with mixed question types
        let hydrationGoal = createGoal(
            title: "Hydration",
            description: "Track daily water intake",
            category: .health
        )
        let exerciseGoal = createGoal(
            title: "Exercise",
            description: "Track workout minutes",
            category: .fitness
        )
        let sleepGoal = createGoal(
            title: "Sleep",
            description: "Track sleep quality",
            category: .health
        )
        let readingGoal = createGoal(
            title: "Reading",
            description: "Track reading progress",
            category: .learning
        )

        let goals = [hydrationGoal, exerciseGoal, sleepGoal, readingGoal]

        // Configure each goal
        for goal in goals {
            let schedule = Schedule(
                startDate: startDate,
                frequency: .daily,
                times: [ScheduleTime(hour: 9, minute: 0)],
                timezoneIdentifier: TimeZone.current.identifier
            )
            goal.schedule = schedule
            schedule.goal = goal
            modelContext.insert(goal)
        }

        // Hydration: Numeric question (glasses of water)
        let hydrationQuestion = Question(
            text: "How many glasses of water did you drink?",
            responseType: .numeric,
            validationRules: ValidationRules(minimumValue: 0, maximumValue: 15, allowsEmpty: true)
        )
        hydrationGoal.questions = [hydrationQuestion]
        hydrationQuestion.goal = hydrationGoal

        for dayOffset in 0..<45 {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) {
                let baseValue = 6.0 + Double(dayOffset % 7) * 0.5
                let variance = Double.random(in: -1.5...1.5)
                let glassCount = max(2, min(15, baseValue + variance))
                let dataPoint = DataPoint(
                    goal: hydrationGoal,
                    question: hydrationQuestion,
                    timestamp: date,
                    numericValue: glassCount
                )
                hydrationGoal.dataPoints.append(dataPoint)
            }
        }

        // Exercise: Numeric question (minutes)
        let exerciseQuestion = Question(
            text: "How many minutes did you exercise?",
            responseType: .numeric,
            validationRules: ValidationRules(minimumValue: 0, maximumValue: 180, allowsEmpty: true)
        )
        exerciseGoal.questions = [exerciseQuestion]
        exerciseQuestion.goal = exerciseGoal

        for dayOffset in 0..<45 {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) {
                let baseMinutes = dayOffset % 7 == 6 ? 0 : (30 + Double(dayOffset % 5) * 10)
                let variance = Double.random(in: -5...10)
                let minutes = max(0, min(180, baseMinutes + variance))
                let dataPoint = DataPoint(
                    goal: exerciseGoal,
                    question: exerciseQuestion,
                    timestamp: date,
                    numericValue: minutes
                )
                exerciseGoal.dataPoints.append(dataPoint)
            }
        }

        // Sleep: Numeric question (hours)
        let sleepQuestion = Question(
            text: "How many hours did you sleep?",
            responseType: .numeric,
            validationRules: ValidationRules(minimumValue: 3, maximumValue: 12, allowsEmpty: true)
        )
        sleepGoal.questions = [sleepQuestion]
        sleepQuestion.goal = sleepGoal

        for dayOffset in 0..<45 {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) {
                let baseHours = 7.5 + Double(dayOffset % 3) * 0.3
                let variance = Double.random(in: -0.8...0.8)
                let hours = max(3, min(12, baseHours + variance))
                let dataPoint = DataPoint(
                    goal: sleepGoal,
                    question: sleepQuestion,
                    timestamp: date,
                    numericValue: hours
                )
                sleepGoal.dataPoints.append(dataPoint)
            }
        }

        // Reading: Boolean question (did you read?)
        let readingQuestion = Question(
            text: "Did you read today?",
            responseType: .boolean
        )
        readingGoal.questions = [readingQuestion]
        readingQuestion.goal = readingGoal

        for dayOffset in 0..<45 {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) {
                let didRead = dayOffset % 3 != 0
                let dataPoint = DataPoint(
                    goal: readingGoal,
                    question: readingQuestion,
                    timestamp: date,
                    boolValue: didRead
                )
                readingGoal.dataPoints.append(dataPoint)
            }
        }

        try modelContext.save()
    }

    private func createGoal(
        title: String,
        description: String,
        category: TrackingCategory
    ) -> TrackingGoal {
        TrackingGoal(
            title: title,
            description: description,
            category: category,
            isActive: true
        )
    }

    private static func makeFilenameFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = .current
        formatter.timeZone = .current
        return formatter
    }
}
