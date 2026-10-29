import SwiftUI
import IgnitionCore

/// The parts of a Mac that Apply can take care of.
enum ApplyStep: String, CaseIterable, Identifiable {
    case folders, packages, dotfiles, preferences, dock, sidebar, startup
    var id: String { rawValue }

    var title: String {
        switch self {
        case .folders: return "Folders"
        case .packages: return "Software"
        case .dotfiles: return "Dotfiles"
        case .preferences: return "Settings"
        case .dock: return "Dock"
        case .sidebar: return "Finder sidebar"
        case .startup: return "Login apps"
        }
    }
    var symbol: String {
        switch self {
        case .folders: return "folder.badge.plus"
        case .packages: return "shippingbox"
        case .dotfiles: return "doc.text"
        case .preferences: return "slider.horizontal.3"
        case .dock: return "dock.rectangle"
        case .sidebar: return "sidebar.left"
        case .startup: return "power"
        }
    }
    var summary: String {
        switch self {
        case .folders: return "Create the folder structure from your profiles"
        case .packages: return "Install the Homebrew, App Store and VS Code software in your profiles"
        case .dotfiles: return "Link or copy your dotfiles into your home folder"
        case .preferences: return "Set the settings saved in your profiles"
        case .dock: return "Arrange the Dock"
        case .sidebar: return "Set the Finder sidebar favourites"
        case .startup: return "Open your login apps at startup"
        }
    }
}

/// One thing Apply would do, and that is not already the case.
struct ApplyAction: Identifiable {
    let id = UUID()
    let step: ApplyStep
    let title: String
    var detail: String?
    var symbol: String? = nil
    var prefID: String? = nil
}

extension AppState {
    var enabledSteps: Set<ApplyStep> {
        Set((device.applySteps ?? ApplyStep.allCases.map(\.rawValue)).compactMap(ApplyStep.init(rawValue:)))
    }
    var applyConfigured: Bool { device.applySteps != nil }

    func setApplySteps(_ steps: Set<ApplyStep>) {
        device.applySteps = ApplyStep.allCases.filter(steps.contains).map(\.rawValue)
        saveDevice()
    }

    /// Everything Apply would change right now, compared with the real state of this Mac.
    func computeApplyPlan() async -> [ApplyAction] {
        let steps = enabledSteps
        let profile = effective
        let layerNames = layers
        let prefActions: [ApplyAction] = steps.contains(.preferences)
            ? pending.map { ApplyAction(step: .preferences, title: $0.def.title,
                                        detail: "\(formatted($0.def, $0.from)) → \(formatted($0.def, $0.to))",
                                        symbol: $0.def.category.symbol, prefID: $0.def.id) }
            : []
        let rest = await Task.detached(priority: .userInitiated) {
            AppState.inspect(profile: profile, layers: layerNames, steps: steps)
        }.value
        return (prefActions + rest).sorted {
            (ApplyStep.allCases.firstIndex(of: $0.step) ?? 0) < (ApplyStep.allCases.firstIndex(of: $1.step) ?? 0)
        }
    }

