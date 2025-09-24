import Foundation
import UserNotifications
import SwiftData

final class NotificationScheduler: @unchecked Sendable {
    static let shared = NotificationScheduler()
    private let center = UNUserNotificationCenter.current()

    private init() { }

    func scheduleNotifications(for goal: TrackingGoal) {
        Task { [weak self] in
            guard let self else { return }
            let authorized = await ensureAuthorization()
            guard authorized else { return }

            let requestIdentifiers = goal.schedule.times.enumerated().map { index, _ in
                "goal-\(goal.id.uuidString)-notification-\(index)"
            }
            await center.removePendingNotificationRequests(withIdentifiers: requestIdentifiers)

            let timezone = goal.schedule.timezone
            for (index, scheduleTime) in goal.schedule.times.enumerated() {
                var dateComponents = scheduleTime.dateComponents
                dateComponents.timeZone = timezone

                let content = UNMutableNotificationContent()
                content.title = goal.title
                content.body = nextQuestionBody(for: goal)
                content.sound = .default
                content.userInfo = ["goalId": goal.id.uuidString]

                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: goal.schedule.frequency == .daily || goal.schedule.frequency == .weekly || goal.schedule.frequency == .monthly)
                let identifier = requestIdentifiers[index]
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

                do {
                    try await center.add(request)
                } catch {
                    print("Failed to schedule notification: \(error)")
                }
            }
        }
    }

    private func ensureAuthorization() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                return granted
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    private func nextQuestionBody(for goal: TrackingGoal) -> String {
        if let activeQuestion = goal.questions.first(where: { $0.isActive }) {
            return activeQuestion.text
        }
        return "How is your progress going today?"
    }
}
