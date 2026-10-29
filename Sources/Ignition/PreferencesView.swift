import SwiftUI
import AppKit
import IgnitionCore

/// A catalogue of what profiles can set. A setting that is in a profile carries its value
/// (change it right here, or per profile through its pill); the rest are one tap from a profile.
struct PreferencesView: View {
    @EnvironmentObject var state: AppState
    let category: PrefCategory
    @State private var filter: Filter = .all

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All", planned = "In a profile", open = "Not in a profile"
        var id: String { rawValue }
    }

    private var defs: [PreferenceDef] { PreferenceCatalog.defs(in: category) }
    private var plannedCount: Int { defs.filter { state.isPlanned($0) }.count }

    private func visible(_ def: PreferenceDef) -> Bool {
        switch filter {
        case .all: return true
        case .planned: return state.isPlanned(def)
        case .open: return !state.isPlanned(def)
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            form
                .onAppear { focus(proxy) }
                .onChange(of: state.focusPref) { _, _ in focus(proxy) }
        }
    }

    /// Scrolls to the setting that was asked for and lets the highlight fade out.
    private func focus(_ proxy: ScrollViewProxy) {
        guard let id = state.focusPref else { return }
        filter = .all
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation { proxy.scrollTo(id, anchor: .center) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            if state.focusPref == id { state.focusPref = nil }
        }
    }

    private var form: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(plannedCount) of \(defs.count) in a profile").font(.headline)
                        Text("The controls change this Mac right away, like System Settings. “Add” saves the value to a profile; click a profile pill to edit the saved value.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $filter) {
                        ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 300)
                }
            }
            ForEach(PreferenceCatalog.sections(in: category)) { section in
                let rows = section.defs.filter(visible)
                if !rows.isEmpty {
                    Section(section.name) {
                        ForEach(rows) { def in PreferenceRow(def: def).id(def.id) }
                    }
                }
            }
            ForEach(ManualSettings.items(in: category)) { item in
                ManualSettingSection(item: item)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(category.title)
        .onAppear { state.refreshLive() }
    }
}

// MARK: - Row

struct PreferenceRow: View {
    @EnvironmentObject var state: AppState
    let def: PreferenceDef

    var body: some View {
        let origins = state.origins(for: def)
        let owner = state.controlOrigin(for: def)
        let live = state.liveValue(def)
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(def.title).layoutPriority(1)
                    if def.scope == .system {
                        Image(systemName: "lock").font(.caption).foregroundStyle(.secondary)
                            .help("Needs administrator rights")
                    }
                    if def.osDefault != nil, live != def.osDefault || owner != nil {
                        DefaultPill(def: def, origins: origins)
                    }
                    OriginPills(def: def, origins: origins)
                    if owner == nil, def.osDefault != nil, live != def.osDefault {
                        Text("Not in a profile")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Color.orange.opacity(0.18), in: .capsule)
                            .foregroundStyle(.orange)
                            .help("This Mac has a value that differs from the default, but no profile has it. Use Add to save it.")
                    }
                    SaveToProfileMenu(def: def, value: live ?? state.initialValue(def), labelled: owner == nil)
                }
                if let detail = def.detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 12)
            PrefValueControl(def: def, value: live) { state.applyLive(def, $0) }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(Color.accentColor.opacity(state.focusPref == def.id ? 0.22 : 0))
        )
        .animation(.easeInOut(duration: 0.4), value: state.focusPref)
    }
}

// MARK: - Control

/// The right control for a setting; reports changes, stores nothing itself.
struct PrefValueControl: View {
    @EnvironmentObject var state: AppState
    let def: PreferenceDef
    let value: PrefValue?
    let onChange: (PrefValue) -> Void

    var body: some View {
        switch def.control {
        case .toggle:
            Toggle("", isOn: Binding(get: { value?.boolValue ?? false }, set: { onChange(.bool($0)) }))
                .labelsHidden()
                .toggleStyle(.switch)
        case .slider(let range, let step, _):
            HStack(spacing: 6) {
                Text(state.formatted(def, value))
                    .monospacedDigit()
                    .frame(minWidth: 70, alignment: .trailing)
                Stepper("", value: Binding(
                    get: { value?.doubleValue ?? range.lowerBound },
                    set: { v in
                        if case .double? = def.osDefault { onChange(.double((v * 10).rounded() / 10)) }
                        else { onChange(.int(Int(v.rounded()))) }
                    }), in: range, step: step)
                    .labelsHidden()
            }
        case .picker(let options):
            Picker("", selection: Binding(
                get: { value ?? options.first?.value ?? .int(0) },
                set: { onChange($0) })) {
                if let value, !options.contains(where: { $0.value == value }) {
                    Text(value.description).tag(value)
                }
                ForEach(options, id: \.self) { Text($0.label).tag($0.value) }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
        case .text(let placeholder):
            CommitTextField(placeholder: placeholder, initial: value?.stringValue ?? "") { onChange(.string($0)) }
        }
    }
}

/// Text field that only reports when the user presses return.
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

// MARK: - Adding

/// The "+" pill next to a setting's name: saves this Mac's value into a profile.
/// Says "Add" while the setting is in no profile; afterwards it is just "+" (saving again updates).
struct SaveToProfileMenu: View {
    @EnvironmentObject var state: AppState
    let def: PreferenceDef
    let value: PrefValue
    let labelled: Bool

