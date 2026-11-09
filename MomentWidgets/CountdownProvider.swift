import WidgetKit
import Foundation

struct CountdownEntry: TimelineEntry {
    let date: Date
    let event: CountdownEvent?
    var unavailable = false
    var deleted = false
    var manual = false
}

struct CountdownProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CountdownEntry {
        CountdownEntry(date: .now, event: .preview)
    }

    func snapshot(for configuration: CountdownConfiguration, in context: Context) async -> CountdownEntry {
        if context.isPreview { return placeholder(in: context) }
        return load(configuration, at: .now)
    }

    func timeline(for configuration: CountdownConfiguration, in context: Context) async -> Timeline<CountdownEntry> {
        let now = Date.now
        let current = load(configuration, at: now)
        var entries = [current]
        if let event = current.event, event.date > now {
            // Only the end state needs a new entry. Text(timerInterval:) renders
            // the seconds itself without one-second timeline reloads.
            entries.append(CountdownEntry(date: event.date, event: event, manual: current.manual))
        }
        return Timeline(entries: entries, policy: .after(now.addingTimeInterval(3600)))
    }

    private func load(_ configuration: CountdownConfiguration, at now: Date) -> CountdownEntry {
        if configuration.mode == .manual {
            let event = ManualWidgetEvent.make(title: configuration.manualTitle,
                                               date: configuration.targetDate,
                                               seconds: configuration.seconds, now: now)
            return CountdownEntry(date: now, event: event, manual: true)
        }
        do {
            let archive = try SharedStore.live().read()
            if let selected = configuration.event {
                let event = archive.events.first { $0.id.uuidString == selected.id }
                return CountdownEntry(date: now, event: event, deleted: event == nil)
            }
            return CountdownEntry(date: now, event: archive.pinnedEvent)
        } catch {
            return CountdownEntry(date: now, event: nil, unavailable: true)
        }
    }
}
