# Insights Tab: Time Interval Aggregation Implementation Plan

## Overview

This document outlines the implementation plan for adding progressive time-based aggregation to the Insights tab. As users accumulate more data, the chart will automatically adapt to show aggregated views (weekly, monthly, quarterly, etc.) to keep visualizations clear and actionable.

---

## Current State Analysis

### GoalTrendsViewModel (Current Behavior)

**Data Processing:**
- Fetches all DataPoints for a goal
- Aggregates by **day** only (via `buildDailySeries`)
- Computes daily averages for numeric values
- Tracks boolean streaks (current and best)
- No concept of time intervals or date range awareness

**Chart Display (GoalTrendsView):**
- Shows ALL daily data points with LineMark + AreaMark
- Adds PointMark with annotation on EVERY data point
- Uses `.annotation(position: .top)` showing numeric values
- No aggregation beyond daily
- Chart becomes cluttered with 14+ days of data

**Problem:**
After ~1.5 months of usage, the chart is overcrowded with individual data points making it hard to identify trends.

---

## Requirements

### Functional Requirements

1. **Automatic Interval Detection**
   - System detects the span of available data (first to last data point)
   - Automatically selects appropriate interval based on data span
   - No user action required for initial view

2. **Time Intervals**
   - **Day:** < 14 days of data (current behavior)
   - **Week:** 14-28 days of data
   - **Month:** 28-90 days (3 months)
   - **Quarter:** 90-180 days (6 months)
   - **Half:** 180-365 days (1 year)
   - **Year:** 365+ days

3. **Manual Interval Selection**
   - User can override automatic selection
   - Picker shows: Day | Week | Month | Quarter | Half | Year
   - Only show intervals that have sufficient data (e.g., hide "Year" if < 365 days)

4. **Aggregation Logic**
   - **Numeric Questions:** Average values per interval
   - **Boolean Questions:** Count of "Yes" days per interval (and streak logic)
   - **Other Question Types:** Latest value per interval (for snapshots)

5. **Chart Adaptation**
   - **Day view:** Show point markers + annotations (current behavior)
   - **Week+ views:** Remove point markers, keep line smooth, no annotations
   - **Hover/Tap:** Show tooltip with details for any view

### Non-Functional Requirements

- Performance: Aggregation should complete < 100ms for up to 1 year of daily data
- Smooth transitions between intervals
- Maintain accessibility (VoiceOver support, high contrast)
- Preserve liquid glass aesthetic for charts

---

## Design

### Data Model

#### TimeInterval Enum

```swift
enum TimeInterval: String, CaseIterable, Identifiable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case quarter = "Quarter"
    case half = "Half"
    case year = "Year"
    
    var id: String { rawValue }
    
    /// Minimum number of days of data required to use this interval
    var minimumDataDays: Int {
        switch self {
        case .day: return 1
        case .week: return 14
        case .month: return 28
        case .quarter: return 90
        case .half: return 180
        case .year: return 365
        }
    }
    
    /// Calendar component for aggregation
    var calendarComponent: Calendar.Component {
        switch self {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        case .quarter: return .quarter
        case .half: return .month // Half-year uses month with custom logic
        case .year: return .year
        }
    }
    
    /// Number of components to group by (e.g., half-year = 6 months)
    var groupingCount: Int {
        switch self {
        case .day: return 1
        case .week: return 1
        case .month: return 1
        case .quarter: return 3
        case .half: return 6
        case .year: return 12
        }
    }
}
```

#### AggregatedDataPoint

```swift
struct AggregatedDataPoint: Identifiable, Hashable {
    let id: UUID = UUID()
    let startDate: Date // Start of the interval
    let endDate: Date   // End of the interval
    let averageValue: Double
    let minValue: Double
    let maxValue: Double
    let sampleCount: Int
    let interval: TimeInterval
    
    /// Display label for the interval (e.g., "Jan 1-7", "Q1 2024")
    var displayLabel: String {
        // Format based on interval type
        switch interval {
        case .day:
            return startDate.formatted(.dateTime.month().day())
        case .week:
            let endDay = endDate.formatted(.dateTime.month().day())
            return "\(startDate.formatted(.dateTime.month().day()))-\(endDay)"
        case .month:
            return startDate.formatted(.dateTime.month().year())
        case .quarter:
            let quarter = Calendar.current.component(.quarter, from: startDate)
            let year = Calendar.current.component(.year, from: startDate)
            return "Q\(quarter) \(year)"
        case .half:
            let month = Calendar.current.component(.month, from: startDate)
            let year = Calendar.current.component(.year, from: startDate)
            let half = month <= 6 ? "H1" : "H2"
            return "\(half) \(year)"
        case .year:
            return startDate.formatted(.dateTime.year())
        }
    }
}
```

