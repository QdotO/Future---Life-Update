import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class TodayDashboardViewModel {
    struct GoalSummary: Identifiable, Hashable {
        let id: UUID
        let title: String
        let categoryDisplayName: String?
        let timezoneIdentifier: String
    }

    struct UpcomingReminder: Identifiable, Hashable {
        let id = UUID()
        let goal: GoalSummary
        let scheduledDate: Date

        var timezoneIdentifier: String { goal.timezoneIdentifier }
    }

    struct GoalQuestionMetrics: Identifiable, Hashable {
        let goal: GoalSummary
        let metrics: [QuestionMetric]

        var id: UUID { goal.id }
    }

    struct QuestionMetric: Identifiable, Hashable {
    enum MetricStatus: Hashable {
            case numeric
            case boolean(isComplete: Bool)
            case options
            case text
            case time
        }

        let id: UUID
        let questionText: String
        let responseType: ResponseType
        let primaryValue: String
        let detail: String
        let status: MetricStatus
        let progressFraction: Double?
        let targetValue: String?
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
    private var snapshotCache: DashboardSnapshot?
    private static let cacheTTL: TimeInterval = 20

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
        let trace = PerformanceMetrics.trace("TodayDashboard.refresh")
        let now = dateProvider()
        let startOfDay = calendar.startOfDay(for: now)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            trace.end(extraMetadata: ["error": "endOfDay"])
            return
        }

        let activeGoals = fetchActiveGoals()
        let activeGoalIDs = Set(activeGoals.map(\.id))
        let newestGoalUpdate = activeGoals.map(\.updatedAt).max() ?? .distantPast

        if let cache = snapshotCache,
           calendar.isDate(cache.timestamp, inSameDayAs: now),
           now.timeIntervalSince(cache.timestamp) < Self.cacheTTL,
           cache.goalIDs == activeGoalIDs,
           cache.newestGoalUpdate == newestGoalUpdate,
           !modelContext.hasChanges {
            upcomingReminders = cache.reminders
            goalQuestionMetrics = cache.metrics
            trace.end(extraMetadata: [
                "goals": "\(activeGoals.count)",
                "reminders": "\(upcomingReminders.count)",
                "metrics": "\(goalQuestionMetrics.reduce(0) { $0 + $1.metrics.count })",
                "source": "cache"
            ])
            return
        }

        upcomingReminders = computeUpcomingReminders(for: activeGoals, referenceDate: now)
        goalQuestionMetrics = computeGoalQuestionMetrics(
            for: activeGoals,
            startOfDay: startOfDay,
            endOfDay: endOfDay
        )

        trace.end(extraMetadata: [
            "goals": "\(activeGoals.count)",
            "reminders": "\(upcomingReminders.count)",
            "metrics": "\(goalQuestionMetrics.reduce(0) { $0 + $1.metrics.count })",
            "source": "fresh"
        ])

        snapshotCache = DashboardSnapshot(
            timestamp: now,
            newestGoalUpdate: newestGoalUpdate,
            goalIDs: activeGoalIDs,
            reminders: upcomingReminders,
            metrics: goalQuestionMetrics
        )
    }

    private func fetchActiveGoals() -> [TrackingGoal] {
        let trace = PerformanceMetrics.trace("TodayDashboard.fetchActiveGoals")
        var descriptor = FetchDescriptor<TrackingGoal>(predicate: #Predicate { goal in
            goal.isActive
        })
        descriptor.includePendingChanges = true
        descriptor.sortBy = [SortDescriptor(\TrackingGoal.updatedAt, order: .reverse)]
        let goals = (try? modelContext.fetch(descriptor)) ?? []
        trace.end(extraMetadata: ["goals": "\(goals.count)"])
        return goals
    }

    private func computeUpcomingReminders(for goals: [TrackingGoal], referenceDate: Date) -> [UpcomingReminder] {
        let trace = PerformanceMetrics.trace("TodayDashboard.computeUpcomingReminders", metadata: ["goalCount": "\(goals.count)"])
        let reminderItems = goals.flatMap { goal in
            reminders(for: goal, referenceDate: referenceDate)
        }
        .sorted { $0.scheduledDate < $1.scheduledDate }
        trace.end(extraMetadata: ["reminders": "\(reminderItems.count)"])
        return reminderItems
    }

    private func reminders(for goal: TrackingGoal, referenceDate: Date) -> [UpcomingReminder] {
        guard goal.isActive, !goal.schedule.times.isEmpty else { return [] }

        var goalCalendar = calendar
        goalCalendar.timeZone = goal.schedule.timezone

        guard occurs(on: referenceDate, schedule: goal.schedule, calendar: goalCalendar) else { return [] }

        let summary = makeSummary(for: goal)
        let startOfDay = goalCalendar.startOfDay(for: referenceDate)
        return goal.schedule.times.compactMap { scheduleTime in
            guard let occurrence = scheduleTime.date(on: startOfDay, calendar: goalCalendar) else {
                return nil
            }
            guard occurrence >= referenceDate else { return nil }
            return UpcomingReminder(goal: summary, scheduledDate: occurrence)
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
        let trace = PerformanceMetrics.trace("TodayDashboard.computeMetrics", metadata: ["goalCount": "\(goals.count)"])
        guard !goals.isEmpty else {
            trace.end(extraMetadata: ["result": "no-goals"])
            return []
        }

        let allowedGoalIDs = Set(goals.map(\.id))

        var descriptor = FetchDescriptor<DataPoint>(predicate: #Predicate { dataPoint in
            dataPoint.timestamp >= startOfDay && dataPoint.timestamp < endOfDay
        })
        descriptor.includePendingChanges = true
        descriptor.propertiesToFetch = [
            \.timestamp,
            \.numericValue,
            \.boolValue,
            \.selectedOptions,
            \.textValue,
            \.timeValue
        ]
        descriptor.relationshipKeyPathsForPrefetching = [\.question, \.goal]

        let todaysDataPoints = (try? modelContext.fetch(descriptor))?.filter { dataPoint in
            guard let goalID = dataPoint.goal?.id else { return false }
            return allowedGoalIDs.contains(goalID)
        } ?? []

        var pointsByQuestion: [UUID: [DataPoint]] = [:]
        for dataPoint in todaysDataPoints {
            guard let question = dataPoint.question else { continue }
            pointsByQuestion[question.id, default: []].append(dataPoint)
        }

        let goalMetrics = goals.map { goal in
            let summary = makeSummary(for: goal)
            let questionMetrics = goal.questions
                .filter { $0.isActive }
                .compactMap { question in
                    metric(
                        for: question,
                        dataPoints: pointsByQuestion[question.id] ?? [],
                        goalTimezoneIdentifier: summary.timezoneIdentifier
                    )
                }

            return GoalQuestionMetrics(goal: summary, metrics: questionMetrics)
        }

        trace.end(extraMetadata: [
            "dataPoints": "\(todaysDataPoints.count)",
            "questions": "\(pointsByQuestion.count)",
            "metrics": "\(goalMetrics.reduce(0) { $0 + $1.metrics.count })"
        ])
        return goalMetrics
    }

    private func metric(
        for question: Question,
        dataPoints: [DataPoint],
        goalTimezoneIdentifier: String
    ) -> QuestionMetric? {
        let trace = PerformanceMetrics.trace("TodayDashboard.metric", metadata: [
            "question": question.id.uuidString,
            "type": question.responseType.displayName
        ])
        let latest = dataPoints.max(by: { $0.timestamp < $1.timestamp })
        var result: QuestionMetric?

        switch question.responseType {
        case .numeric, .scale, .slider:
            if let value = latest?.numericValue {
                let detail = question.responseType == .numeric ? "Today's total" : "So far today"
                let (progress, target) = progressInfo(for: value, rules: question.validationRules)
                result = QuestionMetric(
                    id: question.id,
                    questionText: question.text,
                    responseType: question.responseType,
                    primaryValue: formatNumber(value),
                    detail: detail,
                    status: .numeric,
                    progressFraction: progress,
                    targetValue: target
                )
            }
        case .boolean:
            if let value = latest?.boolValue {
                let detail = value ? "Completed" : "Not yet"
                result = QuestionMetric(
                    id: question.id,
                    questionText: question.text,
                    responseType: question.responseType,
                    primaryValue: value ? "Yes" : "No",
                    detail: detail,
                    status: .boolean(isComplete: value),
                    progressFraction: nil,
                    targetValue: nil
                )
            }
        case .multipleChoice:
            if let selections = latest?.selectedOptions, !selections.isEmpty {
                let detail = selections.count == 1 ? "1 choice" : "\(selections.count) choices"
                result = QuestionMetric(
                    id: question.id,
                    questionText: question.text,
                    responseType: question.responseType,
                    primaryValue: selections.joined(separator: ", "),
                    detail: detail,
                    status: .options,
                    progressFraction: nil,
                    targetValue: nil
                )
            }
        case .text:
            if let text = latest?.textValue?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                result = QuestionMetric(
                    id: question.id,
                    questionText: question.text,
                    responseType: question.responseType,
                    primaryValue: text,
                    detail: "Latest entry",
                    status: .text,
                    progressFraction: nil,
                    targetValue: nil
                )
            }
        case .time:
            if let date = latest?.timeValue {
                result = QuestionMetric(
                    id: question.id,
                    questionText: question.text,
                    responseType: question.responseType,
                    primaryValue: formatTime(date, timezoneIdentifier: goalTimezoneIdentifier),
                    detail: "Logged time",
                    status: .time,
                    progressFraction: nil,
                    targetValue: nil
                )
            }
        }

        trace.end(extraMetadata: ["result": result == nil ? "nil" : "value"])
        return result
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

    private func makeSummary(for goal: TrackingGoal) -> GoalSummary {
        GoalSummary(
            id: goal.id,
            title: goal.title,
            categoryDisplayName: goal.categoryDisplayName.nonEmpty,
            timezoneIdentifier: goal.schedule.timezoneIdentifier
        )
    }

    private func formatNumber(_ value: Double) -> String {
        numberFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }

    private func formatTime(_ date: Date, timezoneIdentifier: String) -> String {
        timeFormatter.timeZone = TimeZone(identifier: timezoneIdentifier) ?? .current
        return timeFormatter.string(from: date)
    }

    func invalidateCache() {
        snapshotCache = nil
    }
}

private struct DashboardSnapshot {
    let timestamp: Date
    let newestGoalUpdate: Date
    let goalIDs: Set<UUID>
    let reminders: [TodayDashboardViewModel.UpcomingReminder]
    let metrics: [TodayDashboardViewModel.GoalQuestionMetrics]
}
