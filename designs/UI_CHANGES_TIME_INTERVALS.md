# UI Changes: Time Interval Aggregation

## Overview

This document describes the visual changes to the Insights tab after implementing time interval aggregation.

## Before (Original Implementation)

### Chart Header
```
┌────────────────────────────────────┐
│ Daily progress                     │
└────────────────────────────────────┘
```

- Static title "Daily progress"
- No interval selection
- Always shows daily data with all points

### Chart with 5 Days of Data
```
Chart with 5 data points
├── Point markers on every day
├── Value annotations above each point
├── 2pt line connecting points
└── X-axis: Jan 1, Jan 2, Jan 3, Jan 4, Jan 5
```

### Chart with 60 Days of Data
```
Chart with 60 data points (CROWDED!)
├── Point markers on every day (too many!)
├── Value annotations overlap
├── Hard to see trends
└── X-axis labels crowded
```

**Problem**: With 60+ days of data, the chart becomes cluttered and hard to read.

---

## After (With Time Interval Aggregation)

### Chart Header (< 14 days of data)
```
┌────────────────────────────────────┐
│ Daily progress           [Day ▾]   │
└────────────────────────────────────┘
```

- Title still "Daily progress"
- Interval picker shows "Day"
- Single chevron indicates it's a menu

### Chart Header (20 days of data - auto-selected to Week)
```
┌────────────────────────────────────┐
│ Daily progress          [Week ▾]   │
└────────────────────────────────────┘
```

- Automatically switches to "Week" view
- User can tap to see options: Day, Week

### Chart Header (60 days of data - auto-selected to Month)
```
┌────────────────────────────────────┐
│ Daily progress         [Month ▾]   │
└────────────────────────────────────┘
```

- Automatically switches to "Month" view
- User can tap to see options: Day, Week, Month

### Interval Picker Menu
```
┌─────────────────┐
│ Day         ✓   │ ← Currently selected
│ Week            │
│ Month           │
└─────────────────┘
```

- Shows checkmark next to current interval
- Only shows intervals with sufficient data
- Tap to switch intervals

### Chart with 5 Days (Day View)
```
Chart with 5 data points
├── Point markers: ● (visible on every day)
├── Value annotations: "5.2" above each point
├── Line weight: 2pt
├── X-axis: Jan 1, Jan 2, Jan 3, Jan 4, Jan 5
└── Clean, readable
```

**Same as before** - Day view for < 14 days is unchanged.

### Chart with 20 Days (Week View - Auto-Selected)
```
Chart with ~3 weekly data points
├── Point markers: NONE (removed for clarity)
├── Value annotations: NONE (removed for clarity)
├── Line weight: 3pt (bolder)
├── X-axis: Jan 1-7, Jan 8-14, Jan 15-21
└── Much cleaner, easier to see trends
```

**Improvement**: 20 data points reduced to ~3 weekly averages.

### Chart with 60 Days (Month View - Auto-Selected)
```
Chart with 2 monthly data points
├── Point markers: NONE
├── Value annotations: NONE
├── Line weight: 3pt (bold line)
├── X-axis: January 2024, February 2024
└── Clear trend visible at a glance
```

**Improvement**: 60 data points reduced to 2 monthly averages. Much easier to see long-term trends.

### Chart with 1 Year of Data (Year View)
```
Chart with 1 yearly data point
├── Point markers: NONE
├── Value annotations: NONE
├── Line weight: 3pt
├── X-axis: 2023
└── Shows annual performance
```

**Use case**: Long-term tracking shows year-over-year progress.

---

## Accessibility Label Changes

### Before
```
"Trend of daily averages"
```

Always the same, regardless of data span.

### After
```
Day view:     "Trend of day averages"
Week view:    "Trend of week averages"
Month view:   "Trend of month averages"
Quarter view: "Trend of quarter averages"
Half view:    "Trend of half averages"
Year view:    "Trend of year averages"
```

VoiceOver users hear the appropriate granularity.

---

## Visual Design Changes

### Interval Picker Badge
```
┌──────────────┐
│ Week    ▾    │  ← Accent color background (10% opacity)
└──────────────┘
     ↑
  Semi-bold caption font
  Accent color text
  8pt rounded corners
  Horizontal: 12pt padding
  Vertical: 6pt padding
```

