import Foundation
import Testing
import SwiftData
import Observation
@testable import Future___Life_Updates

@MainActor
struct PhaseTwoAnalyticsTests {
    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([
            TrackingGoal.self,
            Question.self,
            Schedule.self,
            DataPoint.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    @Test("Goal trends aggregates numeric responses by day")
    func goalTrendsAggregatesDailyAverages() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar(identifier: .gregorian)
        let goal = TrackingGoal(title: "Hydration", description: "Drink more water", category: .health)
        let question = Question(text: "How many glasses?", responseType: .numeric)
        goal.questions = [question]
        goal.schedule = Schedule()
        context.insert(goal)

        let baseDate = calendar.date(from: DateComponents(timeZone: .gmt, year: 2025, month: 1, day: 1, hour: 9))!
        let dayOneSecondEntry = calendar.date(byAdding: .hour, value: 6, to: baseDate)!
        let dayTwo = calendar.date(byAdding: .day, value: 1, to: baseDate)!
        let dayFour = calendar.date(byAdding: .day, value: 3, to: baseDate)!

        let points: [DataPoint] = [
            DataPoint(goal: goal, question: question, timestamp: baseDate, numericValue: 6),
            DataPoint(goal: goal, question: question, timestamp: dayOneSecondEntry, numericValue: 8),
            DataPoint(goal: goal, question: question, timestamp: dayTwo, numericValue: 10),
            DataPoint(goal: goal, question: question, timestamp: dayFour, numericValue: 4)
        ]

        goal.dataPoints.append(contentsOf: points)
        question.dataPoints.append(contentsOf: points)
        points.forEach { context.insert($0) }
        try context.save()

        let viewModel = GoalTrendsViewModel(
            goal: goal,
            modelContext: context,
            calendar: calendar,
            dateProvider: { calendar.date(byAdding: .day, value: 5, to: baseDate)! }
        )

        #expect(viewModel.dailySeries.count == 3)

        let averagesByDay: [Date: Double] = Dictionary(uniqueKeysWithValues: viewModel.dailySeries.map { dataPoint in
            (calendar.startOfDay(for: dataPoint.date), dataPoint.averageValue)
        })

    #expect(averagesByDay[calendar.startOfDay(for: baseDate)] == 7.0)
    #expect(averagesByDay[calendar.startOfDay(for: dayTwo)] == 10.0)
    #expect(averagesByDay[calendar.startOfDay(for: dayFour)] == 4.0)
    }

    @Test("Goal trends computes current streak of logged days")
    func goalTrendsComputesCurrentStreak() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar(identifier: .gregorian)
        let goal = TrackingGoal(title: "Mindfulness", description: "Daily meditation", category: .habits)
        let question = Question(text: "How long did you meditate?", responseType: .numeric)
        goal.questions = [question]
        goal.schedule = Schedule()
        context.insert(goal)

        let baseDate = calendar.date(from: DateComponents(timeZone: .gmt, year: 2025, month: 3, day: 10, hour: 7))!
        let dayMinusOne = calendar.date(byAdding: .day, value: -1, to: baseDate)!
        let dayMinusTwo = calendar.date(byAdding: .day, value: -2, to: baseDate)!
        let dayMinusFour = calendar.date(byAdding: .day, value: -4, to: baseDate)!

        let points: [DataPoint] = [
            DataPoint(goal: goal, question: question, timestamp: baseDate, numericValue: 20),
            DataPoint(goal: goal, question: question, timestamp: dayMinusOne, numericValue: 15),
            DataPoint(goal: goal, question: question, timestamp: dayMinusTwo, numericValue: 10),
            DataPoint(goal: goal, question: question, timestamp: dayMinusFour, numericValue: 25)
        ]

        goal.dataPoints.append(contentsOf: points)
        question.dataPoints.append(contentsOf: points)
        points.forEach { context.insert($0) }
        try context.save()

        let currentDate = calendar.date(byAdding: .hour, value: 2, to: baseDate)!

        let viewModel = GoalTrendsViewModel(
            goal: goal,
            modelContext: context,
            calendar: calendar,
            dateProvider: { currentDate }
        )

        #expect(viewModel.currentStreakDays == 3)
    }
}
