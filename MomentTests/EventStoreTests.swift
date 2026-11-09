import XCTest
@testable import Moment

final class EventStoreTests: XCTestCase {
    private func withStores(_ action: (SharedStore, SharedStore, URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try action(SharedStore(fileURL: directory.appendingPathComponent("local.json")),
                   SharedStore(fileURL: directory.appendingPathComponent("shared.json")), directory)
    }

    @MainActor
    func testMissingAppGroupAllowsCreatingAndRestoringEvent() throws {
        try withStores { local, _, _ in
            let store = EventStore(localStoreProvider: { local },
                                   sharedStoreProvider: { throw SharedStoreError.unavailableGroup },
                                   reloadWidgets: {})
            XCTAssertTrue(store.isLoaded)
            XCTAssertNil(store.errorMessage)
            XCTAssertFalse(store.widgetsAvailable)
            let event = CountdownEvent(title: "Поездка", date: .now.addingTimeInterval(86400))
            XCTAssertTrue(store.save(event))

            let relaunched = EventStore(localStoreProvider: { local },
                                        sharedStoreProvider: { throw SharedStoreError.unavailableGroup },
                                        reloadWidgets: {})
            XCTAssertEqual(relaunched.events, [event])
            XCTAssertEqual(relaunched.archive.pinnedID, event.id)
            XCTAssertTrue(relaunched.isLoaded)
            XCTAssertNil(relaunched.errorMessage)
        }
    }

    @MainActor
    func testEditingAndDeletingWorkWithoutAppGroup() throws {
        try withStores { local, _, _ in
            let store = EventStore(localStoreProvider: { local },
                                   sharedStoreProvider: { throw SharedStoreError.unavailableGroup },
                                   reloadWidgets: {})
            var event = CountdownEvent(title: "Встреча", date: .now.addingTimeInterval(3600))
            XCTAssertTrue(store.save(event))
            event.title = "Новая встреча"
            XCTAssertTrue(store.save(event))
            XCTAssertEqual(try local.read().events, [event])
            XCTAssertTrue(store.delete(event))
            XCTAssertTrue(try local.read().events.isEmpty)
            XCTAssertNil(store.archive.pinnedID)
        }
    }

    @MainActor
    func testExistingSharedEventsAreMigratedOnceAndRetainedWithoutGroup() throws {
        try withStores { local, shared, _ in
            let event = CountdownEvent(title: "Из старой версии", date: .now.addingTimeInterval(3600))
            let original = EventArchive(events: [event], pinnedID: event.id)
            try shared.write(original)
            let migrated = EventStore(localStoreProvider: { local }, sharedStoreProvider: { shared }, reloadWidgets: {})
            XCTAssertEqual(migrated.archive, original)
            XCTAssertEqual(try local.read(), original)
            let withoutGroup = EventStore(localStoreProvider: { local },
                                          sharedStoreProvider: { throw SharedStoreError.unavailableGroup },
                                          reloadWidgets: {})
            XCTAssertEqual(withoutGroup.archive, original)
            XCTAssertTrue(withoutGroup.isLoaded)
        }
    }

    @MainActor
    func testLocalDataWinsOverOldWidgetCopy() throws {
        try withStores { local, shared, _ in
            let event = CountdownEvent(title: "Локальное событие", date: .now.addingTimeInterval(3600))
            let archive = EventArchive(events: [event], pinnedID: event.id)
            try local.write(archive)
            try shared.write(EventArchive())
            let store = EventStore(localStoreProvider: { local }, sharedStoreProvider: { shared }, reloadWidgets: {})
            XCTAssertEqual(store.archive, archive)
            XCTAssertEqual(try shared.read(), archive)
            XCTAssertTrue(store.widgetsAvailable)
        }
    }

    @MainActor
    func testWidgetWriteFailureDoesNotFailLocalSave() throws {
        try withStores { local, _, directory in
            try local.write(EventArchive())
            let unwritable = SharedStore(fileURL: directory.appendingPathComponent("missing/shared.json"))
            let store = EventStore(localStoreProvider: { local }, sharedStoreProvider: { unwritable }, reloadWidgets: {})
            let event = CountdownEvent(title: "Сохранено локально", date: .now.addingTimeInterval(3600))
            XCTAssertTrue(store.save(event))
            XCTAssertEqual(try local.read().events, [event])
            XCTAssertTrue(store.isLoaded)
            XCTAssertNil(store.errorMessage)
            XCTAssertFalse(store.widgetsAvailable)
        }
    }

    @MainActor
    func testLocalWriteFailureDoesNotClaimSuccessOrChangeWidget() throws {
        try withStores { local, shared, directory in
            try local.write(EventArchive())
            var available = true
            let missing = SharedStore(fileURL: directory.appendingPathComponent("missing/local.json"))
            let store = EventStore(localStoreProvider: { available ? local : missing },
                                   sharedStoreProvider: { shared }, reloadWidgets: {})
            let before = try shared.read()
            available = false
            let event = CountdownEvent(title: "Не сохранено", date: .now.addingTimeInterval(3600))
            XCTAssertFalse(store.save(event))
            XCTAssertTrue(store.events.isEmpty)
            XCTAssertNotNil(store.errorMessage)
            XCTAssertEqual(try shared.read(), before)
        }
    }

    @MainActor
    func testCorruptLocalFileIsNotOverwritten() throws {
        try withStores { local, shared, directory in
            let file = directory.appendingPathComponent("local.json")
            let broken = Data("broken archive".utf8)
            try broken.write(to: file)
            let store = EventStore(localStoreProvider: { local }, sharedStoreProvider: { shared }, reloadWidgets: {})
            XCTAssertFalse(store.isLoaded)
            XCTAssertNotNil(store.errorMessage)
            XCTAssertFalse(store.save(CountdownEvent(title: "Тест", date: .now)))
            XCTAssertEqual(try Data(contentsOf: file), broken)
            XCTAssertFalse(shared.hasArchive)
        }
    }
}
