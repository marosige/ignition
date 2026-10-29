import SwiftUI

/// A profile as a small coloured capsule: its icon, or its name when it has none.
struct ProfileChip: View {
    @EnvironmentObject var state: AppState
    let name: String
    var dimmed = false
    /// Show the name next to the icon.
    var showName = false

    var body: some View {
        let color = state.color(of: name)
        HStack(spacing: 4) {
            if let icon = state.icon(of: name) {
                Image(systemName: icon)
                if showName { Text(name.capitalized) }
            } else {
                Text(name.capitalized)
            }
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 7).padding(.vertical, 2)
        .background(color.opacity(dimmed ? 0.10 : 0.22), in: .capsule)
        .foregroundStyle(color.opacity(dimmed ? 0.6 : 1))
    }
}

/// Which profile a page edits (Dock layout, login apps, folders, ...). Settings and
/// software choose their profile per item, so only these layout pages need it.
struct ProfileTargetPicker: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: 8) {
            Text("Edit for").foregroundStyle(.secondary)
            ForEach(state.profileNames, id: \.self) { name in
                let color = state.color(of: name)
                let selected = state.device.editingProfile == name
                Button {
                    state.device.editingProfile = name
                    state.saveDevice()
                } label: {
                    HStack(spacing: 4) {
                        if let icon = state.icon(of: name) { Image(systemName: icon) }
                        Text(name.capitalized)
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 9).padding(.vertical, 3)
                    .background(color.opacity(selected ? 0.25 : 0.08), in: .capsule)
                    .overlay(Capsule().stroke(color.opacity(selected ? 0.9 : 0), lineWidth: 1))
                    .foregroundStyle(color.opacity(selected ? 1 : 0.7))
                }
                .buttonStyle(.plain)
            }
            if !state.layers.contains(state.device.editingProfile) {
                Text("not on this Mac").font(.caption).foregroundStyle(.orange)
            }
        }
    }
}
