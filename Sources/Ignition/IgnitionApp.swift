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
    @State private var homebrewExpanded = true

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: Binding(get: { state.destination }, set: { state.navigate(to: $0) }), homebrewExpanded: $homebrewExpanded)
                .navigationSplitViewColumnWidth(min: 230, ideal: 250, max: 300)
        } detail: {
            NavigationStack(path: $state.path) {
                DetailRouter(destination: state.destination ?? .overview)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if !state.editingIsActive { InactiveProfileBanner() }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button { state.goBack() } label: { Label("Back", systemImage: "chevron.left") }
                    .disabled(!state.canGoBack)
                Button { state.goForward() } label: { Label("Forward", systemImage: "chevron.right") }
                    .disabled(!state.canGoForward)
            }
            ToolbarItem(placement: .automatic) { ProfileMenu() }
            ToolbarItem(placement: .automatic) { SyncButton() }
        }
        .sheet(isPresented: $state.showConflicts) { ConflictSheet() }
        .sheet(isPresented: $state.showDiff) { DiffSheet() }
        .sheet(isPresented: $state.showConnection) { ConnectionSheet() }
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
                        Text("\(hardware.chip) · \(hardware.memoryGB) GB")
                            .font(.caption).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.tail)
                        Text(hardware.osVersion).font(.caption).foregroundStyle(.secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Label {
                        Text(state.layers.map(\.capitalized).joined(separator: " + "))
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: { Image(systemName: "square.stack.3d.up") }
                        .help("Profiles switched on for this Mac")
                    Label {
                        Text(state.editingIsActive
                             ? "Editing \(state.device.editingProfile.capitalized)"
                             : "Editing \(state.device.editingProfile.capitalized) (not on this Mac)")
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: { Image(systemName: state.icon(of: state.device.editingProfile) ?? "pencil") }
                        .foregroundStyle(state.editingIsActive ? Color.secondary : Color.orange)
                        .help("Changes you make are saved into this profile")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
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

struct ProfileMenu: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Menu {
            Picker("Changes are saved into", selection: $state.device.editingProfile) {
                ForEach(state.profileNames, id: \.self) { name in
                    Text(state.layers.contains(name) ? name.capitalized : "\(name.capitalized) (not on this Mac)").tag(name)
                }
            }
            .pickerStyle(.inline)
            Divider()
            Button("Manage Profiles…") { state.navigate(to: .profiles) }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: state.icon(of: state.device.editingProfile) ?? "square.stack.3d.up")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(state.profileColor(of: state.device.editingProfile).solid, in: .circle)
                Text(state.device.editingProfile.capitalized)
            }
        }
        .help("The profile your changes are saved into")
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

/// Shown while editing a profile that is not switched on for this Mac.
struct InactiveProfileBanner: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "pencil.and.list.clipboard")
            Text("Editing **\(state.device.editingProfile.capitalized)**, which is not on this Mac. Changes are saved to the profile only; this Mac stays as it is.")
                .font(.callout)
            Spacer()
            Button("Back to \((state.layers.last ?? "base").capitalized)") {
                state.device.editingProfile = state.layers.last ?? "base"
                state.saveDevice()
            }
            .buttonStyle(.glass)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .glassEffect(.regular.tint(.orange.opacity(0.2)), in: .rect(cornerRadius: 14))
        .padding(.horizontal, 12).padding(.top, 6)
    }
}
