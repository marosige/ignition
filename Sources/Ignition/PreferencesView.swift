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
                Text("Values marked “Saved” are part of your profile and get applied on every Mac. Reset removes them and restores the default of this macOS version.")
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
        LabeledContent {
            HStack(spacing: 8) {
                defaultHint
                control
                ResetButton(def: def, origins: origins)
                    .frame(width: 24)
            }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(def.title)
                    OriginPills(def: def, origins: origins)
                    if def.scope == .system {
                        Image(systemName: "lock").font(.caption).foregroundStyle(.secondary)
                            .help("Needs administrator rights")
                    }
                }
                if let detail = def.detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                statusLine(origins)
            }
        }
    }

    @ViewBuilder
    private func statusLine(_ origins: [PrefOrigin]) -> some View {
        let current = state.value(for: def)
        if origins.isEmpty, current != def.osDefault, def.osDefault != nil, state.editingIsActive {
            HStack(spacing: 8) {
                Text("Not in profile").font(.caption).foregroundStyle(.orange)
                addToProfile
            }
        }
    }

    /// The macOS default, right next to the control, only when the value differs from it.
    @ViewBuilder
    private var defaultHint: some View {
        if def.osDefault != nil, state.value(for: def) != def.osDefault {
            HStack(spacing: 3) {
                Image(systemName: "apple.logo")
                Text(state.defaultText(def))
            }
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(Color.secondary.opacity(0.15), in: .capsule)
            .foregroundStyle(.secondary)
            .help("macOS default")
        }
    }

    /// One button for a single active profile, a menu when there are several.
    @ViewBuilder
    private var addToProfile: some View {
        let names = state.layers
        if names.count == 1, let only = names.first {
            Button("Add to \(only.capitalized)") { state.adopt(def, into: only) }
                .buttonStyle(.glass).controlSize(.small)
        } else if names.count > 1 {
            Menu("Add to profile") {
                ForEach(names, id: \.self) { name in
                    Button(name.capitalized) { state.adopt(def, into: name) }
                }
            }
            .menuStyle(.button).buttonStyle(.glass).controlSize(.small).fixedSize()
        }
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

/// "Saved · Base", or one pill per profile (with its value) when several layers set it.
struct OriginPills: View {
    @EnvironmentObject var state: AppState
    let def: PreferenceDef
    let origins: [PrefOrigin]

    var body: some View {
        let multiple = origins.count > 1
        ForEach(Array(origins.enumerated()), id: \.element.id) { index, origin in
            let winner = index == origins.count - 1
            pill(
                multiple ? "\(origin.profile.capitalized): \(state.formatted(def, origin.value))" : (state.profileNames.count > 1 ? origin.profile.capitalized : "Saved"),
                color: winner ? .accentColor : .secondary,
                strike: multiple && !winner)
                .help(multiple
                      ? (winner ? "\(origin.profile.capitalized) wins on this Mac" : "Overridden by \(origins.last!.profile.capitalized)")
                      : "Stored in the \(origin.profile.capitalized) profile")
        }
        if origins.contains(where: \.unsaved) {
            pill("Not saved to GitHub", color: .orange, strike: false)
                .help("This change only exists on this Mac. Use Save to GitHub.")
        }
    }

    private func pill(_ text: String, color: Color, strike: Bool) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .strikethrough(strike)
            .padding(.horizontal, 6).padding(.vertical, 1)
            .background(color.opacity(0.18), in: .capsule)
            .foregroundStyle(color)
    }
}

/// Always occupies its slot so rows don't shift; asks before resetting.
struct ResetButton: View {
    @EnvironmentObject var state: AppState
    let def: PreferenceDef
    let origins: [PrefOrigin]
    @State private var asking = false

    var body: some View {
        if origins.isEmpty {
            Color.clear
        } else {
            let inEditing = state.isManagedByEditing(def)
            Button { asking = true } label: { Image(systemName: "arrow.counterclockwise") }
                .buttonStyle(.borderless)
                .disabled(!inEditing)
                .help(inEditing ? "Reset to the macOS default…"
                      : "Saved in \(origins.map { $0.profile.capitalized }.joined(separator: ", ")). Switch “Saving to” in the toolbar to reset it.")
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
            Text("It is removed from the \(state.device.editingProfile.capitalized) profile.")
                .font(.caption).foregroundStyle(.secondary)
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
