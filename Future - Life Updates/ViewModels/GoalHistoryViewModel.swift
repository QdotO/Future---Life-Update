import Foundation
import Observation
import SwiftData
import os

@MainActor
@Observable
final class GoalHistoryViewModel {
    struct DaySection: Identifiable, Hashable {
        let id: Date
        let date: Date
        var entries: [Entry]
    }

    struct Entry: Identifiable, Hashable {
        let id: UUID
        let timestamp: Date
        let questionTitle: String
        let responseSummary: String
        let timeSummary: String
        let additionalDetails: String?
    }

    private let modelContext: ModelContext
    private let dateProvider: () -> Date
    private let calendar: Calendar

    private(set) var goal: TrackingGoal
    private(set) var sections: [DaySection] = []

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
        refresh()
    }

    func refresh() {
        let trace = PerformanceMetrics.trace(
            "GoalHistory.refresh", metadata: ["goal": goal.id.uuidString])
        do {
            try reloadEntries()
        } catch {
            sections = []
            PerformanceMetrics.logger.error(
                "GoalHistory refresh failed: \(error.localizedDescription, privacy: .public)")
        }
        trace.end(extraMetadata: ["sections": "\(sections.count)"])
    }

    private func reloadEntries() throws {
        let trace = PerformanceMetrics.trace(
            "GoalHistory.reloadEntries", metadata: ["goal": goal.id.uuidString])
        let goalIdentifier = goal.persistentModelID
        var descriptor = FetchDescriptor<DataPoint>(
            predicate: #Predicate<DataPoint> { dataPoint in
                dataPoint.goal?.persistentModelID == goalIdentifier
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        descriptor.propertiesToFetch = [
            \.timestamp,
            \.numericValue,
            \.textValue,
            \.boolValue,
            \.selectedOptions,
            \.timeValue,
            \.numericDelta,
            \.mood,
            \.location,
        ]
        descriptor.relationshipKeyPathsForPrefetching = [\.question]
        descriptor.includePendingChanges = true

        let dataPoints = try modelContext.fetch(descriptor)
        let grouped = Dictionary(grouping: dataPoints) { dataPoint in
            calendar.startOfDay(for: dataPoint.timestamp)
        }

        let sortedDays = grouped.keys.sorted(by: >)
        sections = sortedDays.map { day in
            let points = (grouped[day] ?? []).sorted { $0.timestamp > $1.timestamp }
            let entries = points.map { point in
                Entry(
                    id: point.id,
                    timestamp: point.timestamp,
                    questionTitle: point.question?.text ?? "Question",
                    responseSummary: summary(for: point),
                    timeSummary: TimeFormatter.short.string(from: point.timestamp),
                    additionalDetails: details(for: point)
                )
            }
            return DaySection(id: day, date: day, entries: entries)
        }
        trace.end(extraMetadata: [
            "dataPoints": "\(dataPoints.count)",
            "sections": "\(sections.count)",
            "entries": "\(sections.reduce(0) { $0 + $1.entries.count })",
        ])
    }

    private func summary(for dataPoint: DataPoint) -> String {
        if let formattedDelta = deltaSummary(for: dataPoint) {
            return formattedDelta
        }

        if let responseType = dataPoint.question?.responseType {
            switch responseType {
            case .numeric, .slider:
                if let numeric = dataPoint.numericValue {
                    return NumericFormatter.numberFormatter.string(from: NSNumber(value: numeric))
                        ?? String(numeric)
                }
            case .scale:
                if let numeric = dataPoint.numericValue {
                    return String(Int(numeric.rounded()))
                }
            case .waterIntake:
                if let numeric = dataPoint.numericValue {
                    return HydrationFormatter.ouncesString(numeric)
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
            return NumericFormatter.numberFormatter.string(from: NSNumber(value: numeric))
                ?? String(numeric)
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

    private func deltaSummary(for dataPoint: DataPoint) -> String? {
        guard
            let responseType = dataPoint.question?.responseType,
            responseType == .scale || responseType == .slider || responseType == .waterIntake,
            let afterValue = dataPoint.numericValue
        else {
            return nil
        }

        guard let delta = dataPoint.numericDelta else {
            return nil
        }

        let beforeValue = afterValue - delta
        let formattedBefore = formatValue(beforeValue, for: responseType)
        let formattedAfter = formatValue(afterValue, for: responseType)
        return "\(formattedBefore) -> \(formattedAfter)"
    }

    private func formatValue(_ value: Double, for responseType: ResponseType) -> String {
        switch responseType {
        case .scale:
            return String(Int(value.rounded()))
        case .slider:
            return NumericFormatter.numberFormatter.string(from: NSNumber(value: value))
                ?? String(value)
        case .waterIntake:
            return HydrationFormatter.ouncesString(value)
        default:
            return NumericFormatter.numberFormatter.string(from: NSNumber(value: value))
                ?? String(value)
        }
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
