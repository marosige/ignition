import SwiftUI
import AppKit
import IgnitionCore

// MARK: - App scanning

struct InstalledApp: Identifiable, Hashable {
    let path: String
    var id: String { path }
    var name: String { ((path as NSString).lastPathComponent as NSString).deletingPathExtension }

    static func scan() -> [InstalledApp] {
        let roots = ["/Applications", "/System/Applications", "/System/Applications/Utilities",
                     "/Applications/Utilities", expandTilde("~/Applications")]
        var apps: [InstalledApp] = []
        for root in roots {
            let items = (try? FileManager.default.contentsOfDirectory(atPath: root)) ?? []
            apps += items.filter { $0.hasSuffix(".app") }.map { InstalledApp(path: root + "/" + $0) }
        }
        return apps.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
}

struct AppIcon: View {
    let path: String
    var size: CGFloat = 28
    var body: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: path))
            .resizable().frame(width: size, height: size)
    }
}

struct AppPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var apps = InstalledApp.scan()
    let onPick: (InstalledApp) -> Void

    var filtered: [InstalledApp] {
        query.isEmpty ? apps : apps.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Choose an app").font(.headline)
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(.glass)
            }
            .padding()
            TextField("Search", text: $query).textFieldStyle(.roundedBorder).padding(.horizontal)
            List(filtered) { app in
                Button {
                    onPick(app)
                } label: {
                    HStack { AppIcon(path: app.path); Text(app.name); Spacer(); Image(systemName: "plus.circle") }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 420, height: 520)
    }
}

// MARK: - Dock

struct DockEditorView: View {
    @EnvironmentObject var state: AppState
    @State private var showPicker = false
    @State private var result: String?

    private var items: [DockItem] { state.editing.dock ?? [] }

