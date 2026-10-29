import SwiftUI
import IgnitionCore

/// One understandable change in a profile, instead of a line of JSON.
struct PlanChange: Identifiable {
    enum Kind { case added, removed, changed }
    let id = UUID()
    let profile: String
    let kind: Kind
    let symbol: String
    let title: String
    var detail: String?
    var prefID: String?
    /// Puts the profile back the way it was (only for changes made on this Mac).
    var undo: ((inout Profile) -> Void)?
}

/// A profile as it was and as it is, plus the files that changed in its folder.
struct ProfileDelta {
    let name: String
    let old: Profile?
    let new: Profile?
    let dotfiles: [(status: String, path: String)]
}

@MainActor
extension AppState {
    /// Reads both sides of a diff off the main thread.
    nonisolated static func loadDeltas(sync: GitSync, side: GitSync.DiffSide, folder: String) -> [ProfileDelta] {
        let paths = sync.changedPaths(side)
        let marker = folder + "/profiles/"
        var names: [String: [(status: String, path: String)]] = [:]
        for entry in paths where entry.path.hasPrefix(marker) {
            let rest = entry.path.dropFirst(marker.count)
            guard let name = rest.split(separator: "/").first.map(String.init) else { continue }
            names[name, default: []].append(entry)
        }
        let (oldRev, newRev): (GitSync.Revision, GitSync.Revision) = side == .mine ? (.base, .working) : (.base, .remote)
        func decode(_ name: String, _ rev: GitSync.Revision) -> Profile? {
            guard let data = sync.fileData("\(folder)/profiles/\(name)/profile.json", at: rev) else { return nil }
            return try? JSONDecoder().decode(Profile.self, from: data)
        }
        return names.keys.sorted().map { name in
            let dot = (names[name] ?? []).filter { $0.path.contains("/\(name)/dotfiles/") }
            return ProfileDelta(name: name, old: decode(name, oldRev), new: decode(name, newRev), dotfiles: dot)
        }
    }

