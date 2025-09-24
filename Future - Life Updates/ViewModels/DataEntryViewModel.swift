import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class DataEntryViewModel {
    private let modelContext: ModelContext
    private let dateProvider: () -> Date
    private let calendar: Calendar

    private(set) var goal: TrackingGoal
    private var numericResponses: [UUID: Double] = [:]

    init(
        goal: TrackingGoal,
        modelContext: ModelContext,
        dateProvider: @escaping () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.goal = goal
        self.modelContext = modelContext
        self.dateProvider = dateProvider
        self.calendar = calendar
    }

    func setNumericResponse(_ value: Double, for question: Question) {
        numericResponses[question.id] = value
    }

    func clearResponses() {
        numericResponses.removeAll()
    }

    func saveEntries() throws {
        let now = dateProvider()
        for (questionID, value) in numericResponses {
            guard let question = goal.questions.first(where: { $0.id == questionID }) else { continue }
            if let existing = try existingDataPoint(for: question, on: now) {
                existing.numericValue = value
                existing.timestamp = now
            } else {
                let point = DataPoint(goal: goal, question: question, timestamp: now, numericValue: value)
                point.goal = goal
                point.question = question
                goal.dataPoints.append(point)
                question.dataPoints.append(point)
                modelContext.insert(point)
            }
        }

        goal.bumpUpdatedAt(to: now)
        try modelContext.save()
        clearResponses()
    }

    private func existingDataPoint(for question: Question, on date: Date) throws -> DataPoint? {
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }

        let goalIdentifier = goal.persistentModelID
        let questionIdentifier = question.persistentModelID

        var descriptor = FetchDescriptor<DataPoint>(
            predicate: #Predicate<DataPoint> { dataPoint in
                dataPoint.goal?.persistentModelID == goalIdentifier &&
                dataPoint.question?.persistentModelID == questionIdentifier &&
                dataPoint.timestamp >= startOfDay &&
                dataPoint.timestamp < endOfDay
            }
        )
        descriptor.fetchLimit = 1

        return try modelContext.fetch(descriptor).first
    }
}
