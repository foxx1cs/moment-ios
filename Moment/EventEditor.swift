import SwiftUI

struct EventEditor: View {
    @EnvironmentObject private var store: EventStore
    @Environment(\.dismiss) private var dismiss
    private let original: CountdownEvent?
    @State private var title: String
    @State private var date: Date
    @State private var seconds: Int
    @State private var symbol: String
    @State private var theme: EventTheme
    @State private var note: String
    @State private var saveError: String?
    private enum Field: Hashable { case title, note }
    @FocusState private var focusedField: Field?

    private let symbols = ["sparkles", "airplane", "gift", "heart", "music.note", "gamecontroller", "graduationcap", "sun.max", "house", "flag.checkered", "party.popper", "moon.stars"]

    init(event: CountdownEvent? = nil) {
        original = event
        let initial = event?.date ?? Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        _title = State(initialValue: event?.title ?? "")
        _date = State(initialValue: initial)
        _seconds = State(initialValue: event.map { Calendar.current.component(.second, from: $0.date) } ?? 0)
        _symbol = State(initialValue: event?.symbol ?? "sparkles")
        _theme = State(initialValue: event?.theme ?? .aqua)
        _note = State(initialValue: event?.note ?? "")
    }

    private var targetDate: Date {
        var parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        parts.second = seconds
        return Calendar.current.date(from: parts) ?? date
    }

    private var cleanTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: symbol)
                            .font(.system(size: 28)).foregroundStyle(theme.color)
                            .frame(width: 50, height: 56)
                        TextField("Название события", text: $title)
                            .font(.headline).focused($focusedField, equals: .title)
                            .onChange(of: title) { _, value in title = String(value.prefix(60)) }
                            .accessibilityLabel("Название события")
                            .accessibilityIdentifier("eventTitleField")
                    }
                } header: { Text("Чего ждём?") }
                Section {
                    DatePicker("Дата и время", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    Stepper(value: $seconds, in: 0...59) {
                        HStack {
                            Text("Секунды")
                            Spacer()
                            Text(String(format: "%02d", seconds)).monospacedDigit().foregroundStyle(theme.color)
                        }
                    }
                    Text(targetDate.formatted(.dateTime.day().month(.wide).year().hour().minute().second()))
                        .font(.footnote).foregroundStyle(.secondary)
                } header: { Text("Тот самый момент") } footer: {
                    Text("Часовой пояс: \(TimeZone.current.identifier). Дата сохраняется как точный момент времени; смена часового пояса не сбрасывает отсчёт.")
                }
                Section("Настроение") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(symbols, id: \.self) { item in
                            Button { symbol = item } label: {
                                Image(systemName: item).font(.system(size: 21))
                                    .frame(maxWidth: .infinity).frame(height: 46)
                                    .foregroundStyle(symbol == item ? Palette.ink : .white.opacity(0.7))
                                    .background(symbol == item ? theme.color : Palette.surface,
                                                in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(symbolName(item))
                            .accessibilityAddTraits(symbol == item ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 6)
                    HStack(spacing: 18) {
                        ForEach(EventTheme.allCases) { item in
                            Button { theme = item } label: {
                                Circle().fill(item.color).frame(width: 34, height: 34)
                                    .overlay {
                                        if item == theme {
                                            Image(systemName: "checkmark").font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(Palette.ink)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(item.name)
                            .accessibilityAddTraits(item == theme ? .isSelected : [])
                        }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                }
                Section("Пара слов для себя") {
                    TextField("Почему этот день особенный?", text: $note, axis: .vertical)
                        .focused($focusedField, equals: .note)
                        .lineLimit(3...5)
                        .onChange(of: note) { _, value in note = String(value.prefix(240)) }
                }
                if targetDate <= .now {
                    Section { Text("Выберите дату и время в будущем.").foregroundStyle(.orange) }
                }
                if let saveError {
                    Section { Text(saveError).foregroundStyle(.red) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle(original == nil ? "Новый момент" : "Изменить момент")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", action: save)
                        .accessibilityIdentifier("saveEventButton")
                        .fontWeight(.semibold)
                        .disabled(cleanTitle.isEmpty || targetDate <= .now || !store.isLoaded)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") { focusedField = nil }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func save() {
        guard !cleanTitle.isEmpty, targetDate > .now else { return }
        let event = CountdownEvent(id: original?.id ?? UUID(), title: cleanTitle, date: targetDate,
                                   createdAt: original?.createdAt ?? .now, symbol: symbol, theme: theme,
                                   note: note.trimmingCharacters(in: .whitespacesAndNewlines))
        if store.save(event) { dismiss() }
        else {
            saveError = store.errorMessage
            store.errorMessage = nil
        }
    }

    private func symbolName(_ symbol: String) -> String {
        switch symbol {
        case "sparkles": return "Мечта"
        case "airplane": return "Путешествие"
        case "gift": return "Подарок"
        case "heart": return "Любовь"
        case "music.note": return "Музыка"
        case "gamecontroller": return "Игра"
        case "graduationcap": return "Выпускной"
        case "sun.max": return "Солнце"
        case "house": return "Дом"
        case "flag.checkered": return "Цель"
        case "party.popper": return "Праздник"
        default: return "Ночь"
        }
    }
}
