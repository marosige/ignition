import SwiftUI
import AppKit

/// Icons a profile can wear instead of its name.
enum ProfileIcons {
    static let all: [(symbol: String, label: String)] = [
        ("square.stack.3d.up", "Base"), ("house", "Home"), ("briefcase", "Work"),
        ("laptopcomputer", "Laptop"), ("macmini", "Mac mini"), ("desktopcomputer", "Desktop"),
        ("graduationcap", "School"), ("person.2", "Family"), ("gamecontroller", "Gaming"),
        ("airplane", "Travel"), ("building", "Office"), ("terminal", "Dev"),
        ("paintbrush", "Creative"), ("book", "Study"), ("star", "Favourite"),
    ]
}

/// A calm palette that sits well on the app's grey glass: muted tones, a lighter
/// variant for dark mode, and Telekom magenta kept exactly #E20074.
enum ProfileColor: String, CaseIterable, Identifiable {
    case blue, violet, teal, amber, green, indigo, coral, slate, magenta
    var id: String { rawValue }

    var title: String { self == .magenta ? "Telekom magenta" : rawValue.capitalized }

    /// Colour names stored by earlier versions.
    static func stored(_ raw: String) -> ProfileColor? {
        if let color = ProfileColor(rawValue: raw) { return color }
        switch raw {
        case "purple": return .violet
        case "orange", "yellow": return .amber
        case "red", "pink": return .coral
        case "gray": return .slate
        default: return nil
        }
    }

    /// Text and outline colour; lighter in dark mode.
    var color: Color {
        switch self {
        case .blue: return Color(light: 0x2F6BDE, dark: 0x7FA6FF)
        case .violet: return Color(light: 0x8A4FD0, dark: 0xC09BFF)
        case .teal: return Color(light: 0x1F8A8A, dark: 0x62D2D2)
        case .amber: return Color(light: 0xB86E00, dark: 0xFFB84D)
        case .green: return Color(light: 0x2E8B57, dark: 0x6FD39A)
        case .indigo: return Color(light: 0x5B54D6, dark: 0x9C97FF)
        case .coral: return Color(light: 0xD1553A, dark: 0xFF9A80)
        case .slate: return Color(light: 0x5F6B7A, dark: 0xA7B1C0)
        case .magenta: return Color(light: 0xE20074, dark: 0xE20074)   // Telekom magenta
        }
    }

    /// Solid fill (for badges with a white glyph).
    var solid: Color {
        switch self {
        case .blue: return Color(hex: 0x2F6BDE)
        case .violet: return Color(hex: 0x8A4FD0)
        case .teal: return Color(hex: 0x1F8A8A)
        case .amber: return Color(hex: 0xC77700)
        case .green: return Color(hex: 0x2E8B57)
        case .indigo: return Color(hex: 0x5B54D6)
        case .coral: return Color(hex: 0xD1553A)
        case .slate: return Color(hex: 0x5F6B7A)
        case .magenta: return Color(hex: 0xE20074)
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }

    /// Adapts to light and dark appearance.
    init(light: UInt32, dark: UInt32) {
        func ns(_ hex: UInt32) -> NSColor {
            NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                    green: CGFloat((hex >> 8) & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        }
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? ns(dark) : ns(light)
        })
    }
}
