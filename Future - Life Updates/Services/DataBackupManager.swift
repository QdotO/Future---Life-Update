import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

protocol NotificationScheduling {
    func scheduleNotifications(for goal: TrackingGoal)
}

extension NotificationScheduler: NotificationScheduling {}

@MainActor
struct DataBackupManager {
    private enum Constants {
        static let schemaVersion: Int = 1
    }

    struct ImportSummary: Sendable {
        let goalsImported: Int
        let dataPointsImported: Int
    }

    enum BackupError: LocalizedError {
        case unsupportedVersion(Int)
        case emptyBackup
        case invalidDocument

        var errorDescription: String? {
            switch self {
            case .unsupportedVersion(let version):
                return "This backup was created with a newer version (\(version))."
            case .emptyBackup:
                return "The selected backup file is empty."
            case .invalidDocument:
                return "We couldn’t read that backup file."
            }
        }
    }

    private let modelContext: ModelContext
    private let dateProvider: () -> Date
    private let notificationScheduler: NotificationScheduling

    init(
        modelContext: ModelContext,
        dateProvider: @escaping () -> Date = Date.init,
        notificationScheduler: NotificationScheduling = NotificationScheduler.shared
    ) {
        self.modelContext = modelContext
        self.dateProvider = dateProvider
        self.notificationScheduler = notificationScheduler
    }

    func makeBackupDocument() throws -> BackupDocument {
        let payload = try exportPayload()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        return BackupDocument(data: data)
    }

    func exportPayload() throws -> BackupPayload {
        var descriptor = FetchDescriptor<TrackingGoal>()
        descriptor.includePendingChanges = true
        descriptor.sortBy = [SortDescriptor(\TrackingGoal.createdAt, order: .forward)]
        descriptor.relationshipKeyPathsForPrefetching = [\.schedule, \.questions, \.dataPoints]

        let goals = try modelContext.fetch(descriptor)

        let goalPayloads = goals.map { goal in
            BackupPayload.Goal(
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
                dataPoints: goal.dataPoints.sorted(by: { $0.timestamp < $1.timestamp }).map { dataPoint in
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
        }

        return BackupPayload(
            version: Constants.schemaVersion,
            exportedAt: dateProvider(),
            goals: goalPayloads
        )
    }

    @discardableResult
    func importBackup(from data: Data, replaceExisting: Bool = true) throws -> ImportSummary {
        guard !data.isEmpty else { throw BackupError.emptyBackup }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let payload = try decoder.decode(BackupPayload.self, from: data)
        guard payload.version <= Constants.schemaVersion else {
            throw BackupError.unsupportedVersion(payload.version)
        }

        modelContext.rollback()

        if replaceExisting {
            try removeExistingGoals()
        }

        var importedGoals: [TrackingGoal] = []
        var totalDataPoints = 0

        do {
            for goalPayload in payload.goals {
                let schedule = Schedule(
                    startDate: goalPayload.schedule.startDate,
                    frequency: goalPayload.schedule.frequency,
                    times: goalPayload.schedule.times,
                    endDate: goalPayload.schedule.endDate,
                    timezoneIdentifier: goalPayload.schedule.timezoneIdentifier,
                    selectedWeekdays: goalPayload.schedule.selectedWeekdays,
                    intervalDayCount: goalPayload.schedule.intervalDayCount
                )
                schedule.id = goalPayload.schedule.id

                let goal = TrackingGoal(
                    title: goalPayload.title,
                    description: goalPayload.goalDescription,
                    category: goalPayload.category,
                    customCategoryLabel: goalPayload.customCategoryLabel,
                    schedule: schedule,
                    isActive: goalPayload.isActive,
                    createdAt: goalPayload.createdAt,
                    updatedAt: goalPayload.updatedAt
                )
                goal.id = goalPayload.id
                schedule.goal = goal

                let questions = goalPayload.questions.map { questionPayload -> Question in
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

                let dataPoints = goalPayload.dataPoints.map { pointPayload -> DataPoint in
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
                totalDataPoints += dataPoints.count

                importedGoals.append(goal)
                modelContext.insert(goal)
            }

            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }

        for goal in importedGoals where goal.isActive {
            notificationScheduler.scheduleNotifications(for: goal)
        }

        return ImportSummary(goalsImported: importedGoals.count, dataPointsImported: totalDataPoints)
    }

    private func removeExistingGoals() throws {
        var descriptor = FetchDescriptor<TrackingGoal>()
        descriptor.includePendingChanges = true
        let existingGoals = try modelContext.fetch(descriptor)
        for goal in existingGoals {
            modelContext.delete(goal)
        }
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw DataBackupManager.BackupError.invalidDocument
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct BackupPayload: Codable, Sendable {
    struct Goal: Codable, Sendable {
        let id: UUID
        let title: String
        let goalDescription: String
        let category: TrackingCategory
        let customCategoryLabel: String?
        let isActive: Bool
        let createdAt: Date
        let updatedAt: Date
        let schedule: Schedule
        let questions: [Question]
        let dataPoints: [DataPoint]
    }

    struct Schedule: Codable, Sendable {
        let id: UUID
        let startDate: Date
        let frequency: Frequency
        let times: [ScheduleTime]
        let endDate: Date?
        let timezoneIdentifier: String
        let selectedWeekdays: [Weekday]
        let intervalDayCount: Int?
    }

    struct Question: Codable, Sendable {
        let id: UUID
        let text: String
        let responseType: ResponseType
        let isActive: Bool
        let options: [String]?
        let validationRules: ValidationRules?
    }

    struct DataPoint: Codable, Sendable {
        let id: UUID
        let goalID: UUID
        let questionID: UUID?
        let timestamp: Date
        let numericValue: Double?
        let numericDelta: Double?
        let textValue: String?
        let boolValue: Bool?
        let selectedOptions: [String]?
        let timeValue: Date?
        let mood: Int?
        let location: String?
    }

    let version: Int
    let exportedAt: Date
    let goals: [Goal]
}
