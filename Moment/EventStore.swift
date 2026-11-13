import SwiftUI
import WidgetKit

@MainActor
final class EventStore: ObservableObject {
    @Published private(set) var archive = EventArchive()
    @Published var errorMessage: String?
    @Published private(set) var isLoaded = false
    @Published private(set) var widgetsAvailable = false

    private let localStoreProvider: () throws -> SharedStore
    private let sharedStoreProvider: () throws -> SharedStore
    private let reloadWidgets: () -> Void

    convenience init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing-no-app-group") {
            var shouldReset = ProcessInfo.processInfo.arguments.contains("--ui-testing-reset")
            self.init(localStoreProvider: {
                let local = try SharedStore.local(fileName: "ui-tests-events.json")
                if shouldReset {
                    try local.write(EventArchive())
                    shouldReset = false
                }
                return local
            }, sharedStoreProvider: { throw SharedStoreError.unavailableGroup })
            return
        }
        #endif
        self.init(localStoreProvider: { try SharedStore.local() },
                  sharedStoreProvider: { try SharedStore.live() })
    }

    init(localStoreProvider: @escaping () throws -> SharedStore,
         sharedStoreProvider: @escaping () throws -> SharedStore,
         reloadWidgets: @escaping () -> Void = {
             WidgetCenter.shared.reloadTimelines(ofKind: SharedStore.widgetKind)
         }) {
        self.localStoreProvider = localStoreProvider
        self.sharedStoreProvider = sharedStoreProvider
        self.reloadWidgets = reloadWidgets
        reload()
    }

    func reload() {
        do {
            let local = try localStoreProvider()
            if !local.hasArchive {
                // Preserve events created by versions that stored only in App Groups.
                let initial: EventArchive
                do {
                    initial = try sharedStoreProvider().read()
                } catch SharedStoreError.unavailableGroup {
                    initial = EventArchive()
                }
                try local.write(initial)
            }
            archive = try local.read()
            isLoaded = true
            errorMessage = nil
            syncWidgets()
        } catch {
            isLoaded = false
            widgetsAvailable = false
            errorMessage = error.localizedDescription
        }
    }

    var events: [CountdownEvent] { archive.events }
    var featured: CountdownEvent? { archive.pinnedEvent }

    @discardableResult
    func save(_ event: CountdownEvent) -> Bool {
        var next = archive
        if let index = next.events.firstIndex(where: { $0.id == event.id }) {
            next.events[index] = event
        } else {
            next.events.append(event)
        }
        if next.pinnedID == nil { next.pinnedID = event.id }
        return commit(next, requestReminderPermission: !event.reminderOffsets.isEmpty)
    }

    @discardableResult
    func delete(_ event: CountdownEvent) -> Bool {
        var next = archive
        next.events.removeAll { $0.id == event.id }
        if next.pinnedID == event.id { next.pinnedID = nil }
        return commit(next)
    }

    func pin(_ event: CountdownEvent) {
        var next = archive
        next.pinnedID = event.id
        _ = commit(next)
    }

    @discardableResult
    func mergeImported(_ imported: EventArchive) -> Int? {
        var next = archive
        var knownIDs = Set(next.events.map(\.id))
        var additions: [CountdownEvent] = []
        for event in imported.events where knownIDs.insert(event.id).inserted {
            additions.append(event)
        }
        next.events.append(contentsOf: additions)
        if next.pinnedID == nil {
            if let importedID = imported.pinnedID,
               next.events.contains(where: { $0.id == importedID }) {
                next.pinnedID = importedID
            } else {
                next.pinnedID = additions.first?.id
            }
        }
        guard !additions.isEmpty || next.pinnedID != archive.pinnedID else { return 0 }
        guard commit(next, requestReminderPermission: additions.contains { !$0.reminderOffsets.isEmpty }) else { return nil }
        return additions.count
    }

    private func commit(_ next: EventArchive, requestReminderPermission: Bool = false) -> Bool {
        guard isLoaded else {
            errorMessage = String(localized: "Сначала восстановите доступ к хранилищу и перезапустите приложение. Существующие данные не будут перезаписаны.")
            return false
        }
        do {
            // Saving in the app never depends on widget provisioning or sync.
            try localStoreProvider().write(next)
            archive = next
            syncWidgets()
            Task {
                await ReminderScheduler.sync(events: next.events,
                                             requestAuthorization: requestReminderPermission)
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func syncWidgets() {
        do {
            let shared = try sharedStoreProvider()
            // Do not replace an unreadable pre-existing archive silently.
            _ = try shared.read()
            try shared.write(archive)
            widgetsAvailable = true
            reloadWidgets()
        } catch {
            widgetsAvailable = false
            // Widget failures are nonfatal: the local save is already durable.
        }
    }
}
