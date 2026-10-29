import SwiftUI
import AppKit
import IgnitionCore

/// Native-looking password dialog; works from any thread.
func promptForPassword(retry: Bool) -> String? {
    let ask: () -> String? = {
        let alert = NSAlert()
        alert.messageText = retry ? "That password was not accepted" : "Ignition needs your password"
        alert.informativeText = "It is needed to change system-wide settings. Ignition asks once and keeps it in memory only until you quit the app."
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        alert.accessoryView = field
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        return alert.runModal() == .alertFirstButtonReturn ? field.stringValue : nil
    }
    return Thread.isMainThread ? ask() : DispatchQueue.main.sync(execute: ask)
}

/// One profile that sets a preference.
struct PrefOrigin: Identifiable {
    let profile: String
    let value: PrefValue
    /// Differs from what is committed in the repo.
    let unsaved: Bool
    /// The profile is switched on for this Mac.
    let active: Bool
    var id: String { profile }
}

@MainActor
final class AppState: ObservableObject {
    /// One instance for the whole app: SwiftUI may rebuild the App value several times,
    /// and every extra AppState would read the keychain again.
    static let shared = AppState()

    @Published var destination: Destination? = .overview
    /// Detail pages pushed inside a section (e.g. a Homebrew package).
    @Published var path: [BrewPackage] = []
    @Published var showConnection = false
    /// A setting to scroll to and flash after navigating from Apply or a diff.
    @Published var focusPref: String?
    @Published var checking = false
    private var history: [Destination] = [.overview]
    private var historyIndex = 0
    @Published var device: DeviceConfig
    @Published var profiles: [String: Profile] = [:]
    @Published var committed: [String: Profile] = [:]
    @Published var profileNames: [String] = []
    @Published var live: [String: PrefValue] = [:]
    @Published var token: String
    @Published var changedFiles: [String] = []
    @Published var commits: [String] = []
    @Published var syncInfo: SyncInfo?
    @Published var showConflicts = false
    @Published var showDiff = false
    @Published var busy = false
    @Published var status: String?
    @Published var errorMessage: String?
    @Published var log: [String] = []
    @Published var connected = false

    private var pendingRestart = Set<ProcessToRestart>()
    private var restartTask: Task<Void, Never>?

    init() {
        Privileged.passwordProvider = promptForPassword
        let device = ConfigStore.loadDevice()
        self.device = device
        self.token = Keychain.load(account: "github-token") ?? ""
        self.connected = FileManager.default.fileExists(atPath: AppPaths.repo.appendingPathComponent(".git").path)
        reloadProfiles()
        refreshLive()
    }

    // MARK: Navigation

    var canGoBack: Bool { !path.isEmpty || historyIndex > 0 }
    var canGoForward: Bool { historyIndex < history.count - 1 }

    func navigate(to new: Destination?) {
        guard let new, new != destination else { return }
        history = Array(history.prefix(historyIndex + 1)) + [new]
        historyIndex = history.count - 1
        path = []
        destination = new
    }

    func goBack() {
        if !path.isEmpty { path.removeLast(); return }
        guard historyIndex > 0 else { return }
        historyIndex -= 1
        destination = history[historyIndex]
    }

    func goForward() {
        guard canGoForward else { return }
        historyIndex += 1
        path = []
        destination = history[historyIndex]
    }

    // MARK: Profiles

    /// The picked profiles plus everything they build on, parents first.
    func resolve(_ names: [String]) -> [String] {
        var out: [String] = []
        var seen = Set<String>()
        func visit(_ name: String) {
            guard let profile = profiles[name], seen.insert(name).inserted else { return }
            if let parent = profile.extends { visit(parent) }
            out.append(name)
        }
        names.forEach(visit)
        return out
    }

    /// What is switched on for this Mac, in layering order.
    var layers: [String] { resolve(device.activeProfiles) }
    /// Same, plus the profile being edited (which may not be on this Mac).
    var viewLayers: [String] { resolve(device.activeProfiles + [device.editingProfile]) }
    var editingIsActive: Bool { layers.contains(device.editingProfile) }
    var activeProfiles: [Profile] { layers.compactMap { profiles[$0] } }
    /// The colour of a profile: its own choice, else one picked by position.
    func profileColor(of name: String) -> ProfileColor {
        if let raw = profiles[name]?.color, let chosen = ProfileColor.stored(raw) { return chosen }
        let index = profileNames.firstIndex(of: name) ?? 0
        return ProfileColor.allCases[index % ProfileColor.allCases.count]
    }

