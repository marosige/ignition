import SwiftUI
import IgnitionCore

struct ProfilesView: View {
    @EnvironmentObject var state: AppState
    @State private var deleting: String?
    @State private var creating = false

    var body: some View {
        Form {
            Section {
                ForEach(state.profileNames, id: \.self) { name in
                    ProfileRow(name: name, askDelete: { deleting = name })
                }
            } header: {
                Text("Profiles")
            } footer: {
                Text("A profile can build on another one: Work building on Base starts from everything in Base and adds or overrides things. Switching a profile on switches on what it builds on. Settings and software let you add things to any profile, even one that is not on this Mac – nothing is applied here until it is switched on.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Profiles")
        .toolbar {
            ToolbarItem {
                Button { creating = true } label: { Label("New Profile", systemImage: "plus") }
                    .help("New profile")
            }
        }
        .sheet(isPresented: $creating) { NewProfileSheet() }
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

// MARK: - Pickers

struct ColorSwatches: View {
    let selected: ProfileColor?
    let onPick: (ProfileColor) -> Void

    var body: some View {
        HStack(spacing: 5) {
            ForEach(ProfileColor.allCases) { c in
                Button { onPick(c) } label: {
                    Circle().fill(c.color).frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color.primary.opacity(selected == c ? 0.8 : 0), lineWidth: 2))
                }
                .buttonStyle(.plain)
                .help(c.title)
            }
        }
    }
}

struct IconChoices: View {
    let selected: String?
    let tint: Color
    let onPick: (String?) -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button { onPick(nil) } label: {
                Text("Aa").font(.caption2.weight(.semibold))
                    .frame(width: 22, height: 22)
                    .background(Color.secondary.opacity(selected == nil ? 0.3 : 0.1), in: .rect(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("No icon – show the name")
            ForEach(ProfileIcons.all, id: \.symbol) { item in
                Button { onPick(item.symbol) } label: {
                    Image(systemName: item.symbol).font(.caption)
                        .frame(width: 22, height: 22)
                        .background(tint.opacity(selected == item.symbol ? 0.3 : 0), in: .rect(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help(item.label)
            }
        }
    }
}

// MARK: - New profile

struct NewProfileSheet: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var parent = ""
    @State private var color: ProfileColor = .violet
    @State private var icon: String?

    private var taken: Bool {
        let slug = name.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return state.profileNames.contains(slug)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("New profile") {
                    TextField("Name", text: $name, prompt: Text("e.g. School"))
                    if taken { Text("A profile with this name already exists.").font(.caption).foregroundStyle(.red) }
                    Picker("Builds on", selection: $parent) {
                        Text("Nothing (stand-alone)").tag("")
                        ForEach(state.profileNames, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                    LabeledContent("Colour") { ColorSwatches(selected: color) { color = $0 } }
                    LabeledContent("Icon") { IconChoices(selected: icon, tint: color.color) { icon = $0 } }
                }
                Section("Preview") {
                    HStack(spacing: 8) {
                        if let icon { Image(systemName: icon) }
                        Text(name.isEmpty ? "Name" : name.capitalized).font(.headline)
                    }
                    .foregroundStyle(color.color)
                }
            }
            .formStyle(.grouped)
            HStack {
                Button("Cancel") { dismiss() }.buttonStyle(.glass)
                Spacer()
                Button("Create") {
                    if state.createProfile(name, extends: parent.isEmpty ? nil : parent, color: color, icon: icon) { dismiss() }
                }
                .buttonStyle(.glassProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || taken)
            }
            .padding()
        }
        .frame(width: 520, height: 520)
        .onAppear { parent = state.profileNames.contains("base") ? "base" : "" }
    }
}

// MARK: - Row

struct ProfileRow: View {
    @EnvironmentObject var state: AppState
    let name: String
    let askDelete: () -> Void

    var body: some View {
        let profile = state.profiles[name] ?? Profile()
        let on = state.layers.contains(name)
        let needed = state.requiredBy(name)
        let packages = profile.packages.brews.count + profile.packages.casks.count + profile.packages.mas.count
        let selectedColor = state.profileColor(of: name)
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    if let icon = state.icon(of: name) {
                        Image(systemName: icon).foregroundStyle(state.color(of: name))
                    }
                    Text(name.capitalized).font(.headline).foregroundStyle(state.color(of: name))
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
                HStack(spacing: 8) {
                    Text("Colour").font(.caption).foregroundStyle(.secondary)
                    ColorSwatches(selected: selectedColor) { state.setColor($0, of: name) }
                }
                HStack(spacing: 8) {
                    Text("Icon").font(.caption).foregroundStyle(.secondary)
                    IconChoices(selected: profile.icon, tint: state.color(of: name)) { state.setIcon($0, of: name) }
                }
                Text("\(profile.preferences.count) settings · \(packages) packages · \(profile.dock?.count ?? 0) Dock items")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
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
