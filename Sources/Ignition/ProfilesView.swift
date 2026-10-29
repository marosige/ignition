import SwiftUI
import IgnitionCore

struct ProfilesView: View {
    @EnvironmentObject var state: AppState
    @State private var creating = false
    @State private var editing: String?

    /// Parents first, children indented below them.
    private var tree: [(name: String, depth: Int)] {
        var out: [(String, Int)] = []
        var seen = Set<String>()
        func visit(_ name: String, _ depth: Int) {
            guard seen.insert(name).inserted else { return }
            out.append((name, depth))
            for child in state.profileNames where state.profiles[child]?.extends == name { visit(child, depth + 1) }
        }
        for name in state.profileNames where state.profiles[name]?.extends == nil
            || !state.profileNames.contains(state.profiles[name]?.extends ?? "") { visit(name, 0) }
        for name in state.profileNames { visit(name, 0) }
        return out
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("A profile is a set of settings, software and files. Switch on the ones this Mac should follow; a profile that builds on another starts from it and adds its own things.")
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
                ForEach(tree, id: \.name) { entry in
                    ProfileCard(name: entry.name, depth: entry.depth) { editing = entry.name }
                }
                Button { creating = true } label: { Label("New Profile", systemImage: "plus") }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                    .padding(.top, 4)
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Profiles")
        .toolbar {
            ToolbarItem {
                Button { creating = true } label: { Label("New Profile", systemImage: "plus") }
                    .help("New profile")
            }
        }
        .sheet(isPresented: $creating) { NewProfileSheet() }
        .sheet(item: Binding(get: { editing.map(EditTarget.init) }, set: { editing = $0?.name })) { target in
            EditProfileSheet(name: target.name)
        }
    }
}

struct EditTarget: Identifiable {
    let name: String
    var id: String { name }
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

// MARK: - Card

/// One profile at a glance: how it looks, what it builds on, what is in it, and whether this Mac follows it.
struct ProfileCard: View {
    @EnvironmentObject var state: AppState
    let name: String
    let depth: Int
    let onEdit: () -> Void

    var body: some View {
        let profile = state.profiles[name] ?? Profile()
        let on = state.layers.contains(name)
        let needed = state.requiredBy(name)
        let color = state.color(of: name)
        let packages = profile.packages.brews.count + profile.packages.casks.count + profile.packages.mas.count
        HStack(alignment: .top, spacing: 8) {
            if depth > 0 {
                Image(systemName: "arrow.turn.down.right")
                    .foregroundStyle(.tertiary)
                    .padding(.top, 22)
                    .frame(width: CGFloat(depth) * 26, alignment: .trailing)
            }
            HStack(spacing: 16) {
                tile(color: color, icon: state.icon(of: name))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(name.capitalized).font(.title3.weight(.semibold))
                        if !on {
                            Text("Not on this Mac").font(.caption2.weight(.semibold))
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15), in: .capsule)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(profile.extends.map { "Builds on \($0.capitalized)" } ?? "Stand-alone")
                        .font(.callout).foregroundStyle(.secondary)
                    HStack(spacing: 14) {
                        stat("slider.horizontal.3", "\(profile.preferences.count)", "settings")
                        stat("shippingbox", "\(packages)", "packages")
                        stat("dock.rectangle", "\(profile.dock?.count ?? 0)", "Dock items")
                    }
                    .padding(.top, 2)
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 8) {
                    Toggle("", isOn: Binding(get: { on }, set: { _ in state.toggleActive(name) }))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .disabled(!needed.isEmpty)
                        .help(needed.isEmpty
                              ? (on ? "This Mac follows it – switch off" : "Make this Mac follow it")
                              : "\(needed.map(\.capitalized).joined(separator: ", ")) builds on it")
                    Text(on ? "On this Mac" : "Off").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular.tint(on ? color.opacity(0.10) : .clear), in: .rect(cornerRadius: 20))
            .opacity(on ? 1 : 0.8)
            .contentShape(.rect(cornerRadius: 20))
            .onTapGesture(perform: onEdit)
            .contextMenu {
                Button("Edit…", action: onEdit)
            }
        }
    }

    private func tile(color: Color, icon: String?) -> some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(color.opacity(0.22))
            .frame(width: 52, height: 52)
            .overlay {
                if let icon {
                    Image(systemName: icon).font(.system(size: 22, weight: .medium)).foregroundStyle(color)
                } else {
                    Text(String(name.prefix(1)).uppercased()).font(.title2.bold()).foregroundStyle(color)
                }
            }
    }

    private func stat(_ symbol: String, _ value: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).foregroundStyle(.secondary)
            Text(value).fontWeight(.semibold)
            Text(label).foregroundStyle(.secondary)
        }
        .font(.caption)
    }
}

// MARK: - Edit

/// Name, what it builds on, colour, icon – everything about how a profile looks and relates.
struct EditProfileSheet: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    let name: String
    @State private var confirmDelete = false

    var body: some View {
        let profile = state.profiles[name] ?? Profile()
        VStack(spacing: 0) {
            Form {
                Section {
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 14).fill(state.color(of: name).opacity(0.22))
                            .frame(width: 52, height: 52)
                            .overlay {
                                if let icon = state.icon(of: name) {
                                    Image(systemName: icon).font(.system(size: 22, weight: .medium)).foregroundStyle(state.color(of: name))
                                } else {
                                    Text(String(name.prefix(1)).uppercased()).font(.title2.bold()).foregroundStyle(state.color(of: name))
                                }
                            }
                        Text(name.capitalized).font(.title2.bold()).foregroundStyle(state.color(of: name))
                    }
                }
                Section("Relationship") {
                    Picker("Builds on", selection: Binding(
                        get: { profile.extends ?? "" },
                        set: { state.setParent($0.isEmpty ? nil : $0, of: name) })) {
                        Text("Nothing (stand-alone)").tag("")
                        ForEach(candidates, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                }
                Section("Look") {
                    LabeledContent("Colour") {
                        ColorSwatches(selected: state.profileColor(of: name)) { state.setColor($0, of: name) }
                    }
                    LabeledContent("Icon") {
                        IconChoices(selected: profile.icon, tint: state.color(of: name)) { state.setIcon($0, of: name) }
                    }
                }
                if name != "base" {
                    Section {
                        Button("Delete this profile…", role: .destructive) { confirmDelete = true }
                    } footer: {
                        Text("Removes its settings, packages and dotfiles from the repo on the next save. Nothing is uninstalled from this Mac.")
                    }
                }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(.glassProminent)
            }
            .padding()
        }
        .frame(width: 560, height: 540)
        .confirmationDialog("Delete the “\(name.capitalized)” profile?", isPresented: $confirmDelete) {
            Button("Delete profile", role: .destructive) {
                state.deleteProfile(name)
                dismiss()
            }
        }
    }

    /// Other profiles this one may build on (no loops).
    private var candidates: [String] {
        state.profileNames.filter { $0 != name && !state.resolve([$0]).contains(name) }
    }
}
