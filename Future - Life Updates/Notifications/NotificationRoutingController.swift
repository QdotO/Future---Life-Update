import Combine
import Foundation

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
        let route = Route(goalID: goalID, questionID: questionID, isTest: isTest)

        #if DEBUG
            print("[NotificationRouter] Activating route:")
            print("  - Goal ID: \(goalID)")
            print("  - Question ID: \(questionID?.uuidString ?? "none")")
            print("  - Is Test: \(isTest)")
        #endif

        activeRoute = route
    }

    func reset() {
        activeRoute = nil
    }
}
