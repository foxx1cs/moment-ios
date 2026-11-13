import XCTest
@testable import Moment

final class ReminderPlanTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func testAnnualLeapDayUsesFebruary28ThenFebruary29() {
        let event = CountdownEvent(title: "Birthday", date: date(2028, 2, 29),
                                   reminderOffsets: [0], repeatsAnnually: true,
                                   repeatMonth: 2, repeatDay: 29, repeatSecondsOfDay: 43_200)
        let plan = ReminderPlan.make(events: [event], now: date(2027, 1, 1), calendar: calendar)
        XCTAssertEqual(plan[0].fireDate, date(2027, 2, 28))
        XCTAssertEqual(plan[1].fireDate, date(2028, 2, 29))
        XCTAssertNotEqual(plan[0].identifier, plan[1].identifier)
    }

    func testPastReminderIsSkippedAndNextAnnualReminderIsKept() {
        let event = CountdownEvent(title: "Birthday", date: date(2027, 3, 1),
                                   reminderOffsets: [7 * 86_400], repeatsAnnually: true,
                                   repeatMonth: 3, repeatDay: 1, repeatSecondsOfDay: 43_200)
        let plan = ReminderPlan.make(events: [event], now: date(2027, 2, 27), calendar: calendar)
        XCTAssertEqual(plan.first?.occurrence, date(2028, 3, 1))
        XCTAssertEqual(plan.first?.fireDate, date(2028, 2, 23))
    }

    func testLimitKeepsEarliestAndDeduplicatesOffsets() {
        let now = date(2027, 1, 1)
        let events = (1...70).map { index in
            CountdownEvent(title: "Event", date: now.addingTimeInterval(Double(index * 3600)),
                           reminderOffsets: [0, 0])
        }
        let plan = ReminderPlan.make(events: Array(events.reversed()), now: now, calendar: calendar)
        XCTAssertEqual(plan.count, 64)
        XCTAssertEqual(plan.first?.fireDate, now.addingTimeInterval(3600))
        XCTAssertEqual(plan.last?.fireDate, now.addingTimeInterval(64 * 3600))
    }
}
