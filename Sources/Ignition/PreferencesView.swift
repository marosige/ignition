import SwiftUI
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
        LabeledContent {
            HStack(spacing: 8) {
                control
                if state.isManaged(def) {
                    Button {
                        state.reset(def)
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Reset to the macOS default")
                } else {
                    Color.clear.frame(width: 20, height: 1)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(def.title)
                    if state.isManaged(def) {
                        Text("Saved")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(.tint.opacity(0.18), in: .capsule)
                            .foregroundStyle(.tint)
                    }
                    if def.scope == .system {
                        Image(systemName: "lock").font(.caption).foregroundStyle(.secondary)
                            .help("Needs administrator rights")
                    }
                }
                if let detail = def.detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
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
        case .slider(let range, let step, let unit):
            HStack {
                Slider(value: Binding(
                    get: { current?.doubleValue ?? range.lowerBound },
                    set: { v in
                        if case .double? = def.osDefault { state.set(def, to: .double((v * 10).rounded() / 10)) }
                        else { state.set(def, to: .int(Int(v))) }
                    }), in: range, step: step)
                    .frame(width: 180)
                Text(label(current, unit: unit))
                    .monospacedDigit().foregroundStyle(.secondary)
                    .frame(width: 56, alignment: .trailing)
            }
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
            .frame(maxWidth: 260)
        case .text(let placeholder):
            CommitTextField(placeholder: placeholder, initial: current?.stringValue ?? "") {
                state.set(def, to: .string($0))
            }
        }
    }

    private func label(_ v: PrefValue?, unit: String) -> String {
        guard let v else { return "–" }
        if let d = v.doubleValue, case .double? = def.osDefault { return String(format: "%.1f", d) + unit }
        return "\(v.intValue ?? 0)\(unit)"
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
