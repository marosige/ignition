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
                        Text("Ignite a reproducible Mac.").font(.title3).foregroundStyle(.secondary)
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
    @State private var plan: [ApplyAction]?
    @State private var results: [ApplyStep: Bool] = [:]
    @State private var showOptions = false
    @State private var draft: Set<ApplyStep> = Set(ApplyStep.allCases)

    private var firstRun: Bool { state.device.lastApplied == nil }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                if !state.applyConfigured {
                    optionsSection(first: true)
                } else {
                    headerSection
                    planSections
                    reminderSection
                }
            }
            .formStyle(.grouped)
            .frame(maxHeight: .infinity)

            if running || !output.isEmpty { logView }
        }
        .navigationTitle("Apply to this Mac")
        .toolbar {
            if state.applyConfigured {
                ToolbarItem {
                    Button { draft = state.enabledSteps; showOptions = true } label: { Label("Options", systemImage: "gearshape") }
                        .help("Choose what Apply handles on this Mac")
                }
            }
        }
        .sheet(isPresented: $showOptions) {
            VStack(spacing: 0) {
                Form { optionsSection(first: false) }.formStyle(.grouped)
                HStack {
                    Button("Cancel") { showOptions = false }.buttonStyle(.glass)
                    Spacer()
                    Button("Save") { saveOptions(); showOptions = false }.buttonStyle(.glassProminent)
                }
                .padding()
            }
            .frame(width: 520, height: 520)
        }
        .task(id: "\(state.applyConfigured)|\(state.planFingerprint)|\(state.enabledSteps.count)") { await refreshPlan() }
    }

    // MARK: Sections

    private func optionsSection(first: Bool) -> some View {
        Section {
            ForEach(ApplyStep.allCases) { step in
                Toggle(isOn: Binding(get: { draft.contains(step) }, set: { on in
                    if on { draft.insert(step) } else { draft.remove(step) }
                })) {
                    VStack(alignment: .leading, spacing: 1) {
                        Label(step.title, systemImage: step.symbol)
                        Text(step.summary).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if first {
                Button("Continue") { saveOptions() }
                    .buttonStyle(.glassProminent).controlSize(.large)
                    .disabled(draft.isEmpty)
            }
        } header: {
            Text(first ? "What should Apply do on \(state.device.deviceName)?" : "Apply handles")
        } footer: {
            Text(first ? "Choose once – Ignition remembers it for this Mac. You can change it later from the gear in the toolbar."
                       : "Parts you switch off are never touched by Apply on this Mac.")
        }
    }

    private var headerSection: some View {
        Section {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { Task { await run() } } label: {
                    if running { ProgressView().controlSize(.small) }
                    else { Label(firstRun ? "Set up this Mac" : "Apply", systemImage: "play.fill") }
                }
                .buttonStyle(.glassProminent).controlSize(.large)
                .disabled(running || (plan?.isEmpty ?? true) || !state.hasConfig)
            }
        }
    }

    private var title: String {
        guard let plan else { return "Checking this Mac…" }
        if plan.isEmpty { return "Everything is in place" }
        return "\(plan.count) thing\(plan.count == 1 ? "" : "s") to do"
    }

    private var subtitle: String {
        if plan == nil { return "Comparing your profiles with what is on this Mac." }
        if plan?.isEmpty == true {
            return state.device.lastApplied.map { "Last applied \(ago($0)). Nothing differs from your profiles." } ?? "Nothing differs from your profiles."
        }
        return "Apply will do exactly this. Anything not listed is already the way your profiles say."
    }

    @ViewBuilder
    private var planSections: some View {
        if let plan {
            ForEach(ApplyStep.allCases.filter { step in plan.contains { $0.step == step } }) { step in
                let actions = plan.filter { $0.step == step }
                Section {
                    ForEach(actions) { action in
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill").foregroundStyle(.green)
                            if let symbol = action.symbol { Image(systemName: symbol).foregroundStyle(.secondary).frame(width: 20) }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(action.title)
                                if let detail = action.detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
                            }
                            Spacer()
                            if action.prefID != nil { Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary) }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { if let id = action.prefID { state.reveal(id) } }
                        .help(action.prefID != nil ? "Open this setting in the plan" : "")
                    }
                } header: {
                    HStack(spacing: 6) {
                        Label("\(step.title) (\(actions.count))", systemImage: step.symbol)
                        if let ok = results[step] {
                            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill").foregroundStyle(ok ? .green : .red)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var reminderSection: some View {
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

    private var logView: some View {
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

    // MARK: Actions

    private func saveOptions() {
        state.setApplySteps(draft)
        plan = nil
        Task { await refreshPlan() }
    }

    private func refreshPlan() async {
        guard state.applyConfigured else { return }
        state.refreshLive()
        plan = await state.computeApplyPlan()
    }

    @MainActor
    private func run() async {
        guard let planned = plan, !planned.isEmpty else { return }
        running = true
        output = []
        results = [:]
        let profile = state.effective
        let names = state.layers
        let live = LineSink { line in Task { @MainActor in output.append(line) } }

        for step in ApplyStep.allCases where planned.contains(where: { $0.step == step }) {
            output.append("▶ \(step.title)")
            let ok = await Task.detached(priority: .userInitiated) { () -> Bool in
                let log: Setup.Log = { live.send($0) }
                switch step {
                case .folders: return Setup.createDirectories(profile.directories, log: log)
                case .packages: return Setup.installPackages(profile.packages, log: log)
                case .dotfiles: return Setup.linkDotfiles(profiles: names, copyFiles: profile.copyFiles, log: log)
                case .preferences: return Setup.applyPreferences(profile.preferences, log: log)
                case .dock: return profile.dock.map { Setup.applyDock($0, log: log) } ?? true
                case .sidebar: return profile.finderSidebar.map { Setup.applySidebar($0, log: log) } ?? true
                case .startup: return Setup.applyStartup(profile.startup, log: log)
                }
            }.value
            results[step] = ok
            output.append(ok ? "✓ \(step.title) done\n" : "✗ \(step.title) had problems\n")
        }
        state.refreshLive()
        if results.values.contains(true) { state.markApplied() }
        running = false
        plan = await state.computeApplyPlan()
    }
}

/// Lets background work report lines back to the UI.
final class LineSink: @unchecked Sendable {
    private let handler: (String) -> Void
    init(_ handler: @escaping (String) -> Void) { self.handler = handler }
    func send(_ line: String) { handler(line) }
}
