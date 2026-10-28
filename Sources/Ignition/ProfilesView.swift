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
                Text("Profiles on \(state.device.deviceName)")
            } footer: {
                Text("Profiles are layers. Base applies to every Mac; the others are switched on per Mac and win over Base when both set the same thing. Which profile an edit lands in is chosen in the toolbar (“Saving to …”).")
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
        let active = state.device.activeProfiles.contains(name)
        let packages = profile.packages.brews.count + profile.packages.casks.count + profile.packages.mas.count
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(name.capitalized).font(.headline)
                    if state.device.editingProfile == name {
                        Text("Saving here").font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.18), in: .capsule)
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Text(name == "base" ? "Shared by every Mac" : "Layered on top of Base")
                    .font(.caption).foregroundStyle(.secondary)
                Text("\(profile.preferences.count) settings · \(packages) packages · \(profile.dock?.count ?? 0) Dock items")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Save changes here") { state.device.editingProfile = name; state.saveDevice() }
                .buttonStyle(.glass)
                .disabled(state.device.editingProfile == name || !active)
                .help(active ? "New edits go into this profile" : "Turn the profile on first")
            if name != "base" {
                Button(role: .destructive) { askDelete() } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
            }
            Toggle("", isOn: Binding(get: { active }, set: { _ in state.toggleActive(name) }))
                .labelsHidden()
                .toggleStyle(.switch)
                .disabled(name == "base")
                .help(name == "base" ? "Base is always on" : "Use this profile on this Mac")
        }
        .padding(.vertical, 2)
    }
}
