import SwiftUI
import SwiftData

struct NotificationLogEntryView: View {
    private let goal: TrackingGoal
    private let questionID: UUID?
    private let isTest: Bool
    private let modelContext: ModelContext

    init(goal: TrackingGoal, questionID: UUID?, isTest: Bool, modelContext: ModelContext) {
        self.goal = goal
        self.questionID = questionID
        self.isTest = isTest
        self.modelContext = modelContext
    }

    var body: some View {
        DataEntryView(
            goal: goal,
            modelContext: modelContext,
            mode: .notification(questionID: questionID, isTest: isTest)
        )
    }
}
