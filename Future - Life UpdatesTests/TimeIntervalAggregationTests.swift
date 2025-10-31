import Foundation
import Testing
import SwiftData
@testable import Future___Life_Updates

@MainActor
struct TimeIntervalAggregationTests {
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
    
    private func createGoalWithDataPoints(
        context: ModelContext,
        dataPointCount: Int,
        startDate: Date = Date()
    ) throws -> TrackingGoal {
        let goal = TrackingGoal(title: "Test Goal", description: "Test", category: .health)
        context.insert(goal)
        
        let question = Question(
            text: "How much water?",
            responseType: .numeric,
            validationRules: ValidationRules(minimumValue: 0, maximumValue: 100)
        )
        goal.questions.append(question)
        
        let calendar = Calendar.current
        for dayOffset in 0..<dataPointCount {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: startDate)!
            let dataPoint = DataPoint(questionID: question.id, questionTitle: question.text)
            dataPoint.timestamp = date
            dataPoint.numericValue = Double(dayOffset % 10 + 1) // Values 1-10
            dataPoint.question = question
            dataPoint.goal = goal
            context.insert(dataPoint)
            goal.dataPoints.append(dataPoint)
        }
        
        try context.save()
        return goal
    }
    
    @Test("TimeInterval enum has correct minimum data days")
    func timeIntervalMinimumDataDays() {
        #expect(TimeInterval.day.minimumDataDays == 1)
        #expect(TimeInterval.week.minimumDataDays == 14)
        #expect(TimeInterval.month.minimumDataDays == 28)
        #expect(TimeInterval.quarter.minimumDataDays == 90)
        #expect(TimeInterval.half.minimumDataDays == 180)
        #expect(TimeInterval.year.minimumDataDays == 365)
    }
    
    @Test("GoalTrendsViewModel with 5 days of data auto-selects day interval")
    func viewModelAutoSelectsDayInterval() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let goal = try createGoalWithDataPoints(context: context, dataPointCount: 5)
        
        let viewModel = GoalTrendsViewModel(goal: goal, modelContext: context)
        
        #expect(viewModel.currentInterval == .day)
        #expect(viewModel.availableIntervals == [.day])
        #expect(viewModel.dataSpanDays >= 4) // At least 4 days span
    }
    
    @Test("GoalTrendsViewModel with 20 days of data auto-selects week interval")
    func viewModelAutoSelectsWeekInterval() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let goal = try createGoalWithDataPoints(context: context, dataPointCount: 20)
        
        let viewModel = GoalTrendsViewModel(goal: goal, modelContext: context)
        
        #expect(viewModel.currentInterval == .week)
        #expect(viewModel.availableIntervals.contains(.day))
        #expect(viewModel.availableIntervals.contains(.week))
        #expect(viewModel.dataSpanDays >= 19)
    }
    
    @Test("GoalTrendsViewModel with 40 days of data auto-selects month interval")
    func viewModelAutoSelectsMonthInterval() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let goal = try createGoalWithDataPoints(context: context, dataPointCount: 40)
        
        let viewModel = GoalTrendsViewModel(goal: goal, modelContext: context)
        
        #expect(viewModel.currentInterval == .month)
        #expect(viewModel.availableIntervals.contains(.day))
        #expect(viewModel.availableIntervals.contains(.week))
        #expect(viewModel.availableIntervals.contains(.month))
        #expect(viewModel.dataSpanDays >= 39)
    }
    
    @Test("Aggregated series for day interval matches daily series count")
    func aggregatedSeriesDayIntervalMatchesDailySeries() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let goal = try createGoalWithDataPoints(context: context, dataPointCount: 10)
        
        let viewModel = GoalTrendsViewModel(goal: goal, modelContext: context)
        viewModel.setInterval(.day)
        
        #expect(viewModel.aggregatedSeries.count == viewModel.dailySeries.count)
    }
    
    @Test("Weekly aggregation reduces data point count")
    func weeklyAggregationReducesDataPoints() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let goal = try createGoalWithDataPoints(context: context, dataPointCount: 21) // 3 weeks
        
        let viewModel = GoalTrendsViewModel(goal: goal, modelContext: context)
        viewModel.setInterval(.week)
        
        // Should have approximately 3 weeks of data (could be 2-4 depending on alignment)
        #expect(viewModel.aggregatedSeries.count >= 2)
        #expect(viewModel.aggregatedSeries.count <= 4)
        #expect(viewModel.aggregatedSeries.count < viewModel.dailySeries.count)
    }
    
    @Test("Monthly aggregation computes averages correctly")
    func monthlyAggregationComputesAverages() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let goal = try createGoalWithDataPoints(context: context, dataPointCount: 35) // ~1 month
        
        let viewModel = GoalTrendsViewModel(goal: goal, modelContext: context)
        viewModel.setInterval(.month)
        
        #expect(!viewModel.aggregatedSeries.isEmpty)
        
        // Check that aggregated values are reasonable
        for aggregated in viewModel.aggregatedSeries {
            #expect(aggregated.averageValue > 0)
            #expect(aggregated.averageValue <= 10) // Our test data is 1-10
            #expect(aggregated.minValue <= aggregated.averageValue)
            #expect(aggregated.maxValue >= aggregated.averageValue)
            #expect(aggregated.sampleCount > 0)
        }
    }
    
    @Test("setInterval updates current interval")
    func setIntervalUpdatesCurrentInterval() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let goal = try createGoalWithDataPoints(context: context, dataPointCount: 40)
        
        let viewModel = GoalTrendsViewModel(goal: goal, modelContext: context)
        
        let originalInterval = viewModel.currentInterval
        let originalSeriesCount = viewModel.aggregatedSeries.count
        
        // Try changing to day interval
        viewModel.setInterval(.day)
        
        #expect(viewModel.currentInterval == .day)
        #expect(viewModel.aggregatedSeries.count != originalSeriesCount)
    }
    
    @Test("AggregatedDataPoint display label formats correctly")
    func aggregatedDataPointDisplayLabel() {
        let startDate = Date(timeIntervalSince1970: 1609459200) // Jan 1, 2021
        
        let dayPoint = AggregatedDataPoint(
            startDate: startDate,
            endDate: startDate,
            averageValue: 5.0,
            minValue: 5.0,
            maxValue: 5.0,
            sampleCount: 1,
            interval: .day
        )
        #expect(!dayPoint.displayLabel.isEmpty)
        
        let monthPoint = AggregatedDataPoint(
            startDate: startDate,
            endDate: startDate,
            averageValue: 5.0,
            minValue: 5.0,
            maxValue: 5.0,
            sampleCount: 30,
            interval: .month
        )
        #expect(!monthPoint.displayLabel.isEmpty)
        
        let yearPoint = AggregatedDataPoint(
            startDate: startDate,
            endDate: startDate,
            averageValue: 5.0,
            minValue: 5.0,
            maxValue: 5.0,
            sampleCount: 365,
            interval: .year
        )
        #expect(!yearPoint.displayLabel.isEmpty)
    }
}
