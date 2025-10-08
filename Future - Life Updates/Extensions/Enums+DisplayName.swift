import Foundation

extension ResponseType {
    var displayName: String {
        switch self {
        case .numeric: "Numeric"
        case .scale: "Scale"
        case .boolean: "Yes/No"
        case .multipleChoice: "Multiple Choice"
        case .text: "Text"
        case .time: "Time"
        case .slider: "Slider"
        case .waterIntake: "Water Intake"
        }
    }
}

extension Frequency {
    var displayName: String {
        switch self {
        case .once: "One time"
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .custom: "Custom"
        }
    }
}
