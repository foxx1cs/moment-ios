import ActivityKit
import SwiftUI
import WidgetKit

@main
struct MomentWidgetBundle: WidgetBundle {
    var body: some Widget {
        MomentWidgets()
        CountdownLiveActivity()
    }
}

struct CountdownLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CountdownActivityAttributes.self) { context in
            lockScreenView(context)
                .activityBackgroundTint(Palette.background)
                .activitySystemActionForegroundColor(.white)
                .widgetURL(eventURL(context.attributes.eventID))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.symbol)
                        .font(.title2)
                        .foregroundStyle(accent(context.state.theme))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(context.state, size: 18)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.title)
                        .font(.headline)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: context.state.symbol)
                    .foregroundStyle(accent(context.state.theme))
            } compactTrailing: {
                countdown(context.state, size: 12)
                    .frame(maxWidth: 48)
            } minimal: {
                Image(systemName: context.state.symbol)
                    .foregroundStyle(accent(context.state.theme))
            }
            .keylineTint(accent(context.state.theme))
            .widgetURL(eventURL(context.attributes.eventID))
        }
    }

    private func lockScreenView(
        _ context: ActivityViewContext<CountdownActivityAttributes>
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: context.state.symbol)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(accent(context.state.theme))
                .frame(width: 48, height: 48)
                .background(accent(context.state.theme).opacity(0.14), in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 7) {
                Text(context.state.title)
                    .font(.headline)
                    .lineLimit(1)
                countdown(context.state, size: 28)
                    .foregroundStyle(accent(context.state.theme))
            }
            Spacer(minLength: 0)
        }
        .padding(16)
    }

    private func countdown(
        _ state: CountdownActivityAttributes.ContentState,
        size: CGFloat
    ) -> some View {
        Text(timerInterval: state.startedAt...state.targetDate, countsDown: true, showsHours: true)
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .accessibilityLabel("Осталось времени")
    }

    private func accent(_ name: String) -> Color {
        EventTheme(rawValue: name)?.color ?? Palette.aqua
    }

    private func eventURL(_ id: UUID) -> URL? {
        URL(string: "moment://event/\(id.uuidString)")
    }
}
