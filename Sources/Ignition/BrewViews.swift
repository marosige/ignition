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

extension PackageRef {
    /// Tools Ignition itself needs (dockutil, mas, mysides): installed by Apply, never planned in a profile.
    var isIgnitionTool: Bool {
        switch self {
        case .cask(let t): return Packages.ignitionTools.casks.contains { $0.name == t }
        case .formula(let t): return Packages.ignitionTools.brews.contains { $0.name == t }
        default: return false
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
    @Published var masEntries: [MasEntry] = []
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
        let result = await Task.detached { () -> ([MasEntry], Set<String>) in
            let mas = Mas.isInstalled ? Mas.installed() : []
            let code = Shell.which("code")
                ? Set(Shell.run("code", ["--list-extensions"]).out.lowercased().components(separatedBy: "\n"))
                : []
            return (mas, code)
        }.value
        masEntries = result.0
        masInstalled = Set(result.0.map(\.id))
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

    /// Uninstalls anything Ignition manages from this Mac; `removeFrom` profiles forget it too.
    func uninstall(_ ref: PackageRef, removeFrom: [String], state: AppState) async {
        let ok = await Task.detached { () -> Bool in
            switch ref {
            case .cask(let t): return Brew.uninstall(BrewPackage(kind: .cask, token: t)) { _ in }.ok
            case .formula(let t): return Brew.uninstall(BrewPackage(kind: .formula, token: t)) { _ in }.ok
            case .mas(let id, _): return Mas.uninstall(id).ok
            case .vscode(let t): return Shell.run("code", ["--uninstall-extension", t]).ok
            }
        }.value
        await refreshEverything()
        if ok { for name in removeFrom { remove(ref, from: name, state: state) } }
        else { state.errorMessage = "Could not uninstall \(ref.title)." }
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
        if ref.isIgnitionTool {
            HStack(spacing: 3) {
                Image(systemName: "flame.fill")
                Text("Ignition")
            }
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(Color.orange.opacity(0.18), in: .capsule)
            .foregroundStyle(.orange)
            .help("Needed by Ignition itself – Apply installs it automatically, no profile required")
        } else {
            planPills
        }
    }

    @ViewBuilder
    private var planPills: some View {
        let have = store.profiles(containing: ref, state: state)
        // Profiles that build on one that already has the package get it from there.
        let missing = state.profileNames.filter { name in
            !have.contains(name) && !state.resolve([name]).contains(where: have.contains)
        }
        HStack(spacing: 5) {
            ForEach(have, id: \.self) { name in
                if editable {
                    PackagePill(ref: ref, profile: name)
                } else {
                    ProfileChip(name: name, dimmed: !state.layers.contains(name))
                }
            }
            if editable {
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
                .disabled(missing.isEmpty)
                .opacity(missing.isEmpty ? 0.4 : 1)
                .help(missing.isEmpty ? "Every profile already has it, directly or through a profile it builds on"
                      : (have.isEmpty ? "Not in any profile – add it to one" : "Add to another profile"))
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

// MARK: - Uninstall button for lists

/// Trash button with the same question everywhere: remove from this Mac, and from the profiles?
struct UninstallButton: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var store: BrewStore
    let ref: PackageRef
    var assumeInstalled = false
    @State private var confirm = false

    var body: some View {
        let installed = (assumeInstalled || store.isInstalled(ref)) && !ref.isIgnitionTool
        let activeHave = store.profiles(containing: ref, state: state).filter { state.layers.contains($0) }
        if installed {
            Button { confirm = true } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless)
                .help("Uninstall from this Mac")
                .confirmationDialog("Uninstall \(ref.title) from this Mac?", isPresented: $confirm) {
                    if activeHave.isEmpty {
                        Button("Uninstall", role: .destructive) {
                            Task { await store.uninstall(ref, removeFrom: [], state: state) }
                        }
                    } else {
                        Button("Uninstall and remove from \(activeHave.map(\.capitalized).joined(separator: ", "))", role: .destructive) {
                            Task { await store.uninstall(ref, removeFrom: activeHave, state: state) }
                        }
                        Button("Uninstall, keep in profiles", role: .destructive) {
                            Task { await store.uninstall(ref, removeFrom: [], state: state) }
                        }
                    }
                } message: {
                    Text(activeHave.isEmpty ? "It is not in any profile on this Mac." : "If it stays in a profile, the next Apply installs it again.")
                }
        }
    }
}

// MARK: - Discover

struct BrewDiscoverView: View {
    @EnvironmentObject var store: BrewStore
    @EnvironmentObject var state: AppState
    @State private var query = ""
    @State private var kind: KindFilter = .all
    @State private var storeResults: [MasEntry] = []
    @State private var searchedStore = ""

    enum KindFilter: String, CaseIterable, Identifiable {
        case all = "All", apps = "Apps", tools = "Command line", appStore = "App Store"
        var id: String { rawValue }
        var kinds: Set<BrewPackage.Kind> {
            switch self {
            case .all: return [.cask, .formula]
            case .apps: return [.cask]
            case .tools: return [.formula]
            case .appStore: return []
            }
        }
    }

    private var results: [BrewPackage] { Brew.search(query, in: store.catalog, kinds: kind.kinds) }
    private var showsStore: Bool { kind == .all || kind == .appStore }

    var body: some View {
        Group {
            if query.isEmpty {
                ContentUnavailableView("Search Homebrew and the App Store", systemImage: "sparkle.magnifyingglass",
                                       description: Text("Try “firefox”, “raycast” or “ripgrep”. Press return to include the App Store."))
            } else if store.loading && store.catalog.isEmpty {
                ProgressView("Loading the Homebrew catalog…")
            } else if results.isEmpty && (!showsStore || storeResults.isEmpty) {
                ContentUnavailableView.search(text: query)
            } else {
                List {
                    ForEach(results) { p in
                        Button { state.path.append(p) } label: {
                            PackageRow(package: p, installed: store.installedIDs.contains(p.id))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    if showsStore, !storeResults.isEmpty, searchedStore == query {
                        Section("Mac App Store") {
                            ForEach(storeResults) { m in
                                HStack(spacing: 12) {
                                    SourceBadge(source: .appStore)
                                    Text(m.name).font(.headline)
                                    Spacer()
                                    PackagePills(ref: .mas(m.id, m.name))
                                    if store.masInstalled.contains(m.id) {
                                        Label("Installed", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.green)
                                    } else {
                                        Button("Get") { Task.detached { _ = Mas.install(m.id) { _ in } } }
                                            .buttonStyle(.glassProminent)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Install Software")
        .searchable(text: $query, placement: .toolbar, prompt: "Search apps and tools")
        .onSubmit(of: .search) {
            let q = query
            guard showsStore, Mas.isInstalled else { return }
            Task {
                storeResults = await Task.detached { Mas.search(q) }.value
                searchedStore = q
            }
        }
        .toolbar {
            ToolbarItem {
                Picker("Source", selection: $kind) { ForEach(KindFilter.allCases) { Text($0.rawValue).tag($0) } }
                    .pickerStyle(.segmented)
            }
        }
        .task {
            await store.loadCatalog()
            await store.refreshEverything()
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
            SourceBadge(source: package.kind == .cask ? .cask : .formula)
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
                UninstallButton(ref: package.ref, assumeInstalled: true)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Installed on this Mac

/// How a package got here, shown as an icon.
enum SoftwareSource {
    case cask, formula, appStore

    var symbol: String {
        switch self {
        case .cask: return "app.fill"
        case .formula: return "terminal.fill"
        case .appStore: return "bag.fill"
        }
    }
    var label: String {
        switch self {
        case .cask: return "Homebrew app (cask)"
        case .formula: return "Homebrew command line tool"
        case .appStore: return "Mac App Store"
        }
    }
    var tint: Color {
        switch self {
        case .cask: return .accentColor
        case .formula: return .secondary
        case .appStore: return .blue
        }
    }
}

struct SourceBadge: View {
    let source: SoftwareSource
    var size: CGFloat = 34

    var body: some View {
        Image(systemName: source.symbol)
            .font(.system(size: size * 0.5))
            .foregroundStyle(source.tint)
            .frame(width: size, height: size)
            .glassEffect(.regular, in: .rect(cornerRadius: size * 0.27))
            .help(source.label)
    }
}

/// One installed thing, whichever store it came from.
struct SoftwareItem: Identifiable {
    let ref: PackageRef
    let name: String
    let desc: String
    let source: SoftwareSource
    var package: BrewPackage?
    var id: PackageRef { ref }
}

/// Everything installed here – Homebrew apps and tools plus App Store apps – in one list.
struct InstalledView: View {
    @EnvironmentObject var store: BrewStore
    @EnvironmentObject var state: AppState
    @State private var query = ""
    @State private var planFilter: PlanFilter = .all
    @State private var profileFilter: String?
    @State private var sourceFilter: SourceFilter = .all

    enum PlanFilter: String, CaseIterable, Identifiable {
        case all = "All", planned = "In a profile", open = "Not in a profile"
        var id: String { rawValue }
    }
    enum SourceFilter: String, CaseIterable, Identifiable {
        case all = "Everything", apps = "Apps", tools = "Command line", appStore = "App Store"
        var id: String { rawValue }
    }

    private var items: [SoftwareItem] {
        let brew = store.installed.map {
            SoftwareItem(ref: $0.ref, name: $0.name, desc: $0.desc, source: $0.kind == .cask ? .cask : .formula, package: $0)
        }
        let mas = store.masEntries.map {
            SoftwareItem(ref: .mas($0.id, $0.name), name: $0.name, desc: "Mac App Store", source: .appStore, package: nil)
        }
        return (brew + mas).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Stable order: rows never jump when you add something to a profile.
    private var filtered: [SoftwareItem] {
        items.filter { item in
            guard query.isEmpty || item.name.localizedCaseInsensitiveContains(query) || item.desc.localizedCaseInsensitiveContains(query) else { return false }
            switch sourceFilter {
            case .all: break
            case .apps: if item.source != .cask { return false }
            case .tools: if item.source != .formula { return false }
            case .appStore: if item.source != .appStore { return false }
            }
            let have = store.profiles(containing: item.ref, state: state)
            if let profileFilter { return have.contains(profileFilter) }
            switch planFilter {
            case .all: return true
            case .planned: return !have.isEmpty
            case .open: return have.isEmpty && !item.ref.isIgnitionTool
            }
        }
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    Picker("", selection: $planFilter) {
                        ForEach(PlanFilter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 300)
                    .disabled(profileFilter != nil)
                    Picker("Profile", selection: $profileFilter) {
                        Text("Any profile").tag(String?.none)
                        ForEach(state.profileNames, id: \.self) { Text($0.capitalized).tag(String?.some($0)) }
                    }
                    .fixedSize()
                    Picker("Source", selection: $sourceFilter) {
                        ForEach(SourceFilter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .fixedSize()
                    Spacer()
                    Text("\(filtered.count) of \(items.count)").font(.caption).foregroundStyle(.secondary)
                }
            }
            Section {
                ForEach(filtered) { row($0) }
            }
        }
        .overlay {
            if items.isEmpty { ContentUnavailableView("Nothing installed yet", systemImage: "mug") }
            else if filtered.isEmpty { ContentUnavailableView("Nothing to show", systemImage: "checkmark.circle") }
        }
        .navigationTitle("Installed")
        .searchable(text: $query, placement: .toolbar)
        .toolbar {
            Button { Task { await store.refreshEverything() } } label: { Label("Refresh", systemImage: "arrow.clockwise") }
        }
        .task { await store.refreshEverything() }
    }

    private func row(_ item: SoftwareItem) -> some View {
        HStack(spacing: 12) {
            SourceBadge(source: item.source)
            Button {
                if let package = item.package { state.path.append(package) }
            } label: {
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name).font(.headline)
                    Text(item.desc).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(item.package == nil)
            Spacer()
            PackagePills(ref: item.ref, comment: item.desc)
            UninstallButton(ref: item.ref, assumeInstalled: true)
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
    @State private var appURL: URL?

    private var isInstalled: Bool { store.installedIDs.contains(package.id) }
    private var isWorking: Bool { store.working.contains(package.id) }
    private var inProfiles: [String] { store.profiles(containing: package.ref, state: state) }
    private var activeHave: [String] { inProfiles.filter { state.layers.contains($0) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if !package.desc.isEmpty {
                    Text(package.desc).font(.title3).foregroundStyle(.primary)
                }

                card("Details") {
                    detailRow("On this Mac") {
                        Label(isInstalled ? "Installed" : "Not installed",
                              systemImage: isInstalled ? "checkmark.circle.fill" : "circle.dashed")
                            .foregroundStyle(isInstalled ? Color.green : Color.secondary)
                    }
                    detailRow("Kind") { Text(package.kind == .cask ? "App (cask)" : "Command line tool (formula)") }
                    detailRow("Token") { Text(package.token).textSelection(.enabled).font(.body.monospaced()) }
                    if !package.version.isEmpty { detailRow("Version") { Text(package.version) } }
                    if let url = URL(string: package.homepage), !package.homepage.isEmpty {
                        detailRow("Website") {
                            Link(destination: url) { Label(url.host() ?? package.homepage, systemImage: "arrow.up.forward.square") }
                        }
                    }
                }

                card("Profiles") {
                    VStack(alignment: .leading, spacing: 8) {
                        PackagePills(ref: package.ref, comment: package.desc)
                        Text(package.ref.isIgnitionTool
                             ? "Ignition installs this itself – no profile needed."
                             : "Profiles that list it get it installed by Apply. Click a pill to remove it, + to add it to another profile.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }

                if let lines = store.logs[package.id], !lines.isEmpty {
                    card("Output") {
                        ScrollView {
                            Text(lines.suffix(200).joined(separator: "\n"))
                                .font(.callout.monospaced()).frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .frame(height: 200)
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationTitle(package.name)
        .task(id: isInstalled) {
            await store.refreshInstalled()
            if package.kind == .cask, isInstalled {
                let token = package.token
                appURL = await Task.detached { Brew.appURL(forCask: token) }.value
            } else { appURL = nil }
        }
        .confirmationDialog("Get \(package.name)", isPresented: $confirmGet) {
            ForEach(state.layers, id: \.self) { name in
                Button("Install and add to \(name.capitalized)") {
                    Task { await store.install(package, addTo: name, state: state) }
                }
            }
            Button("Install on this Mac only") {
                Task { await store.install(package, addTo: nil, state: state) }
            }
        } message: {
            Text("Ignition plans your Macs: put it in a profile so every Mac that uses it gets it. You can also add it to other profiles with the + pill without installing.")
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

    private var header: some View {
        HStack(alignment: .center, spacing: 20) {
            Group {
                if let appURL {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                        .resizable().interpolation(.high)
                        .frame(width: 88, height: 88)
                } else {
                    Image(systemName: package.kind == .cask ? "app.fill" : "terminal.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(package.kind == .cask ? Color.accentColor : Color.secondary)
                        .frame(width: 88, height: 88)
                        .glassEffect(.regular, in: .rect(cornerRadius: 22))
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(package.name).font(.system(size: 32, weight: .bold))
                Text([package.kind == .cask ? "App" : "Command line tool", package.version.isEmpty ? nil : package.version]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.title3).foregroundStyle(.secondary)
            }
            Spacer(minLength: 16)
            actions
        }
    }

    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            VStack(alignment: .leading, spacing: 0) { content() }
                .padding(.horizontal, 16).padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: .rect(cornerRadius: 18))
        }
    }

    private func detailRow<Value: View>(_ label: String, @ViewBuilder value: () -> Value) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(label).foregroundStyle(.secondary).frame(width: 110, alignment: .leading)
            value()
            Spacer(minLength: 0)
        }
        .font(.body)
        .padding(.vertical, 9)
    }

    @ViewBuilder
    private var actions: some View {
        if isWorking {
            ProgressView().controlSize(.large)
        } else if isInstalled {
            HStack(spacing: 10) {
                if let appURL {
                    Button {
                        NSWorkspace.shared.open(appURL)
                    } label: { Label("Open", systemImage: "arrow.up.forward.app") }
                    .buttonStyle(.glassProminent).controlSize(.large)
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([appURL])
                    } label: { Image(systemName: "folder") }
                    .buttonStyle(.glass).controlSize(.large)
                    .help("Show in Finder")
                }
                if !package.ref.isIgnitionTool {
                    Button("Uninstall", role: .destructive) { confirmDelete = true }.buttonStyle(.glass).controlSize(.large)
                }
            }
        } else {
            Button("Get") {
                if activeHave.isEmpty { confirmGet = true }
                else { Task { await store.install(package, addTo: nil, state: state) } }
            }
            .buttonStyle(.glassProminent).controlSize(.large)
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
            Section("Add a VS Code extension") {
                HStack {
                    TextField("publisher.extension-id", text: $newExtension)
                    Menu("Add to…") {
                        ForEach(state.profileNames, id: \.self) { name in
                            Button {
                                store.add(.vscode(newExtension.trimmingCharacters(in: .whitespaces)), to: name, state: state)
                                newExtension = ""
                            } label: {
                                Label(name.capitalized, systemImage: state.icon(of: name) ?? "square.stack.3d.up")
                            }
                        }
                    }
                    .menuStyle(.button).buttonStyle(.glass).fixedSize()
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
                    UninstallButton(ref: ref, assumeInstalled: true)
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
