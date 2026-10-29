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
        let info = state.syncInfo
        let hasLocal = !state.changedFiles.isEmpty || (info?.ahead ?? 0) > 0
        let hasIncoming = (info?.behind ?? 0) > 0
        Form {
            Section { StatusCard() }
            if info?.kind == .conflict {
                Section {
                    ForEach(state.conflicts) { ConflictCard(conflict: $0) }
                } header: {
                    Text("Conflicts")
                } footer: {
                    Text("The same file was changed on this Mac and on GitHub. Pick the version to keep for each one.")
                }
            }
            if hasLocal && info?.kind != .conflict {
                Section {
                    ChangeList(side: .mine)
                } header: { Text("Changes to save") }
            }
            if hasIncoming && info?.kind != .conflict {
                Section {
                    ChangeList(side: .theirs)
                } header: { Text("New on GitHub") }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("GitHub Sync")
        .task { await state.checkSync() }
        .task(id: info?.conflicts ?? []) { if info?.kind == .conflict { await state.loadConflicts() } }
    }
}

enum ChangeSide: String, CaseIterable, Identifiable {
    case mine = "My changes", theirs = "On GitHub"
    var id: String { rawValue }
}

/// The changes between this Mac and GitHub in plain terms, grouped by profile.
/// Your own changes can be undone; settings open in the plan when clicked.
struct ChangeList: View {
    @EnvironmentObject var state: AppState
    let side: ChangeSide
    var onNavigate: (() -> Void)?
    @State private var changes: [PlanChange] = []
    @State private var loading = true

    private var reloadKey: String {
        "\(side.rawValue)|\(state.changedFiles)|\(state.syncInfo?.ahead ?? 0)|\(state.syncInfo?.behind ?? 0)"
    }

    private var profileNames: [String] {
        var seen = Set<String>()
        return changes.map(\.profile).filter { seen.insert($0).inserted }
    }

    var body: some View {
        Group {
            if loading && changes.isEmpty {
                ProgressView().controlSize(.small)
            } else if changes.isEmpty {
                Text(side == .mine ? "Nothing changed on this Mac" : "Nothing new on GitHub").foregroundStyle(.secondary)
            } else {
                ForEach(profileNames, id: \.self) { name in
                    HStack(spacing: 6) {
                        ProfileChip(name: name, showName: true)
                    }
                    ForEach(changes.filter { $0.profile == name }) { row($0) }
                }
            }
        }
        .task(id: reloadKey) { await load() }
    }

    private func row(_ change: PlanChange) -> some View {
        let color: Color = change.kind == .added ? .green : (change.kind == .removed ? .red : .orange)
        let mark = change.kind == .added ? "plus.circle.fill" : (change.kind == .removed ? "minus.circle.fill" : "pencil.circle.fill")
        let canOpen = side == .mine && change.prefID != nil
        return HStack(spacing: 10) {
            Image(systemName: mark).foregroundStyle(color)
            Image(systemName: change.symbol).foregroundStyle(.secondary).frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(change.title)
                if let detail = change.detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
            if side == .mine, change.undo != nil {
                Button {
                    state.undo(change)
                } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                .buttonStyle(.glass).controlSize(.small)
                .help("Put it back the way it is on GitHub")
            }
            if canOpen { Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary) }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard canOpen, let id = change.prefID else { return }
            onNavigate?()
            state.reveal(id)
        }
    }

    private func load() async {
        guard let sync = state.sync else { return }
        loading = true
        let diffSide: GitSync.DiffSide = side == .mine ? .mine : .theirs
        let folder = AppPaths.normalizeFolder(state.device.configFolder)
        let deltas = await Task.detached { AppState.loadDeltas(sync: sync, side: diffSide, folder: folder) }.value
        changes = deltas.flatMap { state.planChanges($0) }
        loading = false
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
            if !state.changedFiles.isEmpty {
                Divider()
                Text("Changed files (\(state.changedFiles.count))").font(.subheadline.bold())
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(state.changedFiles, id: \.self) { Text($0).font(.caption.monospaced()).lineLimit(1) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 120)
            }
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
            HStack {
                Button("Show local copy in Finder") { NSWorkspace.shared.activateFileViewerSelecting([AppPaths.repo]) }
                    .buttonStyle(.glass)
                Button("Technical diff…") { state.showDiff = true }
                    .buttonStyle(.glass)
            }
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
                    Text(kind == .conflict ? "Finish and save" : kind.buttonTitle(changes: state.changedFiles.count))
                }
                .buttonStyle(.glassProminent)
                .disabled(state.busy || (kind == .conflict && !(state.conflicts.count > 0
                    && state.conflicts.allSatisfy { state.conflictChoices[$0.file] != nil })))
                if kind == .conflict {
                    Button("Cancel merge", role: .destructive) { Task { await state.abortMerge() } }
                        .buttonStyle(.glass)
                }
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

