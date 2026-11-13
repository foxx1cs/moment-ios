import Foundation
import UserNotifications

enum ReminderScheduler {
    private static let identifierPrefix = "moment.reminder."
    private static let maximumPendingRequests = 64
    private static let maximumOffset = 180 * 86_400

    static func sync(events: [CountdownEvent], requestAuthorization: Bool) async {
        let center = UNUserNotificationCenter.current()
        let existing = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(
            withIdentifiers: existing.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        )

        let now = Date.now
        let reminders = events.flatMap { event in
            let targetDate = event.nextOccurrence(after: now)
            return Set(event.reminderOffsets)
                .filter { (0...maximumOffset).contains($0) }
                .map { Reminder(event: event, offset: $0, fireDate: targetDate.addingTimeInterval(-Double($0))) }
        }
        .filter { $0.event.repeatsAnnually || $0.fireDate > now }
        .sorted { $0.fireDate < $1.fireDate }

        guard !reminders.isEmpty else { return }

        let settings = await center.notificationSettings()
        var isAuthorized = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
            || settings.authorizationStatus == .ephemeral

        if settings.authorizationStatus == .notDetermined, requestAuthorization {
            isAuthorized = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        }
        guard isAuthorized else { return }

        for reminder in reminders.prefix(maximumPendingRequests) {
            let content = UNMutableNotificationContent()
            content.title = reminder.event.title
            content.body = reminder.offset == 0
                ? String(localized: "Настал момент, которого вы ждали.")
                : String(localized: "Скоро наступит ваш момент.")
            content.sound = .default
            content.userInfo = ["eventID": reminder.event.id.uuidString]

            let calendar = Calendar.current
            var components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: reminder.fireDate
            )
            components.timeZone = TimeZone.current
            if reminder.event.repeatsAnnually { components.year = nil }
            let trigger = UNCalendarNotificationTrigger(dateMatching: components,
                                                       repeats: reminder.event.repeatsAnnually)
            let identifier = "\(identifierPrefix)\(reminder.event.id.uuidString).\(reminder.offset)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    private struct Reminder {
        let event: CountdownEvent
        let offset: Int
        let fireDate: Date
    }
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
