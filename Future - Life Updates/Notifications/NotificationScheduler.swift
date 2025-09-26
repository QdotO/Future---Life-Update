import Foundation
import UserNotifications
import SwiftData
import os

final class NotificationScheduler: @unchecked Sendable {
    static let shared = NotificationScheduler()
    private let center = UNUserNotificationCenter.current()
    private let authorizationCache = AuthorizationCache()
#if DEBUG
    private let logger = Logger(subsystem: "com.quincy.Future-Life-Updates", category: "NotificationScheduler")
#endif

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
                debugLog("Skipping schedule – authorization not granted")
                return
            }

            let existingIdentifiers = await pendingRequestIdentifiers(for: goal)
            if !existingIdentifiers.isEmpty {
                await center.removePendingNotificationRequests(withIdentifiers: existingIdentifiers)
            }

            let requests = buildNotificationRequests(for: goal)
            for request in requests {
                do {
                    try await center.add(request)
                } catch {
                    errorLog("Failed to schedule notification: \(error.localizedDescription)")
                }
            }
        }
    }

    func sendTestNotification(for goal: TrackingGoal) {
        Task { [weak self] in
            guard let self else { return }
            let authorized = await ensureAuthorization()
            guard authorized else {
                debugLog("Skipping test notification – authorization not granted")
                return
            }

            let activeQuestion = nextActiveQuestion(for: goal)
            let content = UNMutableNotificationContent()
            content.title = "Test: \(goal.title)"
            content.body = activeQuestion?.text ?? defaultQuestionPrompt()
            content.sound = .default
            var userInfo: [AnyHashable: Any] = [
                "goalId": goal.id.uuidString,
                "isTest": true
            ]
            if let question = activeQuestion {
                userInfo["questionId"] = question.id.uuidString
            }
            content.userInfo = userInfo

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let identifier = "goal-\(goal.id.uuidString)-test-\(UUID().uuidString)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            do {
                try await center.add(request)
            } catch {
                errorLog("Failed to schedule test notification: \(error.localizedDescription)")
            }
        }
    }

    private func pendingRequestIdentifiers(for goal: TrackingGoal) async -> [String] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                let prefix = "goal-\(goal.id.uuidString)"
                let identifiers = requests
                    .map(\.identifier)
                    .filter { $0.hasPrefix(prefix) }
                continuation.resume(returning: identifiers)
            }
        }
    }

    private func buildNotificationRequests(for goal: TrackingGoal) -> [UNNotificationRequest] {
        let schedule = goal.schedule
        guard !schedule.times.isEmpty else { return [] }

        var requests: [UNNotificationRequest] = []
        let timezone = schedule.timezone
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone

        switch schedule.frequency {
        case .daily:
            for (index, scheduleTime) in schedule.times.enumerated() {
                var components = scheduleTime.dateComponents
                components.timeZone = timezone
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let identifier = "goal-\(goal.id.uuidString)-daily-\(index)"
                requests.append(makeRequest(identifier: identifier, goal: goal, trigger: trigger))
            }
        case .weekly:
            let weekdays = schedule.normalizedWeekdays()
            let effectiveWeekdays = weekdays.isEmpty ? Weekday.allCases : weekdays
            for weekday in effectiveWeekdays {
                for (index, scheduleTime) in schedule.times.enumerated() {
                    var components = scheduleTime.dateComponents
                    components.weekday = weekday.rawValue
                    components.timeZone = timezone
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                    let identifier = "goal-\(goal.id.uuidString)-weekly-\(weekday.rawValue)-\(index)"
                    requests.append(makeRequest(identifier: identifier, goal: goal, trigger: trigger))
                }
            }
        case .monthly:
            let day = calendar.component(.day, from: schedule.startDate)
            for (index, scheduleTime) in schedule.times.enumerated() {
                var components = scheduleTime.dateComponents
                components.day = day
                components.timeZone = timezone
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let identifier = "goal-\(goal.id.uuidString)-monthly-\(index)"
                requests.append(makeRequest(identifier: identifier, goal: goal, trigger: trigger))
            }
        case .once:
            let occurrences = onceOccurrences(for: schedule, calendar: calendar)
            for (index, date) in occurrences.enumerated() {
                var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                components.timeZone = timezone
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let identifier = "goal-\(goal.id.uuidString)-once-\(index)"
                requests.append(makeRequest(identifier: identifier, goal: goal, trigger: trigger))
            }
        case .custom:
            let occurrences = customOccurrences(for: schedule, calendar: calendar)
            for (index, date) in occurrences.enumerated() {
                var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                components.timeZone = timezone
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let identifier = "goal-\(goal.id.uuidString)-custom-\(index)"
                requests.append(makeRequest(identifier: identifier, goal: goal, trigger: trigger))
            }
        }

        return requests
    }

    private func onceOccurrences(for schedule: Schedule, calendar: Calendar) -> [Date] {
        let now = Date()
        return schedule.times.compactMap { time in
            guard let date = time.date(on: schedule.startDate, calendar: calendar) else { return nil }
            return date >= now ? date : nil
        }.sorted()
    }

    private func customOccurrences(for schedule: Schedule, calendar: Calendar, limit: Int = 12) -> [Date] {
        guard let interval = schedule.intervalDayCount, interval >= 2 else { return [] }
        var occurrences: [Date] = []
        let now = Date()

        var baseDate = max(schedule.startDate, now)
        baseDate = calendar.startOfDay(for: baseDate)
        let startOfSchedule = calendar.startOfDay(for: schedule.startDate)
        let dayOffset = calendar.dateComponents([.day], from: startOfSchedule, to: baseDate).day ?? 0
        if dayOffset % interval != 0 {
            let remainder = dayOffset % interval
            if let adjusted = calendar.date(byAdding: .day, value: interval - remainder, to: baseDate) {
                baseDate = adjusted
            }
        }

        var cursor = baseDate
        while occurrences.count < limit {
            for time in schedule.times {
                if let date = time.date(on: cursor, calendar: calendar), date >= now {
                    occurrences.append(date)
                }
            }
            guard let next = calendar.date(byAdding: .day, value: interval, to: cursor) else { break }
            cursor = next
        }

        return occurrences.sorted()
    }

    private func makeRequest(identifier: String, goal: TrackingGoal, trigger: UNNotificationTrigger) -> UNNotificationRequest {
        let content = makeContent(for: goal)
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    private func makeContent(for goal: TrackingGoal) -> UNMutableNotificationContent {
        let activeQuestion = nextActiveQuestion(for: goal)
        let content = UNMutableNotificationContent()
        content.title = goal.title
        content.body = activeQuestion?.text ?? defaultQuestionPrompt()
        content.sound = .default
        var userInfo: [AnyHashable: Any] = ["goalId": goal.id.uuidString]
        if let question = activeQuestion {
            userInfo["questionId"] = question.id.uuidString
        }
        content.userInfo = userInfo
        return content
    }

    private func ensureAuthorization() async -> Bool {
        await authorizationCache.getOrCreate { [center] in
            let settings = await center.notificationSettings()
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                self.debugLog("Authorization already granted: \(settings.authorizationStatus.rawValue)")
                return true
            case .denied:
                self.debugLog("Authorization denied by user")
                return false
            case .notDetermined:
                do {
                    self.debugLog("Requesting notification authorization")
                    let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                    if granted {
                        self.debugLog("Authorization granted on request")
                    } else {
                        self.debugLog("Authorization request declined")
                    }
                    return granted
                } catch {
                    self.errorLog("Authorization request failed: \(error.localizedDescription)")
                    return false
                }
            @unknown default:
                self.errorLog("Unknown authorization status: \(settings.authorizationStatus.rawValue)")
                return false
            }
        }
    }

    private func nextActiveQuestion(for goal: TrackingGoal) -> Question? {
        goal.questions.first(where: { $0.isActive })
    }

    private func defaultQuestionPrompt() -> String {
        "How is your progress going today?"
    }
}

private actor AuthorizationCache {
    private var task: Task<Bool, Never>?

    func getOrCreate(_ factory: @escaping () async -> Bool) async -> Bool {
        if let task {
            return await task.value
        }

        let newTask = Task { await factory() }
        task = newTask
        let result = await newTask.value

        if !result {
            task = nil
        }

        return result
    }
}

private extension NotificationScheduler {
    func debugLog(_ message: String) {
#if DEBUG
        logger.debug("\(message, privacy: .public)")
#endif
    }

    func errorLog(_ message: String) {
#if DEBUG
        logger.error("\(message, privacy: .public)")
#endif
    }
}
