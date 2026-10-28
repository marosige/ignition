import Foundation

/// Categories mirror the sections of System Settings, but only the ones
/// Ignition actually manages.
public enum PrefCategory: String, CaseIterable, Identifiable {
    case general, desktopDock, missionControl, finder, menuBar, dateTime, keyboard, trackpad
    case displays, accessibility, notifications, siri, privacy, screenshot, shell

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .general: return "General"
        case .desktopDock: return "Desktop & Dock"
        case .missionControl: return "Mission Control"
        case .finder: return "Finder"
        case .menuBar: return "Menu Bar"
        case .dateTime: return "Date & Time"
        case .keyboard: return "Keyboard"
        case .trackpad: return "Trackpad"
        case .displays: return "Displays"
        case .accessibility: return "Accessibility"
        case .notifications: return "Notifications"
        case .siri: return "Siri"
        case .privacy: return "Privacy & Security"
        case .screenshot: return "Screenshot"
        case .shell: return "Terminal & Shell"
        }
    }

    public var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .desktopDock: return "dock.rectangle"
        case .missionControl: return "rectangle.3.group"
        case .finder: return "face.smiling"
        case .menuBar: return "menubar.rectangle"
        case .dateTime: return "clock"
        case .keyboard: return "keyboard"
        case .trackpad: return "rectangle.and.hand.point.up.left"
        case .displays: return "display"
        case .accessibility: return "accessibility"
        case .notifications: return "bell.badge"
        case .siri: return "waveform"
        case .privacy: return "hand.raised"
        case .screenshot: return "camera.viewfinder"
        case .shell: return "terminal"
        }
    }
}

public enum PrefScope: Equatable {
    case user
    case currentHost
    /// Absolute-path domain that needs administrator rights to write.
    case system
}

public enum PrefControl: Equatable {
    case toggle
    case slider(ClosedRange<Double>, step: Double, unit: String)
    case picker([PrefOption])
    case text(placeholder: String)
}

public struct PrefOption: Equatable, Hashable {
    public let value: PrefValue
    public let label: String
    public init(_ value: PrefValue, _ label: String) {
        self.value = value
        self.label = label
    }
}

/// Settings that are not a plain `defaults` key.
public enum PrefCustom: String {
    case timezone, networkTime, showLibrary, inputSource, defaultShell
}

public enum ProcessToRestart: String { case dock = "Dock", finder = "Finder", systemUI = "SystemUIServer", controlCenter = "ControlCenter" }

public struct PreferenceDef: Identifiable {
    public let id: String
    public let category: PrefCategory
    public let section: String
    public let title: String
    public let detail: String?
    public let domain: String
    public let key: String
    public let control: PrefControl
    /// The value macOS ships with when the key is absent.
    public let osDefault: PrefValue?
    public let scope: PrefScope
    public let restart: [ProcessToRestart]
    public let custom: PrefCustom?
}

public enum PreferenceCatalog {
    public static let all: [PreferenceDef] = build()
    public static let byID: [String: PreferenceDef] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    public static func defs(in category: PrefCategory) -> [PreferenceDef] {
        all.filter { $0.category == category }
    }

    public struct Section: Identifiable {
        public let name: String
        public let defs: [PreferenceDef]
        public var id: String { name }
    }

    public static func sections(in category: PrefCategory) -> [Section] {
        var order: [String] = []
        var groups: [String: [PreferenceDef]] = [:]
        for d in defs(in: category) {
            if groups[d.section] == nil { order.append(d.section) }
            groups[d.section, default: []].append(d)
        }
        return order.map { Section(name: $0, defs: groups[$0] ?? []) }
    }

    // MARK: Definition

