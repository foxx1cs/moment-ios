import SwiftUI
import WidgetKit

@MainActor
final class EventStore: ObservableObject {
    @Published private(set) var archive = EventArchive()
    @Published var errorMessage: String?
    @Published private(set) var isLoaded = false

    init() { reload() }

    func reload() {
        do {
            archive = try SharedStore.live().read()
            isLoaded = true
        } catch {
            isLoaded = false
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
        return commit(next)
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

    private func commit(_ next: EventArchive) -> Bool {
        guard isLoaded else {
            errorMessage = "Сначала восстановите доступ к хранилищу и перезапустите приложение. Существующие данные не будут перезаписаны."
            return false
        }
        do {
            try SharedStore.live().write(next)
            archive = next
            WidgetCenter.shared.reloadTimelines(ofKind: SharedStore.widgetKind)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
