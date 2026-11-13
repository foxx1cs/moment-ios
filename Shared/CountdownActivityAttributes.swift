import ActivityKit
import Foundation

struct CountdownActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String
        var symbol: String
        var theme: String
        var startedAt: Date
        var targetDate: Date
    }

    var eventID: UUID
}
