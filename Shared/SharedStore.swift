import Foundation

struct EventArchive: Codable, Equatable {
    var events: [CountdownEvent] = []
    var pinnedID: UUID?

    var pinnedEvent: CountdownEvent? {
        if let pinned = events.first(where: { $0.id == pinnedID }) { return pinned }
        return events.sorted { $0.nextOccurrence(after: .now) < $1.nextOccurrence(after: .now) }
            .first(where: { $0.nextOccurrence(after: .now) > .now })
            ?? events.sorted { $0.nextOccurrence(after: .now) > $1.nextOccurrence(after: .now) }.first
    }
}

enum SharedStoreError: LocalizedError {
    case unavailableGroup
    var errorDescription: String? {
        String(localized: "Общее хранилище недоступно. Проверьте App Groups у приложения и виджета в Xcode.")
    }
}

struct SharedStore {
    static let widgetKind = "MomentCountdown"
    private let fileURL: URL

    init(fileURL: URL) { self.fileURL = fileURL }

    var hasArchive: Bool { FileManager.default.fileExists(atPath: fileURL.path) }

    static func local(fileName: String = "events-v1.json") throws -> SharedStore {
        let support = try FileManager.default.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask,
                                                 appropriateFor: nil, create: true)
        let directory = support.appendingPathComponent("Moment", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return SharedStore(fileURL: directory.appendingPathComponent(fileName))
    }

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
