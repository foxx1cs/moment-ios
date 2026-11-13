import AppIntents
import Foundation

struct CountdownEventEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Событие")
    static var defaultQuery = CountdownEventQuery()

    var id: String
    var title: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }

    init(event: CountdownEvent) {
        id = event.id.uuidString
        title = event.title
    }
}

struct CountdownEventQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [CountdownEventEntity] {
        let events = (try? SharedStore.live().read().events) ?? []
        return events
            .filter { identifiers.contains($0.id.uuidString) }.map(CountdownEventEntity.init)
    }

    func suggestedEntities() async throws -> [CountdownEventEntity] {
        let events = (try? SharedStore.live().read().events) ?? []
        return events
            .sorted { $0.nextOccurrence(after: .now) < $1.nextOccurrence(after: .now) }
            .map(CountdownEventEntity.init)
    }
}

enum WidgetSetupMode: String, AppEnum {
    case manual, fromApp

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Настройка виджета")
    static var caseDisplayRepresentations: [WidgetSetupMode: DisplayRepresentation] = [
        .manual: DisplayRepresentation(title: "Вручную", subtitle: "Название и дата прямо в виджете"),
        .fromApp: DisplayRepresentation(title: "Из приложения", subtitle: "Нужен App Group в подписи приложения и виджета")
    ]
}

struct CountdownConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Ваш момент"
    static var description = IntentDescription("Вручную: задайте название, дату и секунды. Из приложения: выберите сохранённое событие при доступной синхронизации.")

    @Parameter(title: "Настройка", default: .manual)
    var mode: WidgetSetupMode

    @Parameter(title: "Название", default: "Moment")
    var manualTitle: String

    @Parameter(title: "Дата и время", kind: .dateTime)
    var targetDate: Date?

    @Parameter(title: "Секунды", default: 0, inclusiveRange: (0, 59))
    var seconds: Int

    @Parameter(title: "Событие из приложения")
    var event: CountdownEventEntity?

    static var parameterSummary: some ParameterSummary {
        When(\CountdownConfiguration.$mode, .equalTo, WidgetSetupMode.manual) {
            Summary {
                \.$mode
                \.$manualTitle
                \.$targetDate
                \.$seconds
            }
        } otherwise: {
            Summary {
                \.$mode
                \.$event
            }
        }
    }
}