- Uses accent color for emphasis
- Small and compact (doesn't dominate header)
- Clear affordance (chevron) that it's interactive

### Chart Line Weight

| Interval | Line Weight | Point Markers | Annotations |
|----------|-------------|---------------|-------------|
| Day      | 2pt         | Yes (●)       | Yes         |
| Week     | 3pt         | No            | No          |
| Month    | 3pt         | No            | No          |
| Quarter  | 3pt         | No            | No          |
| Half     | 3pt         | No            | No          |
| Year     | 3pt         | No            | No          |

**Rationale**: 
- Day view keeps markers for precise values
- Longer intervals use bolder lines for visibility at lower density
- No markers keeps focus on the trend line

### X-Axis Label Format

| Interval | Format Example       |
|----------|----------------------|
| Day      | "Jan 1"              |
| Week     | "Jan 1-7"            |
| Month    | "Jan 2024"           |
| Quarter  | "Q1 2024"            |
| Half     | "H1 2024"            |
| Year     | "2024"               |

Labels adapt to show appropriate granularity.

---

## User Interaction Flow

### Scenario 1: New User (3 days of data)
1. Opens Insights tab
2. Sees chart with 3 daily points, markers, and annotations
3. Sees "Day" in picker - only option available
4. Chart is clear and readable ✅

### Scenario 2: Regular User (25 days of data)
1. Opens Insights tab
2. Automatically sees "Week" view with ~4 weekly averages
3. Chart is clean with bold line, no clutter ✅
4. Can tap picker to switch to "Day" view if desired
5. "Day" view shows all 25 daily points

### Scenario 3: Long-term User (3 months of data)
1. Opens Insights tab
2. Automatically sees "Month" view with 3 monthly averages
3. Clear trend over 3 months ✅
4. Can tap picker to see: Day, Week, Month options
5. Switching to "Day" shows all 90+ points (dense but available)
6. Switching to "Week" shows ~13 weekly averages

### Scenario 4: Power User (2 years of data)
1. Opens Insights tab
2. Automatically sees "Year" view with 2 yearly averages
3. Big picture visible immediately ✅
4. Can tap picker to see: Day, Week, Month, Quarter, Half, Year
5. Can zoom into any interval to see more detail
6. "Month" view shows 24 monthly averages
7. "Week" view shows ~104 weekly averages

---

## Performance Impact

### Chart Rendering Time (Estimated)

| Data Points | Interval | Rendered Points | Time (ms) |
|-------------|----------|-----------------|-----------|
| 5           | Day      | 5               | < 1       |
| 20          | Week     | ~3              | < 5       |
| 60          | Month    | 2               | < 10      |
| 365         | Year     | 1               | < 50      |

Charts with aggregated data render **faster** than charts with all raw daily data.

### Aggregation Time (Measured in Tests)

| Data Span | Aggregation | Time (ms) |
|-----------|-------------|-----------|
| 30 days   | Any         | < 10      |
| 180 days  | Any         | < 50      |
| 730 days  | Any         | < 100     |

Aggregation is fast enough to feel instant to users.

---

## Comparison Summary

| Aspect               | Before                  | After                        |
|---------------------|-------------------------|------------------------------|
| **Cluttered charts**| Yes (60+ days)          | No (auto-aggregates)         |
| **Point markers**   | Always visible          | Only on day view             |
| **Annotations**     | Always visible          | Only on day view             |
| **Line weight**     | Always 2pt              | 2pt (day), 3pt (others)      |
| **User control**    | None                    | Manual interval selection    |
| **Scalability**     | Breaks at 60+ days      | Works with years of data     |
| **Performance**     | Degrades with data      | Constant (aggregated)        |
| **Accessibility**   | Generic label           | Interval-specific labels     |

---

## Design Philosophy

### Progressive Disclosure
- **Week 1**: Simple daily view, all details visible
- **Month 1**: Week view automatically kicks in, still detailed
- **Month 3**: Month view for big picture, can zoom to weeks
- **Year 1**: Year view for annual trends, can drill down

### User Empowerment
- System makes smart defaults
- User can always override
- No information loss (day view still available)

### Visual Clarity
- Remove noise (markers) when not needed
- Increase signal (bolder line) for sparse data
- Appropriate labels for each granularity

---

## Edge Cases Handled

1. **Single data point**: Shows in day view, no interval picker needed
2. **Sparse data** (gaps): Aggregation still works, shows available data
3. **Exact boundaries** (14 days): Uses lower interval (day, not week)
4. **Empty state**: "No insights yet" message (unchanged)
5. **Very old data**: Works with years-old historical data

---

## Implementation Note

All visual changes are in the Insights tab (`GoalTrendsView`). Other views are unaffected and maintain their current appearance.
