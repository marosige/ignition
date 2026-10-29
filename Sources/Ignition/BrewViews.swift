import SwiftUI
import AppKit
import IgnitionCore

// MARK: - What a package is, across Homebrew, the App Store and VS Code

enum PackageRef: Hashable {
    case cask(String), formula(String), mas(Int, String), vscode(String)

    var title: String {
        switch self {
        case .cask(let t), .formula(let t), .vscode(let t): return t
        case .mas(_, let name): return name
        }
    }

    func contains(in p: Packages) -> Bool {
        switch self {
        case .cask(let t): return p.casks.contains { $0.name == t }
        case .formula(let t): return p.brews.contains { $0.name == t }
        case .mas(let id, _): return p.mas.contains { $0.id == id }
        case .vscode(let t): return p.vscode.contains { $0.name == t }
        }
    }

    func add(to p: inout Packages, comment: String?) {
        guard !contains(in: p) else { return }
        switch self {
        case .cask(let t): p.casks.append(PackageEntry(name: t, comment: comment))
        case .formula(let t): p.brews.append(PackageEntry(name: t, comment: comment))
        case .mas(let id, let name): p.mas.append(MasEntry(id: id, name: name))
        case .vscode(let t): p.vscode.append(PackageEntry(name: t, comment: comment))
        }
    }

    func remove(from p: inout Packages) {
        switch self {
        case .cask(let t): p.casks.removeAll { $0.name == t }
        case .formula(let t): p.brews.removeAll { $0.name == t }
        case .mas(let id, _): p.mas.removeAll { $0.id == id }
        case .vscode(let t): p.vscode.removeAll { $0.name == t }
        }
    }
}

extension BrewPackage {
    var ref: PackageRef { kind == .cask ? .cask(token) : .formula(token) }
}

// MARK: - Store

@MainActor
final class BrewStore: ObservableObject {
    @Published var catalog: [BrewPackage] = []
    @Published var installed: [BrewPackage] = []
    @Published var masInstalled: Set<Int> = []
    @Published var vscodeInstalled: Set<String> = []
    @Published var loading = false
    @Published var loadError: String?
    @Published var logs: [String: [String]] = [:]
    @Published var working: Set<String> = []

    var installedIDs: Set<String> { Set(installed.map(\.id)) }

    func loadCatalog(force: Bool = false) async {
        guard catalog.isEmpty || force else { return }
        loading = true
        defer { loading = false }
        do { catalog = try await Brew.loadCatalog(forceRefresh: force); loadError = nil }
        catch { loadError = error.localizedDescription }
    }

    func refreshInstalled() async {
        installed = await Task.detached { Brew.installed() }.value
    }

    /// Also looks at the App Store and VS Code (slower, used by the profile software page).
    func refreshEverything() async {
        await refreshInstalled()
        let result = await Task.detached { () -> (Set<Int>, Set<String>) in
            let mas = Mas.isInstalled ? Set(Mas.installed().map(\.id)) : []
            let code = Shell.which("code")
                ? Set(Shell.run("code", ["--list-extensions"]).out.lowercased().components(separatedBy: "\n"))
                : []
            return (mas, code)
        }.value
        masInstalled = result.0
        vscodeInstalled = result.1
    }

    func isInstalled(_ ref: PackageRef) -> Bool {
        switch ref {
        case .cask(let t): return installedIDs.contains("cask:\(t)")
        case .formula(let t): return installedIDs.contains("formula:\(t)")
        case .mas(let id, _): return masInstalled.contains(id)
        case .vscode(let t): return vscodeInstalled.contains(t.lowercased())
        }
    }

    // MARK: Install / uninstall (this Mac)

    /// Installs here. If `profile` is given the package is also added to it.
    func install(_ p: BrewPackage, addTo profile: String?, state: AppState) async {
        working.insert(p.id); logs[p.id] = []
        let id = p.id
        let result = await Task.detached { [weak self] in
            Brew.install(p) { line in Task { @MainActor in self?.logs[id, default: []].append(line) } }
        }.value
        working.remove(p.id)
        if !result.ok { logs[id, default: []].append("✗ " + result.combined) }
        await refreshInstalled()
        if result.ok, let profile { add(p.ref, comment: p.desc, to: profile, state: state) }
    }