### ViewModel Changes

#### GoalTrendsViewModel Updates

```swift
@MainActor
@Observable
final class GoalTrendsViewModel {
    // MARK: - New Properties
    private(set) var availableIntervals: [TimeInterval] = []
    private(set) var currentInterval: TimeInterval = .day
    private(set) var aggregatedSeries: [AggregatedDataPoint] = []
    private(set) var dataSpanDays: Int = 0
    
    // MARK: - Existing Properties (keep as-is)
    private(set) var goal: TrackingGoal
    private(set) var dailySeries: [DailyAverage] = [] // Keep for day view
    private(set) var currentStreakDays: Int = 0
    private(set) var booleanStreaks: [BooleanStreak] = []
    private(set) var responseSnapshots: [ResponseSnapshot] = []
    
    // ... existing init and properties
    
    // MARK: - New Public Methods
    
    func setInterval(_ interval: TimeInterval) {
        guard availableIntervals.contains(interval) else { return }
        currentInterval = interval
        rebuildAggregatedSeries()
    }
    
    // MARK: - New Private Methods
    
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
            let quarterStart = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
            
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
            let halfStart = calendar.date(from: DateComponents(year: year, month: halfStartMonth, day: 1))!
            
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
    
    // MARK: - Modified refresh() Method
    
    func refresh() {
        let trace = PerformanceMetrics.trace(
            "GoalTrends.refresh", metadata: ["goal": goal.id.uuidString])
        
        do {
            try rebuildNumericTrends()
        } catch {
            dailySeries = []
            aggregatedSeries = []
            currentStreakDays = 0
            PerformanceMetrics.logger.error(
                "GoalTrends numeric refresh failed: \(error.localizedDescription, privacy: .public)"
            )
        }
        
        // Compute available intervals AFTER dailySeries is built
        let dataPoints = try? fetchAllDataPoints()
        if let dataPoints = dataPoints {
            computeAvailableIntervals(from: dataPoints)
            rebuildAggregatedSeries()
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
}
```

### View Changes

#### GoalTrendsView Updates

