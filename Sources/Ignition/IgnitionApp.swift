import SwiftUI
import AppKit
import IgnitionCore

@main
struct IgnitionApp: App {
    @StateObject private var state = AppState()
    @StateObject private var store = BrewStore()

    var body: some Scene {
        WindowGroup("Ignition") {
            ContentView()
                .environmentObject(state)
                .environmentObject(store)
                .frame(minWidth: 940, minHeight: 620)
        }
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1080, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

enum Destination: Hashable {
    case overview, profiles, sync, apply
    case pref(PrefCategory)
    case dock, loginApps, finderSidebar, directories, dotfiles
    case brewDiscover, brewInstalled, appStore, brewfile
}

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var store: BrewStore
    @State private var homebrewExpanded = true

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: Binding(get: { state.destination }, set: { state.navigate(to: $0) }), homebrewExpanded: $homebrewExpanded)
                .navigationSplitViewColumnWidth(min: 230, ideal: 250, max: 300)
        } detail: {
            // Package pages replace the section instead of being pushed, so only the
            // toolbar's own back/forward buttons exist.
            Group {
                if let package = state.path.last {
                    PackageDetailView(package: package)
                } else {
                    DetailRouter(destination: state.destination ?? .overview)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button { state.goBack() } label: { Label("Back", systemImage: "chevron.left") }
                    .disabled(!state.canGoBack)
                Button { state.goForward() } label: { Label("Forward", systemImage: "chevron.right") }
                    .disabled(!state.canGoForward)
            }
            ToolbarItem(placement: .automatic) { ApplyButton() }
            ToolbarItem(placement: .automatic) { SyncButton() }
        }
        .sheet(isPresented: $state.showConflicts) { ConflictSheet() }
        .sheet(isPresented: $state.showDiff) { DiffSheet() }
        .sheet(isPresented: $state.showConnection) { ConnectionSheet() }
        .task {
            await state.checkSync()
            await store.refreshInstalled()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task {
                await state.checkSync()
                await store.refreshInstalled()   // picks up what you installed from the terminal
            }
            state.refreshLive()
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { state.errorMessage != nil },
            set: { if !$0 { state.errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(state.errorMessage ?? "")
        }
        .overlay(alignment: .bottom) {
            if let status = state.status {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(status).font(.callout)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .glassEffect(.regular, in: .capsule)
                .padding(.bottom, 14)
            }
        }
    }
}

struct DetailRouter: View {
    let destination: Destination

    var body: some View {
        switch destination {
        case .overview: OverviewView()
        case .profiles: ProfilesView()
        case .sync: SyncView()
        case .apply: ApplyView()
        case .pref(let category): PreferencesView(category: category)
        case .dock: DockEditorView()
        case .loginApps: LoginAppsView()
        case .finderSidebar: FinderSidebarView()
        case .directories: DirectoriesView()
        case .dotfiles: DotfilesView()
        case .brewDiscover: BrewDiscoverView()
        case .brewInstalled: BrewInstalledView()
        case .appStore: AppStoreView()
        case .brewfile: BrewfileView()
        }
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var store: BrewStore
    @Binding var selection: Destination?
    @Binding var homebrewExpanded: Bool

    var body: some View {
        List(selection: $selection) {
            Section {
                DeviceCard()
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 10, trailing: 0))
                    .listRowBackground(Color.clear)
            }
            Section {
                Label("Overview", systemImage: "flame").tag(Destination.overview)
                Label("Profiles", systemImage: "square.stack.3d.up").tag(Destination.profiles)
                Label("GitHub Sync", systemImage: "arrow.triangle.2.circlepath.icloud")
                    .badge(state.changedFiles.count)
                    .tag(Destination.sync)
                Label("Apply to this Mac", systemImage: "play.circle")
                    .badge(state.pending.count)
                    .tag(Destination.apply)
            }
            Section("Settings") {
                ForEach(PrefCategory.allCases.filter { !PreferenceCatalog.defs(in: $0).isEmpty }) { c in
                    Label(c.title, systemImage: c.symbol)
                        .badge(state.savedCount(in: c))
                        .tag(Destination.pref(c))
                }
            }
            Section("Layout") {
                Label("Dock Layout", systemImage: "dock.rectangle").tag(Destination.dock)
                Label("Login Apps", systemImage: "power").tag(Destination.loginApps)
                Label("Finder Sidebar", systemImage: "sidebar.left").tag(Destination.finderSidebar)
                Label("Folders", systemImage: "folder.badge.plus").tag(Destination.directories)
                Label("Dotfiles", systemImage: "doc.text").tag(Destination.dotfiles)
            }
            Section("Software") {
                Label("Profile Software", systemImage: "list.bullet.rectangle").tag(Destination.brewfile)
                DisclosureGroup(isExpanded: $homebrewExpanded) {
                    Label("Discover", systemImage: "sparkle.magnifyingglass").tag(Destination.brewDiscover)
                    Label("Installed", systemImage: "checkmark.circle")
                        .badge(store.installed.filter { !$0.ref.isIgnitionTool && store.profiles(containing: $0.ref, state: state).isEmpty }.count)
                        .tag(Destination.brewInstalled)
                } label: {
                    Label("Homebrew", systemImage: "mug")
                }
                Label("App Store", systemImage: "app.badge").tag(Destination.appStore)
            }
        }
        .listStyle(.sidebar)
    }
}

