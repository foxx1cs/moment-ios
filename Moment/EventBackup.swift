import Foundation
import UniformTypeIdentifiers
import SwiftUI

struct EventBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    let archive: EventArchive

    init(archive: EventArchive) {
        self.archive = archive
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        archive = try Self.decode(data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return FileWrapper(regularFileWithContents: try encoder.encode(archive))
    }

    static func decode(_ data: Data) throws -> EventArchive {
        let iso8601 = JSONDecoder()
        iso8601.dateDecodingStrategy = .iso8601
        do {
            return try iso8601.decode(EventArchive.self, from: data)
        } catch {
            return try JSONDecoder().decode(EventArchive.self, from: data)
        }
    }
}
