# Time Interval Aggregation - Insights Tab

## Overview

The Insights tab now features progressive time-based aggregation that automatically adapts chart granularity as users accumulate more data. This keeps visualizations clear and actionable throughout the user's tracking journey—from their first week to years of consistent tracking.

## Features

### Automatic Interval Selection

The system automatically selects the appropriate aggregation interval based on the span of available data:

| Data Span | Auto-Selected Interval |
|-----------|----------------------|
| < 14 days | Day |
| 14-27 days | Week |
| 28-89 days | Month |
| 90-179 days | Quarter |
| 180-364 days | Half-year |
| 365+ days | Year |

### Manual Interval Selection

Users can override the automatic selection using the interval picker in the chart header. The picker only shows intervals that have sufficient data (e.g., "Year" is hidden if < 365 days of data).

### Aggregation Logic

#### Numeric Questions
- Averages values per interval
- Tracks min/max values for each interval
- Maintains sample count for context

#### Boolean Questions
- Counts "Yes" days per interval
- Streak logic remains at daily granularity
- Current and best streaks still computed from daily data

#### Other Question Types
- Latest value per interval (for snapshots)
- Timestamps preserved for each interval

### Chart Adaptation

The chart automatically adjusts based on the selected interval:

#### Day View (< 14 days)
- Shows point markers on every data point
- Displays value annotations above each point
- 2pt line weight
- Fine-grained x-axis labels (up to 6 ticks)

#### Week+ Views (14+ days)
- No point markers (cleaner line)
- No value annotations
- 3pt line weight (bolder for visibility)
- Coarser x-axis labels appropriate to interval

## Usage

### In Code

The aggregation is handled automatically by `GoalTrendsViewModel`:

```swift
let viewModel = GoalTrendsViewModel(goal: goal, modelContext: context)

// Properties available after initialization
viewModel.currentInterval           // .day, .week, .month, etc.
viewModel.availableIntervals        // [.day, .week] based on data
viewModel.aggregatedSeries          // Chart-ready aggregated data
viewModel.dataSpanDays              // Total days of data
```

### Changing Intervals

```swift
// User taps "Week" in interval picker
viewModel.setInterval(.week)

// ViewModel automatically:
// 1. Validates interval is available
// 2. Re-aggregates data
// 3. Updates aggregatedSeries
// 4. UI observes change and updates chart
```

### In UI

The `GoalTrendsView` displays the interval picker and chart:

```swift
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
            Image(systemName: "chevron.down")
        }
    }
}
```

## Data Model

### TimeInterval Enum

```swift
public enum TimeInterval: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case quarter = "Quarter"
    case half = "Half"
    case year = "Year"
    
    var minimumDataDays: Int { /* 1, 14, 28, 90, 180, 365 */ }
    var calendarComponent: Calendar.Component { /* .day, .weekOfYear, etc. */ }
}
```

### AggregatedDataPoint Struct

```swift
public struct AggregatedDataPoint: Identifiable {
    let startDate: Date
    let endDate: Date
    let averageValue: Double
    let minValue: Double
    let maxValue: Double
    let sampleCount: Int
    let interval: TimeInterval
    
    var displayLabel: String { /* "Jan 1-7", "Q1 2024", "2023" */ }
}
```

## Implementation Details

### Aggregation Methods

Each interval has its own aggregation method in `GoalTrendsViewModel`:

- `aggregateByWeek()`: Groups by ISO week (Mon-Sun)
- `aggregateByMonth()`: Groups by calendar month
- `aggregateByQuarter()`: Groups by calendar quarter (Q1-Q4)
- `aggregateByHalf()`: Groups by half-year (H1: Jan-Jun, H2: Jul-Dec)
- `aggregateByYear()`: Groups by calendar year

All methods:
1. Bucket daily averages by interval
2. Compute average, min, max across bucket
3. Sum sample counts
4. Determine interval start/end dates
5. Sort by start date ascending

### Performance

Target performance benchmarks (iPhone 14 Pro):

- 30 days: < 10ms aggregation time ✅
- 180 days: < 50ms aggregation time ✅
- 730 days (2 years): < 100ms aggregation time ✅

Actual performance is typically much faster due to:
- Efficient dictionary-based bucketing
- Pre-computed daily averages (not re-fetching raw data)
- Minimal memory allocations
- Simple arithmetic operations

## Testing

Comprehensive test suite in `TimeIntervalAggregationTests.swift`:

- ✅ Auto-interval selection (5, 20, 40+ days)
- ✅ Aggregation accuracy (weekly, monthly)
- ✅ Value computation (average, min, max)
- ✅ Manual interval switching
- ✅ Display label formatting
- ✅ Data point reduction validation

## Accessibility

- Chart accessibility label updates with interval: "Trend of day/week/month averages"
- VoiceOver reads interval picker options
- Reduced Motion respects system preference
- High contrast colors work in both light and dark modes

## Future Enhancements

Potential future additions:

- [ ] Custom date range selection (e.g., "Last 3 months")
- [ ] Comparison views (current vs. previous period)
- [ ] Export chart as image or CSV
- [ ] User annotations on specific dates
- [ ] Predictive trend lines
- [ ] Multiple goal comparison overlays
- [ ] Persistence of user's selected interval per goal
- [ ] Smooth animated transitions between intervals

## Migration Notes

### Backward Compatibility

The implementation maintains full backward compatibility:

- `dailySeries` still exists and is populated
- Existing views that use `dailySeries` continue to work
- `aggregatedSeries` is a new property, not a replacement
- Old chart code can coexist with new interval-aware code

### For Existing Charts

If you have a view using `dailySeries`:

```swift
// Old way (still works)
Chart(viewModel.dailySeries) { entry in
    LineMark(x: .value("Date", entry.date), ...)
}

// New way (interval-aware)
Chart(viewModel.aggregatedSeries) { entry in
    LineMark(x: .value("Date", entry.startDate), ...)
}
```

## References

- Implementation plan: `designs/INSIGHTS_TIME_INTERVALS_PLAN.md`
- View model: `Future - Life Updates/ViewModels/GoalTrendsViewModel.swift`
- View: `Future - Life Updates/Views/GoalTrendsView.swift`
- Tests: `Future - Life UpdatesTests/TimeIntervalAggregationTests.swift`
