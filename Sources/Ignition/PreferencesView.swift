import SwiftUI
import AppKit
import IgnitionCore

/// Looks like a System Settings pane: grouped form, one section per topic.
struct PreferencesView: View {
    @EnvironmentObject var state: AppState
    let category: PrefCategory

    var body: some View {
        Form {
            ForEach(PreferenceCatalog.sections(in: category)) { section in
                Section(section.name) {
                    ForEach(section.defs) { def in PreferenceRow(def: def) }
                }
            }
            ForEach(ManualSettings.items(in: category)) { item in
                ManualSettingSection(item: item)
            }
            Section {
                Button("Reset all in \(category.title) to macOS defaults", role: .destructive) {
                    for def in PreferenceCatalog.defs(in: category) where state.isManaged(def) { state.reset(def) }
                }
                .disabled(!PreferenceCatalog.defs(in: category).contains { state.isManaged($0) })
            } footer: {
                Text("Rows with a profile pill are part of your profile and get applied on every Mac that uses it. Click the Apple pill to reset one to the default of this macOS version.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle(category.title)
        .onAppear { state.refreshLive() }
    }
}

struct PreferenceRow: View {
    @EnvironmentObject var state: AppState
    let def: PreferenceDef

    var body: some View {
        let origins = state.origins(for: def)
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(def.title).layoutPriority(1)
                    if def.scope == .system {
                        Image(systemName: "lock").font(.caption).foregroundStyle(.secondary)
                            .help("Needs administrator rights")
                    }
                    DefaultPill(def: def, origins: origins)
                    OriginPills(def: def, origins: origins)
                    notInProfile(origins)
                }
                if let detail = def.detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 12)
            control
        }
    }

    /// Value differs from the default but no profile has it: a "+" pill to add it.
    @ViewBuilder
    private func notInProfile(_ origins: [PrefOrigin]) -> some View {
        if origins.isEmpty, state.editingIsActive, def.osDefault != nil, state.value(for: def) != def.osDefault {
            addToProfile
        }
    }

    /// One "+" pill for a single active profile, a menu of profiles when there are several.
    @ViewBuilder
    private var addToProfile: some View {
        let names = state.layers
        if names.count == 1, let only = names.first {
            Button { state.adopt(def, into: only) } label: { plusPill }
                .buttonStyle(.plain)
                .help("Not in a profile yet – add to \(only.capitalized)")
        } else if names.count > 1 {
            Menu {
                ForEach(names, id: \.self) { name in
                    Button { state.adopt(def, into: name) } label: {
                        Label(name.capitalized, systemImage: state.icon(of: name) ?? "square.stack.3d.up")
                    }
                }
            } label: { plusPill }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Not in a profile yet – add to a profile")
        }
    }

    private var plusPill: some View {
        Image(systemName: "plus")
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Color.orange.opacity(0.2), in: .capsule)
            .overlay(Capsule().strokeBorder(Color.orange.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
            .foregroundStyle(.orange)
    }

    @ViewBuilder
    private var control: some View {
        let current = state.value(for: def)
        switch def.control {
        case .toggle:
            Toggle("", isOn: Binding(
                get: { current?.boolValue ?? false },
                set: { state.set(def, to: .bool($0)) }))
                .labelsHidden()
                .toggleStyle(.switch)
                .help("macOS default: \(state.defaultText(def))")
        case .slider(let range, let step, _):
            HStack(spacing: 6) {
                Text(state.formatted(def, current))
                    .monospacedDigit()
                    .frame(minWidth: 70, alignment: .trailing)
                Stepper("", value: Binding(
                    get: { current?.doubleValue ?? range.lowerBound },
                    set: { v in
                        if case .double? = def.osDefault { state.set(def, to: .double((v * 10).rounded() / 10)) }
                        else { state.set(def, to: .int(Int(v.rounded()))) }
                    }), in: range, step: step)
                    .labelsHidden()
            }
            .help("macOS default: \(state.defaultText(def))")
        case .picker(let options):
            Picker("", selection: Binding(
                get: { current ?? options.first?.value ?? .int(0) },
                set: { state.set(def, to: $0) })) {
                if let current, !options.contains(where: { $0.value == current }) {
                    Text(current.description).tag(current)
                }
                ForEach(options, id: \.self) { Text($0.label).tag($0.value) }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
            .help("macOS default: \(state.defaultText(def))")
        case .text(let placeholder):
            CommitTextField(placeholder: placeholder, initial: current?.stringValue ?? "") {
                state.set(def, to: .string($0))
            }
            .help("macOS default: \(state.defaultText(def))")
        }
    }
}

/// One pill per profile that sets the value, in the profile's colour, with its value inside.
/// Clicking a pill offers to remove that value from the profile.
struct OriginPills: View {
    @EnvironmentObject var state: AppState
    let def: PreferenceDef
    let origins: [PrefOrigin]

    var body: some View {
        ForEach(Array(origins.enumerated()), id: \.element.id) { index, origin in
            OriginPill(def: def, origins: origins, index: index)
        }
        if origins.contains(where: \.unsaved) {
            HStack(spacing: 3) {
                Image(systemName: "icloud.and.arrow.up")
                Text("Unsaved")
            }
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(Color.orange.opacity(0.18), in: .capsule)
            .foregroundStyle(.orange)
            .help("This change only exists on this Mac. Use Save to GitHub.")
        }
    }
}

struct OriginPill: View {
    @EnvironmentObject var state: AppState
    let def: PreferenceDef
    let origins: [PrefOrigin]
    let index: Int
    @State private var asking = false

    private var origin: PrefOrigin { origins[index] }

    var body: some View {
        let winner = index == origins.count - 1
        let editing = origin.profile == state.device.editingProfile
        let color = state.color(of: origin.profile)
        Button { asking = true } label: {
            HStack(spacing: 4) {
                if let icon = state.icon(of: origin.profile) {
                    Image(systemName: icon)
                } else {
                    Text(state.profileNames.count > 1 ? origin.profile.capitalized : "Saved")
                }
                Text(state.formatted(def, origin.value))
            }
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(color.opacity(winner ? 0.22 : 0.10), in: .capsule)
            .overlay(Capsule().stroke(color.opacity(editing ? 0.9 : 0), lineWidth: 1))
            .foregroundStyle(color.opacity(winner ? 1 : 0.6))
        }
        .buttonStyle(.plain)
        .help(helpText(winner: winner, editing: editing))
        .popover(isPresented: $asking, arrowEdge: .bottom) { confirm }
    }

    private func helpText(winner: Bool, editing: Bool) -> String {
        var text = "Stored in the \(origin.profile.capitalized) profile – click to remove"
        if !winner, let top = origins.last { text += " (overridden by \(top.profile.capitalized))" }
        if editing { text += ". This is the layer you are editing." }
        return text
    }

    private var confirm: some View {
        let below = index > 0 ? origins[index - 1] : nil
        return VStack(alignment: .leading, spacing: 10) {
            Text("Remove this value from \(origin.profile.capitalized)?").font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                GridRow { Text("Setting").foregroundStyle(.secondary); Text(def.title).bold() }
                GridRow { Text("Value").foregroundStyle(.secondary); Text(state.formatted(def, origin.value)).bold() }
                GridRow {
                    Text("Then").foregroundStyle(.secondary)
                    if let below {
                        Text("\(state.formatted(def, below.value)) (from \(below.profile.capitalized))").bold()
                    } else {
                        Text("\(state.defaultText(def)) (macOS default)").bold()
                    }
                }
            }
            HStack {
                Spacer()
                Button("Cancel") { asking = false }
                Button("Remove") { state.remove(def, from: origin.profile); asking = false }
                    .buttonStyle(.glassProminent)
            }
        }
        .padding(16)
        .frame(width: 320)
    }
}

/// Shows the macOS default; clicking it resets the setting (after asking).
struct DefaultPill: View {
    @EnvironmentObject var state: AppState
    let def: PreferenceDef
    let origins: [PrefOrigin]
    @State private var asking = false