/// Full-screen view of the same changes, with the raw diff for the curious.
struct DiffSheet: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var side: ChangeSide = .mine
    @State private var raw: [FileDiff] = []
    @State private var technical = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Changes").font(.headline)
                Picker("", selection: $side) { ForEach(ChangeSide.allCases) { Text($0.rawValue).tag($0) } }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 260)
                Spacer()
                Toggle("Technical", isOn: $technical).toggleStyle(.button).buttonStyle(.glass)
                Button("Done") { dismiss() }.buttonStyle(.glass)
            }
            .padding()
            Divider()
            if technical {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(raw) { file in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(file.path).font(.subheadline.bold())
                                DiffText(text: file.text)
                            }
                        }
                    }
                    .padding()
                }
            } else {
                Form { Section { ChangeList(side: side, onNavigate: { dismiss() }) } }
                    .formStyle(.grouped)
            }
        }
        .frame(width: 720, height: 560, alignment: .top)
        .task(id: side) {
            guard let sync = state.sync else { return }
            let s = side
            raw = await Task.detached { s == .mine ? sync.localDiff() : sync.incomingDiff() }.value
        }
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

/// One conflicted file: what each side did, and which version to keep.
struct ConflictCard: View {
    @EnvironmentObject var state: AppState
    let conflict: ConflictInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                if let profile = conflict.profile { ProfileChip(name: profile, showName: true) }
                Text(conflict.profile == nil ? conflict.file : "settings, software and layout")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            HStack(alignment: .top, spacing: 12) {
                side("This Mac", systemImage: "laptopcomputer", changes: conflict.mine, text: conflict.mineText, mine: true)
                side("GitHub", systemImage: "icloud", changes: conflict.theirs, text: conflict.theirsText, mine: false)
            }
        }
        .padding(.vertical, 6)
    }

    private func side(_ title: String, systemImage: String, changes: [PlanChange], text: String, mine: Bool) -> some View {
        let selected = state.conflictChoices[conflict.file] == mine
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: systemImage).font(.subheadline.bold())
                Spacer()
                if selected {
                    Button("Keeping this") { state.conflictChoices[conflict.file] = mine }.buttonStyle(.glassProminent)
                } else {
                    Button("Keep this") { state.conflictChoices[conflict.file] = mine }.buttonStyle(.glass)
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                if conflict.profile != nil {
                    if changes.isEmpty { Text("No changes of its own").font(.caption).foregroundStyle(.secondary) }
                    ForEach(changes.prefix(12)) { change in
                        HStack(spacing: 6) {
                            Image(systemName: change.kind == .added ? "plus.circle.fill" : (change.kind == .removed ? "minus.circle.fill" : "pencil.circle.fill"))
                                .foregroundStyle(change.kind == .added ? Color.green : (change.kind == .removed ? .red : .orange))
                            VStack(alignment: .leading, spacing: 0) {
                                Text(change.title).font(.caption)
                                if let detail = change.detail { Text(detail).font(.caption2).foregroundStyle(.secondary) }
                            }
                        }
                    }
                    if changes.count > 12 { Text("and \(changes.count - 12) more…").font(.caption).foregroundStyle(.secondary) }
                } else {
                    Text(text).font(.caption.monospaced()).lineLimit(8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(.quaternary.opacity(0.35), in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? Color.accentColor : .clear, lineWidth: 2))
        }
        .frame(maxWidth: .infinity)
    }
}