```swift
struct GoalTrendsView: View {
    @Bindable private var viewModel: GoalTrendsViewModel
    
    init(viewModel: GoalTrendsViewModel) {
        self._viewModel = Bindable(viewModel)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            let hasNumeric = !viewModel.aggregatedSeries.isEmpty
            let hasBoolean = !viewModel.booleanStreaks.isEmpty
            let hasSnapshots = !viewModel.responseSnapshots.isEmpty
            
            if !hasNumeric && !hasBoolean && !hasSnapshots {
                emptyState
            } else {
                if hasNumeric {
                    numericSection
                }
                if hasSnapshots {
                    responsesSection
                }
                if hasBoolean {
                    booleanSection
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
    
    private var numericSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Daily progress")
                    .font(.headline)
                Spacer()
                intervalPicker
            }
            numericChart
            streakSummary
        }
    }
    
    private var intervalPicker: some View {
        Menu {
            ForEach(viewModel.availableIntervals) { interval in
                Button(interval.rawValue) {
                    viewModel.setInterval(interval)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(viewModel.currentInterval.rawValue)
                    .font(.caption.weight(.semibold))
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.1))
            )
        }
    }
    
    private var numericChart: some View {
        Chart(viewModel.aggregatedSeries) { entry in
            // Area gradient
            AreaMark(
                x: .value("Date", entry.startDate, unit: timeUnit),
                y: .value("Average", entry.averageValue)
            )
            .foregroundStyle(
                .linearGradient(
                    colors: [Color.accentColor.opacity(0.3), Color.accentColor.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // Line
            LineMark(
                x: .value("Date", entry.startDate, unit: timeUnit),
                y: .value("Average", entry.averageValue)
            )
            .foregroundStyle(Color.accentColor)
            .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.monotone)
            
            // Points (only for day view)
            if viewModel.currentInterval == .day {
                PointMark(
                    x: .value("Date", entry.startDate, unit: timeUnit),
                    y: .value("Average", entry.averageValue)
                )
                .symbol(Circle())
                .annotation(position: .top) {
                    Text(entry.averageValue, format: .number.precision(.fractionLength(0...1)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: xAxisTickCount)) { value in
                if let dateValue = value.as(Date.self) {
                    AxisValueLabel {
                        Text(dateValue, format: xAxisFormat)
                    }
                }
                AxisGridLine()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(height: 220)
        .accessibilityLabel("Trend of \(viewModel.currentInterval.rawValue.lowercased()) averages")
    }
    
    // MARK: - Chart Configuration Helpers
    
    private var timeUnit: Calendar.Component {
        switch viewModel.currentInterval {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        case .quarter, .half: return .month
        case .year: return .year
        }
    }
    
    private var lineWidth: CGFloat {
        viewModel.currentInterval == .day ? 2 : 3
    }
    
    private var xAxisTickCount: Int {
        switch viewModel.currentInterval {
        case .day: return min(6, viewModel.aggregatedSeries.count)
        case .week: return min(8, viewModel.aggregatedSeries.count)
        case .month: return min(6, viewModel.aggregatedSeries.count)
        case .quarter: return min(4, viewModel.aggregatedSeries.count)
        case .half: return 2
        case .year: return min(5, viewModel.aggregatedSeries.count)
        }
    }
    
    private var xAxisFormat: Date.FormatStyle {
        switch viewModel.currentInterval {
        case .day:
            return .dateTime.month().day()
        case .week:
            return .dateTime.month().day()
        case .month:
            return .dateTime.month().year()
        case .quarter:
            // Custom format handled in AxisValueLabel
            return .dateTime.month(.abbreviated).year()
        case .half:
            return .dateTime.year()
        case .year:
            return .dateTime.year()
        }
    }
    
    // ... rest of the view (streakSummary, booleanSection, responsesSection unchanged)
}
```

---

## Implementation Phases

### Phase 1: Data Model & Aggregation Logic (2-3 hours)
1. Create `TimeInterval` enum with all cases and helpers
2. Create `AggregatedDataPoint` struct with display formatting
3. Add aggregation methods to `GoalTrendsViewModel`:
   - `aggregateByWeek()`
   - `aggregateByMonth()`
   - `aggregateByQuarter()`
   - `aggregateByHalf()`
   - `aggregateByYear()`
4. Add `computeAvailableIntervals()` and `autoSelectInterval()`
5. Update `refresh()` to compute intervals and aggregated series

**Test:** Unit tests for aggregation logic with sample data

### Phase 2: ViewModel Integration (1-2 hours)
1. Add new properties: `availableIntervals`, `currentInterval`, `aggregatedSeries`, `dataSpanDays`
2. Add `setInterval(_:)` method for manual selection
3. Update `refresh()` to call new methods
4. Ensure backward compatibility (dailySeries still populated)

**Test:** Integration tests with real SwiftData

### Phase 3: View Updates (2-3 hours)
1. Add `intervalPicker` menu to `GoalTrendsView`
2. Update `numericChart` to use `aggregatedSeries` instead of `dailySeries`
3. Conditionally show PointMark only for day view
4. Adjust chart styling (line width, axis ticks) based on interval
5. Update accessibility labels

**Test:** Preview with mock data across all intervals

### Phase 4: UI Polish & Animations (1-2 hours)
1. Add smooth transitions when changing intervals
2. Ensure glass aesthetic is preserved (gradients, materials)
3. Add loading states if aggregation is slow
4. Optimize chart rendering for large datasets

**Test:** Manual testing with real data (1.5 months)

### Phase 5: Persistence & User Preferences (1 hour)
1. Save user's selected interval to UserDefaults (per goal)
2. Restore last-used interval on view load
3. Add "Reset to Auto" option in picker

**Test:** App restart, multiple goals

