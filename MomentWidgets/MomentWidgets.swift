import SwiftUI
import WidgetKit

@main
struct MomentWidgets: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: SharedStore.widgetKind,
                               intent: CountdownConfiguration.self,
                               provider: CountdownProvider()) { entry in
            CountdownWidgetView(entry: entry)
                .containerBackground(for: .widget) { Palette.background }
        }
        .configurationDisplayName("Тот самый момент")
        .description("Отсчёт до секунды. Название и дату можно задать прямо в настройках виджета, без синхронизации с приложением.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct CountdownWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CountdownEntry

    var body: some View {
        Group {
            if let event = entry.event {
                if family == .accessoryRectangular {
                    lockScreen(event)
                } else {
                    homeScreen(event)
                }
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    Label("Moment", systemImage: "sparkles").font(.headline)
                    Text(entry.unavailable
                         ? "События приложения требуют App Groups. Выберите «Вручную» и задайте название и дату в настройках виджета."
                         : entry.deleted ? "Событие удалено"
                         : entry.manual ? "Укажите дату и время"
                         : "Создайте событие")
                        .font(.caption)
                    if !entry.deleted && family != .accessoryRectangular {
                        Text("Зажмите → Изменить виджет").font(.caption2)
                    }
                    if entry.deleted && family != .accessoryRectangular {
                        Text("Выберите другое в настройках виджета").font(.caption2)
                    }
                }
                .widgetURL(URL(string: "moment://widgets"))
            }
        }
    }

    private func lockScreen(_ event: CountdownEvent) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(event.title, systemImage: event.symbol)
                .font(.system(size: 12, weight: .semibold)).lineLimit(1)
            timer(event, targetDate: entry.targetDate ?? event.date, size: 26)
            Text("ЧАСЫ : МИН : СЕК")
                .font(.system(size: 8, weight: .medium)).opacity(0.7)
        }
        .widgetURL(eventURL(event))
    }

    private func homeScreen(_ event: CountdownEvent) -> some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 9 : 12) {
            HStack {
                Image(systemName: event.symbol).foregroundStyle(event.theme.color)
                if family == .systemMedium {
                    Text("MOMENT").font(.system(size: 9, weight: .bold)).tracking(2)
                        .foregroundStyle(event.theme.color)
                }
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 10)).foregroundStyle(.gray)
            }
            Text(event.title).font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
            VStack(alignment: .leading, spacing: 4) {
                timer(event, targetDate: entry.targetDate ?? event.date,
                      size: family == .systemSmall ? 30 : 38)
                    .foregroundStyle(event.theme.color)
                Text("ЧАСЫ : МИНУТЫ : СЕКУНДЫ")
                    .font(.system(size: family == .systemSmall ? 7 : 8, weight: .medium))
                    .tracking(0.5).foregroundStyle(.gray)
            }
            if family == .systemMedium {
                Text((entry.targetDate ?? event.date).formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 10)).foregroundStyle(.gray)
            }
        }
        .widgetURL(eventURL(event))
    }

    @ViewBuilder
    private func timer(_ event: CountdownEvent, targetDate: Date, size: CGFloat) -> some View {
        if targetDate > entry.date {
            Text(timerInterval: entry.date...targetDate, countsDown: true, showsHours: true)
                .font(.system(size: size, weight: .light, design: .rounded))
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.35)
                .multilineTextAlignment(.leading)
        } else {
            Text("00:00:00")
                .font(.system(size: size, weight: .light, design: .rounded))
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.35)
                .accessibilityLabel("Момент настал")
        }
    }

    private func eventURL(_ event: CountdownEvent) -> URL? {
        if entry.manual { return URL(string: "moment://widgets") }
        return URL(string: "moment://event/\(event.id.uuidString)")
    }
}
