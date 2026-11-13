import Foundation
import Combine
import UserNotifications

enum ReminderScheduler {
    private static let identifierPrefix = "moment.reminder."
    static func sync(events: [CountdownEvent], requestAuthorization: Bool) async {
        let center = UNUserNotificationCenter.current()
        let existing = await center.pendingNotificationRequests()
        let existingIDs = existing.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }

        let now = Date.now
        let reminders = ReminderPlan.make(events: events, now: now)

        guard !reminders.isEmpty else {
            center.removePendingNotificationRequests(withIdentifiers: existingIDs)
            return
        }

        let settings = await center.notificationSettings()
        var isAuthorized = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
            || settings.authorizationStatus == .ephemeral

        if settings.authorizationStatus == .notDetermined, requestAuthorization {
            isAuthorized = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        }
        guard isAuthorized else {
            center.removePendingNotificationRequests(withIdentifiers: existingIDs)
            return
        }

        let desiredIDs = Set(reminders.map(\.identifier))
        center.removePendingNotificationRequests(withIdentifiers: existingIDs.filter { !desiredIDs.contains($0) })

        for reminder in reminders {
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
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: reminder.identifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

}

@MainActor
final class NotificationRouter: ObservableObject {
    static let shared = NotificationRouter()
    @Published var pendingEventID: UUID?
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let value = response.notification.request.content.userInfo["eventID"] as? String
        Task { @MainActor in
            if let value, let id = UUID(uuidString: value) {
                NotificationRouter.shared.pendingEventID = id
            }
            completionHandler()
        }
    }
}
