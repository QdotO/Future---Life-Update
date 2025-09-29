import Foundation
import Testing
import SwiftData
@testable import Future___Life_Updates

private actor StubSuggestionService: GoalSuggestionServing {
    let providerName: String
    let result: [GoalSuggestion]

    init(providerName: String = "Stub Model", result: [GoalSuggestion]) {
        self.providerName = providerName
        self.result = result
    }

    func suggestions(title: String, description: String, limit: Int) async throws -> [GoalSuggestion] {
        result
    }
}

@MainActor
struct GoalSuggestionServiceTests {
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

    @Test("Flow view model integrates AI suggestions")
    func suggestionFlowAppliesToDraft() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let legacy = GoalCreationViewModel(modelContext: context)
        let suggestions = [
            GoalSuggestion(prompt: "Did you complete your stretch today?", responseType: .boolean, rationale: "Keeps you accountable"),
            GoalSuggestion(prompt: "How many minutes did you stretch?", responseType: .numeric, validationRules: ValidationRules(minimumValue: 0, maximumValue: 60))
        ]
        let service = StubSuggestionService(result: suggestions)
        let viewModel = GoalCreationFlowViewModel(legacyViewModel: legacy, suggestionService: service)

        viewModel.updateTitle("Daily Stretch")
        await viewModel.refreshSuggestions(limit: 2)

        #expect(viewModel.suggestions.count == 2)
        #expect(viewModel.suggestionError == nil)

        guard let first = viewModel.suggestions.first else {
            Issue.record("Expected an AI suggestion")
            return
        }

        viewModel.applySuggestion(first)

        #expect(viewModel.draft.questionDrafts.count == 1)
        let applied = viewModel.draft.questionDrafts.first
        #expect(applied?.trimmedText == first.prompt)
        #expect(applied?.responseType == .boolean)
        #expect(applied?.suggestionID == first.id)
        #expect(viewModel.appliedSuggestionIDs.contains(where: { $0 == first.id }))
    }

    @Test("Flow view model surfaces missing input error before contacting service")
    func suggestionsRequireGoalContext() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let legacy = GoalCreationViewModel(modelContext: context)
        let service = StubSuggestionService(result: [])
        let viewModel = GoalCreationFlowViewModel(legacyViewModel: legacy, suggestionService: service)

        await viewModel.refreshSuggestions(limit: 2)

        #expect(viewModel.suggestions.isEmpty)
        #expect(viewModel.suggestionError == GoalSuggestionError.missingInput.errorDescription)
    }

    @Test("Availability helper messages cover statuses")
    func availabilityHelperMessages() {
        #expect(GoalSuggestionAvailability.message(for: .deviceNotEligible) == "This device doesn’t support Apple Intelligence features yet.")
        #expect(GoalSuggestionAvailability.message(for: .appleIntelligenceDisabled) == "Turn on Apple Intelligence in Settings to enable suggestions.")
        #expect(GoalSuggestionAvailability.message(for: .modelNotReady) == "Suggestions will be ready once on-device intelligence finishes preparing.")
        #expect(GoalSuggestionAvailability.message(for: .unsupportedPlatform) == "Update to the latest OS to use on-device suggestions.")
        #expect(GoalSuggestionAvailability.message(for: .unknown) == "Suggestions are temporarily unavailable.")
        #expect(GoalSuggestionAvailability.message(for: .available(providerName: "Test")) == nil)
    }
}
