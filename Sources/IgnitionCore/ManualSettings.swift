import Foundation

/// Settings macOS does not let scripts change. Ignition links to the right pane
/// and keeps a note of how they should be set.
public struct ManualSetting: Identifiable {
    public let id: String
    public let category: PrefCategory
    public let title: String
    public let detail: String
    public let settingsURL: String
    public let placeholder: String
}

public enum ManualSettings {
    public static let all: [ManualSetting] = [
        ManualSetting(
            id: "menubar.allowed-apps",
            category: .menuBar,
            title: "Menu bar apps: allowed and hidden",
            detail: "macOS 26 keeps the “Allow in the Menu Bar” list out of reach of scripts. Set it in System Settings, and write down here what you like, so the next Mac is a two-minute job.",
            settingsURL: "x-apple.systempreferences:com.apple.ControlCenter-Settings.extension",
            placeholder: "Hidden: MonitorControl, Amphetamine\nAllowed: Magnet, Logi Options+")
    ]

    public static func items(in category: PrefCategory) -> [ManualSetting] {
        all.filter { $0.category == category }
    }
}
