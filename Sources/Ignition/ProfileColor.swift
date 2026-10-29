import SwiftUI

/// The palette profiles can pick from. Unset profiles get one by their position.
enum ProfileColor: String, CaseIterable, Identifiable {
    case blue, purple, pink, orange, green, teal, red, yellow, gray
    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .orange: return .orange
        case .green: return .green
        case .teal: return .teal
        case .red: return .red
        case .yellow: return .yellow
        case .gray: return .gray
        }
    }
}
