import SwiftUI

struct EventDetail: View {
    let eventID: UUID
    @EnvironmentObject private var store: EventStore
    @Environment(\.dismiss) private var dismiss
    @State private var showEditor = false
    @State private var confirmDelete = false
    @State private var showGuide = false

    private var event: CountdownEvent? { store.events.first { $0.id == eventID } }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let event {
                    VStack(alignment: .leading, spacing: 24) {
                        TimelineView(.periodic(from: .distantPast, by: 1)) { context in
                            EventHero(event: event, now: context.date)
                        }
                        if !event.note.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("ДЛЯ МЕНЯ").font(.system(size: 10, weight: .bold)).tracking(2)
                                    .foregroundStyle(Palette.muted)
                                Text(event.note).font(.body).textSelection(.enabled)
                            }.padding(.horizontal, 4)
                        }
                        VStack(spacing: 12) {
                            ShareLink(item: shareMessage(for: event)) {
                                Label("Поделиться отсчётом", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity).padding(16)
                                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
                            }
                            Button {
                                store.pin(event)
                            } label: {
                                Label(store.archive.pinnedID == event.id ? "Главное событие" : "Сделать главным",
                                      systemImage: store.archive.pinnedID == event.id ? "pin.fill" : "pin")
                                    .frame(maxWidth: .infinity).padding(16)
                                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
                            }
                            Text("Главное событие отображается на первом экране и в виджете без выбранного события.")
                                .font(.footnote).foregroundStyle(Palette.muted)
                            Button { showGuide = true } label: {
                                Label("Добавить виджет", systemImage: "lock.rectangle")
                                    .frame(maxWidth: .infinity).padding(16)
                                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
                            }
                            Button("Удалить событие", role: .destructive) { confirmDelete = true }
                                .padding(.top, 16)
                        }
                    }
                    .padding(22)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                } else {
                    ContentUnavailableView("Событие удалено", systemImage: "calendar.badge.minus")
                }
            }
            .background(Palette.background)
            .navigationTitle("Ваш момент")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    if event != nil { Button("Изменить") { showEditor = true } }
                }
            }
            .sheet(isPresented: $showEditor) { if let event { EventEditor(event: event) } }
            .sheet(isPresented: $showGuide) { WidgetGuide() }
            .confirmationDialog("Удалить событие? Оно исчезнет и из виджета.",
                                isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Удалить", role: .destructive) {
                    if let event, store.delete(event) { dismiss() }
                }
                Button("Отмена", role: .cancel) {}
            }
            .alert("Не удалось сохранить", isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )) {
                Button("Понятно") { store.errorMessage = nil }
            } message: { Text(store.errorMessage ?? "") }
        }
        .preferredColorScheme(.dark)
    }

    private func shareMessage(for event: CountdownEvent) -> String {
        let now = Date.now
        let target = event.nextOccurrence(after: now)
        let remaining = CountdownComponents(deadline: target, now: now)
        let date = target.formatted(date: .long, time: .shortened)
        if remaining.isFinished {
            return "\(String(localized: "Момент уже наступил:")) \(event.title)\n\(String(localized: "Дата:")) \(date)"
        }
        let time = "\(remaining.days)\(String(localized: "д")) \(remaining.hours)\(String(localized: "ч")) \(remaining.minutes)\(String(localized: "м")) \(remaining.seconds)\(String(localized: "с"))"
        let recurrence = event.repeatsAnnually ? "\n\(String(localized: "Повторяется каждый год"))" : ""
        return "\(String(localized: "Я жду:")) \(event.title)!\n\(String(localized: "Осталось:")) \(time)\n\(String(localized: "Дата:")) \(date)\(recurrence)"
    }
}
