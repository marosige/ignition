import SwiftUI
import IgnitionCore

@MainActor
final class BrewStore: ObservableObject {
    @Published var catalog: [BrewPackage] = []
    @Published var installed: [BrewPackage] = []
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

    func install(_ p: BrewPackage, remember profile: String?, state: AppState) async {
        working.insert(p.id); logs[p.id] = []
        let id = p.id
        let result = await Task.detached { [weak self] in
            Brew.install(p) { line in Task { @MainActor in self?.logs[id, default: []].append(line) } }
        }.value
        working.remove(p.id)
        if !result.ok { logs[id, default: []].append("✗ " + result.combined) }
        await refreshInstalled()
        if result.ok, let profile { remember(p, in: profile, state: state, add: true) }
    }

    func uninstall(_ p: BrewPackage, state: AppState) async {
        working.insert(p.id); logs[p.id] = []
        let id = p.id
        let result = await Task.detached { [weak self] in
            Brew.uninstall(p) { line in Task { @MainActor in self?.logs[id, default: []].append(line) } }
        }.value
        working.remove(p.id)
        if !result.ok { logs[id, default: []].append("✗ " + result.combined) }
        await refreshInstalled()
        if result.ok { for name in state.profileNames { remember(p, in: name, state: state, add: false) } }
    }

    func remember(_ p: BrewPackage, in profileName: String, state: AppState, add: Bool) {
        guard var profile = state.profiles[profileName] else { return }
        switch p.kind {
        case .cask:
            profile.packages.casks.removeAll { $0.name == p.token }
            if add { profile.packages.casks.append(PackageEntry(name: p.token, comment: p.desc.isEmpty ? nil : p.desc)) }
        case .formula:
            profile.packages.brews.removeAll { $0.name == p.token }
            if add { profile.packages.brews.append(PackageEntry(name: p.token, comment: p.desc.isEmpty ? nil : p.desc)) }
        }
        state.profiles[profileName] = profile
        state.persist(profileName)
    }

