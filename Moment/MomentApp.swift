import SwiftUI
import UserNotifications

@main
struct MomentApp: App {
    @StateObject private var store = EventStore()
    @StateObject private var liveActivities = LiveActivityManager.shared
    @StateObject private var notificationRouter = NotificationRouter.shared

    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .environmentObject(liveActivities)
                .environmentObject(notificationRouter)
                .preferredColorScheme(.dark)
                .tint(Palette.aqua)
        }
    }
}