    func color(of name: String) -> Color { profileColor(of: name).color }

    /// SF Symbol of a profile, or nil when its name should be shown.
    func icon(of name: String) -> String? {
        guard let icon = profiles[name]?.icon, !icon.isEmpty else { return nil }
        return icon
    }

    func setIcon(_ symbol: String?, of name: String) {
        guard var p = profiles[name] else { return }
        p.icon = symbol
        profiles[name] = p
        persist(name)
    }

    func setColor(_ color: ProfileColor, of name: String) {
        guard var p = profiles[name] else { return }
        p.color = color.rawValue
        profiles[name] = p
        persist(name)
    }

    /// What gets applied to this Mac.
    var effective: Profile { Profile.merged(activeProfiles) }
    /// What the settings pages show (includes a profile that is only being edited).
    var viewEffective: Profile { Profile.merged(viewLayers.compactMap { profiles[$0] }) }

    /// Active profiles that need this one (so it cannot be switched off).
    func requiredBy(_ name: String) -> [String] {
        layers.filter { $0 != name && resolve([$0]).contains(name) }
    }

    func setParent(_ parent: String?, of name: String) {
        guard var p = profiles[name] else { return }
        p.extends = parent
        profiles[name] = p
        persist(name)
    }
    var editing: Profile {
        get { profiles[device.editingProfile] ?? Profile(title: device.editingProfile) }
        set { profiles[device.editingProfile] = newValue; persist(device.editingProfile) }
    }

