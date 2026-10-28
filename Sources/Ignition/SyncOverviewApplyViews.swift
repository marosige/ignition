import SwiftUI
import IgnitionCore

// MARK: - Overview

struct OverviewView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 18) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 40)).foregroundStyle(.orange)
                        .frame(width: 84, height: 84)
                        .glassEffect(.regular, in: .rect(cornerRadius: 24))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ignition").font(.largeTitle.bold())
                        Text("Your Mac, reproducible.").foregroundStyle(.secondary)
                    }
                }

                if !state.connected {
                    card("1  Connect your private config repo", "Paste the repository and a fine-grained access token (Contents: read & write). Your whole setup lives in the `ignition/` folder of that repo.", "icloud.and.arrow.down")
                } else if !state.hasConfig {
                    VStack(alignment: .leading, spacing: 10) {
                        card("2  Start from a configuration", "The repo has no Ignition data yet. Begin with the bundled starter (the original author’s Base, Personal and Work profiles) or an empty Base profile.", "square.and.arrow.down")
                        HStack {
                            Button("Load starter configuration") { state.loadStarterConfig() }.buttonStyle(.glassProminent)
                            Button("Empty Base profile") { state.createProfile("base"); state.reloadProfiles() }.buttonStyle(.glass)
                        }
                    }
                } else {
                    card("This Mac is “\(state.device.deviceName)”",
                         "Active profiles: " + state.device.activeProfiles.map(\.capitalized).joined(separator: " → ") + ". Change settings anywhere in the sidebar, then use Save to GitHub; on your other Macs pull and Apply.",
                         "laptopcomputer")
                    summary
                }
            }
            .padding(28)
            .frame(maxWidth: 720, alignment: .leading)
        }
        .navigationTitle("Overview")
    }

    private var summary: some View {
        let e = state.effective
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            stat("\(e.preferences.count)", "saved settings", "slider.horizontal.3")
            stat("\((e.dock ?? []).filter { $0.kind == .app }.count)", "apps in Dock", "dock.rectangle")
            stat("\(e.packages.casks.count + e.packages.brews.count + e.packages.mas.count)", "packages", "shippingbox")
            stat("\(Dotfiles.scan(profiles: state.device.activeProfiles, copyFiles: e.copyFiles).count)", "dotfiles", "doc.text")
            stat("\(e.directories.count)", "folders", "folder")
            stat("\(e.startup.apps.count)", "login apps", "power")
        }
    }

    private func stat(_ value: String, _ label: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).foregroundStyle(.secondary)
            Text(value).font(.title.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    private func card(_ title: String, _ text: String, _ icon: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.title2).frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(text).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }
}

// MARK: - Sync

struct SyncView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Form {
            Section {
                TextField("Repository", text: $state.device.repository, prompt: Text("owner/repo or GitHub URL"))
                SecureField("Fine-grained personal access token", text: $state.token)
                TextField("Device name", text: $state.device.deviceName, prompt: Text("Mac mini"))
            } header: {
                Text("Connection")
            } footer: {
                Text("The token needs access to this one repository with Contents: Read and write. It is stored in your Keychain. The device name appears in every commit, so you can see which Mac changed what.")
            }
            Section {
                HStack {
                    Button(state.connected ? "Reconnect" : "Connect") { Task { await state.connect() } }
                        .buttonStyle(.glassProminent)
                    Button("Pull") { Task { await state.pull() } }.disabled(!state.connected || state.busy)
                    Button("Save to GitHub") { Task { await state.push() } }.disabled(!state.connected || state.busy)
                }
            }
            if !state.changedFiles.isEmpty {
                Section("Waiting to be saved (\(state.changedFiles.count))") {
                    ForEach(state.changedFiles, id: \.self) { Text($0).font(.caption.monospaced()) }
                }
            }
            if !state.commits.isEmpty {
                Section("History") {
                    ForEach(state.commits, id: \.self) { Text($0).font(.caption.monospaced()).lineLimit(1) }
                }
            }
            Section("Profiles") {
                ForEach(state.profileNames, id: \.self) { name in
                    Toggle(isOn: Binding(get: { state.device.activeProfiles.contains(name) }, set: { _ in state.toggleActive(name) })) {
                        VStack(alignment: .leading) {
                            Text(name.capitalized)
                            Text(name == "base" ? "Shared by every Mac" : "Layered on top of Base").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .disabled(name == "base")
                }
                NewProfileRow()
            }
        }
        .formStyle(.grouped)
        .navigationTitle("GitHub Sync")
        .onChange(of: state.device.deviceName) { _, _ in state.saveDevice() }
        .onAppear { state.refreshChanges() }
    }
}

