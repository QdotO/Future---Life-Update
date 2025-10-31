import Foundation
import Observation
import SwiftData
import os

/// Observes a `TrackingGoal` and produces chart-ready analytics including daily averages
/// and the user's current completion streak. All interactions occur on the main actor
/// so UI updates remain consistent with SwiftUI expectations.
@MainActor
@Observable
final class GoalTrendsViewModel {
    struct DailyAverage: Identifiable, Hashable {
        let date: Date
        let averageValue: Double
        let sampleCount: Int

        var id: Date { date }
    }

    struct BooleanStreak: Identifiable, Hashable {
        let questionID: UUID
        let questionTitle: String
        let currentStreak: Int
        let bestStreak: Int
        let lastResponseDate: Date?
        let lastResponseValue: Bool?

        var id: UUID { questionID }
    }

    struct ResponseSnapshot: Identifiable, Hashable {
        enum Status: Hashable {
            case numeric(progress: Double?, target: String?)
            case boolean(isComplete: Bool)
            case options
            case text
            case time
        }

        let questionID: UUID
        let questionTitle: String
        let responseType: ResponseType
        let primaryValue: String
        let detail: String
        let status: Status
        let timestamp: Date?

        var id: UUID { questionID }
    }

    private(set) var goal: TrackingGoal
    private(set) var dailySeries: [DailyAverage] = []
    private(set) var currentStreakDays: Int = 0
    private(set) var booleanStreaks: [BooleanStreak] = []
    private(set) var responseSnapshots: [ResponseSnapshot] = []
    
    // MARK: - Time Interval Aggregation
    private(set) var availableIntervals: [TimeInterval] = []
    private(set) var currentInterval: TimeInterval = .day
    private(set) var aggregatedSeries: [AggregatedDataPoint] = []
    private(set) var dataSpanDays: Int = 0

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

    init(
        goal: TrackingGoal,
        modelContext: ModelContext,
        calendar: Calendar = .current,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.goal = goal
        self.modelContext = modelContext
        self.calendar = calendar
        self.dateProvider = dateProvider
        refresh()
    }

    func refresh() {
        let trace = PerformanceMetrics.trace(
            "GoalTrends.refresh", metadata: ["goal": goal.id.uuidString])
        do {
            try rebuildNumericTrends()
        } catch {
            dailySeries = []
            currentStreakDays = 0
            PerformanceMetrics.logger.error(
                "GoalTrends numeric refresh failed: \(error.localizedDescription, privacy: .public)"
            )
        }
        
        // Compute available intervals AFTER dailySeries is built
        do {
            let dataPoints = try fetchAllDataPoints()
            computeAvailableIntervals(from: dataPoints)
            rebuildAggregatedSeries()
        } catch {
            availableIntervals = [.day]
            dataSpanDays = 0
            aggregatedSeries = []
            PerformanceMetrics.logger.error(
                "GoalTrends interval computation failed: \(error.localizedDescription, privacy: .public)"
            )
        }

        do {
            try rebuildBooleanStreaks()
        } catch {
            booleanStreaks = []
            PerformanceMetrics.logger.error(
                "GoalTrends boolean refresh failed: \(error.localizedDescription, privacy: .public)"
            )
        }

        do {
            try rebuildResponseSnapshots()
        } catch {
            responseSnapshots = []
            PerformanceMetrics.logger.error(
                "GoalTrends snapshot refresh failed: \(error.localizedDescription, privacy: .public)"
            )
        }

        trace.end(extraMetadata: [
            "dailySeries": "\(dailySeries.count)",
            "aggregatedSeries": "\(aggregatedSeries.count)",
            "currentInterval": currentInterval.rawValue,
            "dataSpanDays": "\(dataSpanDays)",
            "booleanStreaks": "\(booleanStreaks.count)",
            "snapshots": "\(responseSnapshots.count)",
            "streakDays": "\(currentStreakDays)",
        ])
    }
    
    // MARK: - Public Methods for Time Interval
    
    func setInterval(_ interval: TimeInterval) {
        guard availableIntervals.contains(interval) else { return }
        currentInterval = interval
        rebuildAggregatedSeries()
    }

    private func rebuildNumericTrends() throws {
        let trace = PerformanceMetrics.trace(
            "GoalTrends.rebuildNumeric", metadata: ["goal": goal.id.uuidString])
        let goalIdentifier = goal.persistentModelID
        var descriptor = FetchDescriptor<DataPoint>(
            predicate: #Predicate<DataPoint> { dataPoint in
                dataPoint.goal?.persistentModelID == goalIdentifier && dataPoint.numericValue != nil
            },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        descriptor.propertiesToFetch = [\.timestamp, \.numericValue]

        let dataPoints = try modelContext.fetch(descriptor)
        buildDailySeries(from: dataPoints)
        computeCurrentStreak(using: dataPoints)
        trace.end(extraMetadata: ["samples": "\(dataPoints.count)"])
    }

