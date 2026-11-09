import SwiftUI

@main
struct MomentApp: App {
    @StateObject private var store = EventStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .tint(Palette.aqua)
        }
    }
}
