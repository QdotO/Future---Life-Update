import AppIntents
import Foundation

struct QuickLogGoalIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Goal Progress"
    static var description = IntentDescription("Quickly add numeric progress for one of your tracking goals.")

    @Parameter(title: "Goal")
    var goal: GoalShortcutEntity

    @Parameter(title: "Value")
    var value: Double

    @Parameter(title: "Entry Date")
    var entryDate: Date?

    init() {}

    init(goal: GoalShortcutEntity, value: Double, entryDate: Date? = nil) {
        self.goal = goal
        self.value = value
        self.entryDate = entryDate
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$value) for \(\.$goal)") {
            \.$entryDate
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let timestamp = entryDate ?? Date()
        let result = try await MainActor.run {
            let logger = GoalShortcutLogger(modelContext: AppEnvironment.shared.modelContext)
            return try logger.logNumericValue(value, for: goal.id, at: timestamp)
        }
        let formattedValue = value.formatted(.number.precision(.fractionLength(0...2)))
        return .result(dialog: IntentDialog("Logged \(formattedValue) to \(result.goal.title)"))
    }
}
