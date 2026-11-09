import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: EventStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var showEditor = false
    @State private var showGuide = false
    @State private var selectedEvent: CountdownEvent?
    @State private var showCompleted = false

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .distantPast, by: 1)) { context in
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        header
                        if let event = store.featured {
                            Button { selectedEvent = event } label: {
                                EventHero(event: event, now: context.date)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("featuredEvent")
                            .accessibilityLabel(event.title)
                            .accessibilityHint("Открыть событие")
                        } else {
                            emptyHero
                        }
                        eventsSection(now: context.date)
                        widgetBanner
                        Text("У хорошего впереди есть точное время.")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.muted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                }
            }
            .background(Palette.background)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showEditor) { EventEditor() }
            .sheet(isPresented: $showGuide) { WidgetGuide() }
            .sheet(item: $selectedEvent) { EventDetail(eventID: $0.id) }
            .alert(store.isLoaded ? "Не удалось сохранить данные" : "Не удалось открыть данные", isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )) {
                if !store.isLoaded { Button("Повторить") { store.reload() } }
                Button("Понятно") { store.errorMessage = nil }
            } message: { Text(store.errorMessage ?? "") }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { store.reload() }
            }
            .onOpenURL { url in
                guard url.scheme == "moment", url.host == "event",
                      let id = UUID(uuidString: url.lastPathComponent) else { return }
                selectedEvent = store.events.first { $0.id == id }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text("MOMENT")
                    .font(.system(size: 11, weight: .bold)).tracking(4)
                    .foregroundStyle(Palette.aqua)
                Text("Ждать — красиво.")
                    .font(.system(size: 29, weight: .semibold, design: .rounded))
            }
            Spacer(minLength: 10)
            Button { showEditor = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(Palette.aqua)
                    .frame(width: 48, height: 48)
                    .background(Palette.surface, in: Circle())
            }
            .accessibilityLabel("Создать событие")
            .accessibilityIdentifier("addEventButton")
            .disabled(!store.isLoaded)
        }
    }

    private var emptyHero: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Image(systemName: "sparkles").font(.system(size: 32))
                Spacer()
                Text("ВАШ ПЕРВЫЙ МОМЕНТ").font(.system(size: 9, weight: .bold)).tracking(1.5)
            }
            Text("Впереди —\nчто-то хорошее.")
                .font(.system(size: 36, weight: .semibold, design: .rounded))
            Text("Путешествие, встреча или большая мечта.\nНачните отсчёт до важного.")
                .font(.subheadline).opacity(0.7)
            Button { showEditor = true } label: {
                Label("Создать событие", systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 20).padding(.vertical, 15)
                    .foregroundStyle(.white)
                    .background(Palette.ink, in: Capsule())
            }
            .accessibilityIdentifier("createEventButton")
            .disabled(!store.isLoaded)
        }
        .foregroundStyle(Palette.ink)
        .padding(26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.aqua.gradient, in: RoundedRectangle(cornerRadius: 30))
    }

    private func eventsSection(now: Date) -> some View {
        let events = store.events.filter { showCompleted ? $0.date <= now : $0.date > now }
            .sorted { showCompleted ? $0.date > $1.date : $0.date < $1.date }
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Мои события").font(.system(size: 20, weight: .semibold))
                Text("\(events.count)")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.muted)
                    .padding(7).background(Palette.surface, in: Circle())
                Spacer()
            }
            Picker("События", selection: $showCompleted) {
                Text("Впереди").tag(false)
                Text("Завершённые").tag(true)
            }
            .pickerStyle(.segmented)
            if events.isEmpty {
                Text(showCompleted ? "Здесь будут ваши прошедшие моменты." : "Добавьте то, чего ждёте с нетерпением.")
                    .font(.subheadline).foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 20)
            } else {
                ForEach(events) { event in
                    Button { selectedEvent = event } label: {
                        EventRow(event: event, now: now, pinned: store.archive.pinnedID == event.id)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Главное событие", systemImage: "pin") { store.pin(event) }
                        Button("Открыть", systemImage: "arrow.up.right") { selectedEvent = event }
                    }
                }
            }
        }
    }

    private var widgetBanner: some View {
        Button { showGuide = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "lock.rectangle.stack")
                    .font(.system(size: 25, weight: .light))
                    .foregroundStyle(Palette.aqua)
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.widgetsAvailable ? "Всегда перед глазами" : "События на вашем iPhone")
                        .font(.system(size: 14, weight: .semibold))
                    Text(store.widgetsAvailable ? "Отсчёт на экране блокировки" : "Виджеты недоступны в этой установке")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right").font(.system(size: 13))
                    .foregroundStyle(Palette.muted)
            }
            .padding(20)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.05)))
        }
        .buttonStyle(.plain)
    }
}

private struct EventRow: View {
    let event: CountdownEvent
    let now: Date
    let pinned: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: event.symbol)
                .font(.system(size: 21))
                .foregroundStyle(event.theme.color)
                .frame(width: 48, height: 52)
                .background(event.theme.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(event.title).font(.system(size: 15, weight: .medium)).lineLimit(1)
                    if pinned { Image(systemName: "pin.fill").font(.system(size: 9)).foregroundStyle(Palette.aqua) }
                }
                Text(event.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11)).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 4) {
                let time = event.remaining(at: now)
                Text(time.isFinished ? "✓" : String(format: "%02d:%02d:%02d", time.hours, time.minutes, time.seconds))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .monospacedDigit().foregroundStyle(event.theme.color)
                Text(time.isFinished ? "Настал" : "Дней: \(time.days)")
                    .font(.system(size: 10)).foregroundStyle(Palette.muted)
            }
        }
        .padding(15)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 22))
    }
}

#Preview { HomeView().environmentObject(EventStore()) }
