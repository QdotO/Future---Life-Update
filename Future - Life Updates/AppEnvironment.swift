import Foundation
import SwiftData

@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    private struct OverrideContextContainer: @unchecked Sendable {
        let context: ModelContext
    }

    @TaskLocal
    private static var overrideContextContainer: OverrideContextContainer?

    private static var overrideContext: ModelContext? {
        overrideContextContainer?.context
    }

    private lazy var container: ModelContainer = {
        let schema = Schema([
            TrackingGoal.self,
            Question.self,
            Schedule.self,
            DataPoint.self,
            GoalTrashItem.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var modelContainer: ModelContainer {
        container
    }

    var modelContext: ModelContext {
        AppEnvironment.overrideContext ?? container.mainContext
    }

    @discardableResult
    func withModelContext<R>(_ context: ModelContext, perform operation: () async throws -> R)
        async rethrows -> R
    {
        try await AppEnvironment.$overrideContextContainer.withValue(
            OverrideContextContainer(context: context)
        ) {
            try await operation()
        }
    }
}
