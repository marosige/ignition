import SwiftUI
import IgnitionCore

@MainActor
final class AppState: ObservableObject {
    @Published var device: DeviceConfig
    @Published var profiles: [String: Profile] = [:]
    @Published var profileNames: [String] = []
    @Published var live: [String: PrefValue] = [:]
    @Published var token: String
    @Published var changedFiles: [String] = []
    @Published var commits: [String] = []
    @Published var busy = false
    @Published var status: String?
    @Published var errorMessage: String?
    @Published var log: [String] = []
    @Published var connected = false

    init() {
        let device = ConfigStore.loadDevice()
        self.device = device
        self.token = Keychain.load(account: "github-token") ?? ""
        self.connected = FileManager.default.fileExists(atPath: AppPaths.repo.appendingPathComponent(".git").path)
        reloadProfiles()
        refreshLive()
    }

    // MARK: Profiles

    var activeProfiles: [Profile] { device.activeProfiles.compactMap { profiles[$0] } }
    var effective: Profile { Profile.merged(activeProfiles) }
    var editing: Profile {
        get { profiles[device.editingProfile] ?? Profile(title: device.editingProfile) }
        set { profiles[device.editingProfile] = newValue; persist(device.editingProfile) }
    }

    func reloadProfiles() {
        profileNames = ConfigStore.profileNames()
        profiles = [:]
        for name in profileNames { profiles[name] = ConfigStore.loadProfile(name) }
        device.activeProfiles = device.activeProfiles.filter { profileNames.contains($0) }
        if device.activeProfiles.isEmpty, profileNames.contains("base") { device.activeProfiles = ["base"] }
        if !profileNames.contains(device.editingProfile) {
            device.editingProfile = device.activeProfiles.last ?? profileNames.first ?? "base"
        }
        saveDevice()
        refreshChanges()
    }

    func persist(_ name: String) {
        guard let profile = profiles[name] else { return }
        do { try ConfigStore.saveProfile(profile, name: name) }
        catch { errorMessage = error.localizedDescription }
        refreshChanges()
    }

    func createProfile(_ name: String) {
        let slug = name.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "-" }
        guard !slug.isEmpty, profiles[slug] == nil else { return }
        profiles[slug] = Profile(title: name)
        persist(slug)
        profileNames = ConfigStore.profileNames()
    }

    func toggleActive(_ name: String) {
        if let idx = device.activeProfiles.firstIndex(of: name) {
            if name != "base" { device.activeProfiles.remove(at: idx) }
        } else {
            device.activeProfiles.append(name)
        }
        saveDevice()
        refreshLive()
    }

    func saveDevice() {
        ConfigStore.saveDevice(device)
    }

    // MARK: Preferences

    func refreshLive() {
        var values: [String: PrefValue] = [:]
        for def in PreferenceCatalog.all {
            if let v = DefaultsService.read(def) { values[def.id] = v }
        }
        live = values
    }

    /// What the control should show: profile value, else the Mac's current value, else macOS's default.
    func value(for def: PreferenceDef) -> PrefValue? {
        effective.preferences[def.id] ?? live[def.id] ?? def.osDefault
    }

    func isManaged(_ def: PreferenceDef) -> Bool {
        effective.preferences[def.id] != nil
    }

    func set(_ def: PreferenceDef, to value: PrefValue) {
        let r = DefaultsService.write(def, value)
        if !r.ok { errorMessage = "\(def.title): \(r.combined)"; return }
        DefaultsService.restart(Set(def.restart))
        live[def.id] = value
        var p = editing
        p.preferences[def.id] = value
        editing = p
    }

    /// Drops the setting from the profile and puts the Mac back to its macOS default.
    func reset(_ def: PreferenceDef) {
        var p = editing
        p.preferences[def.id] = nil
        editing = p
        if let inherited = effective.preferences[def.id] {
            _ = DefaultsService.write(def, inherited)
            live[def.id] = inherited
        } else {
            _ = DefaultsService.reset(def)
            DefaultsService.restart(Set(def.restart))
            live[def.id] = DefaultsService.read(def)
        }
    }

    // MARK: Sync

    var sync: GitSync? {
        guard !device.repository.isEmpty, !token.isEmpty else { return nil }
        return GitSync(repository: device.repository, token: token, deviceName: device.deviceName)
    }

    func saveCredentials() {
        Keychain.save(token, account: "github-token")
        saveDevice()
    }

    func refreshChanges() {
        guard FileManager.default.fileExists(atPath: AppPaths.repo.appendingPathComponent(".git").path),
              let sync else { changedFiles = []; return }
        changedFiles = sync.changedFiles()
        commits = sync.log()
    }

    func connect() async {
        saveCredentials()
        guard let sync else { errorMessage = "Enter the repository and the access token first."; return }
        await work("Connecting…") {
            let r = sync.connect()
            guard r.ok else { return r.combined }
            let pull = sync.pull()
            return pull.ok ? nil : pull.combined
        }
        connected = FileManager.default.fileExists(atPath: AppPaths.repo.appendingPathComponent(".git").path)
        reloadProfiles()
    }

    func pull() async {
        guard let sync else { return }
        await work("Pulling latest configuration…") {
            let r = sync.pull()
            return r.ok ? nil : r.combined
        }
        reloadProfiles()
        refreshLive()
    }

    func push() async {
        guard let sync else { return }
        await work("Saving to GitHub…") {
            let r = sync.commitAndPush()
            return r.ok ? nil : r.combined
        }
        refreshChanges()
    }

    func loadStarterConfig() {
        do {
            try ConfigStore.installSeed()
            reloadProfiles()
        } catch { errorMessage = error.localizedDescription }
    }

    var hasConfig: Bool { !profileNames.isEmpty }

    /// Runs blocking work off the main actor and reports errors.
    func work(_ message: String, _ body: @escaping @Sendable () -> String?) async {
        busy = true
        status = message
        let error = await Task.detached(priority: .userInitiated) { body() }.value
        busy = false
        status = nil
        if let error, !error.isEmpty { errorMessage = error }
    }

    // MARK: Logging

    func append(_ line: String) { log.append(line) }
}
