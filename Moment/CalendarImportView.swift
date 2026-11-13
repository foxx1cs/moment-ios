import SwiftUI
import EventKit

struct CalendarImportView: View {
    let onSelect: (CountdownEvent) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var eventStore = EKEventStore()
    @State private var events: [EKEvent] = []
    @State private var denied = false
    @State private var loading = true

    var body: some View {
        NavigationStack {
            Group {
                if loading { ProgressView() }
                else if denied { ContentUnavailableView("Нет доступа к календарю", systemImage: "calendar.badge.exclamationmark", description: Text("Разрешите доступ к календарю в настройках iPhone.")) }
                else if events.isEmpty { ContentUnavailableView("Событий не найдено", systemImage: "calendar", description: Text("В ближайший год нет будущих событий.")) }
                else {
                    List(events, id: \.eventIdentifier) { event in
                        Button {
                            let copy = CountdownEvent(title: event.title ?? "Moment", date: event.startDate)
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { onSelect(copy) }
                        } label: {
                            VStack(alignment: .leading) {
                                Text(event.title ?? "Moment")
                                Text(event.startDate.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Импорт из календаря")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } } }
            .task {
                do {
                    guard try await eventStore.requestFullAccessToEvents() else { denied = true; loading = false; return }
                    let now = Date.now
                    let end = Calendar.current.date(byAdding: .year, value: 1, to: now) ?? now
                    let predicate = eventStore.predicateForEvents(withStart: now, end: end, calendars: nil)
                    events = eventStore.events(matching: predicate).filter { $0.startDate > now }.sorted { $0.startDate < $1.startDate }
                } catch { denied = true }
                loading = false
            }
        }
        .preferredColorScheme(.dark)
    }
}