    var body: some View {
        let current = state.value(for: def)
        let inEditing = state.isManagedByEditing(def)
        let differs = def.osDefault != nil && current != def.osDefault
        let canReset = inEditing || (origins.isEmpty && differs && state.editingIsActive)
        if (differs || inEditing) && def.osDefault != nil {
            Button { asking = true } label: {
                HStack(spacing: 3) {
                    Image(systemName: "apple.logo")
                    Text(state.defaultText(def))
                }
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15), in: .capsule)
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(!canReset)
            .help(canReset ? "macOS default – click to reset" : "macOS default")
            .popover(isPresented: $asking, arrowEdge: .bottom) { confirm }
        }
    }

    private var confirm: some View {
        let current = state.value(for: def)
        let others = origins.filter { $0.profile != state.device.editingProfile }
        return VStack(alignment: .leading, spacing: 10) {
            Text("Reset “\(def.title)”?").font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                GridRow { Text("Now").foregroundStyle(.secondary); Text(state.formatted(def, current)).bold() }
                GridRow {
                    Text("After").foregroundStyle(.secondary)
                    if let inherited = others.last {
                        Text("\(state.formatted(def, inherited.value)) (from \(inherited.profile.capitalized))").bold()
                    } else {
                        Text("\(state.defaultText(def)) (macOS default)").bold()
                    }
                }
            }
            if state.isManagedByEditing(def) {
                Text("It is removed from the \(state.device.editingProfile.capitalized) profile.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("Cancel") { asking = false }
                Button("Reset") { state.reset(def); asking = false }
                    .buttonStyle(.glassProminent)
            }
        }
        .padding(16)
        .frame(width: 300)
    }
}

/// Text field that only writes the preference when the user presses return.
struct CommitTextField: View {
    let placeholder: String
    let initial: String
    let commit: (String) -> Void
    @State private var text = ""

    var body: some View {
        TextField(placeholder, text: $text)
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .frame(width: 200)
            .onSubmit { commit(text) }
            .onAppear { text = initial }
            .onChange(of: initial) { _, new in text = new }
    }
}

/// A setting only the user can change, with a shortcut to the right System Settings pane.
struct ManualSettingSection: View {
    @EnvironmentObject var state: AppState
    let item: ManualSetting
    @State private var text = ""

    var body: some View {
        Section {
            Label {
                Text("Not scriptable – set it by hand in System Settings.")
            } icon: {
                Image(systemName: "hand.point.up.left")
            }
            .foregroundStyle(.secondary)
            Button {
                if let url = URL(string: item.settingsURL) { NSWorkspace.shared.open(url) }
            } label: {
                Label("Open System Settings", systemImage: "arrow.up.forward.app")
            }
            .buttonStyle(.glass)
            TextEditor(text: $text)
                .font(.body)
                .frame(minHeight: 80)
                .scrollContentBackground(.hidden)
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(item.placeholder).foregroundStyle(.tertiary).padding(.top, 8).padding(.leading, 5).allowsHitTesting(false)
                    }
                }
                .onChange(of: text) { _, new in
                    var p = state.editing
                    p.manualNotes[item.id] = new.isEmpty ? nil : new
                    state.editing = p
                }
        } header: {
            Text(item.title)
        } footer: {
            Text(item.detail)
        }
        .onAppear { text = state.viewEffective.manualNotes[item.id] ?? "" }
    }
}
