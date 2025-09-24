import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class DataEntryViewModel {
    enum ResponseValue: Equatable {
        case numeric(Double)
        case boolean(Bool)
        case text(String)
        case options(Set<String>)
        case time(Date)
    }

    private let modelContext: ModelContext
    private let dateProvider: () -> Date
    private let calendar: Calendar

    private(set) var goal: TrackingGoal
    private var responses: [UUID: ResponseValue] = [:]

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
        seedDefaultResponses()
    }

    var canSubmit: Bool {
        let activeQuestions = goal.questions.filter { $0.isActive }
        guard !activeQuestions.isEmpty else { return false }

        for question in activeQuestions {
            guard
                let response = responses[question.id],
                isValid(response, for: question)
            else {
                return false
            }
        }

        return true
    }

    func updateNumericResponse(_ value: Double, for question: Question) {
        let clamped = clampedNumericValue(value, for: question)
        responses[question.id] = .numeric(clamped)
    }

    func updateBooleanResponse(_ value: Bool, for question: Question) {
        responses[question.id] = .boolean(value)
    }

    func updateTextResponse(_ text: String, for question: Question) {
        responses[question.id] = .text(text)
    }

    func toggleOption(_ option: String, for question: Question) {
        var selections = selectedOptions(for: question)
        if selections.contains(option) {
            selections.remove(option)
        } else {
            selections.insert(option)
        }
        responses[question.id] = .options(selections)
    }

    func setOption(_ option: String, isSelected: Bool, for question: Question) {
        var selections = selectedOptions(for: question)
        if isSelected {
            selections.insert(option)
        } else {
            selections.remove(option)
        }
        responses[question.id] = .options(selections)
    }

    func updateTimeResponse(_ date: Date, for question: Question) {
        responses[question.id] = .time(date)
    }

    func numericValue(for question: Question, default defaultValue: Double = 0) -> Double {
        if case let .numeric(value) = responses[question.id] {
            return value
        }
        return defaultValue
    }

    func booleanValue(for question: Question) -> Bool {
        if case let .boolean(value) = responses[question.id] {
            return value
        }
        return false
    }

    func textValue(for question: Question) -> String {
        if case let .text(value) = responses[question.id] {
            return value
        }
        return ""
    }

    func selectedOptions(for question: Question) -> Set<String> {
        if case let .options(set) = responses[question.id] {
            return set
        }
        return []
    }

    func timeValue(for question: Question, fallback: Date) -> Date {
        if case let .time(date) = responses[question.id] {
            return date
        }
        return fallback
    }

    func clearResponses() {
        seedDefaultResponses()
    }

    func saveEntries() throws {
        let now = dateProvider()
        for question in goal.questions where question.isActive {
            guard
                let response = responses[question.id],
                isValid(response, for: question)
            else { continue }

            let dataPoint = try existingDataPoint(for: question, on: now) ?? {
                let point = DataPoint(goal: goal, question: question, timestamp: now)
                point.goal = goal
                point.question = question
                goal.dataPoints.append(point)
                question.dataPoints.append(point)
                modelContext.insert(point)
                return point
            }()

            dataPoint.timestamp = now
            dataPoint.numericValue = nil
            dataPoint.boolValue = nil
            dataPoint.textValue = nil
            dataPoint.selectedOptions = nil
            dataPoint.timeValue = nil

            switch question.responseType {
            case .numeric, .scale, .slider:
                if case let .numeric(value) = response {
                    dataPoint.numericValue = value
                }
            case .boolean:
                if case let .boolean(value) = response {
                    dataPoint.boolValue = value
                }
            case .text:
                if case let .text(value) = response {
                    dataPoint.textValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            case .multipleChoice:
                if case let .options(set) = response {
                    if set.isEmpty {
                        dataPoint.selectedOptions = nil
                    } else if let orderedOptions = question.options {
                        dataPoint.selectedOptions = orderedOptions.filter { set.contains($0) }
                    } else {
                        dataPoint.selectedOptions = Array(set)
                    }
                }
            case .time:
                if case let .time(date) = response {
                    dataPoint.timeValue = date
                }
            }
        }

        goal.bumpUpdatedAt(to: now)
        try modelContext.save()
        clearResponses()
    }

    private func seedDefaultResponses() {
        responses.removeAll()
        for question in goal.questions where question.isActive {
            switch question.responseType {
            case .numeric:
                let baseline = question.validationRules?.minimumValue ?? 0
                responses[question.id] = .numeric(baseline)
            case .scale:
                let baseline = question.validationRules?.minimumValue ?? 1
                responses[question.id] = .numeric(baseline)
            case .slider:
                let baseline = question.validationRules?.minimumValue ?? 0
                responses[question.id] = .numeric(baseline)
            case .boolean:
                responses[question.id] = .boolean(false)
            case .text:
                responses[question.id] = .text("")
            case .multipleChoice:
                responses[question.id] = .options([])
            case .time:
                let defaultDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: dateProvider()) ?? dateProvider()
                responses[question.id] = .time(defaultDate)
            }
        }
    }

    private func isValid(_ response: ResponseValue, for question: Question) -> Bool {
        switch (question.responseType, response) {
        case (.numeric, .numeric(let value)), (.scale, .numeric(let value)), (.slider, .numeric(let value)):
            if let minimum = question.validationRules?.minimumValue, value < minimum { return false }
            if let maximum = question.validationRules?.maximumValue, value > maximum { return false }
            return true
        case (.boolean, .boolean):
            return true
        case (.text, .text(let value)):
            let allowsEmpty = question.validationRules?.allowsEmpty ?? false
            return allowsEmpty || !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case (.multipleChoice, .options(let set)):
            let allowsEmpty = question.validationRules?.allowsEmpty ?? false
            return allowsEmpty || !set.isEmpty
        case (.time, .time):
            return true
        default:
            return false
        }
    }

    private func clampedNumericValue(_ value: Double, for question: Question) -> Double {
        let minimum = question.validationRules?.minimumValue
        let maximum = question.validationRules?.maximumValue
        if let minimum, let maximum {
            return min(max(value, minimum), maximum)
        } else if let minimum {
            return max(value, minimum)
        } else if let maximum {
            return min(value, maximum)
        }
        return value
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