struct DeviceCard: View {
    @EnvironmentObject var state: AppState
    private let hardware = HardwareInfo.current

    var body: some View {
        Button { state.navigate(to: .profiles) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: hardware.symbol(forName: state.device.deviceName))
                        .font(.title2)
                        .frame(width: 38, height: 38)
                        .glassEffect(.regular, in: .rect(cornerRadius: 11))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.device.deviceName)
                            .font(.headline)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(hardware.model) · \(hardware.chip) · \(hardware.memoryGB) GB")
                            .font(.caption).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.tail)
                        Text(hardware.osVersion).font(.caption).foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 5) {
                    ForEach(state.layers, id: \.self) { name in
                        ProfileChip(name: name, showName: true)
                            .help("\(name.capitalized) is configured on this Mac")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
            .contentShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Toolbar


struct ApplyButton: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        let needs = state.needsApply
        let count = state.pending.count
        Button { state.navigate(to: .apply) } label: {
            Label {
                Text(needs ? (count > 0 ? "Apply (\(count))" : "Apply") : "Applied")
            } icon: {
                Image(systemName: needs ? "play.circle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(needs ? Color.orange : Color.green)
            }
        }
        .help(needs
              ? "The plan has changes that are not on this Mac yet – review and apply"
              : "This Mac matches the plan")
    }
}

struct SyncButton: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        let kind = state.syncKind
        Button {
            Task { await state.syncPrimary() }
        } label: {
            Label {
                Text(kind.buttonTitle(changes: state.changedFiles.count))
            } icon: {
                Image(systemName: kind.symbol).foregroundStyle(kind.color)
            }
        }
        .disabled(state.busy)
        .help(kind.summary)
    }
}

extension SyncKind {
    var color: Color {
        switch self {
        case .upToDate: return .green
        case .needsPush, .needsPull, .diverged: return .orange
        case .conflict, .error: return .red
        case .unconfigured, .notConnected: return .secondary
        }
    }

    var symbol: String {
        switch self {
        case .upToDate: return "checkmark.icloud.fill"
        case .needsPush: return "icloud.and.arrow.up.fill"
        case .needsPull: return "icloud.and.arrow.down.fill"
        case .diverged: return "arrow.triangle.2.circlepath.icloud.fill"
        case .conflict, .error: return "exclamationmark.icloud.fill"
        case .unconfigured, .notConnected: return "icloud.slash"
        }
    }

    var summary: String {
        switch self {
        case .upToDate: return "Everything is in sync with GitHub"
        case .needsPush: return "You have changes that are not on GitHub yet"
        case .needsPull: return "GitHub has newer changes"
        case .diverged: return "Both this Mac and GitHub have new changes"
        case .conflict: return "Changes collide – choose which version to keep"
        case .error: return "Cannot reach GitHub"
        case .unconfigured: return "GitHub is not set up yet"
        case .notConnected: return "Not connected to the repository"
        }
    }

    func buttonTitle(changes: Int) -> String {
        switch self {
        case .upToDate: return "In sync"
        case .needsPush: return changes > 0 ? "Save to GitHub (\(changes))" : "Save to GitHub"
        case .needsPull: return "Pull updates"
        case .diverged: return "Sync with GitHub"
        case .conflict: return "Resolve conflicts"
        case .error: return "Retry sync"
        case .unconfigured, .notConnected: return "Set up GitHub"
        }
    }
}