    var body: some View {
        let have = state.origins(for: def).map(\.profile)
        Menu {
            Section(labelled ? "Add to profile" : "Save this Mac's value to") {
                ForEach(state.profileNames, id: \.self) { name in
                    Button {
                        state.set(def, to: value, in: name)
                    } label: {
                        let suffix = have.contains(name) ? " – update" : (state.layers.contains(name) ? "" : " (not on this Mac)")
                        Label(name.capitalized + suffix, systemImage: state.icon(of: name) ?? "square.stack.3d.up")
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "plus").font(.system(size: 9, weight: .bold))
                if labelled { Text("Add").font(.caption2.weight(.semibold)) }
            }
            .padding(.horizontal, labelled ? 9 : 8).padding(.vertical, 3)
            .background(Color.secondary.opacity(0.15), in: .capsule)
            .overlay(Capsule().strokeBorder(Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
            .foregroundStyle(.secondary)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(labelled ? "Add \(state.formatted(def, value)) (this Mac now) to a profile"
                       : "Save \(state.formatted(def, value)) (this Mac now) into a profile, or update it")
    }
}

// MARK: - Pills

/// One pill per profile that sets the value, in the profile's colour, with its value inside.
/// Click a pill to change that profile's value or remove it.
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
    @State private var editing = false

    private var origin: PrefOrigin { origins[index] }

    var body: some View {
        let winner = origin.id == state.controlOrigin(for: def)?.id
        let color = state.color(of: origin.profile)
        Button { editing = true } label: {
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
            .foregroundStyle(color.opacity(origin.active ? (winner ? 1 : 0.6) : 0.45))
        }
        .buttonStyle(.plain)
        .help(helpText(winner: winner))
        .popover(isPresented: $editing, arrowEdge: .bottom) { editor }
    }

    private func helpText(winner: Bool) -> String {
        var text = "\(origin.profile.capitalized) profile – click to change or remove"
        if !origin.active { text += " (not on this Mac)" }
        else if !winner, let top = state.controlOrigin(for: def) { text += " (overridden by \(top.profile.capitalized))" }
        return text
    }

    private var editor: some View {
        let current = state.profiles[origin.profile]?.preferences[def.id] ?? origin.value
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                ProfileChip(name: origin.profile)
                Text(def.title).font(.headline)
            }
            HStack {
                Text("Value in \(origin.profile.capitalized)").foregroundStyle(.secondary)
                Spacer()
                PrefValueControl(def: def, value: current) { state.set(def, to: $0, in: origin.profile) }
            }
            if def.osDefault != nil {
                HStack(spacing: 4) {
                    Image(systemName: "apple.logo")
                    Text("macOS default: \(state.defaultText(def))")
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Button {
                state.set(def, to: state.liveValue(def) ?? current, in: origin.profile)
            } label: {
                Label("Use this Mac's value (\(state.formatted(def, state.liveValue(def))))", systemImage: "laptopcomputer")
            }
            .buttonStyle(.glass)
            Divider()
            HStack {
                Button("Remove from \(origin.profile.capitalized)", role: .destructive) {
                    state.remove(def, from: origin.profile)
                    editing = false
                }
                Spacer()
                Button("Done") { editing = false }.buttonStyle(.glassProminent)
            }
        }
        .padding(16)
        .frame(width: 340)
    }
}

/// Shows the macOS default; clicking it takes the setting out of every profile (after asking).
struct DefaultPill: View {
    @EnvironmentObject var state: AppState
    let def: PreferenceDef
    let origins: [PrefOrigin]
    @State private var asking = false

    var body: some View {
        if def.osDefault != nil {
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
            .help("macOS default – click to reset this Mac or the profiles")
            .popover(isPresented: $asking, arrowEdge: .bottom) { confirm }
        }
    }

    private var confirm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Reset “\(def.title)” to the macOS default?").font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                GridRow { Text("This Mac").foregroundStyle(.secondary); Text(state.formatted(def, state.liveValue(def))).bold() }
                GridRow { Text("Default").foregroundStyle(.secondary); Text(state.defaultText(def)).bold() }
                if !origins.isEmpty {
                    GridRow {
                        Text("Profiles").foregroundStyle(.secondary)
                        Text(origins.map { "\($0.profile.capitalized): \(state.formatted(def, $0.value))" }.joined(separator: ", ")).bold()
                    }
                }
            }
            HStack {
                Button("Cancel") { asking = false }
                Spacer()
                if !origins.isEmpty {
                    Button("Remove from profiles") { state.reset(def); asking = false }
                }
                if let value = def.osDefault {
                    Button("Set this Mac to default") {
                        state.applyLive(def, value)
                        if !origins.isEmpty { state.reset(def) }
                        asking = false
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        }
        .padding(16)
        .frame(width: 320)
    }
}

// MARK: - Manual settings

struct ManualSettingSection: View {
    @EnvironmentObject var state: AppState
    let item: ManualSetting
    @State private var text = ""

    /// Notes live in the most specific profile on this Mac.
    private var target: String { state.layers.last ?? state.device.editingProfile }

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
                    guard var profile = state.profiles[target] else { return }
                    profile.manualNotes[item.id] = new.isEmpty ? nil : new
                    state.profiles[target] = profile
                    state.persist(target)
                }
        } header: {
            Text(item.title)
        } footer: {
            Text("\(item.detail) Saved in \(target.capitalized).")
        }
        .onAppear { text = state.effective.manualNotes[item.id] ?? "" }
    }
}
