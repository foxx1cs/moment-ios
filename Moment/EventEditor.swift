import SwiftUI
import PhotosUI
import UIKit

struct EventEditor: View {
    @EnvironmentObject private var store: EventStore
    @Environment(\.dismiss) private var dismiss
    private let original: CountdownEvent?
    private let source: CountdownEvent?
    private let initialDate: Date
    @State private var title: String
    @State private var date: Date
    @State private var seconds: Int
    @State private var symbol: String
    @State private var theme: EventTheme
    @State private var note: String
    @State private var category: String
    @State private var photoData: Data?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var reminderOffsets: Set<Int>
    @State private var customReminderAmount = 2
    @State private var customReminderUnit: CustomReminderUnit = .days
    @State private var repeatsAnnually: Bool
    @State private var saveError: String?
    private enum Field: Hashable { case title, note }
    @FocusState private var focusedField: Field?

    private enum ReminderChoice: Int, CaseIterable, Identifiable {
        case week = 604_800
        case day = 86_400
        case hour = 3_600
        case moment = 0

        var id: Int { rawValue }
        var title: LocalizedStringKey {
            switch self {
            case .week: return "За неделю"
            case .day: return "За день"
            case .hour: return "За час"
            case .moment: return "В момент события"
            }
        }
    }

    private enum CustomReminderUnit: String, CaseIterable, Identifiable {
        case minutes, hours, days, weeks

        var id: String { rawValue }
        var seconds: Int {
            switch self {
            case .minutes: return 60
            case .hours: return 3_600
            case .days: return 86_400
            case .weeks: return 604_800
            }
        }
        var title: LocalizedStringKey {
            switch self {
            case .minutes: return "Минуты"
            case .hours: return "Часы"
            case .days: return "Дни"
            case .weeks: return "Недели"
            }
        }
        var shortName: String {
            switch self {
            case .minutes: return String(localized: "м")
            case .hours: return String(localized: "ч")
            case .days: return String(localized: "д")
            case .weeks: return String(localized: "н")
            }
        }
    }

    private let symbols = ["sparkles", "airplane", "gift", "heart", "music.note", "gamecontroller", "graduationcap", "sun.max", "house", "flag.checkered", "party.popper", "moon.stars"]

