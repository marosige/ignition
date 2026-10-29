import SwiftUI

/// Icons a profile can wear instead of its name.
enum ProfileIcons {
    static let all: [(symbol: String, label: String)] = [
        ("square.stack.3d.up", "Base"), ("house", "Home"), ("briefcase", "Work"),
        ("laptopcomputer", "Laptop"), ("macmini", "Mac mini"), ("desktopcomputer", "Desktop"),
        ("graduationcap", "School"), ("person.2", "Family"), ("gamecontroller", "Gaming"),
        ("airplane", "Travel"), ("building", "Office building"), ("building.2", "Offices"), ("terminal", "Dev"),
        ("paintbrush", "Creative"), ("book", "Study"), ("star", "Favourite"),
    ]
}

/// The palette profiles can pick from. Unset profiles get one by their position.
enum ProfileColor: String, CaseIterable, Identifiable {
    case blue, purple, pink, orange, green, teal, red, yellow, gray, magenta
    var id: String { rawValue }

    var title: String { self == .magenta ? "Telekom magenta" : rawValue.capitalized }

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
        case .magenta: return Color(red: 226 / 255, green: 0, blue: 116 / 255)   // Telekom magenta #E20074
        }
    }
}