    /// Uninstalls from this Mac; `removeFrom` lists profiles that should forget it too.
    func uninstall(_ p: BrewPackage, removeFrom: [String], state: AppState) async {
        working.insert(p.id); logs[p.id] = []
        let id = p.id
        let result = await Task.detached { [weak self] in
            Brew.uninstall(p) { line in Task { @MainActor in self?.logs[id, default: []].append(line) } }
        }.value
        working.remove(p.id)
        if !result.ok { logs[id, default: []].append("✗ " + result.combined) }
        await refreshInstalled()
        if result.ok { for name in removeFrom { remove(p.ref, from: name, state: state) } }
    }

    // MARK: Profiles

    /// Profiles that list the package: the ones on this Mac first, then the rest.
    func profiles(containing ref: PackageRef, state: AppState) -> [String] {
        let order = state.viewLayers + state.profileNames.filter { !state.viewLayers.contains($0) }
        return order.filter { name in
            state.profiles[name].map { ref.contains(in: $0.packages) } ?? false
        }
    }

    func add(_ ref: PackageRef, comment: String? = nil, to name: String, state: AppState) {
        guard var profile = state.profiles[name] else { return }
        ref.add(to: &profile.packages, comment: (comment?.isEmpty ?? true) ? nil : comment)
        state.profiles[name] = profile
        state.persist(name)
    }

    func remove(_ ref: PackageRef, from name: String, state: AppState) {
        guard var profile = state.profiles[name] else { return }
        ref.remove(from: &profile.packages)
        state.profiles[name] = profile
        state.persist(name)
    }
}

// MARK: - Profile pills for a package

/// Which profiles want this package. Click a pill to remove it from that profile, + to add it to another.
struct PackagePills: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var store: BrewStore
    let ref: PackageRef
    var comment: String?
    var editable = true

    var body: some View {
        let have = store.profiles(containing: ref, state: state)
        let missing = state.profileNames.filter { !have.contains($0) }
        HStack(spacing: 5) {
            ForEach(have, id: \.self) { name in
                if editable {
                    PackagePill(ref: ref, profile: name)
                } else {
                    ProfileChip(name: name, dimmed: !state.layers.contains(name))
                }
            }
            if editable, !missing.isEmpty {
                Menu {
                    ForEach(missing, id: \.self) { name in
                        Button {
                            store.add(ref, comment: comment, to: name, state: state)
                        } label: {
                            Label(state.layers.contains(name) ? name.capitalized : "\(name.capitalized) (not on this Mac)",
                                  systemImage: state.icon(of: name) ?? "square.stack.3d.up")
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.15), in: .capsule)
                        .overlay(Capsule().strokeBorder(Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
                .help(have.isEmpty ? "Not in any profile – add it to one" : "Add to another profile")
            }
        }
    }
}

struct PackagePill: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var store: BrewStore
    let ref: PackageRef
    let profile: String
    @State private var asking = false

    var body: some View {
        Button { asking = true } label: {
            ProfileChip(name: profile, dimmed: !state.layers.contains(profile))
        }
        .buttonStyle(.plain)
        .help("In the \(profile.capitalized) profile – click to remove")
        .popover(isPresented: $asking, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Remove “\(ref.title)” from \(profile.capitalized)?").font(.headline)
                Text(state.layers.contains(profile)
                     ? "It stays installed on this Mac. Macs using \(profile.capitalized) will no longer get it from Apply."
                     : "\(profile.capitalized) is not on this Mac, so nothing changes here.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    Button("Cancel") { asking = false }
                    Button("Remove") { store.remove(ref, from: profile, state: state); asking = false }
                        .buttonStyle(.glassProminent)
                }
            }
            .padding(16).frame(width: 320)
        }
    }
}

// MARK: - Discover

struct BrewDiscoverView: View {
    @EnvironmentObject var store: BrewStore
    @EnvironmentObject var state: AppState
    @State private var query = ""
    @State private var kind: KindFilter = .all

    enum KindFilter: String, CaseIterable, Identifiable {
        case all = "All", apps = "Apps", tools = "Command line"
        var id: String { rawValue }
        var kinds: Set<BrewPackage.Kind> {
            switch self { case .all: return [.cask, .formula]; case .apps: return [.cask]; case .tools: return [.formula] }
        }
    }

    var results: [BrewPackage] { Brew.search(query, in: store.catalog, kinds: kind.kinds) }

