import SwiftUI
import IgnitionCore

struct ProfilesView: View {
    @EnvironmentObject var state: AppState
    @State private var deleting: String?

    var body: some View {
        Form {
            Section {
                ForEach(state.profileNames, id: \.self) { name in
                    ProfileRow(name: name, askDelete: { deleting = name })
                }
            } header: {
                Text("Profiles")
            } footer: {
                Text("A profile can build on another one: Work building on Base starts from everything in Base and adds or overrides things. Switching a profile on switches on what it builds on. “Edit” lets you change any profile, even one that is not on this Mac – nothing is applied here until it is switched on.")
            }
            Section("New profile") { NewProfileRow() }
        }
        .formStyle(.grouped)
        .navigationTitle("Profiles")
        .confirmationDialog("Delete the “\((deleting ?? "").capitalized)” profile?", isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Delete profile", role: .destructive) {
                if let name = deleting { state.deleteProfile(name) }
                deleting = nil
            }
        } message: {
            Text("Its settings, packages and dotfiles are removed from the repo on the next save. Nothing is uninstalled from this Mac.")
        }
    }
}

struct ProfileRow: View {
    @EnvironmentObject var state: AppState
    let name: String
    let askDelete: () -> Void

    var body: some View {
        let profile = state.profiles[name] ?? Profile()
        let on = state.layers.contains(name)
        let needed = state.requiredBy(name)
        let packages = profile.packages.brews.count + profile.packages.casks.count + profile.packages.mas.count
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(name.capitalized).font(.headline)
                    if state.device.editingProfile == name { pill("Editing", .accentColor) }
                    if !on { pill("Not on this Mac", .secondary) }
                }
                HStack(spacing: 6) {
                    Text("Builds on").font(.caption).foregroundStyle(.secondary)
                    Picker("", selection: Binding(
                        get: { profile.extends ?? "" },
                        set: { state.setParent($0.isEmpty ? nil : $0, of: name) })) {
                        Text("Nothing (stand-alone)").tag("")
                        ForEach(candidates(for: name), id: \.self) { Text($0.capitalized).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .controlSize(.small)
                    .fixedSize()
                }
                Text("\(profile.preferences.count) settings · \(packages) packages · \(profile.dock?.count ?? 0) Dock items")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(state.device.editingProfile == name ? "Editing" : "Edit") {
                state.device.editingProfile = name
                state.saveDevice()
            }
            .buttonStyle(.glass)
            .disabled(state.device.editingProfile == name)
            Button(role: .destructive) { askDelete() } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless)
                .opacity(name == "base" ? 0 : 1)
                .disabled(name == "base")
            Toggle("", isOn: Binding(
                get: { on },
                set: { _ in state.toggleActive(name) }))
                .labelsHidden()
                .toggleStyle(.switch)
                .disabled(!needed.isEmpty)
                .help(needed.isEmpty
                      ? (on ? "Switch off on this Mac" : "Use this profile on this Mac")
                      : "\(needed.map(\.capitalized).joined(separator: ", ")) builds on it")
        }
        .padding(.vertical, 2)
    }

    /// Other profiles this one may build on (no loops).
    private func candidates(for name: String) -> [String] {
        state.profileNames.filter { $0 != name && !state.resolve([$0]).contains(name) }
    }

    private func pill(_ text: String, _ color: Color) -> some View {
        Text(text).font(.caption2.weight(.semibold))
            .padding(.horizontal, 6).padding(.vertical, 1)
            .background(color.opacity(0.18), in: .capsule)
            .foregroundStyle(color)
    }
}
