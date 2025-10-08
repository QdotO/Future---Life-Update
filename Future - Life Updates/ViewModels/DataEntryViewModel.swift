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
    private var dailyTotals: [UUID: Double] = [:]
    private var totalsDate: Date?

    struct NumericChangePreview: Equatable {
        let previousValue: Double?
        let resultingValue: Double
        let delta: Double?
        let responseType: ResponseType

        var isDeltaBaseline: Bool {
            responseType == .scale || responseType == .slider || responseType == .waterIntake
        }
    }

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
        totalsDate = calendar.startOfDay(for: dateProvider())
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
        if case .numeric(let value) = responses[question.id] {
            return value
        }
        return defaultValue
    }

    func waterIntakeDelta(for question: Question) -> Double {
        numericValue(for: question, default: 0)
    }

    func incrementWaterIntake(by amount: Double, for question: Question) {
        guard amount != 0 else { return }
        let current = waterIntakeDelta(for: question)
        let clamped = clampedNumericValue(current + amount, for: question)
        responses[question.id] = .numeric(clamped)
    }

    func setWaterIntake(_ amount: Double, for question: Question) {
        let clamped = clampedNumericValue(amount, for: question)
        responses[question.id] = .numeric(clamped)
    }

    func resetWaterIntake(for question: Question) {
        responses[question.id] = .numeric(0)
    }

    func waterIntakeTotal(for question: Question) -> Double {
        runningTotal(for: question)
    }

    func waterIntakeDeltaRange(for question: Question) -> ClosedRange<Double> {
        ensureTotalsAreForToday()
        let current = runningTotal(for: question)
        let minimumDelta = 0.0
        let maximumTotal = question.validationRules?.maximumValue ?? (current + 128)
        let available = max(0, maximumTotal - current)
        return minimumDelta...available
    }

    func booleanValue(for question: Question) -> Bool {
        if case .boolean(let value) = responses[question.id] {
            return value
        }
        return false
    }

    func textValue(for question: Question) -> String {
        if case .text(let value) = responses[question.id] {
            return value
        }
        return ""
    }

    func selectedOptions(for question: Question) -> Set<String> {
        if case .options(let set) = responses[question.id] {
            return set
        }
        return []
    }

    func timeValue(for question: Question, fallback: Date) -> Date {
        if case .time(let date) = responses[question.id] {
            return date
        }
        return fallback
    }

    func numericChangePreview(for question: Question) -> NumericChangePreview? {
        guard question.isActive else { return nil }

        guard
            let response = responses[question.id],
            case .numeric(let value) = response
        else {
            return nil
        }

        switch question.responseType {
        case .numeric:
            let previous = mostRecentNumericValue(for: question)
            let delta = previous.map { value - $0 }
            return NumericChangePreview(
                previousValue: previous,
                resultingValue: value,
                delta: delta,
                responseType: .numeric
            )
        case .scale, .slider, .waterIntake:
            let currentTotal = runningTotal(for: question)
            let resulting = currentTotal + value
            return NumericChangePreview(
                previousValue: currentTotal,
                resultingValue: resulting,
                delta: value,
                responseType: question.responseType
            )
        default:
            return nil
        }
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

            switch question.responseType {
            case .scale, .slider, .waterIntake:
                guard case .numeric(let deltaValue) = response else { continue }
                let appliedDelta = try applyDelta(deltaValue, for: question, timestamp: now)
                if appliedDelta == nil {
                    continue
                }
            case .numeric:
                let dataPoint =
                    try existingDataPoint(for: question, on: now)
                    ?? createDataPoint(for: question, at: now)
                dataPoint.timestamp = now
                dataPoint.numericDelta = nil
                if case .numeric(let value) = response {
                    dataPoint.numericValue = value
                } else {
                    dataPoint.numericValue = nil
                }
                resetNonNumericFields(of: dataPoint)
            case .boolean:
                let dataPoint =
                    try existingDataPoint(for: question, on: now)
                    ?? createDataPoint(for: question, at: now)
                dataPoint.timestamp = now
                dataPoint.numericValue = nil
                dataPoint.numericDelta = nil
                dataPoint.textValue = nil
                dataPoint.selectedOptions = nil
                dataPoint.timeValue = nil
                if case .boolean(let value) = response {
                    dataPoint.boolValue = value
                } else {
                    dataPoint.boolValue = nil
                }
            case .text:
                let dataPoint =
                    try existingDataPoint(for: question, on: now)
                    ?? createDataPoint(for: question, at: now)
                dataPoint.timestamp = now
                dataPoint.numericValue = nil
                dataPoint.numericDelta = nil
                dataPoint.boolValue = nil
                dataPoint.selectedOptions = nil
                dataPoint.timeValue = nil
                if case .text(let value) = response {
                    dataPoint.textValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    dataPoint.textValue = nil
                }
            case .multipleChoice:
                let dataPoint =
                    try existingDataPoint(for: question, on: now)
                    ?? createDataPoint(for: question, at: now)
                dataPoint.timestamp = now
                dataPoint.numericValue = nil
                dataPoint.numericDelta = nil
                dataPoint.boolValue = nil
                dataPoint.textValue = nil
                dataPoint.timeValue = nil
                if case .options(let set) = response {
                    if set.isEmpty {
                        dataPoint.selectedOptions = nil
                    } else if let orderedOptions = question.options {
                        dataPoint.selectedOptions = orderedOptions.filter { set.contains($0) }
                    } else {
                        dataPoint.selectedOptions = Array(set)
                    }
                } else {
                    dataPoint.selectedOptions = nil
                }
            case .time:
                let dataPoint =
                    try existingDataPoint(for: question, on: now)
                    ?? createDataPoint(for: question, at: now)
                dataPoint.timestamp = now
                dataPoint.numericValue = nil
                dataPoint.numericDelta = nil
                dataPoint.boolValue = nil
                dataPoint.textValue = nil
                dataPoint.selectedOptions = nil
                if case .time(let date) = response {
                    dataPoint.timeValue = date
                } else {
                    dataPoint.timeValue = nil
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
            case .waterIntake:
                responses[question.id] = .numeric(0)
            case .boolean:
                responses[question.id] = .boolean(false)
            case .text:
                responses[question.id] = .text("")
            case .multipleChoice:
                responses[question.id] = .options([])
            case .time:
                let defaultDate =
                    calendar.date(bySettingHour: 9, minute: 0, second: 0, of: dateProvider())
                    ?? dateProvider()
                responses[question.id] = .time(defaultDate)
            }
        }
    }

    private func isValid(_ response: ResponseValue, for question: Question) -> Bool {
        switch (question.responseType, response) {
        case (.numeric, .numeric(let value)), (.scale, .numeric(let value)),
            (.slider, .numeric(let value)), (.waterIntake, .numeric(let value)):
            if let minimum = question.validationRules?.minimumValue, value < minimum {
                return false
            }
            if let maximum = question.validationRules?.maximumValue, value > maximum {
                return false
            }
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
                dataPoint.goal?.persistentModelID == goalIdentifier
                    && dataPoint.question?.persistentModelID == questionIdentifier
                    && dataPoint.timestamp >= startOfDay && dataPoint.timestamp < endOfDay
            }
        )
        descriptor.fetchLimit = 1

        return try modelContext.fetch(descriptor).first
    }

    private func latestDataPoint(for question: Question, on date: Date) throws -> DataPoint? {
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }

        let goalIdentifier = goal.persistentModelID
        let questionIdentifier = question.persistentModelID

        var descriptor = FetchDescriptor<DataPoint>(
            predicate: #Predicate<DataPoint> { dataPoint in
                dataPoint.goal?.persistentModelID == goalIdentifier
                    && dataPoint.question?.persistentModelID == questionIdentifier
                    && dataPoint.timestamp >= startOfDay && dataPoint.timestamp < endOfDay
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        return try modelContext.fetch(descriptor).first
    }

    private func createDataPoint(for question: Question, at timestamp: Date) -> DataPoint {
        let point = DataPoint(goal: goal, question: question, timestamp: timestamp)
        point.goal = goal
        point.question = question
        goal.dataPoints.append(point)
        question.dataPoints.append(point)
        modelContext.insert(point)
        return point
    }

    private func ensureTotalsAreForToday() {
        let today = calendar.startOfDay(for: dateProvider())
        if totalsDate != today {
            totalsDate = today
            dailyTotals.removeAll()
        }
    }

    private func runningTotal(for question: Question) -> Double {
        ensureTotalsAreForToday()
        if let cached = dailyTotals[question.id] {
            return cached
        }

        let today = totalsDate ?? calendar.startOfDay(for: dateProvider())
        if let latestPoint = try? latestDataPoint(for: question, on: today),
            let numericValue = latestPoint.numericValue
        {
            dailyTotals[question.id] = numericValue
            return numericValue
        }

        dailyTotals[question.id] = 0
        return 0
    }

    private func mostRecentNumericValue(for question: Question) -> Double? {
        question.dataPoints
            .filter { $0.numericValue != nil }
            .max(by: { $0.timestamp < $1.timestamp })?
            .numericValue
    }

    private func applyDelta(_ deltaValue: Double, for question: Question, timestamp: Date) throws
        -> Double?
    {
        ensureTotalsAreForToday()
        let currentTotal = runningTotal(for: question)

        var newTotal = currentTotal + deltaValue

        if let maximum = question.validationRules?.maximumValue {
            newTotal = min(newTotal, maximum)
        }
        if let minimum = question.validationRules?.minimumValue {
            newTotal = max(newTotal, minimum)
        }

        let appliedDelta = newTotal - currentTotal
        guard abs(appliedDelta) > .ulpOfOne else {
            return nil
        }

        let dataPoint = createDataPoint(for: question, at: timestamp)
        dataPoint.numericValue = newTotal
        dataPoint.numericDelta = appliedDelta
        dataPoint.boolValue = nil
        dataPoint.textValue = nil
        dataPoint.selectedOptions = nil
        dataPoint.timeValue = nil

        dailyTotals[question.id] = newTotal
        return appliedDelta
    }

    private func resetNonNumericFields(of dataPoint: DataPoint) {
        dataPoint.boolValue = nil
        dataPoint.textValue = nil
        dataPoint.selectedOptions = nil
        dataPoint.timeValue = nil
    }
}
