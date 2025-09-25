import Foundation
import Combine

@MainActor
final class NotificationRoutingController: ObservableObject, NotificationRouting {
    struct Route: Identifiable, Equatable {
        let id = UUID()
        let goalID: UUID
        let questionID: UUID?
        let isTest: Bool
    }

    @Published private(set) var activeRoute: Route?

    func activate(goalID: UUID, questionID: UUID?, isTest: Bool) {
        activeRoute = Route(goalID: goalID, questionID: questionID, isTest: isTest)
    }

    func reset() {
        activeRoute = nil
    }
}
