import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct GoalSuggestion: Identifiable, Equatable, Sendable {
    let id: UUID
    let prompt: String
    let responseType: ResponseType
    let options: [String]
    let rationale: String?
    let validationRules: ValidationRules?

    init(
        id: UUID = UUID(),
        prompt: String,
        responseType: ResponseType,
        options: [String] = [],
        rationale: String? = nil,
        validationRules: ValidationRules? = nil
    ) {
        self.id = id
        self.prompt = prompt
        self.responseType = responseType
        self.options = options
        self.rationale = rationale
        self.validationRules = validationRules
    }
}

enum GoalSuggestionError: LocalizedError, Sendable {
    case missingInput
    case emptyPayload
    case decodingFailed
    case unsupportedResponseType(String)
    case serviceUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .missingInput:
            return "Add a goal title or description before generating suggestions."
        case .emptyPayload:
            return "The model did not return any suggestions."
        case .decodingFailed:
            return "We couldn’t understand the model response."
        case .unsupportedResponseType(let value):
            return "The model suggested an unsupported response type: \(value)."
        case .serviceUnavailable(let message):
            return message
        }
    }
}

protocol GoalSuggestionServing: Sendable {
    var providerName: String { get }
    func suggestions(
        title: String,
        description: String,
        limit: Int
    ) async throws -> [GoalSuggestion]
}

struct GoalSuggestionPromptBuilder {
    static func makeInstructions() -> String {
        "You help people craft concise, actionable goal-tracking questions. Reply only with valid JSON."
    }

    static func makePrompt(title: String, description: String, limit: Int) -> String {
        var builder = "Goal title: \(title)\n"
        if !description.isEmpty {
            builder.append("Goal description: \(description)\n")
        }
        builder.append("\nReturn \(limit) tracking question suggestions as a JSON object with a `suggestions` array. Each entry needs: `prompt` (string), `response_type` (boolean, numeric, scale, multiple_choice, text, slider, or time), optional `options` (array of strings), optional `rationale` (string), optional `minimum_value`, `maximum_value`, and `allows_empty`. Do not include any other text.")
        return builder
    }
}

#if canImport(FoundationModels)
@available(iOS 18.0, macOS 15.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
final class OnDeviceGoalSuggestionService: GoalSuggestionServing {
    private struct SuggestionPayload: Decodable {
        let prompt: String
        let responseType: String
        let options: [String]?
        let rationale: String?
        let minimumValue: Double?
        let maximumValue: Double?
        let allowsEmpty: Bool?
    }

    private struct ResponseEnvelope: Decodable {
        let suggestions: [SuggestionPayload]
    }

    private let model: SystemLanguageModel
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    var providerName: String { GoalSuggestionAvailability.providerName }

    init(model: SystemLanguageModel = .default) {
        self.model = model
    }

    func suggestions(
        title: String,
        description: String,
        limit: Int
    ) async throws -> [GoalSuggestion] {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty || !trimmedDescription.isEmpty else {
            throw GoalSuggestionError.missingInput
        }

        let availability = GoalSuggestionAvailability.availabilityStatus(for: model)
        guard case .available = availability else {
            let message = GoalSuggestionAvailability.message(for: availability) ?? "Suggestions are unavailable right now."
            throw GoalSuggestionError.serviceUnavailable(message)
        }

        let prompt = GoalSuggestionPromptBuilder.makePrompt(title: trimmedTitle, description: trimmedDescription, limit: max(1, limit))
        let session = LanguageModelSession(instructions: GoalSuggestionPromptBuilder.makeInstructions())
        let response = try await session.respond(to: prompt)

        let payloads = try decodeSuggestions(from: response.content)
        let mapped = try mapSuggestions(payloads)
        guard !mapped.isEmpty else { throw GoalSuggestionError.emptyPayload }
        return mapped
    }

    private func decodeSuggestions(from raw: String) throws -> [SuggestionPayload] {
        let sanitized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = sanitized.data(using: .utf8) else {
            throw GoalSuggestionError.decodingFailed
        }
        let envelope = try decoder.decode(ResponseEnvelope.self, from: data)
        return envelope.suggestions
    }

    private func mapSuggestions(_ payloads: [SuggestionPayload]) throws -> [GoalSuggestion] {
        try payloads.compactMap { payload in
            let trimmedPrompt = payload.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedPrompt.isEmpty else { return nil }
            guard let responseType = mapResponseType(payload.responseType) else {
                throw GoalSuggestionError.unsupportedResponseType(payload.responseType)
            }
            let options = payload.options?.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? []
            let hasValidationMetadata = payload.minimumValue != nil || payload.maximumValue != nil || payload.allowsEmpty != nil
            let validationRules: ValidationRules? = hasValidationMetadata ? ValidationRules(
                minimumValue: payload.minimumValue,
                maximumValue: payload.maximumValue,
                allowsEmpty: payload.allowsEmpty ?? true
            ) : nil
            return GoalSuggestion(
                prompt: trimmedPrompt,
                responseType: responseType,
                options: options,
                rationale: payload.rationale?.trimmingCharacters(in: .whitespacesAndNewlines),
                validationRules: validationRules
            )
        }
    }

    private func mapResponseType(_ raw: String) -> ResponseType? {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "boolean", "bool", "yes_no", "yes-no", "yes/no":
            return .boolean
        case "numeric", "number", "count", "integer", "float":
            return .numeric
        case "scale", "rating", "likert":
            return .scale
        case "multiple_choice", "multiple-choice", "multiplechoice", "multi_select", "multi-select", "multi":
            return .multipleChoice
        case "text", "note", "freeform", "open_ended", "open-ended":
            return .text
        case "time", "timestamp":
            return .time
        case "slider":
            return .slider
        default:
            return nil
        }
    }
}
#endif

enum GoalSuggestionServiceFactory {
    static func makeLive() -> GoalSuggestionServing? {
        #if canImport(FoundationModels)
        if #available(iOS 18.0, macOS 15.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *) {
            let model = SystemLanguageModel.default
            if case .available = GoalSuggestionAvailability.availabilityStatus(for: model) {
                return OnDeviceGoalSuggestionService(model: model)
            }
        }
        #endif
        return nil
    }
}
