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
    case overview, sync, apply
    case pref(PrefCategory)
    case dock, loginApps, finderSidebar, directories, dotfiles
    case brewDiscover, brewInstalled, appStore, brewfile
}

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @State private var homebrewExpanded = true

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $state.destination, homebrewExpanded: $homebrewExpanded)
                .navigationSplitViewColumnWidth(min: 230, ideal: 250, max: 300)
        } detail: {
            NavigationStack {
                DetailRouter(destination: state.destination ?? .overview)
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) { ProfileMenu() }
            ToolbarItem(placement: .automatic) { SyncButton() }
        }
        .sheet(isPresented: $state.showConflicts) { ConflictSheet() }
        .sheet(isPresented: $state.showDiff) { DiffSheet() }
        .task { await state.checkSync() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await state.checkSync() }
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
    @Binding var selection: Destination?
    @Binding var homebrewExpanded: Bool

    var body: some View {
        List(selection: $selection) {
            Section {
                DeviceCard()
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 10, trailing: 8))
            }
            Section {
                Label("Overview", systemImage: "flame").tag(Destination.overview)
                Label {
                    Text("GitHub Sync")
                } icon: {
                    Image(systemName: state.syncKind.symbol).foregroundStyle(state.syncKind.color)
                }
                .badge(state.changedFiles.count)
                .tag(Destination.sync)
                Label("Apply to this Mac", systemImage: "play.circle").tag(Destination.apply)
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
                DisclosureGroup(isExpanded: $homebrewExpanded) {
                    Label("Discover", systemImage: "sparkle.magnifyingglass").tag(Destination.brewDiscover)
                    Label("Installed", systemImage: "checkmark.circle").tag(Destination.brewInstalled)
                    Label("Brewfile", systemImage: "list.bullet.rectangle").tag(Destination.brewfile)
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

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "laptopcomputer")
                .font(.title2)
                .frame(width: 38, height: 38)
                .glassEffect(.regular, in: .circle)
            VStack(alignment: .leading, spacing: 1) {
                Text(state.device.deviceName).font(.headline)
                Text(state.device.activeProfiles.map { $0.capitalized }.joined(separator: " + "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(8)
    }
}

// MARK: - Toolbar

struct ProfileMenu: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Menu {
            Section("Active on this Mac") {
                ForEach(state.profileNames, id: \.self) { name in
                    Toggle(name.capitalized, isOn: Binding(
                        get: { state.device.activeProfiles.contains(name) },
                        set: { _ in state.toggleActive(name) }))
                }
            }
            Section("Changes are saved into") {
                Picker("Editing", selection: $state.device.editingProfile) {
                    ForEach(state.profileNames, id: \.self) { Text($0.capitalized).tag($0) }
                }
                .pickerStyle(.inline)
            }
        } label: {
            Label("Saving to \(state.device.editingProfile.capitalized)", systemImage: "square.stack.3d.up")
        }
        .help("Profiles are layered: Base first, then the others on top.")
        .onChange(of: state.device.editingProfile) { _, _ in state.saveDevice() }
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