    private func rebuildBooleanStreaks() throws {
        let trace = PerformanceMetrics.trace(
            "GoalTrends.rebuildBoolean", metadata: ["goal": goal.id.uuidString])
        let booleanQuestions = goal.questions.filter { $0.responseType == .boolean }
        guard !booleanQuestions.isEmpty else {
            booleanStreaks = []
            trace.end(extraMetadata: ["result": "no-boolean-questions"])
            return
        }

        let goalIdentifier = goal.persistentModelID
        let allowedQuestionIDs = Set(booleanQuestions.map(\.id))

        var descriptor = FetchDescriptor<DataPoint>(
            predicate: #Predicate<DataPoint> { dataPoint in
                dataPoint.goal?.persistentModelID == goalIdentifier && dataPoint.boolValue != nil
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.propertiesToFetch = [\.timestamp, \.boolValue]
        descriptor.relationshipKeyPathsForPrefetching = [\.question]
        descriptor.includePendingChanges = true

        let points = try modelContext.fetch(descriptor).filter { point in
            guard let questionID = point.question?.id else { return false }
            return allowedQuestionIDs.contains(questionID)
        }

        var pointsByQuestion: [UUID: [DataPoint]] = [:]
        for point in points {
            guard let questionID = point.question?.id else { continue }
            pointsByQuestion[questionID, default: []].append(point)
        }

        var streaks: [BooleanStreak] = []
        streaks.reserveCapacity(booleanQuestions.count)

        for question in booleanQuestions {
            let questionPoints = pointsByQuestion[question.id] ?? []
            let successDays: Set<Date> = Set(
                questionPoints.compactMap { point in
                    guard point.boolValue == true else { return nil }
                    return calendar.startOfDay(for: point.timestamp)
                })

            let currentStreak = computeCurrentBooleanStreak(from: successDays)
            let bestStreak = computeBestBooleanStreak(from: successDays)
            let latestResponse = questionPoints.first

            let streak = BooleanStreak(
                questionID: question.id,
                questionTitle: question.text,
                currentStreak: currentStreak,
                bestStreak: bestStreak,
                lastResponseDate: latestResponse?.timestamp,
                lastResponseValue: latestResponse?.boolValue
            )

            streaks.append(streak)
        }

        booleanStreaks = streaks.sorted { lhs, rhs in
            if lhs.currentStreak == rhs.currentStreak {
                return lhs.questionTitle < rhs.questionTitle
            }
            return lhs.currentStreak > rhs.currentStreak
        }
        trace.end(extraMetadata: [
            "questions": "\(booleanQuestions.count)",
            "streaks": "\(booleanStreaks.count)",
        ])
    }

    private func buildDailySeries(from dataPoints: [DataPoint]) {
        var aggregates: [Date: (total: Double, count: Int)] = [:]

        for point in dataPoints {
            guard let value = point.numericValue else { continue }
            let day = calendar.startOfDay(for: point.timestamp)
            var bucket = aggregates[day] ?? (0, 0)
            bucket.total += value
            bucket.count += 1
            aggregates[day] = bucket
        }

        dailySeries =
            aggregates
            .map { entry in
                let (date, aggregate) = entry
                return DailyAverage(
                    date: date,
                    averageValue: aggregate.total / Double(aggregate.count),
                    sampleCount: aggregate.count
                )
            }
            .sorted(by: { $0.date < $1.date })
    }

    private func computeCurrentStreak(using dataPoints: [DataPoint]) {
        guard !dataPoints.isEmpty else {
            currentStreakDays = 0
            return
        }

        let now = dateProvider()

        let daySet: Set<Date> = Set(
            dataPoints.compactMap { point in
                guard point.timestamp <= now else { return nil }
                return calendar.startOfDay(for: point.timestamp)
            })

        guard !daySet.isEmpty else {
            currentStreakDays = 0
            return
        }

        var streak = 0
        var cursor = calendar.startOfDay(for: dateProvider())

        while daySet.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        currentStreakDays = streak
    }

    private func computeCurrentBooleanStreak(from successDays: Set<Date>) -> Int {
        guard !successDays.isEmpty else { return 0 }

        var streak = 0
        var cursor = calendar.startOfDay(for: dateProvider())

        while successDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        return streak
    }

    private func computeBestBooleanStreak(from successDays: Set<Date>) -> Int {
        guard !successDays.isEmpty else { return 0 }

        let sortedDays = successDays.sorted()
        var best = 0
        var current = 0
        var previousDay: Date?

        for day in sortedDays {
            if let previousDay,
                let expectedNext = calendar.date(byAdding: .day, value: 1, to: previousDay),
                calendar.isDate(day, inSameDayAs: expectedNext)
            {
                current += 1
            } else {
                current = 1
            }

            best = max(best, current)
            previousDay = day
        }

        return best
    }

    private func rebuildResponseSnapshots() throws {
        let trace = PerformanceMetrics.trace(
            "GoalTrends.rebuildSnapshots", metadata: ["goal": goal.id.uuidString])
        let goalIdentifier = goal.persistentModelID

        var descriptor = FetchDescriptor<DataPoint>(
            predicate: #Predicate<DataPoint> { dataPoint in
                dataPoint.goal?.persistentModelID == goalIdentifier
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.includePendingChanges = true
        descriptor.relationshipKeyPathsForPrefetching = [\.question]
        descriptor.propertiesToFetch = [
            \.timestamp,
            \.numericValue,
            \.numericDelta,
            \.boolValue,
            \.selectedOptions,
            \.textValue,
            \.timeValue,
        ]

        let dataPoints = try modelContext.fetch(descriptor)
        var snapshots: [UUID: ResponseSnapshot] = [:]
        snapshots.reserveCapacity(goal.questions.count)

        for point in dataPoints {
            guard let question = point.question else { continue }
            guard question.isActive else { continue }
            if snapshots[question.id] != nil { continue }

            if let snapshot = makeSnapshot(for: question, dataPoint: point) {
                snapshots[question.id] = snapshot
            }

            if snapshots.count == goal.questions.filter({ $0.isActive }).count {
                break
            }
        }

        responseSnapshots = goal.questions
            .filter { $0.isActive }
            .compactMap { snapshots[$0.id] }

        trace.end(extraMetadata: ["snapshots": "\(responseSnapshots.count)"])
    }

    private func makeSnapshot(for question: Question, dataPoint: DataPoint) -> ResponseSnapshot? {
        let timestamp = dataPoint.timestamp
        switch question.responseType {
        case .numeric, .scale, .slider:
            guard let value = dataPoint.numericValue else { return nil }
            let (progress, target) = progressInfo(for: value, rules: question.validationRules)
            return ResponseSnapshot(
                questionID: question.id,
                questionTitle: question.text,
                responseType: question.responseType,
                primaryValue: formatNumber(value),
                detail: "Most recent entry",
                status: .numeric(progress: progress, target: target),
                timestamp: timestamp
            )
        case .waterIntake:
            guard let value = dataPoint.numericValue else { return nil }
            let (progress, target) = progressInfo(for: value, rules: question.validationRules)
            return ResponseSnapshot(
                questionID: question.id,
                questionTitle: question.text,
                responseType: question.responseType,
                primaryValue: HydrationFormatter.ouncesString(value),
                detail: "Today's total",
                status: .numeric(progress: progress, target: target),
                timestamp: timestamp
            )
        case .boolean:
            guard let value = dataPoint.boolValue else { return nil }
            let detail = value ? "Marked complete" : "Not completed yet"
            return ResponseSnapshot(
                questionID: question.id,
                questionTitle: question.text,
                responseType: question.responseType,
                primaryValue: value ? "Yes" : "No",
                detail: detail,
                status: .boolean(isComplete: value),
                timestamp: timestamp
            )
        case .multipleChoice:
            guard let selections = dataPoint.selectedOptions, !selections.isEmpty else {
                return nil
            }
            let detail = selections.count == 1 ? "Latest choice" : "Latest choices"
            return ResponseSnapshot(
                questionID: question.id,
                questionTitle: question.text,
                responseType: question.responseType,
                primaryValue: selections.joined(separator: ", "),
                detail: detail,
                status: .options,
                timestamp: timestamp
            )
        case .text:
            guard let text = dataPoint.textValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                !text.isEmpty
            else { return nil }
            return ResponseSnapshot(
                questionID: question.id,
                questionTitle: question.text,
                responseType: question.responseType,
                primaryValue: text,
                detail: "Latest entry",
                status: .text,
                timestamp: timestamp
            )
        case .time:
            guard let value = dataPoint.timeValue else { return nil }
            return ResponseSnapshot(
                questionID: question.id,
                questionTitle: question.text,
                responseType: question.responseType,
                primaryValue: formatTime(
                    value, timezoneIdentifier: goal.schedule.timezoneIdentifier),
                detail: "Logged time",
                status: .time,
                timestamp: timestamp
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

    private func formatTime(_ date: Date, timezoneIdentifier: String) -> String {
        timeFormatter.timeZone = TimeZone(identifier: timezoneIdentifier) ?? .current
        return timeFormatter.string(from: date)
    }
    
    // MARK: - Time Interval Aggregation Methods
    
    private func fetchAllDataPoints() throws -> [DataPoint] {
        let goalIdentifier = goal.persistentModelID
        var descriptor = FetchDescriptor<DataPoint>(
            predicate: #Predicate<DataPoint> { dataPoint in
                dataPoint.goal?.persistentModelID == goalIdentifier
            },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        descriptor.propertiesToFetch = [\.timestamp, \.numericValue]
        return try modelContext.fetch(descriptor)
    }
    
    private func computeAvailableIntervals(from dataPoints: [DataPoint]) {
        guard !dataPoints.isEmpty else {
            availableIntervals = [.day]
            dataSpanDays = 0
            return
        }
        
        let sortedDates = dataPoints.map { $0.timestamp }.sorted()
        guard let firstDate = sortedDates.first,
              let lastDate = sortedDates.last else {
            availableIntervals = [.day]
            dataSpanDays = 0
            return
        }
        
        let daySpan = calendar.dateComponents([.day], from: firstDate, to: lastDate).day ?? 0
        dataSpanDays = daySpan
        
        // Filter intervals based on minimum data requirements
        availableIntervals = TimeInterval.allCases.filter { interval in
            daySpan >= interval.minimumDataDays
        }
        
        // Auto-select interval based on data span
        currentInterval = autoSelectInterval(for: daySpan)
    }
    
    private func autoSelectInterval(for daySpan: Int) -> TimeInterval {
        if daySpan < 14 {
            return .day
        } else if daySpan < 28 {
            return .week
        } else if daySpan < 90 {
            return .month
        } else if daySpan < 180 {
            return .quarter
        } else if daySpan < 365 {
            return .half
        } else {
            return .year
        }
    }
    
    private func rebuildAggregatedSeries() {
        guard !dailySeries.isEmpty else {
            aggregatedSeries = []
            return
        }
        
        switch currentInterval {
        case .day:
            // Use dailySeries as-is, convert to AggregatedDataPoint for consistency
            aggregatedSeries = dailySeries.map { daily in
                AggregatedDataPoint(
                    startDate: daily.date,
                    endDate: daily.date,
                    averageValue: daily.averageValue,
                    minValue: daily.averageValue,
                    maxValue: daily.averageValue,
                    sampleCount: daily.sampleCount,
                    interval: .day
                )
            }
        case .week:
            aggregatedSeries = aggregateByWeek()
        case .month:
            aggregatedSeries = aggregateByMonth()
        case .quarter:
            aggregatedSeries = aggregateByQuarter()
        case .half:
            aggregatedSeries = aggregateByHalf()
        case .year:
            aggregatedSeries = aggregateByYear()
        }
    }
    
    private func aggregateByWeek() -> [AggregatedDataPoint] {
        var buckets: [Date: [DailyAverage]] = [:]
        
        for daily in dailySeries {
            // Get start of week
            let weekStart = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: daily.date)
            guard let weekDate = calendar.date(from: weekStart) else { continue }
            
            buckets[weekDate, default: []].append(daily)
        }
        
        return buckets.map { (weekStart, dailies) in
            let values = dailies.map { $0.averageValue }
            let avgValue = values.reduce(0, +) / Double(values.count)
            let minValue = values.min() ?? avgValue
            let maxValue = values.max() ?? avgValue
            let totalSamples = dailies.map { $0.sampleCount }.reduce(0, +)
            
            // End date is 6 days after start
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
            
            return AggregatedDataPoint(
                startDate: weekStart,
                endDate: weekEnd,
                averageValue: avgValue,
                minValue: minValue,
                maxValue: maxValue,
                sampleCount: totalSamples,
                interval: .week
            )
        }.sorted(by: { $0.startDate < $1.startDate })
    }
    
    private func aggregateByMonth() -> [AggregatedDataPoint] {
        var buckets: [Date: [DailyAverage]] = [:]
        
        for daily in dailySeries {
            let monthStart = calendar.dateComponents([.year, .month], from: daily.date)
            guard let monthDate = calendar.date(from: monthStart) else { continue }
            
            buckets[monthDate, default: []].append(daily)
        }
        
        return buckets.map { (monthStart, dailies) in
            let values = dailies.map { $0.averageValue }
            let avgValue = values.reduce(0, +) / Double(values.count)
            let minValue = values.min() ?? avgValue
            let maxValue = values.max() ?? avgValue
            let totalSamples = dailies.map { $0.sampleCount }.reduce(0, +)
            
            // End date is last day of month
            let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) ?? monthStart
            
            return AggregatedDataPoint(
                startDate: monthStart,
                endDate: monthEnd,
                averageValue: avgValue,
                minValue: minValue,
                maxValue: maxValue,
                sampleCount: totalSamples,
                interval: .month
            )
        }.sorted(by: { $0.startDate < $1.startDate })
    }
    
    private func aggregateByQuarter() -> [AggregatedDataPoint] {
        var buckets: [Date: [DailyAverage]] = [:]
        
        for daily in dailySeries {
            let components = calendar.dateComponents([.year, .quarter], from: daily.date)
            guard let year = components.year, let quarter = components.quarter else { continue }
            
            // Convert quarter to month (Q1 = Jan, Q2 = Apr, Q3 = Jul, Q4 = Oct)
            let month = (quarter - 1) * 3 + 1
            guard let quarterStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else {
                continue
            }
            
            buckets[quarterStart, default: []].append(daily)
        }
        
        return buckets.map { (quarterStart, dailies) in
            let values = dailies.map { $0.averageValue }
            let avgValue = values.reduce(0, +) / Double(values.count)
            let minValue = values.min() ?? avgValue
            let maxValue = values.max() ?? avgValue
            let totalSamples = dailies.map { $0.sampleCount }.reduce(0, +)
            
            // End date is last day of quarter (3 months - 1 day)
            let quarterEnd = calendar.date(byAdding: DateComponents(month: 3, day: -1), to: quarterStart) ?? quarterStart
            
            return AggregatedDataPoint(
                startDate: quarterStart,
                endDate: quarterEnd,
                averageValue: avgValue,
                minValue: minValue,
                maxValue: maxValue,
                sampleCount: totalSamples,
                interval: .quarter
            )
        }.sorted(by: { $0.startDate < $1.startDate })
    }
    
    private func aggregateByHalf() -> [AggregatedDataPoint] {
        var buckets: [Date: [DailyAverage]] = [:]
        
        for daily in dailySeries {
            let components = calendar.dateComponents([.year, .month], from: daily.date)
            guard let year = components.year, let month = components.month else { continue }
            
            // Determine half: H1 (Jan-Jun), H2 (Jul-Dec)
            let halfStartMonth = month <= 6 ? 1 : 7
            guard let halfStart = calendar.date(from: DateComponents(year: year, month: halfStartMonth, day: 1)) else {
                continue
            }
            
            buckets[halfStart, default: []].append(daily)
        }
        
        return buckets.map { (halfStart, dailies) in
            let values = dailies.map { $0.averageValue }
            let avgValue = values.reduce(0, +) / Double(values.count)
            let minValue = values.min() ?? avgValue
            let maxValue = values.max() ?? avgValue
            let totalSamples = dailies.map { $0.sampleCount }.reduce(0, +)
            
            // End date is last day of half (6 months - 1 day)
            let halfEnd = calendar.date(byAdding: DateComponents(month: 6, day: -1), to: halfStart) ?? halfStart
            
            return AggregatedDataPoint(
                startDate: halfStart,
                endDate: halfEnd,
                averageValue: avgValue,
                minValue: minValue,
                maxValue: maxValue,
                sampleCount: totalSamples,
                interval: .half
            )
        }.sorted(by: { $0.startDate < $1.startDate })
    }
    
    private func aggregateByYear() -> [AggregatedDataPoint] {
        var buckets: [Date: [DailyAverage]] = [:]
        
        for daily in dailySeries {
            let yearStart = calendar.dateComponents([.year], from: daily.date)
            guard let yearDate = calendar.date(from: yearStart) else { continue }
            
            buckets[yearDate, default: []].append(daily)
        }
        
        return buckets.map { (yearStart, dailies) in
            let values = dailies.map { $0.averageValue }
            let avgValue = values.reduce(0, +) / Double(values.count)
            let minValue = values.min() ?? avgValue
            let maxValue = values.max() ?? avgValue
            let totalSamples = dailies.map { $0.sampleCount }.reduce(0, +)
            
            // End date is last day of year
            let yearEnd = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: yearStart) ?? yearStart
            
            return AggregatedDataPoint(
                startDate: yearStart,
                endDate: yearEnd,
                averageValue: avgValue,
                minValue: minValue,
                maxValue: maxValue,
                sampleCount: totalSamples,
                interval: .year
            )
        }.sorted(by: { $0.startDate < $1.startDate })
    }
}
