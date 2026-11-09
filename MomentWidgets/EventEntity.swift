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
        try SharedStore.live().read().events
            .filter { identifiers.contains($0.id.uuidString) }.map(CountdownEventEntity.init)
    }

    func suggestedEntities() async throws -> [CountdownEventEntity] {
        try SharedStore.live().read().events
            .sorted { $0.date < $1.date }.map(CountdownEventEntity.init)
    }
}

struct CountdownConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Ваш момент"
    static var description = IntentDescription("Выберите событие или оставьте главное событие приложения.")

    @Parameter(title: "Событие")
    var event: CountdownEventEntity?
}