### Phase 6: Documentation & Edge Cases (1 hour)
1. Update code comments
2. Handle edge cases:
   - Empty data
   - Single data point
   - Gaps in data (missing days/weeks)
   - Very old data (years ago)
3. Add performance metrics to aggregation

---

## Testing Strategy

### Unit Tests

```swift
@Test("Weekly aggregation groups 7 days correctly")
func testWeeklyAggregation() async throws {
    let container = makeInMemoryContainer()
    let context = container.mainContext
    
    // Create goal with 21 days of data
    let goal = TrackingGoal(...)
    context.insert(goal)
    
    let question = Question(...)
    goal.questions.append(question)
    
    let calendar = Calendar.current
    let today = Date()
    
    for dayOffset in 0..<21 {
        let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
        let dataPoint = DataPoint(...)
        dataPoint.timestamp = date
        dataPoint.numericValue = Double(dayOffset) // Increasing values
        context.insert(dataPoint)
        goal.dataPoints.append(dataPoint)
    }
    
    try context.save()
    
    let viewModel = GoalTrendsViewModel(goal: goal, modelContext: context)
    viewModel.refresh()
    
    // Should have week interval available
    #expect(viewModel.availableIntervals.contains(.week))
    
    // Should auto-select week (21 days >= 14)
    #expect(viewModel.currentInterval == .week)
    
    // Should have 3 weeks of aggregated data
    #expect(viewModel.aggregatedSeries.count == 3)
    
    // First week should have 7 samples
    #expect(viewModel.aggregatedSeries[0].sampleCount == 7)
}
```

### Integration Tests

```swift
@Test("Interval picker shows only valid intervals")
func testIntervalPickerFiltering() async throws {
    // Test with 10 days of data
    let viewModel = makeViewModel(withDaysOfData: 10)
    #expect(viewModel.availableIntervals == [.day])
    
    // Test with 20 days of data
    let viewModel2 = makeViewModel(withDaysOfData: 20)
    #expect(viewModel2.availableIntervals == [.day, .week])
    
    // Test with 100 days of data
    let viewModel3 = makeViewModel(withDaysOfData: 100)
    #expect(viewModel3.availableIntervals == [.day, .week, .month, .quarter])
}
```

### Manual Testing Checklist

- [ ] Day view with 5 days of data (shows points + annotations)
- [ ] Week view with 3 weeks of data (smooth line, no points)
- [ ] Month view with 2 months of data
- [ ] Quarter view with 6 months of data
- [ ] Half view with 9 months of data
- [ ] Year view with 2 years of data
- [ ] Interval picker only shows valid options
- [ ] Manual interval selection persists
- [ ] Chart transitions smoothly between intervals
- [ ] Streak summary updates correctly
- [ ] Boolean streaks still work
- [ ] Empty state for new goals
- [ ] VoiceOver reads chart description
- [ ] Dark mode looks correct
- [ ] macOS and iOS both work

---

## Performance Considerations

### Optimization Strategies

1. **Lazy Aggregation:** Only aggregate when interval changes or data refreshes
2. **Caching:** Cache aggregated series for each interval to avoid recomputation
3. **Background Processing:** For very large datasets (1000+ days), aggregate on background thread
4. **Fetch Optimization:** Use `propertiesToFetch` to limit SwiftData overhead

### Benchmarks

Target performance (on iPhone 14 Pro):
- 30 days of data: < 10ms aggregation time
- 180 days of data: < 50ms aggregation time
- 730 days of data: < 100ms aggregation time

---

## Future Enhancements (Out of Scope)

- **Custom Date Ranges:** Allow user to select specific date range (e.g., "Last 3 months")
- **Comparison Views:** Overlay current period vs. previous period
- **Export:** Export chart as image or CSV
- **Annotations:** User can add notes/markers to specific dates
- **Predictive Trends:** Show projected trend line based on historical data
- **Multiple Goals Comparison:** Overlay trends from multiple goals

---

## Conclusion

This implementation plan provides a clear path to progressive time-based aggregation for the Insights tab. By automatically adapting the chart granularity as users accumulate data, we ensure the visualization remains clear and actionable throughout the user's journey—from their first week to years of consistent tracking.

The modular design (separating aggregation logic from UI) enables easy testing and future enhancements while preserving the app's liquid glass aesthetic and maintaining performance standards.