struct NewProfileRow: View {
    @EnvironmentObject var state: AppState
    @State private var name = ""
    var body: some View {
        HStack {
            TextField("New profile", text: $name, prompt: Text("e.g. travel"))
            Button("Create") { state.createProfile(name); name = "" }.disabled(name.isEmpty)
        }
    }
}

// MARK: - Apply

struct ApplyView: View {
    @EnvironmentObject var state: AppState
    @State private var running = false
    @State private var output: [String] = []
    @State private var results: [String: Bool] = [:]
    @State private var selected: Set<String> = Set(ApplyView.steps.map { $0.0 })

    static let steps: [(String, String, String)] = [
        ("folders", "Create folders", "folder.badge.plus"),
        ("packages", "Install packages", "shippingbox"),
        ("dotfiles", "Link dotfiles", "doc.text"),
        ("preferences", "Apply settings", "slider.horizontal.3"),
        ("dock", "Arrange the Dock", "dock.rectangle"),
        ("sidebar", "Set the Finder sidebar", "sidebar.left"),
        ("startup", "Set login apps", "power"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    ForEach(Self.steps, id: \.0) { id, title, icon in
                        HStack {
                            Toggle(isOn: Binding(get: { selected.contains(id) }, set: { on in
                                if on { selected.insert(id) } else { selected.remove(id) }
                            })) { Label(title, systemImage: icon) }
                            if let ok = results[id] {
                                Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill").foregroundStyle(ok ? .green : .red)
                            }
                        }
                    }
                } header: {
                    Text("Turn \(state.device.deviceName) into your \(state.device.activeProfiles.joined(separator: " + ")) Mac")
                } footer: {
                    Text("Settings that need administrator rights ask for your password once.")
                }
                Section {
                    Button { Task { await run() } } label: {
                        if running { ProgressView().controlSize(.small) } else { Text("Apply selected") }
                    }
                    .buttonStyle(.glassProminent).disabled(running || selected.isEmpty || !state.hasConfig)
                }
            }
            .formStyle(.grouped)
            .frame(maxHeight: 420)

            ScrollViewReader { proxy in
                ScrollView {
                    Text(output.joined(separator: "\n"))
                        .font(.caption.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(10)
                        .id("end")
                }
                .background(.black.opacity(0.06), in: .rect(cornerRadius: 12))
                .padding([.horizontal, .bottom])
                .onChange(of: output.count) { _, _ in proxy.scrollTo("end", anchor: .bottom) }
            }
        }
        .navigationTitle("Apply to this Mac")
    }

    @MainActor
    private func run() async {
        running = true
        output = []
        results = [:]
        let profile = state.effective
        let names = state.device.activeProfiles
        let selected = self.selected
        let live = LineSink { line in Task { @MainActor in output.append(line) } }

        for (id, title, _) in Self.steps where selected.contains(id) {
            output.append("▶ \(title)")
            let ok = await Task.detached(priority: .userInitiated) { () -> Bool in
                let log: Setup.Log = { live.send($0) }
                switch id {
                case "folders": return Setup.createDirectories(profile.directories, log: log)
                case "packages": return Setup.installPackages(profile.packages, log: log)
                case "dotfiles": return Setup.linkDotfiles(profiles: names, copyFiles: profile.copyFiles, log: log)
                case "preferences": return Setup.applyPreferences(profile.preferences, log: log)
                case "dock": return profile.dock.map { Setup.applyDock($0, log: log) } ?? true
                case "sidebar": return profile.finderSidebar.map { Setup.applySidebar($0, log: log) } ?? true
                case "startup": return Setup.applyStartup(profile.startup, log: log)
                default: return true
                }
            }.value
            results[id] = ok
            output.append(ok ? "✓ \(title) done\n" : "✗ \(title) had problems\n")
        }
        state.refreshLive()
        running = false
    }
}

/// Lets background work report lines back to the UI.
final class LineSink: @unchecked Sendable {
    private let handler: (String) -> Void
    init(_ handler: @escaping (String) -> Void) { self.handler = handler }
    func send(_ line: String) { handler(line) }
}
