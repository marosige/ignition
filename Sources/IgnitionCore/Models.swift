import Foundation

// MARK: - Preference values

public enum PrefValue: Codable, Equatable, Hashable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(Bool.self) { self = .bool(v); return }
        if let v = try? c.decode(Int.self) { self = .int(v); return }
        if let v = try? c.decode(Double.self) { self = .double(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported preference value")
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .bool(let v): try c.encode(v)
        case .int(let v): try c.encode(v)
        case .double(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        }
    }

    public var boolValue: Bool? {
        switch self {
        case .bool(let v): return v
        case .int(let v): return v != 0
        default: return nil
        }
    }
    public var intValue: Int? {
        switch self {
        case .int(let v): return v
        case .double(let v): return Int(v)
        case .bool(let v): return v ? 1 : 0
        default: return nil
        }
    }
    public var doubleValue: Double? {
        switch self {
        case .double(let v): return v
        case .int(let v): return Double(v)
        default: return nil
        }
    }
    public var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }
    public var description: String {
        switch self {
        case .bool(let v): return v ? "true" : "false"
        case .int(let v): return String(v)
        case .double(let v): return String(v)
        case .string(let v): return v
        }
    }
}

// MARK: - Dock

public struct DockItem: Codable, Equatable, Identifiable, Hashable {
    public enum Kind: String, Codable { case app, spacer, folder }
    public var id = UUID()
    public var kind: Kind
    public var path: String?

    enum CodingKeys: String, CodingKey { case kind, path }

    public init(kind: Kind, path: String? = nil) {
        self.kind = kind
        self.path = path
    }

    public var title: String {
        guard let path else { return "Spacer" }
        return ((path as NSString).lastPathComponent as NSString).deletingPathExtension
    }
}

public struct SidebarItem: Codable, Equatable, Identifiable, Hashable {
    public var id = UUID()
    public var name: String
    public var path: String

    enum CodingKeys: String, CodingKey { case name, path }

    public init(name: String, path: String) {
        self.name = name
        self.path = path
    }
}

public struct DirectorySpec: Codable, Equatable, Identifiable, Hashable {
    public var id = UUID()
    public var path: String
    public var comment: String?

    enum CodingKeys: String, CodingKey { case path, comment }

    public init(path: String, comment: String? = nil) {
        self.path = path
        self.comment = comment
    }
}

// MARK: - Packages

public struct PackageEntry: Codable, Equatable, Identifiable, Hashable {
    public var name: String
    public var comment: String?
    public var id: String { name }
    public init(name: String, comment: String? = nil) {
        self.name = name
        self.comment = comment
    }
}

public struct MasEntry: Codable, Equatable, Identifiable, Hashable {
    public var id: Int
    public var name: String
    public init(id: Int, name: String) {
        self.id = id
        self.name = name
    }
}

public struct Packages: Codable, Equatable {
    public var taps: [String] = []
    public var brews: [PackageEntry] = []
    public var casks: [PackageEntry] = []
    public var mas: [MasEntry] = []
    public var vscode: [PackageEntry] = []

    public init() {}

    enum CodingKeys: String, CodingKey { case taps, brews, casks, mas, vscode }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        taps = try c.decodeIfPresent([String].self, forKey: .taps) ?? []
        brews = try c.decodeIfPresent([PackageEntry].self, forKey: .brews) ?? []
        casks = try c.decodeIfPresent([PackageEntry].self, forKey: .casks) ?? []
        mas = try c.decodeIfPresent([MasEntry].self, forKey: .mas) ?? []
        vscode = try c.decodeIfPresent([PackageEntry].self, forKey: .vscode) ?? []
    }

    public var isEmpty: Bool {
        taps.isEmpty && brews.isEmpty && casks.isEmpty && mas.isEmpty && vscode.isEmpty
    }
}

public struct Startup: Codable, Equatable {
    public var apps: [String] = []
    public var closeFinderWindows: Bool = false
    public init() {}

    enum CodingKeys: String, CodingKey { case apps, closeFinderWindows }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        apps = try c.decodeIfPresent([String].self, forKey: .apps) ?? []
        closeFinderWindows = try c.decodeIfPresent(Bool.self, forKey: .closeFinderWindows) ?? false
    }
}

// MARK: - Profile

/// One layer of configuration (base, personal, work, ...). Lives in
/// `ignition/profiles/<name>/profile.json` in the config repo.
public struct Profile: Codable, Equatable {
    public var title: String = ""
    /// Preference id (see `PreferenceCatalog`) to the value I want.
    public var preferences: [String: PrefValue] = [:]
    /// `nil` means "this profile does not touch the Dock layout".
    public var dock: [DockItem]?
    public var finderSidebar: [SidebarItem]?
    public var directories: [DirectorySpec] = []
    public var packages = Packages()
    public var startup = Startup()
    /// Dotfiles (paths relative to $HOME) that must be copied instead of symlinked.
    public var copyFiles: [String] = []
    /// What I want for settings macOS does not let scripts change (see `ManualSettings`).
    public var manualNotes: [String: String] = [:]
    /// Name of the profile this one builds on (it is switched on together with it).
    public var extends: String?
    /// Colour name used for this profile's pills and icon (see ProfileColor in the app).
    public var color: String?
    /// SF Symbol shown instead of the profile name. Empty means the name is shown.
    public var icon: String?