    nonisolated static func inspect(profile: Profile, layers: [String], steps: Set<ApplyStep>) -> [ApplyAction] {
        var out: [ApplyAction] = []
        let fm = FileManager.default

        if steps.contains(.folders) {
            for d in profile.directories where !fm.fileExists(atPath: expandTilde(d.path)) {
                out.append(ApplyAction(step: .folders, title: "Create \(d.path)", detail: d.comment))
            }
        }

        if steps.contains(.packages) {
            let own = Packages.ignitionTools
            var wantedCasks = profile.packages.casks.map(\.name)
            var wantedBrews = profile.packages.brews.map(\.name)
            for e in own.casks where !wantedCasks.contains(e.name) { wantedCasks.append(e.name) }
            for e in own.brews where !wantedBrews.contains(e.name) { wantedBrews.append(e.name) }
            if !Brew.isInstalled {
                out.append(ApplyAction(step: .packages, title: "Install Homebrew",
                                       detail: "needed for everything below (opens the official installer in Terminal)"))
                for n in wantedCasks { out.append(ApplyAction(step: .packages, title: n, detail: "app (Homebrew cask)", symbol: "app.fill")) }
                for n in wantedBrews { out.append(ApplyAction(step: .packages, title: n, detail: "command line tool", symbol: "terminal.fill")) }
            } else {
                let formulae = Set(Shell.run("brew", ["list", "--formula", "-1"]).out.components(separatedBy: "\n"))
                let casks = Set(Shell.run("brew", ["list", "--cask", "-1"]).out.components(separatedBy: "\n"))
                let taps = Set(Shell.run("brew", ["tap"]).out.components(separatedBy: "\n"))
                for t in profile.packages.taps where !taps.contains(t) {
                    out.append(ApplyAction(step: .packages, title: t, detail: "Homebrew tap", symbol: "shippingbox"))
                }
                for n in wantedCasks where !casks.contains(n) {
                    out.append(ApplyAction(step: .packages, title: n, detail: "app (Homebrew cask)", symbol: "app.fill"))
                }
                for n in wantedBrews where !formulae.contains(n) {
                    out.append(ApplyAction(step: .packages, title: n, detail: "command line tool", symbol: "terminal.fill"))
                }
            }
            if !profile.packages.mas.isEmpty {
                let have = Set(Mas.isInstalled ? Mas.installed().map(\.id) : [])
                for m in profile.packages.mas where !have.contains(m.id) {
                    out.append(ApplyAction(step: .packages, title: m.name, detail: "Mac App Store", symbol: "bag.fill"))
                }
            }
            if !profile.packages.vscode.isEmpty {
                let have = Shell.which("code")
                    ? Set(Shell.run("code", ["--list-extensions"]).out.lowercased().components(separatedBy: "\n")) : []
                for e in profile.packages.vscode where !have.contains(e.name.lowercased()) {
                    out.append(ApplyAction(step: .packages, title: e.name, detail: "VS Code extension",
                                           symbol: "chevron.left.forwardslash.chevron.right"))
                }
            }
        }

        if steps.contains(.dotfiles) {
            for entry in Dotfiles.scan(profiles: layers, copyFiles: profile.copyFiles) {
                switch entry.state {
                case .linked, .copied: break
                case .missing:
                    out.append(ApplyAction(step: .dotfiles, title: "~/\(entry.relativePath)",
                                           detail: entry.copy ? "copy" : "link", symbol: "doc.text"))
                case .conflict, .outdatedCopy:
                    out.append(ApplyAction(step: .dotfiles, title: "~/\(entry.relativePath)",
                                           detail: "replaces the file on this Mac (backed up first)", symbol: "doc.text"))
                }
            }
        }

        if steps.contains(.dock), let plan = profile.dock {
            func key(_ items: [DockItem]) -> [String] { items.map { "\($0.kind.rawValue):\($0.path ?? "")" } }
            let current = Setup.currentDock()
            if key(plan) != key(current) {
                let now = Set(current.compactMap(\.path)), wanted = Set(plan.compactMap(\.path))
                let added = plan.filter { $0.path != nil && !now.contains($0.path!) }.map(\.title)
                let removed = current.filter { $0.path != nil && !wanted.contains($0.path!) }.map(\.title)
                var parts: [String] = []
                if !added.isEmpty { parts.append("adds \(added.joined(separator: ", "))") }
                if !removed.isEmpty { parts.append("removes \(removed.joined(separator: ", "))") }
                if parts.isEmpty { parts.append("reorders items and spacers") }
                out.append(ApplyAction(step: .dock, title: "Rearrange the Dock", detail: parts.joined(separator: "; ")))
            }
        }

        if steps.contains(.sidebar), let plan = profile.finderSidebar {
            let wanted = plan.map(\.name)
            if Setup.sidebarNames() != wanted {
                out.append(ApplyAction(step: .sidebar, title: "Set the Finder sidebar", detail: wanted.joined(separator: ", ")))
            }
        }

        if steps.contains(.startup), !Setup.startupIsCurrent(profile.startup) {
            out.append(ApplyAction(step: .startup, title: "Set login apps",
                                   detail: profile.startup.apps.isEmpty ? "none" : profile.startup.apps.joined(separator: ", ")))
        }
        return out
    }
}
