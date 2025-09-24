import Foundation
import UserNotifications
import SwiftData

final class NotificationScheduler: @unchecked Sendable {
    static let shared = NotificationScheduler()
    private let center = UNUserNotificationCenter.current()

    private init() {
        let currentCenter = center
        Task { @MainActor in
            currentCenter.delegate = NotificationCenterDelegate.shared
        }
    }

    func scheduleNotifications(for goal: TrackingGoal) {
        Task { [weak self] in
            guard let self else { return }
            let authorized = await ensureAuthorization()
            guard authorized else {
                print("[Notifications] Skipping schedule – authorization not granted")
                return
            }

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

    func sendTestNotification(for goal: TrackingGoal) {
        Task { [weak self] in
            guard let self else { return }
            let authorized = await ensureAuthorization()
            guard authorized else {
                print("[Notifications] Skipping test notification – authorization not granted")
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "Test: \(goal.title)"
            content.body = nextQuestionBody(for: goal)
            content.sound = .default
            content.userInfo = [
                "goalId": goal.id.uuidString,
                "isTest": true
            ]

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let identifier = "goal-\(goal.id.uuidString)-test-\(UUID().uuidString)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            do {
                try await center.add(request)
            } catch {
                print("Failed to schedule test notification: \(error)")
            }
        }
    }

    private func ensureAuthorization() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            print("[Notifications] Authorization already granted: \(settings.authorizationStatus.rawValue)")
            return true
        case .denied:
            print("[Notifications] Authorization denied by user")
            return false
        case .notDetermined:
            do {
                print("[Notifications] Requesting notification authorization")
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                if granted {
                    print("[Notifications] Authorization granted on request")
                } else {
                    print("[Notifications] Authorization request declined")
                }
                return granted
            } catch {
                print("[Notifications] Authorization request failed: \(error)")
                return false
            }
        @unknown default:
            print("[Notifications] Unknown authorization status: \(settings.authorizationStatus.rawValue)")
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
