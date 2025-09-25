import Foundation
import UserNotifications

@MainActor
protocol NotificationRouting: AnyObject {
    func activate(goalID: UUID, questionID: UUID?, isTest: Bool)
    func reset()
}

@MainActor
final class NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationCenterDelegate()

    weak var router: NotificationRouting?

    private override init() {
        super.init()
    }

    func configure(router: NotificationRouting) {
        self.router = router
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }

        guard
            let goalIdString = response.notification.request.content.userInfo["goalId"] as? String,
            let goalId = UUID(uuidString: goalIdString)
        else {
            print("[Notifications] Unable to parse goal ID from notification userInfo")
            return
        }

        let questionId: UUID? = (response.notification.request.content.userInfo["questionId"] as? String).flatMap(UUID.init)
        let isTest = response.notification.request.content.userInfo["isTest"] as? Bool ?? false

        router?.activate(goalID: goalId, questionID: questionId, isTest: isTest)
    }
}
