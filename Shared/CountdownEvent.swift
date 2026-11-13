import Foundation

struct CountdownEvent: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var title: String
    var date: Date
    var createdAt: Date
    var symbol: String
    var theme: EventTheme
    var note: String
    var reminderOffsets: [Int]
    var repeatsAnnually: Bool
    var repeatMonth: Int?
    var repeatDay: Int?
    var repeatSecondsOfDay: Int?

    init(id: UUID = UUID(), title: String, date: Date, createdAt: Date = .now,
         symbol: String = "sparkles", theme: EventTheme = .aqua, note: String = "",
         reminderOffsets: [Int] = [], repeatsAnnually: Bool = false,
         repeatMonth: Int? = nil, repeatDay: Int? = nil, repeatSecondsOfDay: Int? = nil) {
        self.id = id
        self.title = title
        self.date = date
        self.createdAt = createdAt
        self.symbol = symbol
        self.theme = theme
        self.note = note
        self.reminderOffsets = reminderOffsets
        self.repeatsAnnually = repeatsAnnually
        let parts = Calendar.current.dateComponents([.month, .day, .hour, .minute, .second], from: date)
        self.repeatMonth = repeatsAnnually ? (repeatMonth ?? parts.month) : nil
        self.repeatDay = repeatsAnnually ? (repeatDay ?? parts.day) : nil
        self.repeatSecondsOfDay = repeatsAnnually
            ? (repeatSecondsOfDay ?? ((parts.hour ?? 0) * 3600 + (parts.minute ?? 0) * 60 + (parts.second ?? 0)))
            : nil
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, date, createdAt, symbol, theme, note, reminderOffsets
        case repeatsAnnually, repeatMonth, repeatDay, repeatSecondsOfDay
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        date = try values.decode(Date.self, forKey: .date)
        createdAt = try values.decode(Date.self, forKey: .createdAt)
        symbol = try values.decodeIfPresent(String.self, forKey: .symbol) ?? "sparkles"
        theme = try values.decodeIfPresent(EventTheme.self, forKey: .theme) ?? .aqua
        note = try values.decodeIfPresent(String.self, forKey: .note) ?? ""
        reminderOffsets = try values.decodeIfPresent([Int].self, forKey: .reminderOffsets) ?? []
        repeatsAnnually = try values.decodeIfPresent(Bool.self, forKey: .repeatsAnnually) ?? false
        repeatMonth = try values.decodeIfPresent(Int.self, forKey: .repeatMonth)
        repeatDay = try values.decodeIfPresent(Int.self, forKey: .repeatDay)
        repeatSecondsOfDay = try values.decodeIfPresent(Int.self, forKey: .repeatSecondsOfDay)
        if repeatsAnnually && (repeatMonth == nil || repeatDay == nil || repeatSecondsOfDay == nil) {
            let parts = Calendar.current.dateComponents([.month, .day, .hour, .minute, .second], from: date)
            repeatMonth = repeatMonth ?? parts.month
            repeatDay = repeatDay ?? parts.day
            repeatSecondsOfDay = repeatSecondsOfDay
                ?? ((parts.hour ?? 0) * 3600 + (parts.minute ?? 0) * 60 + (parts.second ?? 0))
        }
    }

    func nextOccurrence(after now: Date, calendar: Calendar = .current) -> Date {
        guard repeatsAnnually,
              let month = repeatMonth, (1...12).contains(month),
              let day = repeatDay, (1...31).contains(day),
              let seconds = repeatSecondsOfDay, (0..<86_400).contains(seconds) else { return date }

        let hour = seconds / 3_600
        let minute = seconds / 60 % 60
        let second = seconds % 60
        let year = calendar.component(.year, from: now)

        func occurrence(in year: Int) -> Date? {
            func make(day candidateDay: Int) -> Date? {
                var parts = DateComponents()
                parts.year = year
                parts.month = month
                parts.day = candidateDay
                parts.hour = hour
                parts.minute = minute
                parts.second = second
                guard let value = calendar.date(from: parts),
                      calendar.component(.month, from: value) == month,
                      calendar.component(.day, from: value) == candidateDay else { return nil }
                return value
            }
            if let value = make(day: day) { return value }
            if month == 2 && day == 29 { return make(day: 28) }
            return nil
        }

        if let thisYear = occurrence(in: year), thisYear > now { return thisYear }
        return occurrence(in: year + 1) ?? date
    }

    func remaining(at now: Date) -> CountdownComponents {
        CountdownComponents(deadline: nextOccurrence(after: now), now: now)
    }

    func progress(at now: Date) -> Double {
        let endDate = nextOccurrence(after: now)
        let startDate = repeatsAnnually
            ? (Calendar.current.date(byAdding: .year, value: -1, to: endDate) ?? createdAt)
            : createdAt
        let duration = endDate.timeIntervalSince(startDate)
        guard duration > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(startDate) / duration))
    }

    static let preview: CountdownEvent = {
        let now = Date.now
        let remaining: TimeInterval = 804_728 // 9 days, 7 hours, 32 minutes, 8 seconds
        return CountdownEvent(
            id: UUID(uuidString: "C6342364-284D-4520-A280-7F20562EE36F")!,
            title: String(localized: "Большое путешествие"),
            date: now.addingTimeInterval(remaining),
            createdAt: now.addingTimeInterval(-432_000),
            symbol: "airplane", theme: .aqua
        )
    }()
}

enum EventTheme: String, Codable, CaseIterable, Identifiable, Sendable {
    case aqua, violet, peach, blue, rose
    var id: String { rawValue }
    var name: String {
        switch self {
        case .aqua: return String(localized: "Мята")
        case .violet: return String(localized: "Лаванда")
        case .peach: return String(localized: "Персик")
        case .blue: return String(localized: "Небо")
        case .rose: return String(localized: "Роза")
        }
    }
}

struct CountdownComponents: Equatable, Sendable {
    let totalSeconds: Int
    var days: Int { totalSeconds / 86400 }
    var hours: Int { totalSeconds / 3600 % 24 }
    var minutes: Int { totalSeconds / 60 % 60 }
    var seconds: Int { totalSeconds % 60 }
    var isFinished: Bool { totalSeconds == 0 }

    init(deadline: Date, now: Date) {
        // Recompute from the absolute deadline: no accumulated timer drift.
        let remaining = deadline.timeIntervalSince(now)
        if !remaining.isFinite || remaining <= 0 {
            totalSeconds = 0
        } else {
            totalSeconds = Int(min(remaining.rounded(.up), Double(Int.max / 2)))
        }
    }
}
