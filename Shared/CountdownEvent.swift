import Foundation

struct CountdownEvent: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var title: String
    var date: Date
    var createdAt: Date
    var symbol: String
    var theme: EventTheme
    var note: String

    init(id: UUID = UUID(), title: String, date: Date, createdAt: Date = .now,
         symbol: String = "sparkles", theme: EventTheme = .aqua, note: String = "") {
        self.id = id
        self.title = title
        self.date = date
        self.createdAt = createdAt
        self.symbol = symbol
        self.theme = theme
        self.note = note
    }

    func remaining(at now: Date) -> CountdownComponents {
        CountdownComponents(deadline: date, now: now)
    }

    func progress(at now: Date) -> Double {
        let duration = date.timeIntervalSince(createdAt)
        guard duration > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(createdAt) / duration))
    }

    static let preview = CountdownEvent(
        id: UUID(uuidString: "C6342364-284D-4520-A280-7F20562EE36F")!,
        title: "Большое путешествие",
        date: Date.now.addingTimeInterval(9 * 86400 + 7 * 3600 + 32 * 60 + 8),
        createdAt: Date.now.addingTimeInterval(-5 * 86400),
        symbol: "airplane", theme: .aqua
    )
}

enum EventTheme: String, Codable, CaseIterable, Identifiable, Sendable {
    case aqua, violet, peach, blue, rose
    var id: String { rawValue }
    var name: String {
        switch self {
        case .aqua: return "Мята"
        case .violet: return "Лаванда"
        case .peach: return "Персик"
        case .blue: return "Небо"
        case .rose: return "Роза"
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
