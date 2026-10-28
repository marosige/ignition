import Foundation

public enum AppPaths {
    public static var support: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Ignition", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    /// Local clone of the private config repository.
    public static var repo: URL { support.appendingPathComponent("repo", isDirectory: true) }
    /// Root folder of Ignition's data inside the repo.
    public static var configRoot: URL { repo.appendingPathComponent("ignition", isDirectory: true) }
    public static var profiles: URL { configRoot.appendingPathComponent("profiles", isDirectory: true) }
    public static var device: URL { support.appendingPathComponent("device.json") }
    public static var cache: URL {
        let url = support.appendingPathComponent("cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    public static var generatedBrewfile: URL { support.appendingPathComponent("Brewfile") }
    public static var backups: URL {
        URL(fileURLWithPath: expandTilde("~/.ignition-backup"), isDirectory: true)
    }

    public static func profileDir(_ name: String) -> URL {
        profiles.appendingPathComponent(name, isDirectory: true)
    }
    public static func profileFile(_ name: String) -> URL {
        profileDir(name).appendingPathComponent("profile.json")
    }
    public static func dotfilesDir(_ name: String) -> URL {
        profileDir(name).appendingPathComponent("dotfiles", isDirectory: true)
    }

    /// Bundled starter configuration (the author's own setup).
    public static var seed: URL? {
        let fm = FileManager.default
        var candidates: [URL] = []
        if let env = ProcessInfo.processInfo.environment["IGNITION_SEED"] {
            candidates.append(URL(fileURLWithPath: env))
        }
        if let res = Bundle.main.resourceURL { candidates.append(res.appendingPathComponent("Seed")) }
        candidates.append(URL(fileURLWithPath: fm.currentDirectoryPath).appendingPathComponent("seed"))
        return candidates.first { fm.fileExists(atPath: $0.appendingPathComponent("ignition").path) }
    }
}
