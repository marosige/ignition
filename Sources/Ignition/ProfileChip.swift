import SwiftUI

/// A profile as a small coloured capsule: its icon, or its name when it has none.
struct ProfileChip: View {
    @EnvironmentObject var state: AppState
    let name: String
    var dimmed = false

    var body: some View {
        let color = state.color(of: name)
        Group {
            if let icon = state.icon(of: name) {
                Image(systemName: icon)
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
