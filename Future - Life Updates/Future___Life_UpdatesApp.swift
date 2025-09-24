//___FILEHEADER___

import SwiftUI
import SwiftData

@main
struct Future_Life_UpdatesApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TrackingGoal.self,
            Question.self,
            Schedule.self,
            DataPoint.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
