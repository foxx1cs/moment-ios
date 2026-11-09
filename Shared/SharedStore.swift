import Foundation

struct EventArchive: Codable, Equatable {
    var events: [CountdownEvent] = []
    var pinnedID: UUID?

    var pinnedEvent: CountdownEvent? {
        if let pinned = events.first(where: { $0.id == pinnedID }) { return pinned }
        return events.sorted { $0.date < $1.date }.first(where: { $0.date > .now })
            ?? events.sorted { $0.date > $1.date }.first
    }
}

enum SharedStoreError: LocalizedError {
    case unavailableGroup
    var errorDescription: String? {
        "Общее хранилище недоступно. Проверьте App Groups у приложения и виджета в Xcode."
    }
}

struct SharedStore {
    static let widgetKind = "MomentCountdown"
    private let fileURL: URL

    init(fileURL: URL) { self.fileURL = fileURL }

    static func live() throws -> SharedStore {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String,
              let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: group
              ) else { throw SharedStoreError.unavailableGroup }
        return SharedStore(fileURL: container.appendingPathComponent("events-v1.json"))
    }

    func read() throws -> EventArchive {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return EventArchive() }
        return try JSONDecoder().decode(EventArchive.self, from: Data(contentsOf: fileURL))
    }

    func write(_ archive: EventArchive) throws {
        let data = try JSONEncoder().encode(archive)
        try data.write(to: fileURL, options: .atomic)
    }
}