    var body: some View {
        Group {
            if !Brew.isInstalled {
                ContentUnavailableView("Homebrew is not installed", systemImage: "mug",
                                       description: Text("Open “Apply to this Mac” – Ignition installs Homebrew first."))
            } else if store.loading && store.catalog.isEmpty {
                ProgressView("Loading the Homebrew catalog…")
            } else if query.isEmpty {
                ContentUnavailableView("Search Homebrew", systemImage: "sparkle.magnifyingglass",
                                       description: Text("\(store.catalog.count) packages. Try “firefox”, “raycast” or “ripgrep”."))
            } else if results.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                List(results) { p in
                    NavigationLink(value: p) { PackageRow(package: p, installed: store.installedIDs.contains(p.id)) }
                }
            }
        }
        .navigationTitle("Discover")
        .searchable(text: $query, placement: .toolbar, prompt: "Search apps and tools")
        .toolbar {
            ToolbarItem {
                Picker("Kind", selection: $kind) { ForEach(KindFilter.allCases) { Text($0.rawValue).tag($0) } }
                    .pickerStyle(.segmented)
            }
        }
        .navigationDestination(for: BrewPackage.self) { PackageDetailView(package: $0) }
        .task {
            await store.loadCatalog()
            await store.refreshInstalled()
        }
    }
}

