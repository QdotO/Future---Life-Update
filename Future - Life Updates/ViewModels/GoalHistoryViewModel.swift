import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class GoalHistoryViewModel {
    struct Entry: Identifiable, Hashable {
        let id: UUID
        let timestamp: Date
        let questionTitle: String
        let responseSummary: String
        let additionalDetails: String?
    }

    private let modelContext: ModelContext
    private let dateProvider: () -> Date

    private(set) var goal: TrackingGoal
    private(set) var entries: [Entry] = []

    init(goal: TrackingGoal, modelContext: ModelContext, dateProvider: @escaping () -> Date = Date.init) {
        self.goal = goal
        self.modelContext = modelContext
        self.dateProvider = dateProvider
        refresh()
    }

    func refresh() {
        do {
            try reloadEntries()
        } catch {
            entries = []
        }
    }

    private func reloadEntries() throws {
        let goalIdentifier = goal.persistentModelID
        let descriptor = FetchDescriptor<DataPoint>(
            predicate: #Predicate<DataPoint> { dataPoint in
                dataPoint.goal?.persistentModelID == goalIdentifier
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        let dataPoints = try modelContext.fetch(descriptor)
        entries = dataPoints.map { point in
            Entry(
                id: point.id,
                timestamp: point.timestamp,
                questionTitle: point.question?.text ?? "Question",
                responseSummary: summary(for: point),
                additionalDetails: details(for: point)
            )
        }
    }

    private func summary(for dataPoint: DataPoint) -> String {
        if let responseType = dataPoint.question?.responseType {
            switch responseType {
            case .numeric, .slider:
                if let numeric = dataPoint.numericValue {
                    return NumericFormatter.numberFormatter.string(from: NSNumber(value: numeric)) ?? String(numeric)
                }
            case .scale:
                if let numeric = dataPoint.numericValue {
                    return String(Int(numeric.rounded()))
                }
            case .boolean:
                if let boolValue = dataPoint.boolValue {
                    return boolValue ? "Yes" : "No"
                }
            case .text:
                if let text = dataPoint.textValue, !text.isEmpty {
                    return text
                }
            case .multipleChoice:
                if let options = dataPoint.selectedOptions, !options.isEmpty {
                    return options.joined(separator: ", ")
                }
            case .time:
                if let time = dataPoint.timeValue {
                    return TimeFormatter.short.string(from: time)
                }
            }
        }

        if let numeric = dataPoint.numericValue {
            return NumericFormatter.numberFormatter.string(from: NSNumber(value: numeric)) ?? String(numeric)
        }
        if let text = dataPoint.textValue, !text.isEmpty {
            return text
        }
        if let boolValue = dataPoint.boolValue {
            return boolValue ? "Yes" : "No"
        }
        if let options = dataPoint.selectedOptions, !options.isEmpty {
            return options.joined(separator: ", ")
        }
        if let time = dataPoint.timeValue {
            return TimeFormatter.short.string(from: time)
        }
        if let mood = dataPoint.mood {
            return "Mood: \(mood)"
        }
        return "No response recorded"
    }

    private func details(for dataPoint: DataPoint) -> String? {
        var components: [String] = []
        if let location = dataPoint.location, !location.isEmpty {
            components.append("Location: \(location)")
        }
        return components.isEmpty ? nil : components.joined(separator: " • ")
    }
}

private enum NumericFormatter {
    static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter
    }()
}

private enum TimeFormatter {
    static let short: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}
