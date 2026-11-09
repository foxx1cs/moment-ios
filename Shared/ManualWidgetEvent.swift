import Foundation

enum ManualWidgetEvent {
    static func make(title: String, date: Date?, seconds: Int,
                     calendar: Calendar = .current, now: Date = .now) -> CountdownEvent? {
        guard let date, date.timeIntervalSince1970.isFinite, (0...59).contains(seconds),
              let minute = calendar.dateInterval(of: .minute, for: date)?.start else { return nil }
        let name = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        return CountdownEvent(
            id: UUID(uuidString: "1F849A89-2C70-40D2-97D0-9DAF4B11FEF2")!,
            title: name.isEmpty ? "Мой момент" : name,
            date: minute.addingTimeInterval(TimeInterval(seconds)), createdAt: now,
            symbol: "hourglass", theme: .aqua
        )
    }
}
