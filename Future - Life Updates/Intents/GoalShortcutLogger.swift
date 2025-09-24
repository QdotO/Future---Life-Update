import Foundation
import SwiftData

enum QuickLogIntentError: Error, LocalizedError, Sendable {
    case goalNotFound
    case missingNumericQuestion

    var errorDescription: String? {
        switch self {
        case .goalNotFound:
            return String(localized: "We couldn't find that goal.")
        case .missingNumericQuestion:
            return String(localized: "This goal doesn't include a numeric question to log.")
        }
    }
}

@MainActor
struct GoalShortcutLogger {
    let modelContext: ModelContext

    func logNumericValue(_ value: Double, for goalID: UUID, at date: Date) throws -> (goal: TrackingGoal, dataPoint: DataPoint) {
        guard let goal = try fetchGoal(goalID: goalID) else {
            throw QuickLogIntentError.goalNotFound
        }

        guard let question = goal.questions.first(where: { $0.responseType == .numeric && $0.isActive }) else {
            throw QuickLogIntentError.missingNumericQuestion
        }

        let dataPoint = DataPoint(
            goal: goal,
            question: question,
            timestamp: date,
            numericValue: value
        )
        goal.dataPoints.append(dataPoint)
        question.dataPoints.append(dataPoint)
        modelContext.insert(dataPoint)
        goal.bumpUpdatedAt(to: date)

        try modelContext.save()

        return (goal, dataPoint)
    }

    private func fetchGoal(goalID: UUID) throws -> TrackingGoal? {
        var descriptor = FetchDescriptor<TrackingGoal>(
            predicate: #Predicate { goal in goal.id == goalID },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
