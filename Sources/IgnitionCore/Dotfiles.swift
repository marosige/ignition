import Foundation

public struct DotfileEntry: Identifiable, Hashable {
    public enum State: String { case linked, copied, missing, conflict, outdatedCopy }
    public let relativePath: String
    public let profile: String
    public let source: URL
    public let destination: URL
    public let copy: Bool
    public var state: State
    public var id: String { relativePath }
}

public enum Dotfiles {
    private static let fm = FileManager.default
    private static let ignored: Set<String> = [".DS_Store", ".gitkeep"]

    /// All dotfiles of the given layered profiles; later profiles win per path.
    public static func scan(profiles: [String], copyFiles: [String]) -> [DotfileEntry] {
        var map: [String: (String, URL)] = [:]
        for name in profiles {
            let root = AppPaths.dotfilesDir(name)
            guard let walker = fm.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey]) else { continue }
            for case let url as URL in walker {
                let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                guard values?.isRegularFile == true || values?.isSymbolicLink == true else { continue }
                if ignored.contains(url.lastPathComponent) { continue }
                let rel = String(url.path.dropFirst(root.path.count + 1))
                map[rel] = (name, url)
            }
        }
        let home = URL(fileURLWithPath: NSHomeDirectory())
        return map.keys.sorted().map { rel in
            let (profile, source) = map[rel]!
            let dest = home.appendingPathComponent(rel)
            let copy = copyFiles.contains(rel)
            var entry = DotfileEntry(relativePath: rel, profile: profile, source: source, destination: dest, copy: copy, state: .missing)
            entry.state = state(of: entry)
            return entry
        }
    }

    public static func state(of e: DotfileEntry) -> DotfileEntry.State {
        let path = e.destination.path
        guard (try? fm.attributesOfItem(atPath: path)) != nil else { return .missing }
        if e.copy {
            return fm.contentsEqual(atPath: e.source.path, andPath: path) ? .copied : .outdatedCopy
        }
        if let target = try? fm.destinationOfSymbolicLink(atPath: path), target == e.source.path { return .linked }
        return .conflict
    }

    /// Links (or copies) one file. An existing different file is moved to ~/.ignition-backup first.
    public static func apply(_ e: DotfileEntry, log: (String) -> Void) throws {
        try fm.createDirectory(at: e.destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if (try? fm.attributesOfItem(atPath: e.destination.path)) != nil {
            if state(of: e) == .linked || state(of: e) == .copied { return }
            let backup = AppPaths.backups
                .appendingPathComponent(ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-"))
                .appendingPathComponent(e.relativePath)
            try fm.createDirectory(at: backup.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.moveItem(at: e.destination, to: backup)
            log("Backed up ~/\(e.relativePath)")
        }
        if e.copy {
            try fm.copyItem(at: e.source, to: e.destination)
            log("Copied ~/\(e.relativePath)")
        } else {
            try fm.createSymbolicLink(at: e.destination, withDestinationURL: e.source)
            log("Linked ~/\(e.relativePath)")
        }
    }

    /// Moves a file (or every file in a folder) from $HOME into the profile's dotfiles
    /// and links it back, so the repo becomes the source of truth.
    public static func adopt(_ url: URL, into profile: String, copy: Bool = false) throws -> [String] {
        let home = NSHomeDirectory()
        guard url.path.hasPrefix(home + "/") else {
            throw NSError(domain: "Ignition", code: 2, userInfo: [NSLocalizedDescriptionKey: "Only files inside your home folder can be tracked."])
        }
        var adopted: [String] = []
        var isDir: ObjCBool = false
        fm.fileExists(atPath: url.path, isDirectory: &isDir)
        let files: [URL]
        if isDir.boolValue {
            files = (fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey])?.compactMap { $0 as? URL } ?? [])
                .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true && !ignored.contains($0.lastPathComponent) }
        } else {
            files = [url]
        }
        for file in files {
            let rel = String(file.path.dropFirst(home.count + 1))
            let target = AppPaths.dotfilesDir(profile).appendingPathComponent(rel)
            try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fm.fileExists(atPath: target.path) { try fm.removeItem(at: target) }
            try fm.copyItem(at: file, to: target)
            if !copy {
                try fm.removeItem(at: file)
                try fm.createSymbolicLink(at: file, withDestinationURL: target)
            }
            adopted.append(rel)
        }
        return adopted
    }

    public static func remove(_ e: DotfileEntry) throws {
        if e.state == .linked { try fm.removeItem(at: e.destination) }
        try fm.removeItem(at: e.source)
    }

    /// Well-known config files that exist on this Mac but are not tracked yet.
    public static func suggestions(tracked: Set<String>) -> [String] {
        let candidates = [
            ".zshrc", ".zprofile", ".bashrc", ".bash_profile", ".gitconfig", ".gitignore_global", ".vimrc",
            ".tmux.conf", ".config/fish/config.fish", ".config/starship.toml", ".config/btop/btop.conf",
            ".config/git/ignore", ".config/ghostty/config", ".config/zed/settings.json", ".ssh/config",
            "Library/Application Support/Code/User/settings.json", "Library/Application Support/Code/User/keybindings.json",
            ".env.sh", ".hushlogin", ".editorconfig",
        ]
        let home = NSHomeDirectory()
        return candidates.filter { rel in
            !tracked.contains(rel) && fm.fileExists(atPath: home + "/" + rel)
                && (try? fm.destinationOfSymbolicLink(atPath: home + "/" + rel)) == nil
        }
    }
}
