import SwiftData
import Foundation

enum PreviewSampleData {
    static func makePreviewContainer() throws -> ModelContainer {
        let schema = Schema([
            TrackingGoal.self,
            Question.self,
            Schedule.self,
            DataPoint.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        let hydration = TrackingGoal(
            title: "Hydration",
            description: "Drink eight glasses of water",
            category: .health
        )
        let schedule = Schedule(
            startDate: Date(),
            frequency: .daily,
            times: [ScheduleTime(hour: 9, minute: 0)],
            timezoneIdentifier: TimeZone.current.identifier
        )
        hydration.schedule = schedule
        schedule.goal = hydration

        let question = Question(text: "How many glasses did you drink today?", responseType: .numeric)
        hydration.questions = [question]
        question.goal = hydration

        context.insert(hydration)
        try context.save()
        return container
    }
}
