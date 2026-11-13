import SwiftUI
import UserNotifications
import UIKit

struct NotificationStatusView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var status: UNAuthorizationStatus = .notDetermined
    @State private var pending = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Разрешение") {
                    Text(status == .authorized || status == .provisional || status == .ephemeral ? "Уведомления разрешены" : "Уведомления выключены или ещё не разрешены")
                    Button("Открыть настройки") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }
                Section("Запланированные напоминания") {
                    LabeledContent("Количество", value: "\(pending) / 64")
                    Text("iOS показывает уведомления с учётом режима фокусирования. При открытии Moment список обновляется.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Состояние уведомлений")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } } }
            .task { await refresh() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await refresh() } }
            }
        }
        .preferredColorScheme(.dark)
    }

    @MainActor private func refresh() async {
        let center = UNUserNotificationCenter.current()
        status = await center.notificationSettings().authorizationStatus
        pending = await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix("moment.reminder.") }.count
    }
}
