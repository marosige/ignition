import SwiftUI
import AppKit
import IgnitionCore

struct DotfilesView: View {
    @EnvironmentObject var state: AppState
    @State private var entries: [DotfileEntry] = []
    @State private var suggestions: [String] = []
    @State private var message: String?

    var body: some View {
        List {
            Section {
                if entries.isEmpty {
                    Text("No dotfiles tracked yet. Add one from the suggestions below or pick any file in your home folder.")
                        .foregroundStyle(.secondary)
                }
                ForEach(entries) { entry in
                    HStack(spacing: 10) {
                        Image(systemName: icon(entry.state)).foregroundStyle(color(entry.state))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("~/" + entry.relativePath).font(.body.monospaced())
                            Text("\(entry.profile.capitalized) · \(label(entry))").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if entry.state != .linked && entry.state != .copied {
                            Button("Link") { run { try Dotfiles.apply(entry, log: { _ in }) } }.buttonStyle(.glass)
                        }
                        Button { NSWorkspace.shared.open(entry.source) } label: { Image(systemName: "square.and.pencil") }
                            .buttonStyle(.borderless).help("Open in your editor")
                        Button(role: .destructive) { run { try Dotfiles.remove(entry) } } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless).help("Stop tracking")
                    }
                }
            } header: {
                Text("Tracked files")
            } footer: {
                Text("Files live in the config repo and are symlinked into your home folder, so editing ~/.zshrc edits the repo. Don’t track secrets – the repo is only as private as your GitHub account.")
            }
            if !suggestions.isEmpty {
                Section("Found on this Mac") {
                    ForEach(suggestions, id: \.self) { rel in
                        HStack {
                            Text("~/" + rel).font(.body.monospaced())
                            Spacer()
                            Button("Track") { track(URL(fileURLWithPath: NSHomeDirectory() + "/" + rel)) }.buttonStyle(.glass)
                        }
                    }
                }
            }
            if let message { Section { Text(message).foregroundStyle(.secondary) } }
        }
        .navigationTitle("Dotfiles")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    let panel = NSOpenPanel()
                    panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory())
                    panel.canChooseFiles = true
                    panel.canChooseDirectories = true
                    panel.showsHiddenFiles = true
                    if panel.runModal() == .OK, let url = panel.url { track(url) }
                } label: { Label("Track File or Folder…", systemImage: "plus") }
                Button {
                    run {
                        _ = Setup.linkDotfiles(profiles: state.layers, copyFiles: state.effective.copyFiles, log: { _ in })
                    }
                } label: { Label("Link All", systemImage: "link") }
                .buttonStyle(.glassProminent)
                .disabled(!state.editingIsActive)
            }
        }
        .onAppear(perform: reload)
    }

    private func reload() {
        entries = Dotfiles.scan(profiles: state.viewLayers, copyFiles: state.viewEffective.copyFiles)
        suggestions = Dotfiles.suggestions(tracked: Set(entries.map(\.relativePath)))
    }

    private func run(_ body: () throws -> Void) {
        do { try body() } catch { state.errorMessage = error.localizedDescription }
        reload()
        state.refreshChanges()
    }

    private func track(_ url: URL) {
        run {
            let rels = try Dotfiles.adopt(url, into: state.device.editingProfile, copy: !state.editingIsActive)
            message = "Tracking \(rels.count) file\(rels.count == 1 ? "" : "s") in \(state.device.editingProfile.capitalized)."
        }
    }

    private func label(_ e: DotfileEntry) -> String {
        switch e.state {
        case .linked: return "linked"
        case .copied: return "copied, up to date"
        case .missing: return "not on this Mac yet"
        case .conflict: return "a different file exists (will be backed up)"
        case .outdatedCopy: return "copy differs from repo"
        }
    }
    private func icon(_ s: DotfileEntry.State) -> String {
        switch s {
        case .linked, .copied: return "checkmark.circle.fill"
        case .missing: return "circle.dashed"
        case .conflict, .outdatedCopy: return "exclamationmark.triangle.fill"
        }
    }
    private func color(_ s: DotfileEntry.State) -> Color {
        switch s {
        case .linked, .copied: return .green
        case .missing: return .secondary
        case .conflict, .outdatedCopy: return .orange
        }
    }
}
