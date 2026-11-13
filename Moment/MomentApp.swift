import SwiftUI
import UserNotifications

@main
struct MomentApp: App {
    @StateObject private var store = EventStore()

    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .tint(Palette.aqua)
        }
    }
}