    init(event: CountdownEvent? = nil, duplicate: Bool = false) {
        original = duplicate ? nil : event
        let initial = event?.nextOccurrence(after: .now)
            ?? Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        source = event
        initialDate = initial
        _title = State(initialValue: event?.title ?? "")
        _date = State(initialValue: initial)
        _seconds = State(initialValue: Calendar.current.component(.second, from: initial))
        _symbol = State(initialValue: event?.symbol ?? "sparkles")
        _theme = State(initialValue: event?.theme ?? .aqua)
        _note = State(initialValue: event?.note ?? "")
        _category = State(initialValue: event?.category ?? "personal")
        _photoData = State(initialValue: event?.photoData)
        _reminderOffsets = State(initialValue: Set(event?.reminderOffsets ?? []))
        _repeatsAnnually = State(initialValue: event?.repeatsAnnually ?? false)
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
                Section("Категория") {
                    Picker("Категория", selection: $category) {
                        Text("Личное").tag("personal")
                        Text("Игры").tag("games")
                        Text("Путешествия").tag("travel")
                        Text("Праздники").tag("celebration")
                        Text("Другое").tag("other")
                    }
                }
                Section("Фотография") {
                    if let photoData, let image = UIImage(data: photoData) {
                        Image(uiImage: image).resizable().scaledToFill()
                            .frame(height: 150).clipped().clipShape(RoundedRectangle(cornerRadius: 12))
                        Button("Удалить фото", role: .destructive) { self.photoData = nil; selectedPhoto = nil }
                    }
                    PhotosPicker("Выбрать фото", selection: $selectedPhoto, matching: .images)
                }
                Section("Повторение") {
                    Toggle("Повторять каждый год", isOn: $repeatsAnnually)
                    if repeatsAnnually {
                        Text("Например, для дней рождения. Для 29 февраля в невисокосный год будет использоваться 28 февраля.")
                            .font(.footnote).foregroundStyle(Palette.muted)
                    }
                }
                Section {
                    ForEach(ReminderChoice.allCases) { choice in
                        Toggle(choice.title, isOn: reminderBinding(for: choice.rawValue))
                    }
                    Text("При первом сохранении напоминаний iOS запросит доступ к уведомлениям. Уже прошедшее время напоминания не отправляется.")
                        .font(.footnote).foregroundStyle(Palette.muted)
                } header: { Text("Напоминания") }
                Section {
                    HStack(spacing: 8) {
                        Text("За")
                        Text(String(customReminderAmount)).monospacedDigit()
                        Stepper("Количество", value: $customReminderAmount,
                                in: 1...max(1, 180 * 86_400 / customReminderUnit.seconds))
                            .labelsHidden()
                        Picker("Единица", selection: $customReminderUnit) {
                            ForEach(CustomReminderUnit.allCases) { unit in
                                Text(unit.title).tag(unit)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .onChange(of: customReminderUnit) { _, unit in
                            customReminderAmount = min(customReminderAmount, 180 * 86_400 / unit.seconds)
                        }
                    }
                    Button {
                        reminderOffsets.insert(customReminderAmount * customReminderUnit.seconds)
                    } label: {
                        Label("Добавить своё напоминание", systemImage: "plus.circle")
                    }
                    .disabled(reminderOffsets.contains(customReminderAmount * customReminderUnit.seconds))

                    ForEach(customReminderOffsets, id: \.self) { offset in
                        HStack {
                            Label(customReminderDescription(offset), systemImage: "bell")
                            Spacer()
                            Button(role: .destructive) { reminderOffsets.remove(offset) } label: {
                                Image(systemName: "minus.circle")
                            }
                            .accessibilityLabel("Удалить напоминание")
                        }
                    }
                } header: { Text("Свои напоминания") } footer: {
                    Text("Выберите интервал до 180 дней до события.")
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
            .onChange(of: selectedPhoto) { _, item in
                Task {
                    guard let item, let data = try? await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else { return }
                    let ratio = min(1, 900 / max(image.size.width, image.size.height))
                    let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
                    let renderer = UIGraphicsImageRenderer(size: size)
                    photoData = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
                        .jpegData(compressionQuality: 0.65)
                }
            }
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
        let preserveAnnualDate = source?.repeatsAnnually == true && repeatsAnnually
            && Calendar.current.isDate(targetDate, inSameDayAs: initialDate)
        let event = CountdownEvent(id: original?.id ?? UUID(), title: cleanTitle, date: targetDate,
                                   createdAt: original?.createdAt ?? .now, symbol: symbol, theme: theme,
                                   note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                                   reminderOffsets: Array(reminderOffsets).sorted(by: >),
                                   repeatsAnnually: repeatsAnnually,
                                   repeatMonth: preserveAnnualDate ? source?.repeatMonth : nil,
                                   repeatDay: preserveAnnualDate ? source?.repeatDay : nil,
                                   category: category, photoData: photoData)
        if store.save(event) { dismiss() }
        else {
            saveError = store.errorMessage
            store.errorMessage = nil
        }
    }

    private func reminderBinding(for offset: Int) -> Binding<Bool> {
        Binding(
            get: { reminderOffsets.contains(offset) },
            set: { enabled in
                if enabled { reminderOffsets.insert(offset) }
                else { reminderOffsets.remove(offset) }
            }
        )
    }

    private var customReminderOffsets: [Int] {
        let standard = Set(ReminderChoice.allCases.map(\.rawValue))
        return reminderOffsets.subtracting(standard).sorted(by: >)
    }

    private func customReminderDescription(_ offset: Int) -> String {
        let units = [CustomReminderUnit.weeks, .days, .hours, .minutes]
        if let unit = units.first(where: { offset >= $0.seconds && offset % $0.seconds == 0 }) {
            return "\(String(localized: "За")) \(offset / unit.seconds) \(unit.shortName)"
        }
        return "\(String(localized: "За")) \(offset) \(String(localized: "с"))"
    }

    private func symbolName(_ symbol: String) -> String {
        switch symbol {
        case "sparkles": return String(localized: "Мечта")
        case "airplane": return String(localized: "Путешествие")
        case "gift": return String(localized: "Подарок")
        case "heart": return String(localized: "Любовь")
        case "music.note": return String(localized: "Музыка")
        case "gamecontroller": return String(localized: "Игра")
        case "graduationcap": return String(localized: "Выпускной")
        case "sun.max": return String(localized: "Солнце")
        case "house": return String(localized: "Дом")
        case "flag.checkered": return String(localized: "Цель")
        case "party.popper": return String(localized: "Праздник")
        default: return String(localized: "Ночь")
        }
    }
}