    private static func build() -> [PreferenceDef] {
        var out: [PreferenceDef] = []

        func add(
            _ id: String, _ cat: PrefCategory, _ section: String, _ title: String, _ detail: String? = nil,
            domain: String, key: String, _ control: PrefControl, default def: PrefValue?,
            scope: PrefScope = .user, restart: [ProcessToRestart] = [], custom: PrefCustom? = nil
        ) {
            out.append(PreferenceDef(
                id: id, category: cat, section: section, title: title, detail: detail,
                domain: domain, key: key, control: control, osDefault: def,
                scope: scope, restart: restart, custom: custom))
        }
        func toggle(
            _ id: String, _ cat: PrefCategory, _ section: String, _ title: String, _ detail: String? = nil,
            domain: String, key: String, default def: Bool, scope: PrefScope = .user,
            restart: [ProcessToRestart] = []
        ) {
            add(id, cat, section, title, detail, domain: domain, key: key, .toggle, default: .bool(def), scope: scope, restart: restart)
        }
        func slider(
            _ id: String, _ cat: PrefCategory, _ section: String, _ title: String, _ detail: String? = nil,
            domain: String, key: String, _ range: ClosedRange<Double>, step: Double = 1, unit: String = "",
            default def: PrefValue, scope: PrefScope = .user, restart: [ProcessToRestart] = []
        ) {
            add(id, cat, section, title, detail, domain: domain, key: key, .slider(range, step: step, unit: unit), default: def, scope: scope, restart: restart)
        }
        func picker(
            _ id: String, _ cat: PrefCategory, _ section: String, _ title: String, _ detail: String? = nil,
            domain: String, key: String, _ options: [PrefOption], default def: PrefValue?,
            scope: PrefScope = .user, restart: [ProcessToRestart] = []
        ) {
            add(id, cat, section, title, detail, domain: domain, key: key, .picker(options), default: def, scope: scope, restart: restart)
        }

        let global = "NSGlobalDomain"

        // MARK: Desktop & Dock
        let dock = "com.apple.dock"
        slider("dock.tilesize", .desktopDock, "Dock", "Size", domain: dock, key: "tilesize", 16...128, step: 4, unit: "px", default: .int(48), restart: [.dock])
        toggle("dock.magnification", .desktopDock, "Dock", "Magnification", domain: dock, key: "magnification", default: false, restart: [.dock])
        slider("dock.largesize", .desktopDock, "Dock", "Magnified size", domain: dock, key: "largesize", 16...128, step: 4, unit: "px", default: .int(128), restart: [.dock])
        picker("dock.orientation", .desktopDock, "Dock", "Position on screen", domain: dock, key: "orientation",
               [.init(.string("left"), "Left"), .init(.string("bottom"), "Bottom"), .init(.string("right"), "Right")],
               default: .string("bottom"), restart: [.dock])
        picker("dock.mineffect", .desktopDock, "Dock", "Minimize windows using", domain: dock, key: "mineffect",
               [.init(.string("genie"), "Genie effect"), .init(.string("scale"), "Scale effect"), .init(.string("suck"), "Suck effect")],
               default: .string("genie"), restart: [.dock])
        toggle("dock.autohide", .desktopDock, "Dock", "Automatically hide and show the Dock", domain: dock, key: "autohide", default: false, restart: [.dock])
        toggle("dock.show-recents", .desktopDock, "Dock", "Show suggested and recent apps in Dock", domain: dock, key: "show-recents", default: true, restart: [.dock])
        toggle("dock.static-only", .desktopDock, "Dock", "Only show open applications", "When on, pinned apps are hidden.", domain: dock, key: "static-only", default: false, restart: [.dock])
        toggle("dock.size-immutable", .desktopDock, "Dock", "Lock the Dock size", domain: dock, key: "size-immutable", default: false, restart: [.dock])
        toggle("dock.scroll-to-open", .desktopDock, "Dock", "Scroll up on an icon to show its windows", domain: dock, key: "scroll-to-open", default: false, restart: [.dock])
        toggle("desktop.click-to-show", .desktopDock, "Desktop & Stage Manager", "Click wallpaper to reveal desktop",
               "On: always. Off: only in Stage Manager.", domain: "com.apple.WindowManager", key: "EnableStandardClickToShowDesktop", default: true)
        toggle("desktop.icons", .desktopDock, "Desktop Items", "Show items on desktop", domain: "com.apple.finder", key: "CreateDesktop", default: true, restart: [.finder])
        toggle("desktop.harddisks", .desktopDock, "Desktop Items", "Hard disks", domain: "com.apple.finder", key: "ShowHardDrivesOnDesktop", default: false, restart: [.finder])
        toggle("desktop.external", .desktopDock, "Desktop Items", "External disks", domain: "com.apple.finder", key: "ShowExternalHardDrivesOnDesktop", default: false, restart: [.finder])
        toggle("desktop.removable", .desktopDock, "Desktop Items", "CDs, DVDs and iPods", domain: "com.apple.finder", key: "ShowRemovableMediaOnDesktop", default: false, restart: [.finder])
        toggle("desktop.servers", .desktopDock, "Desktop Items", "Connected servers", domain: "com.apple.finder", key: "ShowMountedServersOnDesktop", default: false, restart: [.finder])

        let corners: [(String, String)] = [("tl", "Top left"), ("tr", "Top right"), ("bl", "Bottom left"), ("br", "Bottom right")]
        let cornerActions: [PrefOption] = [
            .init(.int(0), "–"), .init(.int(2), "Mission Control"), .init(.int(3), "Application Windows"),
            .init(.int(4), "Desktop"), .init(.int(5), "Start Screen Saver"), .init(.int(6), "Disable Screen Saver"),
            .init(.int(10), "Put Display to Sleep"), .init(.int(11), "Launchpad"), .init(.int(12), "Notification Center"),
            .init(.int(13), "Lock Screen"), .init(.int(14), "Quick Note"),
        ]
        let modifiers: [PrefOption] = [
            .init(.int(0), "–"), .init(.int(131072), "⇧ Shift"), .init(.int(262144), "⌃ Control"),
            .init(.int(524288), "⌥ Option"), .init(.int(1048576), "⌘ Command"),
        ]
        for (code, name) in corners {
            picker("hotcorner.\(code)", .desktopDock, "Hot Corners", name, domain: dock, key: "wvous-\(code)-corner", cornerActions,
                   default: .int(code == "br" ? 14 : 0), restart: [.dock])
            picker("hotcorner.\(code).modifier", .desktopDock, "Hot Corners", "\(name) – modifier key", domain: dock, key: "wvous-\(code)-modifier", modifiers,
                   default: .int(0), restart: [.dock])
        }

        // MARK: Mission Control
        toggle("mc.mru-spaces", .missionControl, "Spaces", "Automatically rearrange Spaces based on most recent use", domain: dock, key: "mru-spaces", default: true, restart: [.dock])
        toggle("mc.switch-on-activate", .missionControl, "Spaces", "When switching to an application, switch to a Space with open windows", domain: global, key: "AppleSpacesSwitchOnActivate", default: true)
        toggle("mc.spans-displays", .missionControl, "Spaces", "Displays have separate Spaces", "Off means one Space spans all displays.", domain: "com.apple.spaces", key: "spans-displays", default: false, restart: [.dock])

        // MARK: Finder
        toggle("finder.extensions", .finder, "Files", "Show all filename extensions", domain: global, key: "AppleShowAllExtensions", default: false, restart: [.finder])
        toggle("finder.hidden", .finder, "Files", "Show hidden files", domain: "com.apple.finder", key: "AppleShowAllFiles", default: false, restart: [.finder])
        add("finder.library", .finder, "Files", "Show the ~/Library folder", domain: "", key: "", .toggle, default: .bool(false), custom: .showLibrary)
        toggle("finder.folders-first", .finder, "Files", "Keep folders on top when sorting by name", domain: "com.apple.finder", key: "_FXSortFoldersFirst", default: false, restart: [.finder])
        toggle("finder.ext-warning", .finder, "Files", "Show warning before changing an extension", domain: "com.apple.finder", key: "FXEnableExtensionChangeWarning", default: true)
        toggle("finder.trash-warning", .finder, "Files", "Show warning before emptying the Trash", domain: "com.apple.finder", key: "WarnOnEmptyTrash", default: true)
        picker("finder.view", .finder, "Windows", "Default view style", domain: "com.apple.finder", key: "FXPreferredViewStyle",
               [.init(.string("icnv"), "Icons"), .init(.string("Nlsv"), "List"), .init(.string("clmv"), "Columns"), .init(.string("glyv"), "Gallery")],
               default: .string("icnv"), restart: [.finder])
        toggle("finder.pathbar", .finder, "Windows", "Show path bar", domain: "com.apple.finder", key: "ShowPathbar", default: false, restart: [.finder])
        picker("finder.new-window", .finder, "Windows", "New Finder windows show", domain: "com.apple.finder", key: "NewWindowTarget",
               [.init(.string("PfAF"), "Recents"), .init(.string("PfHm"), "Home folder"), .init(.string("PfDe"), "Desktop"),
                .init(.string("PfDo"), "Documents"), .init(.string("PfCm"), "Computer")],
               default: .string("PfAF"), restart: [.finder])
        picker("finder.search-scope", .finder, "Windows", "When performing a search", domain: "com.apple.finder", key: "FXDefaultSearchScope",
               [.init(.string("SCev"), "Search This Mac"), .init(.string("SCcf"), "Search the Current Folder"), .init(.string("SCsp"), "Use the Previous Search Scope")],
               default: .string("SCev"))
        picker("finder.sidebar-icon-size", .finder, "Sidebar", "Sidebar icon size", domain: global, key: "NSTableViewDefaultSizeMode",
               [.init(.int(1), "Small"), .init(.int(2), "Medium"), .init(.int(3), "Large")], default: .int(2), restart: [.finder])
        toggle("finder.no-dsstore-network", .finder, "Advanced", "Avoid .DS_Store files on network volumes", domain: "com.apple.desktopservices", key: "DSDontWriteNetworkStores", default: false)
        toggle("finder.no-dsstore-usb", .finder, "Advanced", "Avoid .DS_Store files on USB volumes", domain: "com.apple.desktopservices", key: "DSDontWriteUSBStores", default: false)

        // MARK: Menu bar
        let cc = "com.apple.controlcenter"
        let menuOptions: [PrefOption] = [.init(.int(18), "Show in Menu Bar"), .init(.int(24), "Don't show in Menu Bar")]
        toggle("menubar.battery-percent", .menuBar, "Control Center", "Show battery percentage", domain: cc, key: "BatteryShowPercentage", default: false, restart: [.controlCenter])
        picker("menubar.bluetooth", .menuBar, "Control Center", "Bluetooth", domain: cc, key: "Bluetooth", menuOptions, default: nil, restart: [.controlCenter])
        picker("menubar.sound", .menuBar, "Control Center", "Sound", domain: cc, key: "Sound", menuOptions, default: nil, restart: [.controlCenter])
        toggle("menubar.text-input", .menuBar, "Menu Bar Only", "Show Input menu in menu bar", domain: "com.apple.TextInputMenu", key: "visible", default: false, restart: [.systemUI])
        toggle("menubar.airplay", .menuBar, "Menu Bar Only", "Show mirroring options in the menu bar when available", domain: "com.apple.airplay", key: "showInMenuBarIfPresent", default: true, restart: [.systemUI])

        // MARK: Date & Time
        add("datetime.timezone", .dateTime, "Time Zone", "Time zone", "e.g. Europe/Budapest – see `systemsetup -listtimezones`.",
            domain: "", key: "", .text(placeholder: "Europe/Budapest"), default: nil, custom: .timezone)
        add("datetime.network-time", .dateTime, "Time Zone", "Set time and date automatically", domain: "", key: "", .toggle, default: .bool(true), custom: .networkTime)
        toggle("datetime.auto-timezone", .dateTime, "Time Zone", "Set time zone automatically using your current location",
               domain: "/Library/Preferences/com.apple.timezone.auto.plist", key: "Active", default: true, scope: .system)
        toggle("clock.analog", .dateTime, "Clock", "Analog clock in menu bar", domain: "com.apple.menuextra.clock", key: "IsAnalog", default: false, restart: [.systemUI])
        toggle("clock.flash-separators", .dateTime, "Clock", "Flash the time separators", domain: "com.apple.menuextra.clock", key: "FlashDateSeparators", default: false, restart: [.systemUI])
        add("clock.format", .dateTime, "Clock", "Menu bar clock format",
            "h = 12h, HH = 24h, mm, ss, a = AM/PM, EEE = weekday, d = day, MMM = month.",
            domain: "com.apple.menuextra.clock", key: "DateFormat", .text(placeholder: "MMM d EEE HH:mm"), default: .string("EEE MMM d  h:mm a"), restart: [.systemUI])

        // MARK: Keyboard
        let keyboardUI: [PrefOption] = [.init(.int(0), "Text boxes and lists only"), .init(.int(1), "Text boxes and lists only (Ignition)"), .init(.int(3), "All controls")]
        picker("keyboard.full-access", .keyboard, "Keyboard Navigation", "Move focus with Tab between", domain: global, key: "AppleKeyboardUIMode", keyboardUI, default: .int(0))
        toggle("keyboard.fn-state", .keyboard, "Keyboard Navigation", "Use F1, F2, etc. keys as standard function keys", domain: global, key: "com.apple.keyboard.fnState", default: false)
        toggle("keyboard.press-and-hold", .keyboard, "Key Repeat", "Show accent menu when holding a key", "Off enables key repeat for held keys.", domain: global, key: "ApplePressAndHoldEnabled", default: true)
        slider("keyboard.key-repeat", .keyboard, "Key Repeat", "Key repeat interval", "Lower is faster. Minimum 1.", domain: global, key: "KeyRepeat", 1...120, unit: "", default: .int(6))
        slider("keyboard.initial-repeat", .keyboard, "Key Repeat", "Delay until repeat", "Lower is shorter.", domain: global, key: "InitialKeyRepeat", 10...120, unit: "", default: .int(25))
        toggle("keyboard.autocorrect", .keyboard, "Text Input", "Correct spelling automatically", domain: global, key: "NSAutomaticSpellingCorrectionEnabled", default: true)
        toggle("keyboard.spellcheck", .keyboard, "Text Input", "Check spelling while typing", domain: global, key: "NSAllowContinuousSpellChecking", default: true)
        toggle("keyboard.autocapitalize", .keyboard, "Text Input", "Capitalize words automatically", domain: global, key: "NSAutomaticCapitalizationEnabled", default: true)
        toggle("keyboard.period-substitution", .keyboard, "Text Input", "Add period with double-space", domain: global, key: "NSAutomaticPeriodSubstitutionEnabled", default: true)
        toggle("keyboard.smart-dashes", .keyboard, "Text Input", "Use smart dashes", domain: global, key: "NSAutomaticDashSubstitutionEnabled", default: true)
        toggle("keyboard.smart-quotes", .keyboard, "Text Input", "Use smart quotes", domain: global, key: "NSAutomaticQuoteSubstitutionEnabled", default: true)
        add("keyboard.input-source", .keyboard, "Input Sources", "Custom keyboard layout", "Name of a .keylayout in ~/Library/Keyboard Layouts (shipped via dotfiles). Replaces the default input sources.",
            domain: "", key: "", .text(placeholder: "en_hu"), default: nil, custom: .inputSource)
        toggle("keyboard.backlight-auto", .keyboard, "Keyboard Backlight", "Adjust keyboard brightness in low light",
               domain: "/Library/Preferences/com.apple.iokit.AmbientLightSensor", key: "Automatic Keyboard Enabled", default: true, scope: .system)
        slider("keyboard.backlight-dim", .keyboard, "Keyboard Backlight", "Turn off backlight after inactivity",
               domain: "/Library/Preferences/com.apple.iokit.AmbientLightSensor", key: "Keyboard Dim Time", 0...600, step: 30, unit: "s", default: .int(0), scope: .system)

        // MARK: Trackpad
        slider("trackpad.speed", .trackpad, "Point & Click", "Tracking speed", domain: global, key: "com.apple.trackpad.scaling", 0...5, step: 0.1, default: .double(1.0))
        let click: [PrefOption] = [.init(.int(0), "Light"), .init(.int(1), "Medium"), .init(.int(2), "Firm")]
        picker("trackpad.click", .trackpad, "Point & Click", "Click", domain: "com.apple.AppleMultitouchTrackpad", key: "FirstClickThreshold", click, default: .int(1))
        picker("trackpad.force-click", .trackpad, "Point & Click", "Force Click pressure", domain: "com.apple.AppleMultitouchTrackpad", key: "SecondClickThreshold", click, default: .int(1))
        toggle("trackpad.swipe-navigate", .trackpad, "More Gestures", "Swipe between pages with two fingers", domain: global, key: "AppleEnableSwipeNavigateWithScrolls", default: true)

        // MARK: Displays
        toggle("displays.auto-brightness", .displays, "Brightness", "Automatically adjust brightness", domain: "com.apple.BezelServices", key: "dAuto", default: true)
        toggle("displays.auto-brightness-system", .displays, "Brightness", "Ambient light sensor: automatic display",
               domain: "/Library/Preferences/com.apple.iokit.AmbientLightSensor", key: "Automatic Display Enabled", default: true, scope: .system)
        picker("displays.font-smoothing", .displays, "Rendering", "Font smoothing on non-Apple displays", domain: global, key: "AppleFontSmoothing",
               [.init(.int(0), "Disabled"), .init(.int(1), "Minimal"), .init(.int(2), "Medium"), .init(.int(3), "Smoother"), .init(.int(4), "Strong")], default: nil)
        toggle("displays.hidpi", .displays, "Rendering", "Enable HiDPI display modes", "Requires a restart.",
               domain: "/Library/Preferences/com.apple.windowserver", key: "DisplayResolutionEnabled", default: false, scope: .system)

        // MARK: Accessibility
        toggle("a11y.shake-to-locate", .accessibility, "Pointer", "Disable shake mouse pointer to locate", domain: global, key: "CGDisableCursorLocationMagnification", default: false)
        let ua = "com.apple.universalaccess"
        toggle("a11y.zoom-temporary", .accessibility, "Zoom", "Hold ⌃⌥ to zoom temporarily", "Stored as 'press on release off'.", domain: ua, key: "closeViewPressOnReleaseOff", default: false)
        toggle("a11y.zoom-scroll", .accessibility, "Zoom", "Use scroll gesture with modifier key to zoom", domain: ua, key: "closeViewScrollWheelToggle", default: false)
        picker("a11y.zoom-modifier", .accessibility, "Zoom", "Modifier key for scroll zoom", domain: ua, key: "HIDScrollZoomModifierMask",
               [.init(.int(131072), "⇧ Shift"), .init(.int(262144), "⌃ Control"), .init(.int(524288), "⌥ Option"), .init(.int(1048576), "⌘ Command")], default: .int(262144))
        toggle("a11y.zoom-smooth", .accessibility, "Zoom", "Smooth images when zoomed", domain: ua, key: "closeViewSmoothImages", default: true)
        toggle("a11y.zoom-follow-focus", .accessibility, "Zoom", "Follow the keyboard focus while zoomed", domain: ua, key: "closeViewZoomFollowsFocus", default: false)
        picker("a11y.zoom-style", .accessibility, "Zoom", "Zoom style", domain: ua, key: "closeViewZoomMode",
               [.init(.int(0), "Fullscreen"), .init(.int(1), "Picture-in-picture")], default: .int(0))

        // MARK: Notifications
        slider("notifications.banner-time", .notifications, "Banners", "Banner display time", domain: "com.apple.notificationcenterui", key: "bannerTime", 1...10, unit: "s", default: .int(5))

        // MARK: Siri
        toggle("siri.enabled", .siri, "Siri", "Ask Siri", domain: "com.apple.assistant.support", key: "Assistant Enabled", default: true)
        add("siri.language", .siri, "Siri", "Language", domain: "com.apple.assistant.backedup", key: "Session Language", .text(placeholder: "en-US"), default: nil)
        picker("siri.voice-feedback", .siri, "Siri", "Voice feedback", domain: "com.apple.assistant.backedup", key: "Use device speaker for TTS",
               [.init(.int(2), "On"), .init(.int(3), "Off")], default: nil)
        picker("siri.shortcut", .siri, "Siri", "Keyboard shortcut", domain: "com.apple.Siri", key: "HotkeyTag",
               [.init(.int(0), "Off"), .init(.int(2), "Hold ⌘ Space"), .init(.int(3), "Hold ⌥ Space"), .init(.int(4), "Press 🌐 (Fn)"), .init(.int(7), "Customize")], default: nil)
        toggle("siri.menubar", .siri, "Siri", "Show Siri in menu bar", domain: "com.apple.Siri", key: "StatusMenuVisible", default: true, restart: [.systemUI])

        // MARK: Privacy & Security
        toggle("privacy.screensaver-password", .privacy, "Lock Screen", "Require password after sleep or screen saver", domain: "com.apple.screensaver", key: "askForPassword", default: false)
        picker("privacy.password-delay", .privacy, "Lock Screen", "Require password", domain: "com.apple.screensaver", key: "askForPasswordDelay",
               [.init(.int(0), "Immediately"), .init(.int(5), "After 5 seconds"), .init(.int(60), "After 1 minute"), .init(.int(300), "After 5 minutes")], default: .int(0))
        toggle("privacy.quarantine", .privacy, "Security", "Ask “Are you sure you want to open this application?”", domain: "com.apple.LaunchServices", key: "LSQuarantine", default: true)
        picker("privacy.firewall", .privacy, "Firewall", "Firewall", domain: "/Library/Preferences/com.apple.alf", key: "globalstate",
               [.init(.int(0), "Off"), .init(.int(1), "On"), .init(.int(2), "Block all incoming connections")], default: .int(0), scope: .system)
        toggle("privacy.firewall-signed", .privacy, "Firewall", "Automatically allow signed software", domain: "/Library/Preferences/com.apple.alf", key: "allowsignedenabled", default: true, scope: .system)

        // MARK: Screenshot
        toggle("screenshot.thumbnail", .screenshot, "Screenshots", "Show floating thumbnail", domain: "com.apple.screencapture", key: "show-thumbnail", default: true)
        picker("screenshot.format", .screenshot, "Screenshots", "Format", domain: "com.apple.screencapture", key: "type",
               [.init(.string("png"), "PNG"), .init(.string("jpg"), "JPEG"), .init(.string("pdf"), "PDF"), .init(.string("tiff"), "TIFF"), .init(.string("gif"), "GIF"), .init(.string("bmp"), "BMP")],
               default: .string("png"))

        // MARK: Shell
        add("shell.default", .shell, "Shell", "Default login shell", "Name of an installed shell, e.g. fish, zsh.", domain: "", key: "", .text(placeholder: "fish"), default: .string("zsh"), custom: .defaultShell)

        return out
    }
}