    var body: some View {
        List {
            Section {
                ForEach(items) { item in
                    HStack(spacing: 12) {
                        Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary)
                        switch item.kind {
                        case .spacer:
                            Image(systemName: "rectangle.split.2x1").frame(width: 28)
                            Text("Spacer").foregroundStyle(.secondary)
                        case .app:
                            AppIcon(path: item.path ?? "")
                            VStack(alignment: .leading) {
                                Text(item.title)
                                if !FileManager.default.fileExists(atPath: item.path ?? "") {
                                    Text("Not installed on this Mac").font(.caption).foregroundStyle(.orange)
                                }
                            }
                        case .folder:
                            Image(systemName: "folder.fill").foregroundStyle(.blue).frame(width: 28)
                            Text(item.title)
                            Text("stack").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .onMove { from, to in update { $0.move(fromOffsets: from, toOffset: to) } }
                .onDelete { offsets in update { $0.remove(atOffsets: offsets) } }
            } header: {
                Text("Pinned items, left to right")
            } footer: {
                Text("Drag to reorder. Layout is stored in the “\(state.device.editingProfile.capitalized)” profile; a profile without a Dock layout leaves the Dock of lower layers untouched.")
            }
            if let result { Section { Text(result).font(.callout) } }
        }
        .navigationTitle("Dock Layout")
        .toolbar {
            ToolbarItemGroup {
                Menu {
                    Button("App…") { showPicker = true }
                    Button("Spacer") { update { $0.append(DockItem(kind: .spacer)) } }
                    Button("Folder…") { pickFolder() }
                } label: { Label("Add", systemImage: "plus") }
                Button { update { $0 = Setup.currentDock() } } label: {
                    Label("Import from this Mac", systemImage: "square.and.arrow.down")
                }
                Button {
                    let ok = Setup.applyDock(state.effective.dock ?? [], log: { _ in })
                    result = ok ? "Dock updated." : "Some Dock items could not be applied (is dockutil installed?)."
                } label: { Label("Apply to Dock", systemImage: "play.fill") }
                .buttonStyle(.glassProminent)
                .disabled(!state.editingIsActive)
            }
        }
        .sheet(isPresented: $showPicker) {
            AppPickerSheet { app in update { $0.append(DockItem(kind: .app, path: app.path)) } }
        }
    }

    private func update(_ change: (inout [DockItem]) -> Void) {
        var p = state.editing
        var list = p.dock ?? []
        change(&list)
        p.dock = list
        state.editing = p
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url {
            var path = url.path
            let home = NSHomeDirectory()
            if path.hasPrefix(home) { path = "~" + path.dropFirst(home.count) }
            update { $0.append(DockItem(kind: .folder, path: path)) }
        }
    }
}

// MARK: - Login apps

struct LoginAppsView: View {
    @EnvironmentObject var state: AppState
    @State private var showPicker = false
    @State private var result: String?

    var body: some View {
        Form {
            Section {
                ForEach(state.editing.startup.apps, id: \.self) { name in
                    HStack {
                        if let app = InstalledApp.scan().first(where: { $0.name == name }) { AppIcon(path: app.path) }
                        Text(name)
                        Spacer()
                        Button(role: .destructive) { update { $0.startup.apps.removeAll { $0 == name } } } label: {
                            Image(systemName: "minus.circle")
                        }.buttonStyle(.borderless)
                    }
                }
                Button("Add App…") { showPicker = true }
            } header: { Text("Open at login") }
            Section {
                Toggle("Close Finder windows after login", isOn: Binding(
                    get: { state.editing.startup.closeFinderWindows },
                    set: { v in update { $0.startup.closeFinderWindows = v } }))
            }
            Section {
                Button("Apply now") {
                    result = Setup.applyStartup(state.effective.startup, log: { _ in }) ? "Login apps updated." : "Could not load the launch agent."
                }
                .disabled(!state.editingIsActive)
                if let result { Text(result).foregroundStyle(.secondary) }
            } footer: {
                Text("Ignition installs one launch agent that opens these apps in order a few seconds after login.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Login Apps")
        .sheet(isPresented: $showPicker) {
            AppPickerSheet { app in update { if !$0.startup.apps.contains(app.name) { $0.startup.apps.append(app.name) } } }
        }
    }

    private func update(_ change: (inout Profile) -> Void) {
        var p = state.editing
        change(&p)
        state.editing = p
    }
}

// MARK: - Finder sidebar

struct FinderSidebarView: View {
    @EnvironmentObject var state: AppState
    @State private var result: String?

    private var items: [SidebarItem] { state.editing.finderSidebar ?? [] }

    var body: some View {
        List {
            Section {
                ForEach(items) { item in
                    HStack {
                        Image(systemName: "folder").foregroundStyle(.blue)
                        Text(item.name)
                        Spacer()
                        Text(item.path).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .onMove { from, to in update { $0.move(fromOffsets: from, toOffset: to) } }
                .onDelete { offsets in update { $0.remove(atOffsets: offsets) } }
            } footer: {
                Text("Favorites shown in the Finder sidebar. Requires the mysides tool, which Ignition installs with your packages.")
            }
            if let result { Section { Text(result) } }
        }
        .navigationTitle("Finder Sidebar")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    if panel.runModal() == .OK, let url = panel.url {
                        var path = url.path
                        if path.hasPrefix(NSHomeDirectory()) { path = "~" + path.dropFirst(NSHomeDirectory().count) }
                        update { $0.append(SidebarItem(name: url.lastPathComponent, path: path)) }
                    }
                } label: { Label("Add Folder", systemImage: "plus") }
                Button {
                    result = Setup.applySidebar(state.effective.finderSidebar ?? [], log: { _ in }) ? "Sidebar updated." : "Could not update the sidebar (is mysides installed?)."
                } label: { Label("Apply", systemImage: "play.fill") }
                .buttonStyle(.glassProminent)
                .disabled(!state.editingIsActive)
            }
        }
    }

    private func update(_ change: (inout [SidebarItem]) -> Void) {
        var p = state.editing
        var list = p.finderSidebar ?? []
        change(&list)
        p.finderSidebar = list
        state.editing = p
    }
}

// MARK: - Directories

struct DirectoriesView: View {
    @EnvironmentObject var state: AppState
    @State private var newPath = ""
    @State private var newComment = ""

    var body: some View {
        Form {
            Section {
                ForEach(state.editing.directories) { dir in
                    LabeledContent {
                        HStack {
                            if FileManager.default.fileExists(atPath: expandTilde(dir.path)) {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            }
                            Button(role: .destructive) {
                                var p = state.editing
                                p.directories.removeAll { $0.id == dir.id }
                                state.editing = p
                            } label: { Image(systemName: "minus.circle") }.buttonStyle(.borderless)
                        }
                    } label: {
                        VStack(alignment: .leading) {
                            Text(dir.path).font(.body.monospaced())
                            if let c = dir.comment, !c.isEmpty { Text(c).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
            } header: { Text("Folder structure") }
            Section("Add folder") {
                TextField("Path, e.g. ~/workspace/work", text: $newPath)
                TextField("What is it for? (optional)", text: $newComment)
                Button("Add") {
                    var p = state.editing
                    p.directories.append(DirectorySpec(path: newPath.trimmingCharacters(in: .whitespaces), comment: newComment.isEmpty ? nil : newComment))
                    state.editing = p
                    newPath = ""; newComment = ""
                }
                .disabled(newPath.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Section {
                Button("Create missing folders now") {
                    _ = Setup.createDirectories(state.effective.directories, log: { _ in })
                    state.objectWillChange.send()
                }
                .disabled(!state.editingIsActive)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Folders")
    }
}