    public init(title: String = "") { self.title = title }

    enum CodingKeys: String, CodingKey {
        case title, preferences, dock, finderSidebar, directories, packages, startup, copyFiles, manualNotes, extends, color, icon
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        preferences = try c.decodeIfPresent([String: PrefValue].self, forKey: .preferences) ?? [:]
        dock = try c.decodeIfPresent([DockItem].self, forKey: .dock)
        finderSidebar = try c.decodeIfPresent([SidebarItem].self, forKey: .finderSidebar)
        directories = try c.decodeIfPresent([DirectorySpec].self, forKey: .directories) ?? []
        packages = try c.decodeIfPresent(Packages.self, forKey: .packages) ?? Packages()
        startup = try c.decodeIfPresent(Startup.self, forKey: .startup) ?? Startup()
        copyFiles = try c.decodeIfPresent([String].self, forKey: .copyFiles) ?? []
        manualNotes = try c.decodeIfPresent([String: String].self, forKey: .manualNotes) ?? [:]
        extends = try c.decodeIfPresent(String.self, forKey: .extends)
        color = try c.decodeIfPresent(String.self, forKey: .color)
        icon = try c.decodeIfPresent(String.self, forKey: .icon)
    }

    /// Layers profiles in order; later ones win.
    public static func merged(_ layers: [Profile]) -> Profile {
        var result = Profile(title: layers.map(\.title).joined(separator: " + "))
        for layer in layers {
            result.preferences.merge(layer.preferences) { _, new in new }
            if let dock = layer.dock { result.dock = dock }
            if let sidebar = layer.finderSidebar { result.finderSidebar = sidebar }
            for d in layer.directories where !result.directories.contains(where: { $0.path == d.path }) {
                result.directories.append(d)
            }
            result.packages.taps = unique(result.packages.taps + layer.packages.taps)
            result.packages.brews = uniqueEntries(result.packages.brews + layer.packages.brews)
            result.packages.casks = uniqueEntries(result.packages.casks + layer.packages.casks)
            result.packages.vscode = uniqueEntries(result.packages.vscode + layer.packages.vscode)
            for m in layer.packages.mas where !result.packages.mas.contains(where: { $0.id == m.id }) {
                result.packages.mas.append(m)
            }
            result.startup.apps = unique(result.startup.apps + layer.startup.apps)
            result.startup.closeFinderWindows = result.startup.closeFinderWindows || layer.startup.closeFinderWindows
            result.copyFiles = unique(result.copyFiles + layer.copyFiles)
            result.manualNotes.merge(layer.manualNotes) { _, new in new }
        }
        return result
    }

    private static func unique(_ items: [String]) -> [String] {
        var seen = Set<String>()
        return items.filter { seen.insert($0).inserted }
    }

    private static func uniqueEntries(_ items: [PackageEntry]) -> [PackageEntry] {
        var seen = Set<String>()
        return items.filter { seen.insert($0.name).inserted }
    }
}

// MARK: - Device

/// Machine-local settings. Never committed to the config repo.
public struct DeviceConfig: Codable, Equatable {
    public var deviceName: String
    public var repository: String = ""
    /// Folder inside the repo that holds Ignition's data.
    public var configFolder: String = "ignition"
    /// Branch to sync. Empty means the repository's default branch.
    public var branch: String = ""
    /// Profile names layered in order. `base` should normally come first.
    public var activeProfiles: [String] = ["base"]
    public var editingProfile: String = "base"
    /// When the plan was last applied to this Mac (nil: never).
    public var lastApplied: Date?
    /// Fingerprint of the plan that was applied, to notice later edits.
    public var lastAppliedPlan: String?

    public init(deviceName: String) { self.deviceName = deviceName }

    enum CodingKeys: String, CodingKey {
        case deviceName, repository, configFolder, branch, activeProfiles, editingProfile, lastApplied, lastAppliedPlan
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        deviceName = try c.decodeIfPresent(String.self, forKey: .deviceName) ?? (Host.current().localizedName ?? "Mac")
        repository = try c.decodeIfPresent(String.self, forKey: .repository) ?? ""
        configFolder = try c.decodeIfPresent(String.self, forKey: .configFolder) ?? "ignition"
        branch = try c.decodeIfPresent(String.self, forKey: .branch) ?? ""
        activeProfiles = try c.decodeIfPresent([String].self, forKey: .activeProfiles) ?? ["base"]
        editingProfile = try c.decodeIfPresent(String.self, forKey: .editingProfile) ?? "base"
        lastApplied = try c.decodeIfPresent(Date.self, forKey: .lastApplied)
        lastAppliedPlan = try c.decodeIfPresent(String.self, forKey: .lastAppliedPlan)
    }
}
