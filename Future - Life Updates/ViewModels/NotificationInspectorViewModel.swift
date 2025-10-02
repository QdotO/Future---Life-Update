import Foundation
import SwiftData
import UserNotifications
import os

@MainActor
@Observable
final class NotificationInspectorViewModel {
    private let modelContext: ModelContext
    private let notificationCenter: UNUserNotificationCenter
    private let logger = Logger(
        subsystem: "com.quincy.Future-Life-Updates", category: "NotificationInspector")

    var groupedNotifications: [GoalNotificationGroup] = []
    var isLoading = false
    var lastRefresh: Date?

    struct GoalNotificationGroup: Identifiable {
        let id: UUID
        let goalID: UUID
        let goalTitle: String?
        let goalStatus: GoalStatus
        let notifications: [NotificationDetail]

        enum GoalStatus {
            case active
            case inactive
            case missing

            var displayName: String {
                switch self {
                case .active: return "Active"
                case .inactive: return "Paused"
                case .missing: return "Deleted"
                }
            }

            var symbolName: String {
                switch self {
                case .active: return "checkmark.circle.fill"
                case .inactive: return "pause.circle.fill"
                case .missing: return "exclamationmark.triangle.fill"
                }
            }
        }
    }

    struct NotificationDetail: Identifiable {
        let id: String
        let title: String
        let body: String
        let nextFireDate: Date?
        let triggerDescription: String
        let isDelivered: Bool
        let goalID: UUID?
        let questionID: UUID?
    }

