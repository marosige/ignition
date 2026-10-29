import SwiftUI
import AppKit
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
                        Text("Ignite your Mac.").font(.title3).foregroundStyle(.secondary)
                    }
                }

                if !state.connected {
                    card("1  Connect your private config repo", "Paste the repository and a fine-grained access token (Contents: read & write). Your whole setup lives in a folder of that repo (default `ignition/`).", "icloud.and.arrow.down", goTo: .sync)
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
                         "Active profiles: " + state.layers.map(\.capitalized).joined(separator: " → ") + ". Change settings anywhere in the sidebar, then use Save to GitHub; on your other Macs pull and Apply.",
                         "laptopcomputer", goTo: .sync)
                    if state.device.lastApplied == nil {
                        card("Set up this Mac", "Nothing has been applied to this Mac yet. Apply installs your packages, links your dotfiles and sets everything in the plan.", "play.circle", goTo: .apply)
                    } else if !state.pending.isEmpty {
                        card("\(state.pending.count) setting\(state.pending.count == 1 ? "" : "s") to apply", "This Mac differs from the plan. Review and apply the changes.", "exclamationmark.circle", goTo: .apply)
                    }
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
            stat("\(Dotfiles.scan(profiles: state.layers, copyFiles: e.copyFiles).count)", "dotfiles", "doc.text")
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

    private func card(_ title: String, _ text: String, _ icon: String, goTo: Destination? = nil) -> some View {
        let content = HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.title2).frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(text).foregroundStyle(.secondary).multilineTextAlignment(.leading)
            }
            if goTo != nil {
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
        return Group {
            if let goTo {
                Button { state.navigate(to: goTo) } label: { content }
                    .buttonStyle(.plain)
                    .contentShape(.rect(cornerRadius: 18))
            } else {
                content
            }
        }
    }
}

// MARK: - Sync

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
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(state.device.lastApplied == nil ? "This Mac has not been set up yet" : "Make this Mac match the plan")
                                .font(.headline)
                            Text(state.device.lastApplied.map { "Last applied \(ago($0))" }
                                 ?? "Apply installs your packages, links your dotfiles and sets everything in the plan.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { Task { await run() } } label: {
                            if running { ProgressView().controlSize(.small) }
                            else { Label(state.device.lastApplied == nil ? "Set up this Mac" : "Apply", systemImage: "play.fill") }
                        }
                        .buttonStyle(.glassProminent).controlSize(.large)
                        .disabled(running || selected.isEmpty || !state.hasConfig)
                    }
                }
                let changes = state.pending
                if !changes.isEmpty {
                    Section {
                        ForEach(changes) { change in
                            HStack {
                                Text(change.def.title)
                                Spacer()
                                Text(state.formatted(change.def, change.from)).foregroundStyle(.secondary)
                                Image(systemName: "arrow.right").font(.caption).foregroundStyle(.tertiary)
                                Text(state.formatted(change.def, change.to)).bold()
                            }
                        }
                    } header: {
                        Text("Settings that will change (\(changes.count))")
                    } footer: {
                        Text("Packages, dotfiles, Dock and the rest are checked and fixed while applying.")
                    }
                }
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
                    Text("Turn \(state.device.deviceName) into your \(state.layers.map(\.capitalized).joined(separator: " + ")) Mac")
                } footer: {
                    Text("Settings that need administrator rights ask for your password once.")
                }
                let reminders = ManualSettings.all.filter { state.effective.manualNotes[$0.id] != nil }
                if !reminders.isEmpty {
                    Section {
                        ForEach(reminders) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(item.title).font(.headline)
                                    Spacer()
                                    Button("Open System Settings") {
                                        if let url = URL(string: item.settingsURL) { NSWorkspace.shared.open(url) }
                                    }.buttonStyle(.glass)
                                }
                                Text(state.effective.manualNotes[item.id] ?? "").foregroundStyle(.secondary)
                            }
                        }
                    } header: { Text("Do by hand") } footer: { Text("macOS does not allow scripts to change these.") }
                }
            }
            .formStyle(.grouped)
            .frame(maxHeight: .infinity)

            if running || !output.isEmpty {
            ScrollViewReader { proxy in
                ScrollView {
                    Text(output.joined(separator: "\n"))
                        .font(.caption.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(10)
                        .id("end")
                }
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary))
                .padding([.horizontal, .bottom])
                .onChange(of: output.count) { _, _ in proxy.scrollTo("end", anchor: .bottom) }
            }
            .frame(height: 200)
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
        let names = state.layers
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
        if results.values.contains(true) { state.markApplied() }
        running = false
    }
}

/// Lets background work report lines back to the UI.
final class LineSink: @unchecked Sendable {
    private let handler: (String) -> Void
    init(_ handler: @escaping (String) -> Void) { self.handler = handler }
    func send(_ line: String) { handler(line) }
}
