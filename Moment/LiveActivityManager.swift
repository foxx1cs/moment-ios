import ActivityKit
import Foundation
import SwiftUI

@MainActor
final class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()
    static let maximumDuration: TimeInterval = 8 * 60 * 60

    @Published private(set) var activeEventIDs: Set<UUID> = []

    private init() {
        refresh()
    }

    func isActive(for eventID: UUID) -> Bool {
        activeEventIDs.contains(eventID)
    }

    var activitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func canStart(event: CountdownEvent, at now: Date = .now) -> Bool {
        guard activitiesEnabled else { return false }
        let targetDate = event.nextOccurrence(after: now)
        let secondsRemaining = targetDate.timeIntervalSince(now)
        return secondsRemaining > 0 && secondsRemaining <= Self.maximumDuration
    }

    func start(event: CountdownEvent, at now: Date = .now) async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw LiveActivityError.disabled
        }
        let targetDate = event.nextOccurrence(after: now)
        let secondsRemaining = targetDate.timeIntervalSince(now)
        guard secondsRemaining > 0 && secondsRemaining <= Self.maximumDuration else {
            throw LiveActivityError.outsideWindow
        }

        for activity in Activity<CountdownActivityAttributes>.activities
        where activity.attributes.eventID == event.id {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        let attributes = CountdownActivityAttributes(eventID: event.id)
        let state = CountdownActivityAttributes.ContentState(
            event: event, targetDate: targetDate, startedAt: now
        )
        let content = ActivityContent(state: state, staleDate: targetDate)
        _ = try Activity.request(attributes: attributes, content: content, pushType: nil)
        refresh()
    }

    func stop(eventID: UUID) async {
        for activity in Activity<CountdownActivityAttributes>.activities
        where activity.attributes.eventID == eventID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        refresh()
    }

    func reconcile(events: [CountdownEvent]) async {
        let byID = Dictionary(events.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
        for activity in Activity<CountdownActivityAttributes>.activities
        where activity.activityState == .active || activity.activityState == .stale {
            guard let event = byID[activity.attributes.eventID],
                  canStart(event: event) else {
                await activity.end(nil, dismissalPolicy: .immediate)
                continue
            }
            let targetDate = event.nextOccurrence(after: .now)
            let state = CountdownActivityAttributes.ContentState(
                event: event, targetDate: targetDate, startedAt: Date.now
            )
            await activity.update(ActivityContent(state: state, staleDate: targetDate))
        }
        refresh()
    }

    private func refresh() {
        activeEventIDs = Set(Activity<CountdownActivityAttributes>.activities
            .filter { $0.activityState == .active || $0.activityState == .stale }
            .map { $0.attributes.eventID })
    }
}

private extension CountdownActivityAttributes.ContentState {
    init(event: CountdownEvent, targetDate: Date, startedAt: Date) {
        title = event.title
        symbol = event.symbol
        theme = event.theme.rawValue
        self.startedAt = startedAt
        self.targetDate = targetDate
    }
}

private enum LiveActivityError: LocalizedError {
    case disabled
    case outsideWindow

    var errorDescription: String? {
        switch self {
        case .disabled: return String(localized: "Разрешите Live Activities в настройках iPhone.")
        case .outsideWindow: return String(localized: "Live Activity можно запустить в пределах 8 часов до события.")
        }
    }
}