    func reloadProfiles() {
        profileNames = ConfigStore.profileNames()
        profiles = [:]
        for name in profileNames { profiles[name] = ConfigStore.loadProfile(name) }
        device.activeProfiles = device.activeProfiles.filter { profileNames.contains($0) }
        if device.activeProfiles.isEmpty {
            device.activeProfiles = [profileNames.contains("base") ? "base" : (profileNames.first ?? "base")]
        }
        if !profileNames.contains(device.editingProfile) {
            device.editingProfile = layers.last ?? profileNames.first ?? "base"
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

    @discardableResult
    func createProfile(_ name: String, extends parent: String? = nil, color: ProfileColor? = nil, icon: String? = nil) -> Bool {
        let slug = name.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "-" }
        guard !slug.isEmpty, profiles[slug] == nil else { return false }
        var profile = Profile(title: name)
        profile.extends = parent
        profile.color = color?.rawValue
        profile.icon = icon
        profiles[slug] = profile
        persist(slug)
        profileNames = ConfigStore.profileNames()
        return true
    }

    func deleteProfile(_ name: String) {
        guard name != "base" else { return }
        for other in profileNames where profiles[other]?.extends == name { setParent(nil, of: other) }
        do { try ConfigStore.deleteProfile(name) } catch { errorMessage = error.localizedDescription }
        device.activeProfiles.removeAll { $0 == name }
        reloadProfiles()
    }

    func toggleActive(_ name: String) {
        if let idx = device.activeProfiles.firstIndex(of: name) {
            device.activeProfiles.remove(at: idx)
        } else {
            device.activeProfiles.append(name)
        }
        saveDevice()
        refreshLive()
    }

    func saveDevice() {
        device.configFolder = AppPaths.normalizeFolder(device.configFolder)
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

    /// What a row's control shows: the plan, or the macOS default while no profile says anything.
    func value(for def: PreferenceDef) -> PrefValue? {
        controlOrigin(for: def)?.value ?? def.osDefault ?? live[def.id]
    }

    /// The value a setting starts with when you add it to a profile: what this Mac has now,
    /// else the macOS default.
    func initialValue(_ def: PreferenceDef) -> PrefValue {
        if let v = live[def.id] { return v }
        if let v = def.osDefault { return v }
        switch def.control {
        case .toggle: return .bool(false)
        case .picker(let options): return options.first?.value ?? .int(0)
        case .slider(let range, _, _): return .int(Int(range.lowerBound))
        case .text: return .string("")
        }
    }

    /// What this Mac has right now.
    func liveValue(_ def: PreferenceDef) -> PrefValue? { live[def.id] ?? def.osDefault }

    struct PendingChange: Identifiable {
        let def: PreferenceDef
        let from: PrefValue?
        let to: PrefValue
        var id: String { def.id }
    }

    /// Settings where this Mac differs from what the switched-on profiles plan.
    var pending: [PendingChange] {
        effective.preferences.compactMap { id, value in
            guard let def = PreferenceCatalog.byID[id], liveValue(def) != value else { return nil }
            return PendingChange(def: def, from: liveValue(def), to: value)
        }
        .sorted { ($0.def.category.title, $0.def.title) < ($1.def.category.title, $1.def.title) }
    }

    /// Stable fingerprint of everything the switched-on profiles plan for this Mac.
    var planFingerprint: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = (try? encoder.encode(effective)) ?? Data()
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in data { hash ^= UInt64(byte); hash = hash &* 1_099_511_628_211 }
        return String(hash, radix: 16)
    }

    /// The plan was edited (or never applied) since the last Apply.
    var needsApply: Bool {
        device.lastApplied == nil || device.lastAppliedPlan != planFingerprint || !pending.isEmpty
    }

    func markApplied() {
        device.lastApplied = Date()
        device.lastAppliedPlan = planFingerprint
        saveDevice()
    }

    func isManaged(_ def: PreferenceDef) -> Bool { isPlanned(def) }

    /// Profiles in layering order, then the ones that are not on this Mac.
    var allProfilesOrdered: [String] { layers + profileNames.filter { !layers.contains($0) } }

    /// Every profile that sets this preference: the ones on this Mac first (last one wins here).
    func origins(for def: PreferenceDef) -> [PrefOrigin] {
        allProfilesOrdered.compactMap { name in
            guard let value = profiles[name]?.preferences[def.id] else { return nil }
            let unsaved = connected && committed[name]?.preferences[def.id] != value
            return PrefOrigin(profile: name, value: value, unsaved: unsaved, active: layers.contains(name))
        }
    }

    func isPlanned(_ def: PreferenceDef) -> Bool { !origins(for: def).isEmpty }

    /// The entry a row's main control edits: the winner on this Mac, else the last profile that has it.
    func controlOrigin(for def: PreferenceDef) -> PrefOrigin? {
        let all = origins(for: def)
        return all.last(where: \.active) ?? all.last
    }

    /// Profiles a setting can still be added to (those inheriting it already have it).
    func profilesToAdd(_ def: PreferenceDef) -> [String] {
        let have = origins(for: def).map(\.profile)
        return profileNames.filter { name in
            !have.contains(name) && !resolve([name]).contains(where: have.contains)
        }
    }

    func savedCount(in category: PrefCategory) -> Int {
        PreferenceCatalog.defs(in: category).filter { isManaged($0) }.count
    }

    /// Human readable value ("Genie effect", "32 px", "On").
    func formatted(_ def: PreferenceDef, _ value: PrefValue?) -> String {
        guard let value else { return "not set" }
        switch def.control {
        case .toggle: return value.boolValue == true ? "On" : "Off"
        case .picker(let options): return options.first { $0.value == value }?.label ?? value.description
        case .slider(_, _, let unit):
            if let d = value.doubleValue, case .double? = def.osDefault { return String(format: "%.1f", d) + unit }
            return "\(value.intValue ?? 0)" + (unit.isEmpty ? "" : " " + unit)
        case .text: return value.stringValue?.isEmpty == false ? value.stringValue! : "–"
        }
    }

    func defaultText(_ def: PreferenceDef) -> String {
        def.osDefault == nil ? "decided by macOS" : formatted(def, def.osDefault)
    }

    /// Plans a value in a profile. The Mac only changes when you Apply.
    func set(_ def: PreferenceDef, to value: PrefValue, in profileName: String) {
        guard var profile = profiles[profileName] else { return }
        profile.preferences[def.id] = value
        profiles[profileName] = profile
        persist(profileName)
    }

    /// Removes this profile's value for a setting (the one a pill stands for).
    func remove(_ def: PreferenceDef, from name: String) {
        guard var profile = profiles[name] else { return }
        profile.preferences[def.id] = nil
        profiles[name] = profile
        persist(name)
    }

    /// Changes the Mac itself, right now (like System Settings). Profiles are not touched.
    func applyLive(_ def: PreferenceDef, _ value: PrefValue) {
        let r = DefaultsService.write(def, value)
        if !r.ok { errorMessage = "\(def.title): \(r.combined.isEmpty ? "failed" : r.combined)"; return }
        live[def.id] = value
        scheduleRestart(def.restart)
    }

    /// Takes the setting out of every profile (the plan goes back to the macOS default).
    func reset(_ def: PreferenceDef) {
        for name in profileNames where profiles[name]?.preferences[def.id] != nil { remove(def, from: name) }
    }

    /// Puts what this Mac has now into a profile.
    func adopt(_ def: PreferenceDef, into profileName: String) {
        set(def, to: initialValue(def), in: profileName)
    }

    /// Stepper clicks come in bursts; restart Dock/Finder once things settle.
    private func scheduleRestart(_ processes: [ProcessToRestart]) {
        guard !processes.isEmpty else { return }
        pendingRestart.formUnion(processes)
        restartTask?.cancel()
        restartTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled, let self else { return }
            let pending = self.pendingRestart
            self.pendingRestart = []
            DefaultsService.restart(pending)
        }
    }

