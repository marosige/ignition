import SwiftUI
import AppKit
import IgnitionCore

private let relative: RelativeDateTimeFormatter = {
    let f = RelativeDateTimeFormatter()
    f.unitsStyle = .full
    return f
}()

func ago(_ date: Date) -> String { relative.localizedString(for: date, relativeTo: Date()) }

struct SyncView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Form {
            Section { StatusCard() }
            if !state.changedFiles.isEmpty {
                Section("Changes (\(state.changedFiles.count))") {
                    ForEach(state.changedFiles, id: \.self) { Text($0).font(.caption.monospaced()).lineLimit(1) }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("GitHub Sync")
        .task { await state.checkSync() }
    }
}

// MARK: - Connection (rarely touched, so it lives behind the gear)

struct ConnectionSheet: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showAdvanced = false

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Repository", text: $state.device.repository, prompt: Text("owner/repo or GitHub URL"))
                    SecureField("Fine-grained personal access token", text: $state.token)
                    TextField("Device name", text: $state.device.deviceName, prompt: Text("Mac mini"))
                    DisclosureGroup("Advanced", isExpanded: $showAdvanced) {
                        TextField("Config folder in the repo", text: $state.device.configFolder, prompt: Text("ignition"))
                        TextField("Branch", text: $state.device.branch, prompt: Text("Repository default"))
                        Text("A branch that does not exist yet is created on the first save.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("GitHub connection")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("The token needs access to this one repository with Contents: Read and write. It is stored in your Keychain. The device name appears in every commit, so you can see which Mac changed what.")
                        Text("Tip: save it in your password manager (username = repository, password = token) so it autofills on every device.")
                    }
                }
            }
            .formStyle(.grouped)
            HStack {
                Button("Done") { state.saveCredentials(); dismiss() }.buttonStyle(.glass)
                Spacer()
                Button(state.connected ? "Save and reconnect" : "Connect") {
                    Task {
                        await state.connect()
                        if state.connected, state.errorMessage == nil { dismiss() }
                    }
                }
                .buttonStyle(.glassProminent)
                .disabled(state.busy || state.device.repository.isEmpty || state.token.isEmpty)
            }
            .padding()
        }
        .frame(width: 520, height: 480)
    }
}

// MARK: - Info (for the curious)

struct SyncInfoPopover: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sync details").font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                row("Repository", GitSync.normalize(state.device.repository))
                row("Branch", state.syncInfo?.branch ?? (state.device.branch.isEmpty ? "default" : state.device.branch))
                row("Folder", state.device.configFolder)
                row("Local copy", AppPaths.repo.path)
            }
            .font(.caption)
            Divider()
            Text("History").font(.subheadline.bold())
            if state.commits.isEmpty {
                Text("No commits yet").font(.caption).foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(state.commits, id: \.self) { Text($0).font(.caption.monospaced()).lineLimit(1) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 220)
            }
            Button("Show local copy in Finder") { NSWorkspace.shared.activateFileViewerSelecting([AppPaths.repo]) }
                .buttonStyle(.glass)
        }
        .padding(16)
        .frame(width: 440)
    }

    private func row(_ key: String, _ value: String) -> some View {
        GridRow {
            Text(key).foregroundStyle(.secondary)
            Text(value.isEmpty ? "–" : value).textSelection(.enabled).lineLimit(2)
        }
    }
}

// MARK: - Status

struct StatusCard: View {
    @EnvironmentObject var state: AppState
    @State private var showInfo = false

    var body: some View {
        let kind = state.syncKind
        let info = state.syncInfo
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: kind.symbol)
                    .font(.system(size: 26))
                    .foregroundStyle(kind.color)
                    .frame(width: 52, height: 52)
                    .glassEffect(.regular.tint(kind.color.opacity(0.25)), in: .circle)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title(kind)).font(.title3.bold())
                    Text(kind.summary).foregroundStyle(.secondary)
                    if let info { detail(info) }
                }
                Spacer()
                HStack(spacing: 6) {
                    Button { Task { await state.checkSync() } } label: {
                        Image(systemName: "arrow.clockwise").symbolEffect(.rotate, isActive: state.checking)
                    }
                    .help("Check GitHub now")
                    .disabled(state.busy || !state.connected)
                    Button { showInfo = true } label: { Image(systemName: "info") }
                        .help("Details and history")
                        .popover(isPresented: $showInfo, arrowEdge: .bottom) { SyncInfoPopover() }
                    Button { state.showConnection = true } label: { Image(systemName: "gearshape") }
                        .help("Connection settings")
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
            }
            if let info, kind != .unconfigured, kind != .notConnected { versions(info) }
            HStack {
                Button { Task { await state.syncPrimary() } } label: {
                    Text(kind.buttonTitle(changes: state.changedFiles.count))
                }
                .buttonStyle(.glassProminent)
                .disabled(state.busy)

                Button("View changes") { state.showDiff = true }
                    .buttonStyle(.glass)
                    .disabled(info == nil || (info!.changedFiles.isEmpty && info!.ahead == 0 && info!.behind == 0))
            }
        }
        .padding(.vertical, 6)
    }

    private func title(_ kind: SyncKind) -> String {
        switch kind {
        case .upToDate: return "In sync"
        case .needsPush: return "Changes to save"
        case .needsPull: return "Updates available"
        case .diverged: return "Both sides changed"
        case .conflict: return "Conflict"
        case .error: return "GitHub unreachable"
        case .unconfigured: return "Not set up"
        case .notConnected: return "Not connected"
        }
    }

    @ViewBuilder
    private func detail(_ info: SyncInfo) -> some View {
        if let error = info.error {
            Text(error).font(.caption).foregroundStyle(.red).lineLimit(3)
        } else {
            if info.behind > 0, let remote = info.remote {
                Label("\(info.behind) update\(info.behind == 1 ? "" : "s") on GitHub, latest from \(remote.device), \(ago(remote.date))", systemImage: "arrow.down.circle")
                    .foregroundStyle(.orange)
            }
            let local = info.ahead + (info.changedFiles.isEmpty ? 0 : 1)
            if local > 0 {
                Label(info.changedFiles.isEmpty ? "\(info.ahead) saved change\(info.ahead == 1 ? "" : "s") not on GitHub yet"
                      : "\(info.changedFiles.count) unsaved change\(info.changedFiles.count == 1 ? "" : "s") on this Mac",
                      systemImage: "arrow.up.circle")
                    .foregroundStyle(.orange)
            }
            if info.kind == .upToDate {
                Label("No updates", systemImage: "checkmark").foregroundStyle(.green)
            }
        }
    }

    private func versions(_ info: SyncInfo) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 4) {
            GridRow {
                Text("This Mac").foregroundStyle(.secondary)
                Text(commit(info.local))
            }
            GridRow {
                Text("GitHub").foregroundStyle(.secondary)
                Text(info.remoteBranchExists ? commit(info.remote) : "branch “\(info.branch)” not on GitHub yet")
            }
            GridRow {
                Text("Checked").foregroundStyle(.secondary)
                Text(ago(info.checkedAt))
            }
        }
        .font(.caption)
    }

    private func commit(_ c: CommitInfo?) -> String {
        guard let c else { return "nothing saved yet" }
        return "\(c.hash) · \(c.device) · \(ago(c.date))"
    }
}