    func profileContaining(_ p: BrewPackage, state: AppState) -> [String] {
        state.profileNames.filter { name in
            guard let pk = state.profiles[name]?.packages else { return false }
            return (p.kind == .cask ? pk.casks : pk.brews).contains { $0.name == p.token }
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
    let package: BrewPackage
    let installed: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: package.kind == .cask ? "app.fill" : "terminal.fill")
                .font(.title3).foregroundStyle(package.kind == .cask ? Color.accentColor : Color.secondary)
                .frame(width: 34, height: 34)
                .glassEffect(.regular, in: .rect(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 1) {
                Text(package.name).font(.headline)
                Text(package.desc).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if installed { Label("Installed", systemImage: "checkmark.circle.fill").labelStyle(.titleAndIcon).font(.caption).foregroundStyle(.green) }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Installed

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
        List {
            ForEach([BrewPackage.Kind.cask, .formula], id: \.self) { kind in
                let rows = filtered.filter { $0.kind == kind }
                if !rows.isEmpty {
                    Section(kind == .cask ? "Apps" : "Command line tools") {
                        ForEach(rows) { p in
                            NavigationLink(value: p) {
                                HStack {
                                    PackageRow(package: p, installed: false)
                                    if store.profileContaining(p, state: state).isEmpty {
                                        Text("not in profile").font(.caption2).foregroundStyle(.orange)
                                    }
                                }
                            }
                        }
                    }
                }
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
}

// MARK: - Detail

struct PackageDetailView: View {
    @EnvironmentObject var store: BrewStore
    @EnvironmentObject var state: AppState
    let package: BrewPackage
    @State private var remember = true
    @State private var confirmDelete = false

    private var isInstalled: Bool { store.installedIDs.contains(package.id) }
    private var isWorking: Bool { store.working.contains(package.id) }
    private var inProfiles: [String] { store.profileContaining(package, state: state) }

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
                    actionButton
                }
                Text(package.desc.isEmpty ? "No description." : package.desc).font(.title3)

                GroupBox {
                    VStack(spacing: 10) {
                        info("Token", package.token)
                        if !package.version.isEmpty { info("Version", package.version) }
                        if let url = URL(string: package.homepage), !package.homepage.isEmpty {
                            LabeledContent("Website") { Link(package.homepage, destination: url) }
                        }
                        info("Status", isInstalled ? "Installed" : "Not installed")
                        info("In profiles", inProfiles.isEmpty ? "–" : inProfiles.map(\.capitalized).joined(separator: ", "))
                    }
                    .padding(4)
                }

                if !isInstalled {
                    Toggle("Also add to the “\(state.device.editingProfile.capitalized)” Brewfile", isOn: $remember)
                } else if inProfiles.isEmpty {
                    Button("Add to the “\(state.device.editingProfile.capitalized)” Brewfile") {
                        store.remember(package, in: state.device.editingProfile, state: state, add: true)
                    }
                    .buttonStyle(.glass)
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
        .confirmationDialog("Uninstall \(package.name)?", isPresented: $confirmDelete) {
            Button("Uninstall", role: .destructive) { Task { await store.uninstall(package, state: state) } }
        } message: {
            Text("It will also be removed from all profiles’ Brewfiles.")
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if isWorking {
            ProgressView().controlSize(.large)
        } else if isInstalled {
            Button("Uninstall", role: .destructive) { confirmDelete = true }.buttonStyle(.glass).controlSize(.large)
        } else {
            Button("Get") {
                Task { await store.install(package, remember: remember ? state.device.editingProfile : nil, state: state) }
            }
            .buttonStyle(.glassProminent).controlSize(.large)
        }
    }

    private func info(_ k: String, _ v: String) -> some View {
        LabeledContent(k) { Text(v).textSelection(.enabled) }
    }
}


// MARK: - Brewfile

struct BrewfileView: View {
    @EnvironmentObject var store: BrewStore
    @EnvironmentObject var state: AppState
    @State private var newExtension = ""

    var body: some View {
        let name = state.device.editingProfile
        List {
            ForEach(state.profileNames, id: \.self) { profileName in
                if let pk = state.profiles[profileName]?.packages, !pk.isEmpty {
                    Section(profileName.capitalized) {
                        ForEach(pk.casks) { e in row(e, "app.fill", profileName) { $0.packages.casks.removeAll { $0.name == e.name } } }
                        ForEach(pk.brews) { e in row(e, "terminal.fill", profileName) { $0.packages.brews.removeAll { $0.name == e.name } } }
                        ForEach(pk.mas) { m in
                            HStack {
                                Image(systemName: "app.badge").frame(width: 24)
                                Text(m.name)
                                Spacer()
                                Text("App Store").font(.caption).foregroundStyle(.secondary)
                                removeButton(profileName) { $0.packages.mas.removeAll { $0.id == m.id } }
                            }
                        }
                        ForEach(pk.vscode) { e in row(e, "chevron.left.forwardslash.chevron.right", profileName) { $0.packages.vscode.removeAll { $0.name == e.name } } }
                    }
                }
            }
            Section("VS Code extension") {
                HStack {
                    TextField("publisher.extension-id", text: $newExtension)
                    Button("Add to \(name.capitalized)") {
                        var p = state.editing
                        p.packages.vscode.append(PackageEntry(name: newExtension.trimmingCharacters(in: .whitespaces)))
                        state.editing = p
                        newExtension = ""
                    }
                    .disabled(newExtension.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            let untracked = store.installed.filter { store.profileContaining($0, state: state).isEmpty }
            if !untracked.isEmpty {
                Section {
                    ForEach(untracked) { p in
                        HStack {
                            Text(p.name)
                            Spacer()
                            Button("Add to \(name.capitalized)") { store.remember(p, in: name, state: state, add: true) }.buttonStyle(.glass)
                        }
                    }
                } header: { Text("Installed, but not in any profile") }
                footer: { Text("These are on this Mac only. Add them to a profile to get them on your other Macs too.") }
            }
        }
        .navigationTitle("Brewfile")
        .task { await store.refreshInstalled() }
        .toolbar {
            Button {
                let panel = NSSavePanel()
                panel.nameFieldStringValue = "Brewfile"
                if panel.runModal() == .OK, let url = panel.url {
                    try? Brew.brewfile(for: state.effective.packages).write(to: url, atomically: true, encoding: .utf8)
                }
            } label: { Label("Export Brewfile", systemImage: "square.and.arrow.up") }
        }
    }

    private func row(_ e: PackageEntry, _ icon: String, _ profileName: String, remove: @escaping (inout Profile) -> Void) -> some View {
        HStack {
            Image(systemName: icon).frame(width: 24)
            VStack(alignment: .leading) {
                Text(e.name)
                if let c = e.comment { Text(c).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
            }
            Spacer()
            removeButton(profileName, remove)
        }
    }

    private func removeButton(_ profileName: String, _ remove: @escaping (inout Profile) -> Void) -> some View {
        Button(role: .destructive) {
            guard var p = state.profiles[profileName] else { return }
            remove(&p)
            state.profiles[profileName] = p
            state.persist(profileName)
        } label: { Image(systemName: "minus.circle") }
        .buttonStyle(.borderless)
        .help("Remove from Brewfile (does not uninstall)")
    }
}

// MARK: - App Store

struct AppStoreView: View {
    @EnvironmentObject var state: AppState
    @State private var installed: [MasEntry] = []
    @State private var results: [MasEntry] = []
    @State private var query = ""
    @State private var log: [String] = []

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
                            Button("Add to \(state.device.editingProfile.capitalized)") { add(m) }.buttonStyle(.glass)
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
                        if state.effective.packages.mas.contains(where: { $0.id == m.id }) {
                            Label("In profile", systemImage: "checkmark").font(.caption).foregroundStyle(.green)
                        } else {
                            Button("Add to \(state.device.editingProfile.capitalized)") { add(m) }.buttonStyle(.glass)
                        }
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

    private func add(_ m: MasEntry) {
        var p = state.editing
        if !p.packages.mas.contains(where: { $0.id == m.id }) { p.packages.mas.append(m) }
        state.editing = p
    }
}