    // MARK: Sync

    var sync: GitSync? {
        guard !device.repository.isEmpty, !token.isEmpty else { return nil }
        return GitSync(repository: device.repository, token: token, deviceName: device.deviceName,
                       branch: device.branch, configFolder: device.configFolder)
    }

    var syncKind: SyncKind {
        if sync == nil { return .unconfigured }
        if !connected { return .notConnected }
        return syncInfo?.kind ?? .upToDate
    }

    func saveCredentials() {
        Keychain.save(token, account: "github-token")
        saveDevice()
    }

    /// Cheap, local only: used after every edit.
    func refreshChanges() {
        guard connected, let sync else { changedFiles = []; return }
        changedFiles = sync.changedFiles()
        syncInfo?.changedFiles = changedFiles
    }

    /// Compares with GitHub (fetches) and refreshes what each setting says about being saved.
    func checkSync(fetch: Bool = true) async {
        guard connected, let sync else { syncInfo = nil; return }
        checking = true
        defer { checking = false }
        let names = profileNames
        let folder = AppPaths.normalizeFolder(device.configFolder)
        let result = await Task.detached(priority: .utility) { () -> (SyncInfo, [String], [String: Profile]) in
            let info = sync.check(fetch: fetch)
            var saved: [String: Profile] = [:]
            for name in names {
                if let data = sync.committedFile("\(folder)/profiles/\(name)/profile.json"),
                   let profile = try? JSONDecoder().decode(Profile.self, from: data) {
                    saved[name] = profile
                }
            }
            return (info, sync.log(), saved)
        }.value
        syncInfo = result.0
        changedFiles = result.0.changedFiles
        commits = result.1
        committed = result.2
    }

    func connect() async {
        saveCredentials()
        guard let sync else { errorMessage = "Enter the repository and the access token first."; return }
        await work("Connecting…") {
            let r = sync.connect()
            return r.ok ? nil : r.combined
        }
        connected = FileManager.default.fileExists(atPath: AppPaths.repo.appendingPathComponent(".git").path)
        let out = await Task.detached { sync.sync(push: false) }.value
        if case .failed(let m) = out, !m.isEmpty { errorMessage = m }
        if case .conflicts = out { showConflicts = true }
        reloadProfiles()
        await checkSync()
    }

    /// The one button: does whatever the current state needs.
    func syncPrimary() async {
        guard sync != nil, connected else { navigate(to: .sync); showConnection = true; return }
        guard let info = syncInfo else { await checkSync(); return }
        switch info.kind {
        case .conflict: showConflicts = true
        case .upToDate, .error, .unconfigured, .notConnected: await checkSync()
        case .needsPull: await runSync(push: false)
        case .needsPush, .diverged: await runSync(push: true)
        }
    }

    func runSync(push: Bool) async {
        guard let sync else { return }
        busy = true
        status = push ? "Syncing with GitHub…" : "Pulling updates…"
        let outcome = await Task.detached(priority: .userInitiated) { sync.sync(push: push) }.value
        busy = false
        status = nil
        switch outcome {
        case .done: break
        case .conflicts: showConflicts = true
        case .failed(let m): errorMessage = m
        }
        reloadProfiles()
        refreshLive()
        await checkSync(fetch: false)
    }

    func finishConflicts(choices: [String: Bool]) async {
        guard let sync else { return }
        busy = true
        status = "Finishing the merge…"
        let outcome = await Task.detached { () -> SyncOutcome in
            for (file, mine) in choices { sync.resolve(file, useMine: mine) }
            return sync.finishMerge()
        }.value
        busy = false
        status = nil
        if case .failed(let m) = outcome { errorMessage = m }
        showConflicts = false
        reloadProfiles()
        refreshLive()
        await checkSync()
    }

    func abortMerge() async {
        guard let sync else { return }
        await Task.detached { sync.abortMerge() }.value
        showConflicts = false
        reloadProfiles()
        await checkSync(fetch: false)
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
