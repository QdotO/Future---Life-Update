import Foundation

/// Time interval for aggregating data points in insights/trends
public enum TimeInterval: String, CaseIterable, Identifiable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case quarter = "Quarter"
    case half = "Half"
    case year = "Year"
    
    public var id: String { rawValue }
    
    /// Minimum number of days of data required to use this interval
    public var minimumDataDays: Int {
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
    public var calendarComponent: Calendar.Component {
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
    public var groupingCount: Int {
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

/// Aggregated data point for a specific time interval
public struct AggregatedDataPoint: Identifiable, Hashable {
    public let id: UUID = UUID()
    public let startDate: Date
    public let endDate: Date
    public let averageValue: Double
    public let minValue: Double
    public let maxValue: Double
    public let sampleCount: Int
    public let interval: TimeInterval
    
    public init(
        startDate: Date,
        endDate: Date,
        averageValue: Double,
        minValue: Double,
        maxValue: Double,
        sampleCount: Int,
        interval: TimeInterval
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.averageValue = averageValue
        self.minValue = minValue
        self.maxValue = maxValue
        self.sampleCount = sampleCount
        self.interval = interval
    }
    
    /// Display label for the interval (e.g., "Jan 1-7", "Q1 2024")
    public var displayLabel: String {
        let calendar = Calendar.current
        
        switch interval {
        case .day:
            return startDate.formatted(.dateTime.month().day())
        case .week:
            let endDay = endDate.formatted(.dateTime.month().day())
            return "\(startDate.formatted(.dateTime.month().day()))-\(endDay)"
        case .month:
            return startDate.formatted(.dateTime.month().year())
        case .quarter:
            let quarter = calendar.component(.quarter, from: startDate)
            let year = calendar.component(.year, from: startDate)
            return "Q\(quarter) \(year)"
        case .half:
            let month = calendar.component(.month, from: startDate)
            let year = calendar.component(.year, from: startDate)
            let half = month <= 6 ? "H1" : "H2"
            return "\(half) \(year)"
        case .year:
            return startDate.formatted(.dateTime.year())
        }
    }
}
