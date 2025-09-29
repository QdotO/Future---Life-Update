import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum GoalSuggestionAvailabilityStatus: Equatable {
    case available(providerName: String)
    case deviceNotEligible
    case appleIntelligenceDisabled
    case modelNotReady
    case unsupportedPlatform
    case unknown
}

enum GoalSuggestionAvailability {
    static let providerName = "Apple Foundation Model (On-Device)"

    static func currentStatus() -> GoalSuggestionAvailabilityStatus {
        #if canImport(FoundationModels)
        if #available(iOS 18.0, macOS 15.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *) {
            return availabilityStatus(for: .default)
        } else {
            return .unsupportedPlatform
        }
        #else
        return .unsupportedPlatform
        #endif
    }

    static func message(for status: GoalSuggestionAvailabilityStatus) -> String? {
        switch status {
        case .available:
            return nil
        case .deviceNotEligible:
            return "This device doesn’t support Apple Intelligence features yet."
        case .appleIntelligenceDisabled:
            return "Turn on Apple Intelligence in Settings to enable suggestions."
        case .modelNotReady:
            return "Suggestions will be ready once on-device intelligence finishes preparing."
        case .unsupportedPlatform:
            return "Update to the latest OS to use on-device suggestions."
        case .unknown:
            return "Suggestions are temporarily unavailable."
        }
    }

    #if canImport(FoundationModels)
    @available(iOS 18.0, macOS 15.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    static func availabilityStatus(for model: SystemLanguageModel) -> GoalSuggestionAvailabilityStatus {
        switch model.availability {
        case .available:
            return .available(providerName: providerName)
        case .unavailable(.deviceNotEligible):
            return .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled):
            return .appleIntelligenceDisabled
        case .unavailable(.modelNotReady):
            return .modelNotReady
        case .unavailable:
            return .unknown
        @unknown default:
            return .unknown
        }
    }
    #endif
}
