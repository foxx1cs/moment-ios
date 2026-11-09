import XCTest
@testable import Moment

final class CountdownTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testDecomposesDaysHoursMinutesSeconds() {
        let delta: TimeInterval = 804_728
        let result = CountdownComponents(deadline: now.addingTimeInterval(delta), now: now)
        XCTAssertEqual(result.days, 9)
        XCTAssertEqual(result.hours, 7)
        XCTAssertEqual(result.minutes, 32)
        XCTAssertEqual(result.seconds, 8)
    }

    func testFractionalSecondDoesNotFinishEarly() {
        let result = CountdownComponents(deadline: now.addingTimeInterval(0.1), now: now)
        XCTAssertEqual(result.totalSeconds, 1)
        XCTAssertFalse(result.isFinished)
    }

    func testStopsAtZero() {
        XCTAssertEqual(CountdownComponents(deadline: now, now: now).totalSeconds, 0)
        XCTAssertEqual(CountdownComponents(deadline: now.addingTimeInterval(-12), now: now).totalSeconds, 0)
    }

    func testHourAndDayBoundaries() {
        let day = CountdownComponents(deadline: now.addingTimeInterval(86400), now: now)
        XCTAssertEqual(day.days, 1)
        XCTAssertEqual(day.hours, 0)
        let prior = CountdownComponents(deadline: now.addingTimeInterval(86399), now: now)
        XCTAssertEqual(prior.days, 0)
        XCTAssertEqual(prior.hours, 23)
        XCTAssertEqual(prior.minutes, 59)
        XCTAssertEqual(prior.seconds, 59)
    }

    func testResumingRecomputesFromDeadline() {
        let event = CountdownEvent(title: "Поездка", date: now.addingTimeInterval(3600))
        XCTAssertEqual(event.remaining(at: now.addingTimeInterval(1801)).totalSeconds, 1799)
        XCTAssertEqual(event.remaining(at: now.addingTimeInterval(-10)).totalSeconds, 3610)
    }

    func testProgressIsClamped() {
        let event = CountdownEvent(title: "Тест", date: now.addingTimeInterval(100), createdAt: now)
        XCTAssertEqual(event.progress(at: now.addingTimeInterval(-10)), 0)
        XCTAssertEqual(event.progress(at: now.addingTimeInterval(50)), 0.5)
        XCTAssertEqual(event.progress(at: now.addingTimeInterval(200)), 1)
    }

    func testArchiveRoundTripKeepsPinAndDate() throws {
        let event = CountdownEvent(title: "День рождения 🎂", date: now, symbol: "gift", theme: .rose, note: "Торт!")
        let archive = EventArchive(events: [event], pinnedID: event.id)
        let data = try JSONEncoder().encode(archive)
        XCTAssertEqual(try JSONDecoder().decode(EventArchive.self, from: data), archive)
    }

    func testSharedStoreAtomicReplacementAndCorruption() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("events.json")
        let store = SharedStore(fileURL: file)
        XCTAssertEqual(try store.read(), EventArchive())
        let event = CountdownEvent(title: "Тест", date: now)
        let archive = EventArchive(events: [event], pinnedID: event.id)
        try store.write(archive)
        XCTAssertEqual(try store.read(), archive)
        try store.write(EventArchive())
        XCTAssertTrue(try store.read().events.isEmpty)
        try Data("broken".utf8).write(to: file)
        XCTAssertThrowsError(try store.read())
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "broken")
    }

    func testExplicitPinWinsAndDeletedPinFallsBack() {
        let early = CountdownEvent(title: "Раньше", date: .now.addingTimeInterval(3600))
        let late = CountdownEvent(title: "Позже", date: .now.addingTimeInterval(7200))
        XCTAssertEqual(EventArchive(events: [late, early], pinnedID: late.id).pinnedEvent, late)
        XCTAssertEqual(EventArchive(events: [late, early], pinnedID: UUID()).pinnedEvent, early)
    }
}