struct PackageRow: View {
    @EnvironmentObject var store: BrewStore
    @EnvironmentObject var state: AppState
    let package: BrewPackage
    let installed: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: package.kind == .cask ? "app.fill" : "terminal.fill")
                .font(.title3).foregroundStyle(package.kind == .cask ? Color.accentColor : Color.secondary)
                .frame(width: 34, height: 34)
                .glassEffect(.regular, in: .rect(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(package.name).font(.headline)
                    PackagePills(ref: package.ref, comment: package.desc, editable: false)
                }
                Text(package.desc).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if installed {
                Label("Installed", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.green)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Installed on this Mac

struct BrewInstalledView: View {
    @EnvironmentObject var store: BrewStore
    @EnvironmentObject var state: AppState
    @State private var query = ""

    var filtered: [BrewPackage] {
        query.isEmpty ? store.installed : store.installed.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.desc.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        let loose = filtered.filter { store.profiles(containing: $0.ref, state: state).isEmpty }
        let kept = filtered.filter { !store.profiles(containing: $0.ref, state: state).isEmpty }
        List {
            if !loose.isEmpty {
                Section {
                    ForEach(loose) { row($0) }
                } header: {
                    Text("Only on this Mac")
                } footer: {
                    Text("Not in any profile, so your other Macs will not get these. Use + to add one to a profile.")
                }
            }
            if !kept.isEmpty {
                Section("In your profiles") { ForEach(kept) { row($0) } }
            }
        }
        .overlay { if store.installed.isEmpty { ContentUnavailableView("Nothing installed yet", systemImage: "mug") } }
        .navigationTitle("Installed")
        .searchable(text: $query, placement: .toolbar)
        .navigationDestination(for: BrewPackage.self) { PackageDetailView(package: $0) }
        .toolbar {
            Button { Task { await store.refreshInstalled() } } label: { Label("Refresh", systemImage: "arrow.clockwise") }
        }
        .task { await store.refreshInstalled() }
    }

    private func row(_ p: BrewPackage) -> some View {
        HStack {
            NavigationLink(value: p) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Image(systemName: p.kind == .cask ? "app.fill" : "terminal.fill")
                            .foregroundStyle(p.kind == .cask ? Color.accentColor : Color.secondary)
                        Text(p.name).font(.headline)
                    }
                    Text(p.desc).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            PackagePills(ref: p.ref, comment: p.desc)
        }
    }
}

// MARK: - Detail

struct PackageDetailView: View {
    @EnvironmentObject var store: BrewStore
    @EnvironmentObject var state: AppState
    let package: BrewPackage
    @State private var confirmDelete = false
    @State private var confirmGet = false

    private var isInstalled: Bool { store.installedIDs.contains(package.id) }
    private var isWorking: Bool { store.working.contains(package.id) }
    private var inProfiles: [String] { store.profiles(containing: package.ref, state: state) }
    private var activeHave: [String] { inProfiles.filter { state.layers.contains($0) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    Image(systemName: package.kind == .cask ? "app.fill" : "terminal.fill")
                        .font(.system(size: 34))
                        .frame(width: 76, height: 76)
                        .glassEffect(.regular, in: .rect(cornerRadius: 20))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(package.name).font(.largeTitle.bold())
                        Text(package.kind == .cask ? "App · cask" : "Command line tool · formula")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    actions
                }
                Text(package.desc.isEmpty ? "No description." : package.desc).font(.title3)

                GroupBox {
                    VStack(spacing: 10) {
                        LabeledContent("On this Mac") {
                            Label(isInstalled ? "Installed" : "Not installed",
                                  systemImage: isInstalled ? "checkmark.circle.fill" : "circle.dashed")
                                .foregroundStyle(isInstalled ? Color.green : Color.secondary)
                        }
                        LabeledContent("In profiles") { PackagePills(ref: package.ref, comment: package.desc) }
                        LabeledContent("Token") { Text(package.token).textSelection(.enabled) }
                        if !package.version.isEmpty { LabeledContent("Version") { Text(package.version) } }
                        if let url = URL(string: package.homepage), !package.homepage.isEmpty {
                            LabeledContent("Website") { Link(package.homepage, destination: url) }
                        }
                    }
                    .padding(4)
                }

                if !isInstalled, !state.editingIsActive {
                    Text("You are editing \(state.device.editingProfile.capitalized), which is not on this Mac. “Get” installs here only; use the + pill to add it to a profile.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                if let lines = store.logs[package.id], !lines.isEmpty {
                    GroupBox("Output") {
                        ScrollView {
                            Text(lines.suffix(200).joined(separator: "\n"))
                                .font(.caption.monospaced()).frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .frame(height: 180)
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle(package.name)
        .task { await store.refreshInstalled() }
        .confirmationDialog("Get \(package.name)", isPresented: $confirmGet) {
            let target = state.device.editingProfile
            let alreadyThere = inProfiles.contains(target)
            if !alreadyThere && state.editingIsActive {
                Button("Add to \(target.capitalized) and install now") {
                    Task { await store.install(package, addTo: target, state: state) }
                }
            }
            if !alreadyThere {
                Button("Add to \(target.capitalized) only (installs with the next Apply)") {
                    store.add(package.ref, comment: package.desc, to: target, state: state)
                }
            }
            Button("Install on this Mac only") {
                Task { await store.install(package, addTo: nil, state: state) }
            }
        } message: {
            Text("Ignition plans your Macs: add it to a profile so every Mac that uses it gets it.")
        }
        .confirmationDialog("Uninstall \(package.name) from this Mac?", isPresented: $confirmDelete) {
            if activeHave.isEmpty {
                Button("Uninstall", role: .destructive) {
                    Task { await store.uninstall(package, removeFrom: [], state: state) }
                }
            } else {
                Button("Uninstall and remove from \(activeHave.map(\.capitalized).joined(separator: ", "))", role: .destructive) {
                    Task { await store.uninstall(package, removeFrom: activeHave, state: state) }
                }
                Button("Uninstall, keep in profiles", role: .destructive) {
                    Task { await store.uninstall(package, removeFrom: [], state: state) }
                }
            }
        } message: {
            Text(activeHave.isEmpty
                 ? "It is not in any profile on this Mac."
                 : "If it stays in a profile, the next Apply installs it again.")
        }
    }

    @ViewBuilder
    private var actions: some View {
        if isWorking {
            ProgressView().controlSize(.large)
        } else if isInstalled {
            Button("Uninstall", role: .destructive) { confirmDelete = true }.buttonStyle(.glass).controlSize(.large)
        } else {
            HStack {
                if !state.editingIsActive, !inProfiles.contains(state.device.editingProfile) {
                    Button("Add to \(state.device.editingProfile.capitalized)") {
                        store.add(package.ref, comment: package.desc, to: state.device.editingProfile, state: state)
                    }
                    .buttonStyle(.glass).controlSize(.large)
                }
                Button("Get") {
                    if activeHave.isEmpty { confirmGet = true }
                    else { Task { await store.install(package, addTo: nil, state: state) } }
                }
                .buttonStyle(.glassProminent).controlSize(.large)
            }
        }
    }
}

// MARK: - Software in profiles

struct PlanItem: Identifiable {
    let ref: PackageRef
    let comment: String?
    var id: PackageRef { ref }
}

/// What each profile wants, and how this Mac compares. Replaces comparing Brewfiles by hand.
struct BrewfileView: View {
    @EnvironmentObject var store: BrewStore
    @EnvironmentObject var state: AppState
    @State private var newExtension = ""

    var body: some View {
        let layers = state.viewLayers
        let others = state.profileNames.filter { !layers.contains($0) }
        List {
            ForEach(layers + others, id: \.self) { name in
                section(name, onThisMac: state.layers.contains(name))
            }
            Section("Add VS Code extension to \(state.device.editingProfile.capitalized)") {
                HStack {
                    TextField("publisher.extension-id", text: $newExtension)
                    Button("Add") {
                        store.add(.vscode(newExtension.trimmingCharacters(in: .whitespaces)), to: state.device.editingProfile, state: state)
                        newExtension = ""
                    }
                    .disabled(newExtension.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .navigationTitle("Profile Software")
        .task { await store.refreshEverything() }
        .toolbar {
            Button { Task { await store.refreshEverything() } } label: { Label("Refresh", systemImage: "arrow.clockwise") }
            Button {
                let panel = NSSavePanel()
                panel.nameFieldStringValue = "Brewfile"
                if panel.runModal() == .OK, let url = panel.url {
                    try? Brew.brewfile(for: state.effective.packages).write(to: url, atomically: true, encoding: .utf8)
                }
            } label: { Label("Export Brewfile", systemImage: "square.and.arrow.up") }
        }
    }

    @ViewBuilder
    private func section(_ name: String, onThisMac: Bool) -> some View {
        if let pk = state.profiles[name]?.packages, !pk.isEmpty {
            let items: [PlanItem] =
                pk.casks.map { PlanItem(ref: .cask($0.name), comment: $0.comment) }
                + pk.brews.map { PlanItem(ref: .formula($0.name), comment: $0.comment) }
                + pk.mas.map { PlanItem(ref: .mas($0.id, $0.name), comment: nil) }
                + pk.vscode.map { PlanItem(ref: .vscode($0.name), comment: $0.comment) }
            Section {
                ForEach(items) { item in
                    row(item.ref, comment: item.comment, profile: name, onThisMac: onThisMac)
                }
            } header: {
                HStack(spacing: 6) {
                    ProfileChip(name: name)
                    if state.icon(of: name) != nil { Text(name.capitalized) }
                    if !onThisMac { Text("not on this Mac").font(.caption).foregroundStyle(.secondary) }
                }
            }
        }
    }

    private func row(_ ref: PackageRef, comment: String?, profile: String, onThisMac: Bool) -> some View {
        let installed = store.isInstalled(ref)
        return HStack(spacing: 10) {
            Image(systemName: symbol(ref)).frame(width: 22).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(ref.title)
                if let comment { Text(comment).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
            }
            Spacer()
            if onThisMac {
                if installed {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).help("Installed on this Mac")
                } else if let pkg = brewPackage(ref) {
                    Button("Install") { Task { await store.install(pkg, addTo: nil, state: state) } }
                        .buttonStyle(.glass).controlSize(.small)
                } else {
                    Label("Missing", systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.orange)
                }
            }
            PackagePills(ref: ref, comment: comment)
        }
    }

    private func brewPackage(_ ref: PackageRef) -> BrewPackage? {
        switch ref {
        case .cask(let t): return BrewPackage(kind: .cask, token: t)
        case .formula(let t): return BrewPackage(kind: .formula, token: t)
        default: return nil
        }
    }

    private func symbol(_ ref: PackageRef) -> String {
        switch ref {
        case .cask: return "app.fill"
        case .formula: return "terminal.fill"
        case .mas: return "app.badge"
        case .vscode: return "chevron.left.forwardslash.chevron.right"
        }
    }
}

// MARK: - App Store

struct AppStoreView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var store: BrewStore
    @State private var installed: [MasEntry] = []
    @State private var results: [MasEntry] = []
    @State private var query = ""

    var body: some View {
        List {
            if !Mas.isInstalled {
                Text("`mas` is not installed yet. Run “Apply to this Mac” first.").foregroundStyle(.secondary)
            }
            if !results.isEmpty {
                Section("Search results") {
                    ForEach(results) { m in
                        HStack {
                            Text(m.name)
                            Spacer()
                            PackagePills(ref: .mas(m.id, m.name))
                            Button("Get") {
                                Task.detached { _ = Mas.install(m.id) { _ in } }
                            }.buttonStyle(.glassProminent)
                        }
                    }
                }
            }
            Section("Installed from the App Store") {
                ForEach(installed) { m in
                    HStack {
                        Text(m.name)
                        Spacer()
                        PackagePills(ref: .mas(m.id, m.name))
                    }
                }
            }
        }
        .navigationTitle("App Store")
        .searchable(text: $query, placement: .toolbar, prompt: "Search the Mac App Store")
        .onSubmit(of: .search) {
            let q = query
            Task { results = await Task.detached { Mas.search(q) }.value }
        }
        .task { installed = await Task.detached { Mas.installed() }.value }
    }
}
