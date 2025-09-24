import Foundation
import Observation
import SwiftData

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

    private(set) var goal: TrackingGoal
    private(set) var dailySeries: [DailyAverage] = []
    private(set) var currentStreakDays: Int = 0
    private(set) var booleanStreaks: [BooleanStreak] = []

    private let modelContext: ModelContext
    private let calendar: Calendar
    private let dateProvider: () -> Date

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
        do {
            try rebuildNumericTrends()
        } catch {
            dailySeries = []
            currentStreakDays = 0
        }

        do {
            try rebuildBooleanStreaks()
        } catch {
            booleanStreaks = []
        }
    }

    private func rebuildNumericTrends() throws {
        let goalIdentifier = goal.persistentModelID
        var descriptor = FetchDescriptor<DataPoint>(
            predicate: #Predicate<DataPoint> { dataPoint in
                dataPoint.goal?.persistentModelID == goalIdentifier &&
                dataPoint.numericValue != nil
            },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        descriptor.propertiesToFetch = [\.timestamp, \.numericValue]

        let dataPoints = try modelContext.fetch(descriptor)
        buildDailySeries(from: dataPoints)
        computeCurrentStreak(using: dataPoints)
    }

    private func rebuildBooleanStreaks() throws {
        let goalIdentifier = goal.persistentModelID
        var streaks: [BooleanStreak] = []

        for question in goal.questions where question.responseType == .boolean {
            let questionIdentifier = question.persistentModelID
            var descriptor = FetchDescriptor<DataPoint>(
                predicate: #Predicate<DataPoint> { dataPoint in
                    dataPoint.goal?.persistentModelID == goalIdentifier &&
                    dataPoint.question?.persistentModelID == questionIdentifier &&
                    dataPoint.boolValue != nil
                },
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            descriptor.propertiesToFetch = [\.timestamp, \.boolValue]

            let points = try modelContext.fetch(descriptor)

            let successDays: Set<Date> = Set(points.compactMap { point in
                guard point.boolValue == true else { return nil }
                return calendar.startOfDay(for: point.timestamp)
            })

            let currentStreak = computeCurrentBooleanStreak(from: successDays)
            let bestStreak = computeBestBooleanStreak(from: successDays)
            let latestResponse = points.first

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

        dailySeries = aggregates
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

        let daySet: Set<Date> = Set(dataPoints.compactMap { point in
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
               calendar.isDate(day, inSameDayAs: expectedNext) {
                current += 1
            } else {
                current = 1
            }

            best = max(best, current)
            previousDay = day
        }

        return best
    }
}