    init(modelContext: ModelContext, notificationCenter: UNUserNotificationCenter = .current()) {
        self.modelContext = modelContext
        self.notificationCenter = notificationCenter
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Fetch all pending notifications
            let pendingRequests = await withCheckedContinuation { continuation in
                notificationCenter.getPendingNotificationRequests { requests in
                    continuation.resume(returning: requests)
                }
            }

            // Fetch all delivered notifications
            let deliveredNotifications = await withCheckedContinuation { continuation in
                notificationCenter.getDeliveredNotifications { notifications in
                    continuation.resume(returning: notifications)
                }
            }

            // Parse notifications
            var notificationsByGoal: [UUID: [NotificationDetail]] = [:]

            for request in pendingRequests {
                let detail = parseNotification(request: request, isDelivered: false)
                if let goalID = detail.goalID {
                    notificationsByGoal[goalID, default: []].append(detail)
                }
            }

            for notification in deliveredNotifications {
                let detail = parseNotification(request: notification.request, isDelivered: true)
                if let goalID = detail.goalID {
                    notificationsByGoal[goalID, default: []].append(detail)
                }
            }

            // Fetch all goals to determine status
            let allGoals = try modelContext.fetch(FetchDescriptor<TrackingGoal>())
            let goalLookup = Dictionary(uniqueKeysWithValues: allGoals.map { ($0.id, $0) })

            // Build grouped notifications
            var groups: [GoalNotificationGroup] = []

            for (goalID, notifications) in notificationsByGoal {
                let goal = goalLookup[goalID]
                let status: GoalNotificationGroup.GoalStatus

                if let goal = goal {
                    status = goal.isActive ? .active : .inactive
                } else {
                    status = .missing
                }

                let group = GoalNotificationGroup(
                    id: UUID(),
                    goalID: goalID,
                    goalTitle: goal?.title,
                    goalStatus: status,
                    notifications: notifications.sorted {
                        ($0.nextFireDate ?? .distantFuture) < ($1.nextFireDate ?? .distantFuture)
                    }
                )
                groups.append(group)
            }

            // Sort groups: missing first, then inactive, then active
            groupedNotifications = groups.sorted { lhs, rhs in
                if lhs.goalStatus == .missing && rhs.goalStatus != .missing {
                    return true
                }
                if lhs.goalStatus != .missing && rhs.goalStatus == .missing {
                    return false
                }
                if lhs.goalStatus == .inactive && rhs.goalStatus == .active {
                    return true
                }
                if lhs.goalStatus == .active && rhs.goalStatus == .inactive {
                    return false
                }
                return (lhs.goalTitle ?? "") < (rhs.goalTitle ?? "")
            }

            lastRefresh = Date()
            logger.info(
                "Refreshed notification inspector: \(groups.count) groups, \(notificationsByGoal.values.flatMap { $0 }.count) total notifications"
            )

        } catch {
            logger.error(
                "Failed to refresh notifications: \(error.localizedDescription, privacy: .public)")
        }
    }

    func cancelNotifications(for group: GoalNotificationGroup) {
        let identifiers = group.notifications.map { $0.id }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)

        Task {
            await refresh()
        }

        logger.info(
            "Cancelled \(identifiers.count) notifications for goal \(group.goalID.uuidString, privacy: .public)"
        )
    }

    func rescheduleGoal(_ group: GoalNotificationGroup) {
        let goalID = group.goalID
        let descriptor = FetchDescriptor<TrackingGoal>(
            predicate: #Predicate<TrackingGoal> { goal in
                goal.id == goalID
            }
        )

        guard let goal = try? modelContext.fetch(descriptor).first else {
            logger.error(
                "Cannot reschedule - goal not found: \(group.goalID.uuidString, privacy: .public)")
            return
        }

        NotificationScheduler.shared.scheduleNotifications(for: goal)

        Task {
            await refresh()
        }

        logger.info("Rescheduled notifications for goal '\(goal.title, privacy: .public)'")
    }

    func purgeAllStaleNotifications() {
        let staleGroups = groupedNotifications.filter {
            $0.goalStatus == .missing || $0.goalStatus == .inactive
        }
        let allIdentifiers = staleGroups.flatMap { $0.notifications.map { $0.id } }

        notificationCenter.removePendingNotificationRequests(withIdentifiers: allIdentifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: allIdentifiers)

        Task {
            await refresh()
        }

        logger.info("Purged \(allIdentifiers.count) stale notifications")
    }

    func exportReport() -> Data? {
        let report: [String: Any] = [
            "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "totalGroups": groupedNotifications.count,
            "groups": groupedNotifications.map { group in
                [
                    "goalID": group.goalID.uuidString,
                    "goalTitle": group.goalTitle ?? "Unknown",
                    "status": group.goalStatus.displayName,
                    "notificationCount": group.notifications.count,
                    "notifications": group.notifications.map { notification in
                        [
                            "id": notification.id,
                            "title": notification.title,
                            "body": notification.body,
                            "nextFireDate": notification.nextFireDate.map {
                                ISO8601DateFormatter().string(from: $0)
                            } ?? "N/A",
                            "trigger": notification.triggerDescription,
                            "isDelivered": notification.isDelivered,
                        ]
                    },
                ]
            },
        ]

        return try? JSONSerialization.data(
            withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
    }

    private func parseNotification(request: UNNotificationRequest, isDelivered: Bool)
        -> NotificationDetail
    {
        let content = request.content
        let userInfo = content.userInfo

        let goalID = (userInfo["goalId"] as? String).flatMap { UUID(uuidString: $0) }
        let questionID = (userInfo["questionId"] as? String).flatMap { UUID(uuidString: $0) }

        let nextFireDate: Date?
        let triggerDescription: String

        if let trigger = request.trigger {
            if let calendarTrigger = trigger as? UNCalendarNotificationTrigger {
                nextFireDate = calendarTrigger.nextTriggerDate()
                let components = calendarTrigger.dateComponents
                triggerDescription = formatDateComponents(
                    components, repeats: calendarTrigger.repeats)
            } else if let timeIntervalTrigger = trigger as? UNTimeIntervalNotificationTrigger {
                nextFireDate = timeIntervalTrigger.nextTriggerDate()
                triggerDescription =
                    "Every \(Int(timeIntervalTrigger.timeInterval))s"
                    + (timeIntervalTrigger.repeats ? " (repeating)" : "")
            } else {
                nextFireDate = nil
                triggerDescription = "Unknown trigger"
            }
        } else {
            nextFireDate = nil
            triggerDescription = "No trigger"
        }

        return NotificationDetail(
            id: request.identifier,
            title: content.title,
            body: content.body,
            nextFireDate: nextFireDate,
            triggerDescription: triggerDescription,
            isDelivered: isDelivered,
            goalID: goalID,
            questionID: questionID
        )
    }

    private func formatDateComponents(_ components: DateComponents, repeats: Bool) -> String {
        var parts: [String] = []

        if let weekday = components.weekday {
            let weekdayName = Calendar.current.weekdaySymbols[weekday - 1]
            parts.append(weekdayName)
        }

        if let day = components.day {
            parts.append("Day \(day)")
        }

        if let hour = components.hour, let minute = components.minute {
            parts.append(String(format: "%02d:%02d", hour, minute))
        }

        let description = parts.isEmpty ? "Unspecified" : parts.joined(separator: " at ")
        return description + (repeats ? " (repeating)" : "")
    }
}
