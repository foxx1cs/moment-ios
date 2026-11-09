import SwiftUI

extension EventTheme {
    var color: Color {
        switch self {
        case .aqua: return Color(red: 0.36, green: 0.89, blue: 0.82)
        case .violet: return Color(red: 0.74, green: 0.65, blue: 1)
        case .peach: return Color(red: 1, green: 0.75, blue: 0.55)
        case .blue: return Color(red: 0.50, green: 0.76, blue: 1)
        case .rose: return Color(red: 1, green: 0.61, blue: 0.73)
        }
    }
}

enum Palette {
    static let background = Color(red: 0.055, green: 0.075, blue: 0.09)
    static let surface = Color(red: 0.10, green: 0.125, blue: 0.14)
    static let ink = Color(red: 0.055, green: 0.16, blue: 0.16)
    static let muted = Color(red: 0.57, green: 0.64, blue: 0.65)
    static let aqua = EventTheme.aqua.color
}
