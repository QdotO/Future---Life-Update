import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class TodayDashboardViewModel {
    struct UpcomingReminder: Identifiable {
        let id = UUID()
        let goal: TrackingGoal
        let scheduledDate: Date

        var timezoneIdentifier: String {
            goal.schedule.timezoneIdentifier
        }
    }

    struct GoalQuestionMetrics: Identifiable {
        let goal: TrackingGoal
        let metrics: [QuestionMetric]

        var id: UUID { goal.id }
    }

    struct QuestionMetric: Identifiable {
        enum MetricStatus {
            case numeric
            case boolean(isComplete: Bool)
            case options
            case text
            case time
        }

        let question: Question
        let primaryValue: String
        let detail: String
        let status: MetricStatus
        let progressFraction: Double?
        let targetValue: String?

        var id: UUID { question.id }
    }

    private let modelContext: ModelContext
    private let calendar: Calendar
    private let dateProvider: () -> Date
    private let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    private(set) var upcomingReminders: [UpcomingReminder] = []
    private(set) var goalQuestionMetrics: [GoalQuestionMetrics] = []

    init(
        modelContext: ModelContext,
        calendar: Calendar = .current,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.modelContext = modelContext
        self.calendar = calendar
        self.dateProvider = dateProvider
    }

    func refresh() {
        let now = dateProvider()
        let startOfDay = calendar.startOfDay(for: now)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let activeGoals = fetchActiveGoals()
        upcomingReminders = computeUpcomingReminders(for: activeGoals, referenceDate: now)
        goalQuestionMetrics = computeGoalQuestionMetrics(
            for: activeGoals,
            startOfDay: startOfDay,
            endOfDay: endOfDay
        )
    }

    private func fetchActiveGoals() -> [TrackingGoal] {
        var descriptor = FetchDescriptor<TrackingGoal>(predicate: #Predicate { goal in
            goal.isActive
        })
        descriptor.includePendingChanges = true
        descriptor.sortBy = [SortDescriptor(\TrackingGoal.updatedAt, order: .reverse)]
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func computeUpcomingReminders(for goals: [TrackingGoal], referenceDate: Date) -> [UpcomingReminder] {
        goals.flatMap { goal in
            reminders(for: goal, referenceDate: referenceDate)
        }
        .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    private func reminders(for goal: TrackingGoal, referenceDate: Date) -> [UpcomingReminder] {
        guard goal.isActive, !goal.schedule.times.isEmpty else { return [] }

        var goalCalendar = calendar
        goalCalendar.timeZone = goal.schedule.timezone

        guard occurs(on: referenceDate, schedule: goal.schedule, calendar: goalCalendar) else { return [] }

        let startOfDay = goalCalendar.startOfDay(for: referenceDate)
        return goal.schedule.times.compactMap { scheduleTime in
            guard let occurrence = scheduleTime.date(on: startOfDay, calendar: goalCalendar) else {
                return nil
            }
            guard occurrence >= referenceDate else { return nil }
            return UpcomingReminder(goal: goal, scheduledDate: occurrence)
        }
    }

    private func occurs(on date: Date, schedule: Schedule, calendar: Calendar) -> Bool {
        switch schedule.frequency {
        case .once:
            return calendar.isDate(schedule.startDate, inSameDayAs: date)
        case .daily:
            return true
        case .weekly:
            let weekday = calendar.component(.weekday, from: date)
            let matchedWeekday = schedule.selectedWeekdays.contains { $0.rawValue == weekday }
            if !schedule.selectedWeekdays.isEmpty {
                return matchedWeekday
            }
            return matchedWeekday || calendar.isDate(schedule.startDate, inSameDayAs: date)
        case .monthly:
            let day = calendar.component(.day, from: date)
            let startDay = calendar.component(.day, from: schedule.startDate)
            return day == startDay
        case .custom:
            guard let interval = schedule.intervalDayCount, interval > 0 else { return false }
            let normalizedStart = calendar.startOfDay(for: schedule.startDate)
            let normalizedTarget = calendar.startOfDay(for: date)
            guard normalizedTarget >= normalizedStart else { return false }
            let delta = calendar.dateComponents([.day], from: normalizedStart, to: normalizedTarget).day ?? 0
            return delta % interval == 0
        }
    }

    private func computeGoalQuestionMetrics(for goals: [TrackingGoal], startOfDay: Date, endOfDay: Date) -> [GoalQuestionMetrics] {
        var descriptor = FetchDescriptor<DataPoint>(predicate: #Predicate { dataPoint in
            dataPoint.timestamp >= startOfDay && dataPoint.timestamp < endOfDay
        })
        descriptor.includePendingChanges = true
        let todaysDataPoints = (try? modelContext.fetch(descriptor)) ?? []

        var pointsByQuestion: [UUID: [DataPoint]] = [:]
        for dataPoint in todaysDataPoints {
            guard let question = dataPoint.question else { continue }
            pointsByQuestion[question.id, default: []].append(dataPoint)
        }

        return goals.map { goal in
            let metrics = goal.questions
                .filter { $0.isActive }
                .compactMap { question in
                    metric(for: question, dataPoints: pointsByQuestion[question.id] ?? [])
                }

            return GoalQuestionMetrics(goal: goal, metrics: metrics)
        }
    }

    private func metric(for question: Question, dataPoints: [DataPoint]) -> QuestionMetric? {
        let latest = dataPoints.max(by: { $0.timestamp < $1.timestamp })

        switch question.responseType {
        case .numeric, .scale, .slider:
            guard let value = latest?.numericValue else { return nil }
            let detail = question.responseType == .numeric ? "Today's total" : "So far today"
            let (progress, target) = progressInfo(for: value, rules: question.validationRules)
            return QuestionMetric(
                question: question,
                primaryValue: formatNumber(value),
                detail: detail,
                status: .numeric,
                progressFraction: progress,
                targetValue: target
            )
        case .boolean:
            guard let value = latest?.boolValue else { return nil }
            let detail = value ? "Completed" : "Not yet"
            return QuestionMetric(
                question: question,
                primaryValue: value ? "Yes" : "No",
                detail: detail,
                status: .boolean(isComplete: value),
                progressFraction: nil,
                targetValue: nil
            )
        case .multipleChoice:
            guard let selections = latest?.selectedOptions, !selections.isEmpty else { return nil }
            let detail = selections.count == 1 ? "1 choice" : "\(selections.count) choices"
            return QuestionMetric(
                question: question,
                primaryValue: selections.joined(separator: ", "),
                detail: detail,
                status: .options,
                progressFraction: nil,
                targetValue: nil
            )
        case .text:
            guard let text = latest?.textValue?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
            return QuestionMetric(
                question: question,
                primaryValue: text,
                detail: "Latest entry",
                status: .text,
                progressFraction: nil,
                targetValue: nil
            )
        case .time:
            guard let date = latest?.timeValue else { return nil }
            return QuestionMetric(
                question: question,
                primaryValue: formatTime(date, timezoneIdentifier: question.goal?.schedule.timezoneIdentifier),
                detail: "Logged time",
                status: .time,
                progressFraction: nil,
                targetValue: nil
            )
        }
    }

    private func progressInfo(for value: Double, rules: ValidationRules?) -> (Double?, String?) {
        guard let rules, let maximum = rules.maximumValue, maximum > 0 else {
            return (nil, nil)
        }

        let minimum = rules.minimumValue ?? 0
        let normalized = (value - minimum) / max(maximum - minimum, .ulpOfOne)
        let clamped = max(0, min(1, normalized))

        return (
            clamped,
            "Goal " + formatNumber(maximum)
        )
    }

    private func formatNumber(_ value: Double) -> String {
        numberFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }

    private func formatTime(_ date: Date, timezoneIdentifier: String?) -> String {
        if let identifier = timezoneIdentifier, let timeZone = TimeZone(identifier: identifier) {
            timeFormatter.timeZone = timeZone
        } else {
            timeFormatter.timeZone = .current
        }
        return timeFormatter.string(from: date)
    }
}
