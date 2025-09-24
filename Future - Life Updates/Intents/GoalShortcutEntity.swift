import AppIntents
import Foundation
import SwiftData

struct GoalShortcutEntity: AppEntity, Hashable, Sendable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Tracking Goal")
    }

    static var defaultQuery = GoalShortcutQuery()

    let id: UUID
    let title: String
    let categoryDisplayName: String

    init(model: TrackingGoal) {
        self.id = model.id
        self.title = model.title
        self.categoryDisplayName = model.category.displayName
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: title),
            subtitle: LocalizedStringResource(stringLiteral: categoryDisplayName)
        )
    }
}

struct GoalShortcutQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [GoalShortcutEntity] {
        guard !identifiers.isEmpty else { return [] }
        let identifierSet = Set(identifiers)
        return try await MainActor.run {
            let descriptor = FetchDescriptor<TrackingGoal>(
                predicate: #Predicate { goal in
                    identifierSet.contains(goal.id)
                }
            )
            return try AppEnvironment.shared.modelContext
                .fetch(descriptor)
                .map(GoalShortcutEntity.init)
        }
    }

    func suggestedEntities() async throws -> [GoalShortcutEntity] {
        try await MainActor.run {
            var descriptor = FetchDescriptor<TrackingGoal>(
                predicate: #Predicate { goal in goal.isActive },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            descriptor.fetchLimit = 6
            return try AppEnvironment.shared.modelContext
                .fetch(descriptor)
                .map(GoalShortcutEntity.init)
        }
    }

    func entities(matching string: String) async throws -> [GoalShortcutEntity] {
        guard !string.isEmpty else { return try await suggestedEntities() }
        let searchTerm = string
        return try await MainActor.run {
            var descriptor = FetchDescriptor<TrackingGoal>(
                predicate: #Predicate { goal in
                    goal.title.localizedStandardContains(searchTerm) ||
                    goal.goalDescription.localizedStandardContains(searchTerm)
                },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            descriptor.fetchLimit = 10
            return try AppEnvironment.shared.modelContext
                .fetch(descriptor)
                .map(GoalShortcutEntity.init)
        }
    }
}