    func planChanges(_ delta: ProfileDelta) -> [PlanChange] {
        let name = delta.name
        var out: [PlanChange] = []

        func add(_ kind: PlanChange.Kind, _ symbol: String, _ title: String, detail: String? = nil,
                 pref: String? = nil, undo: ((inout Profile) -> Void)? = nil) {
            out.append(PlanChange(profile: name, kind: kind, symbol: symbol, title: title, detail: detail, prefID: pref, undo: undo))
        }

        switch (delta.old, delta.new) {
        case (nil, let new?):
            add(.added, "plus.square.on.square", "Profile created",
                detail: "\(new.preferences.count) settings, \(new.packages.casks.count + new.packages.brews.count) packages")
        case (_?, nil):
            add(.removed, "trash", "Profile deleted")
        case (let old?, let new?):
            // Settings
            let oldP = old.preferences, newP = new.preferences
            for id in Set(oldP.keys).union(newP.keys).sorted() {
                guard let def = PreferenceCatalog.byID[id], oldP[id] != newP[id] else { continue }
                let o = oldP[id], n = newP[id]
                let kind: PlanChange.Kind = o == nil ? .added : (n == nil ? .removed : .changed)
                let detail: String
                switch kind {
                case .added: detail = formatted(def, n)
                case .removed: detail = "was \(formatted(def, o))"
                case .changed: detail = "\(formatted(def, o)) → \(formatted(def, n))"
                }
                add(kind, def.category.symbol, "\(def.category.title) · \(def.title)", detail: detail, pref: id) { $0.preferences[id] = o }
            }
            // Packages
            func entries(_ label: String, _ symbol: String, _ key: WritableKeyPath<Packages, [PackageEntry]>) {
                let o = old.packages[keyPath: key], n = new.packages[keyPath: key]
                for e in n where !o.contains(where: { $0.name == e.name }) {
                    add(.added, symbol, e.name, detail: label) { $0.packages[keyPath: key].removeAll { $0.name == e.name } }
                }
                for e in o where !n.contains(where: { $0.name == e.name }) {
                    add(.removed, symbol, e.name, detail: label) { $0.packages[keyPath: key].append(e) }
                }
            }
            entries("app", "app.fill", \.casks)
            entries("command line tool", "terminal.fill", \.brews)
            entries("VS Code extension", "chevron.left.forwardslash.chevron.right", \.vscode)
            for m in new.packages.mas where !old.packages.mas.contains(where: { $0.id == m.id }) {
                add(.added, "app.badge", m.name, detail: "App Store") { $0.packages.mas.removeAll { $0.id == m.id } }
            }
            for m in old.packages.mas where !new.packages.mas.contains(where: { $0.id == m.id }) {
                add(.removed, "app.badge", m.name, detail: "App Store") { $0.packages.mas.append(m) }
            }
            for t in Set(new.packages.taps).subtracting(old.packages.taps).sorted() {
                add(.added, "shippingbox", t, detail: "tap") { $0.packages.taps.removeAll { $0 == t } }
            }
            for t in Set(old.packages.taps).subtracting(new.packages.taps).sorted() {
                add(.removed, "shippingbox", t, detail: "tap") { $0.packages.taps.append(t) }
            }
            // Dock
            let oldDock = old.dock ?? [], newDock = new.dock ?? []
            if oldDock != newDock {
                let oldPaths = oldDock.compactMap(\.path), newPaths = newDock.compactMap(\.path)
                let added = newDock.filter { $0.path != nil && !oldPaths.contains($0.path!) }
                let removed = oldDock.filter { $0.path != nil && !newPaths.contains($0.path!) }
                for d in added { add(.added, "dock.rectangle", d.title, detail: "Dock") { $0.dock = old.dock } }
                for d in removed { add(.removed, "dock.rectangle", d.title, detail: "Dock") { $0.dock = old.dock } }
                if added.isEmpty && removed.isEmpty { add(.changed, "dock.rectangle", "Dock order or spacers", detail: "Dock") { $0.dock = old.dock } }
            }
            // Login apps, folders, sidebar
            for a in Set(new.startup.apps).subtracting(old.startup.apps).sorted() {
                add(.added, "power", a, detail: "login app") { $0.startup.apps.removeAll { $0 == a } }
            }
            for a in Set(old.startup.apps).subtracting(new.startup.apps).sorted() {
                add(.removed, "power", a, detail: "login app") { $0.startup.apps.append(a) }
            }
            for d in new.directories where !old.directories.contains(where: { $0.path == d.path }) {
                add(.added, "folder.badge.plus", d.path, detail: "folder") { $0.directories.removeAll { $0.path == d.path } }
            }
            for d in old.directories where !new.directories.contains(where: { $0.path == d.path }) {
                add(.removed, "folder.badge.plus", d.path, detail: "folder") { $0.directories.append(d) }
            }
            if (old.finderSidebar ?? []) != (new.finderSidebar ?? []) {
                add(.changed, "sidebar.left", "Finder sidebar", detail: "\((new.finderSidebar ?? []).count) items") { $0.finderSidebar = old.finderSidebar }
            }
            // Notes and looks
            for key in Set(old.manualNotes.keys).union(new.manualNotes.keys).sorted() where old.manualNotes[key] != new.manualNotes[key] {
                let title = ManualSettings.all.first { $0.id == key }?.title ?? key
                add(.changed, "hand.point.up.left", title, detail: "note") { $0.manualNotes[key] = old.manualNotes[key] }
            }
            if old.extends != new.extends {
                add(.changed, "square.stack.3d.up", "Builds on", detail: "\(old.extends?.capitalized ?? "nothing") → \(new.extends?.capitalized ?? "nothing")") { $0.extends = old.extends }
            }
            if old.color != new.color { add(.changed, "paintpalette", "Colour") { $0.color = old.color } }
            if old.icon != new.icon { add(.changed, "star", "Icon") { $0.icon = old.icon } }
        default:
            break
        }

        for file in delta.dotfiles {
            let rel = file.path.components(separatedBy: "/dotfiles/").last ?? file.path
            let kind: PlanChange.Kind = file.status == "A" ? .added : (file.status == "D" ? .removed : .changed)
            add(kind, "doc.text", "~/\(rel)", detail: "dotfile")
        }
        return out
    }

    /// Jumps to a setting: opens its page, scrolls to it and flashes the row.
    func reveal(_ prefID: String) {
        guard let def = PreferenceCatalog.byID[prefID] else { return }
        navigate(to: .pref(def.category))
        focusPref = prefID
    }

    func undo(_ change: PlanChange) {
        guard let undo = change.undo, var profile = profiles[change.profile] else { return }
        undo(&profile)
        profiles[change.profile] = profile
        persist(change.profile)
    }
}