// MARK: - Diff

struct DiffSheet: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    enum Side: String, CaseIterable, Identifiable { case mine = "My changes", theirs = "On GitHub"; var id: String { rawValue } }
    @State private var side: Side = .mine
    @State private var diffs: [FileDiff] = []
    @State private var loading = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Changes").font(.headline)
                Picker("", selection: $side) { ForEach(Side.allCases) { Text($0.rawValue).tag($0) } }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 260)
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(.glass)
            }
            .padding()
            Divider()
            if loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if diffs.isEmpty {
                ContentUnavailableView(side == .mine ? "Nothing changed on this Mac" : "Nothing new on GitHub",
                                       systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(diffs) { file in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(file.path).font(.subheadline.bold())
                                DiffText(text: file.text)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 720, height: 560, alignment: .top)
        .task(id: side) { await load() }
    }

    private func load() async {
        guard let sync = state.sync else { return }
        loading = true
        let side = self.side
        diffs = await Task.detached { side == .mine ? sync.localDiff() : sync.incomingDiff() }.value
        loading = false
    }
}

struct DiffText: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                Text(line.isEmpty ? " " : line)
                    .font(.caption.monospaced())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 6)
                    .background(background(line))
            }
        }
        .textSelection(.enabled)
        .clipShape(.rect(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
    }

    private func background(_ line: String) -> Color {
        if line.hasPrefix("+") { return .green.opacity(0.18) }
        if line.hasPrefix("-") { return .red.opacity(0.18) }
        if line.hasPrefix("@@") { return .blue.opacity(0.12) }
        return .clear
    }
}

// MARK: - Conflicts

struct ConflictSheet: View {
    @EnvironmentObject var state: AppState
    @State private var files: [String] = []
    @State private var versions: [String: (mine: String, theirs: String)] = [:]
    @State private var choice: [String: Bool] = [:]   // true = keep this Mac's

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Resolve conflicts").font(.title2.bold())
                Text("The same file changed on this Mac and on GitHub. Pick the version to keep for each file.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            Divider()
            ScrollView {
                VStack(spacing: 22) {
                    ForEach(files, id: \.self) { file in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(file).font(.headline)
                            HStack(alignment: .top, spacing: 12) {
                                column("This Mac", versions[file]?.mine ?? "", selected: choice[file] == true) { choice[file] = true }
                                column("GitHub", versions[file]?.theirs ?? "", selected: choice[file] == false) { choice[file] = false }
                            }
                        }
                    }
                }
                .padding()
            }
            Divider()
            HStack {
                Button("Cancel merge", role: .destructive) { Task { await state.abortMerge() } }
                    .buttonStyle(.glass)
                Spacer()
                Text("\(choice.count) of \(files.count) chosen").foregroundStyle(.secondary)
                Button("Finish and save") { Task { await state.finishConflicts(choices: choice) } }
                    .buttonStyle(.glassProminent)
                    .disabled(files.isEmpty || choice.count < files.count || state.busy)
            }
            .padding()
        }
        .frame(width: 860, height: 620)
        .task { await load() }
    }

    private func column(_ title: String, _ text: String, selected: Bool, pick: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.subheadline.bold())
                Spacer()
                if selected {
                    Button("Keeping this") { pick() }.buttonStyle(.glassProminent)
                } else {
                    Button("Keep this") { pick() }.buttonStyle(.glass)
                }
            }
            ScrollView {
                Text(text).font(.caption.monospaced())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(8)
            }
            .frame(height: 170)
            .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color.accentColor : .clear, lineWidth: 2))
        }
        .frame(maxWidth: .infinity)
    }

    private func load() async {
        guard let sync = state.sync else { return }
        let result = await Task.detached { () -> ([String], [String: (mine: String, theirs: String)]) in
            let list = sync.conflicts()
            var v: [String: (mine: String, theirs: String)] = [:]
            for f in list { v[f] = sync.conflictVersions(f) }
            return (list, v)
        }.value
        files = result.0
        versions = result.1
    }
}
