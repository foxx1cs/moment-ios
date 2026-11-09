import XCTest
@testable import Moment

final class ManualWidgetTests: XCTestCase {
    func testManualConfigurationDoesNotNeedStoredEvents() throws {
        let date = Date(timeIntervalSince1970: 1_800_000_020)
        let event = try XCTUnwrap(ManualWidgetEvent.make(title: "  Отпуск  ", date: date, seconds: 59))
        XCTAssertEqual(event.title, "Отпуск")
        XCTAssertEqual(Calendar.current.component(.second, from: event.date), 59)
        XCTAssertEqual(event.date.timeIntervalSince1970.truncatingRemainder(dividingBy: 1), 0)
    }

    func testNoDateProducesSetupState() {
        XCTAssertNil(ManualWidgetEvent.make(title: "Мой момент", date: nil, seconds: 0))
    }

    func testInvalidSecondsAreRejected() {
        XCTAssertNil(ManualWidgetEvent.make(title: "Тест", date: .now, seconds: -1))
        XCTAssertNil(ManualWidgetEvent.make(title: "Тест", date: .now, seconds: 60))
    }

    func testEmptyTitleUsesReadableDefaultAndLongTitleIsBounded() {
        XCTAssertEqual(ManualWidgetEvent.make(title: " \n ", date: .now, seconds: 0)?.title, "Мой момент")
        XCTAssertEqual(ManualWidgetEvent.make(title: String(repeating: "Я", count: 80), date: .now, seconds: 0)?.title.count, 60)
    }

    func testPastManualEventStopsAtZero() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let event = try XCTUnwrap(ManualWidgetEvent.make(title: "Готово", date: now.addingTimeInterval(-3600), seconds: 0))
        XCTAssertEqual(event.remaining(at: now).totalSeconds, 0)
    }

    func testSecondsPreserveRepeatedHourDuringTimeZoneChange() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let formatter = ISO8601DateFormatter()
        let secondOccurrence = try XCTUnwrap(formatter.date(from: "2026-11-01T06:30:42Z"))
        let expected = try XCTUnwrap(formatter.date(from: "2026-11-01T06:30:12Z"))
        let event = try XCTUnwrap(ManualWidgetEvent.make(title: "Тест", date: secondOccurrence, seconds: 12, calendar: calendar))
        XCTAssertEqual(event.date, expected)
    }
}
