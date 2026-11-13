import Foundation

struct PlannedReminder {
    let event: CountdownEvent
    let offset: Int
    let fireDate: Date
    let occurrence: Date

    var identifier: String {
        "moment.reminder.\(event.id.uuidString).\(offset).\(Int(occurrence.timeIntervalSince1970))"
    }
}

enum ReminderPlan {
    static let maximumOffset = 180 * 86_400
    static let maximumPending = 64

    static func make(events: [CountdownEvent], now: Date, calendar: Calendar = .current) -> [PlannedReminder] {
        var reminders: [PlannedReminder] = []
        for event in events {
            let offsets = Set(event.reminderOffsets).filter { (0...maximumOffset).contains($0) }
            guard !offsets.isEmpty else { continue }
            var occurrence = event.nextOccurrence(after: now, calendar: calendar)
            // Refill on app launch; explicit occurrences preserve leap-day and offset changes.
            for _ in 0..<(event.repeatsAnnually ? 5 : 1) {
                for offset in offsets {
                    let fireDate = occurrence.addingTimeInterval(-Double(offset))
                    if fireDate > now {
                        reminders.append(PlannedReminder(event: event, offset: offset,
                                                         fireDate: fireDate, occurrence: occurrence))
                    }
                }
                guard event.repeatsAnnually else { break }
                let next = event.nextOccurrence(after: occurrence.addingTimeInterval(1), calendar: calendar)
                guard next > occurrence else { break }
                occurrence = next
            }
        }
        return Array(reminders.sorted {
            $0.fireDate == $1.fireDate ? $0.identifier < $1.identifier : $0.fireDate < $1.fireDate
        }.prefix(maximumPending))
    }
}
