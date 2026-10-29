import Foundation

public struct BrewPackage: Identifiable, Hashable {
    public enum Kind: String { case formula, cask }
    public let kind: Kind
    public let token: String
    public var name: String
    public var desc: String
    public var homepage: String
    public var version: String
    public var id: String { "\(kind.rawValue):\(token)" }

    public init(kind: Kind, token: String, name: String? = nil, desc: String = "", homepage: String = "", version: String = "") {
        self.kind = kind
        self.token = token
        self.name = name ?? token
        self.desc = desc
        self.homepage = homepage
        self.version = version
    }
}

public enum Brew {
    public static var executable: String? {
        ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"].first { FileManager.default.isExecutableFile(atPath: $0) }
    }
    public static var isInstalled: Bool { executable != nil }

    // MARK: Catalog

    private struct RawFormula: Decodable {
        let name: String
        let desc: String?
        let homepage: String?
        let versions: Versions?
        struct Versions: Decodable { let stable: String? }
    }
    private struct RawCask: Decodable {
        let token: String
        let name: [String]?
        let desc: String?
        let homepage: String?
        let version: String?
    }

    /// Downloads (and caches for a day) the public Homebrew indexes.
    public static func loadCatalog(forceRefresh: Bool = false) async throws -> [BrewPackage] {
        async let formulae = fetch("formula", refresh: forceRefresh)
        async let casks = fetch("cask", refresh: forceRefresh)
        let (f, c) = try await (formulae, casks)
        let decoder = JSONDecoder()
        let rawF = try decoder.decode([RawFormula].self, from: f)
        let rawC = try decoder.decode([RawCask].self, from: c)
        var out: [BrewPackage] = []
        out.reserveCapacity(rawF.count + rawC.count)
        for r in rawC {
            out.append(BrewPackage(kind: .cask, token: r.token, name: r.name?.first ?? r.token,
                                   desc: r.desc ?? "", homepage: r.homepage ?? "", version: r.version ?? ""))
        }
        for r in rawF {
            out.append(BrewPackage(kind: .formula, token: r.name, name: r.name,
                                   desc: r.desc ?? "", homepage: r.homepage ?? "", version: r.versions?.stable ?? ""))
        }
        return out
    }

    private static func fetch(_ kind: String, refresh: Bool) async throws -> Data {
        let file = AppPaths.cache.appendingPathComponent("\(kind).json")
        if !refresh,
           let attrs = try? FileManager.default.attributesOfItem(atPath: file.path),
           let date = attrs[.modificationDate] as? Date,
           Date().timeIntervalSince(date) < 86_400,
           let data = try? Data(contentsOf: file) {
            return data
        }
        let url = URL(string: "https://formulae.brew.sh/api/\(kind).json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        try? data.write(to: file, options: .atomic)
        return data
    }

    public static func search(_ query: String, in catalog: [BrewPackage], kinds: Set<BrewPackage.Kind>, limit: Int = 80) -> [BrewPackage] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        var scored: [(Int, BrewPackage)] = []
        for p in catalog where kinds.contains(p.kind) {
            let token = p.token.lowercased()
            let name = p.name.lowercased()
            var score = 0
            if token == q || name == q { score = 100 }
            else if token.hasPrefix(q) || name.hasPrefix(q) { score = 80 }
            else if token.contains(q) || name.contains(q) { score = 60 }
            else if p.desc.lowercased().contains(q) { score = 20 }
            if score > 0 { scored.append((score + (p.kind == .cask ? 1 : 0), p)) }
        }
        return scored.sorted { $0.0 != $1.0 ? $0.0 > $1.0 : $0.1.token < $1.1.token }
            .prefix(limit).map(\.1)
    }

    // MARK: Installed

    public static func installed() -> [BrewPackage] {
        guard isInstalled else { return [] }
        let r = Shell.run("brew", ["info", "--json=v2", "--installed"])
        guard r.ok, let data = r.out.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        var out: [BrewPackage] = []
        for f in (json["formulae"] as? [[String: Any]]) ?? [] {
            let name = f["name"] as? String ?? ""
            let version = ((f["installed"] as? [[String: Any]])?.first?["version"] as? String) ?? ""
            let onRequest = ((f["installed"] as? [[String: Any]])?.last?["installed_on_request"] as? Bool) ?? true
            guard onRequest else { continue } // hide pure dependencies
            out.append(BrewPackage(kind: .formula, token: name, name: name, desc: f["desc"] as? String ?? "",
                                   homepage: f["homepage"] as? String ?? "", version: version))
        }
        for c in (json["casks"] as? [[String: Any]]) ?? [] {
            let token = c["token"] as? String ?? ""
            let name = (c["name"] as? [String])?.first ?? token
            out.append(BrewPackage(kind: .cask, token: token, name: name, desc: c["desc"] as? String ?? "",
                                   homepage: c["homepage"] as? String ?? "", version: c["installed"] as? String ?? ""))
        }
        return out.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    /// The installed .app of a cask, so it can be opened.
    public static func appURL(forCask token: String) -> URL? {
        let r = Shell.run("brew", ["info", "--json=v2", "--cask", token])
        guard r.ok, let data = r.out.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cask = (json["casks"] as? [[String: Any]])?.first,
              let artifacts = cask["artifacts"] as? [[String: Any]] else { return nil }
        var names: [String] = []
        for artifact in artifacts {
            for entry in (artifact["app"] as? [Any]) ?? [] {
                if let name = entry as? String { names.append(name) }
            }
        }
        let dirs = ["/Applications", expandTilde("~/Applications")]
        for name in names {
            for dir in dirs {
                let path = dir + "/" + (name as NSString).lastPathComponent
                if FileManager.default.fileExists(atPath: path) { return URL(fileURLWithPath: path) }
            }
        }
        return nil
    }

    // MARK: Actions

    @discardableResult
    public static func install(_ p: BrewPackage, log: @escaping (String) -> Void) -> ShellResult {
        Shell.run("brew", ["install"] + (p.kind == .cask ? ["--cask"] : []) + [p.token], onLine: log)
    }

    @discardableResult
    public static func uninstall(_ p: BrewPackage, log: @escaping (String) -> Void) -> ShellResult {
        Shell.run("brew", ["uninstall"] + (p.kind == .cask ? ["--cask"] : []) + [p.token], onLine: log)
    }

    // MARK: Brewfile

    public static func brewfile(for packages: Packages) -> String {
        var lines: [String] = ["# Generated by Ignition – do not edit, change it in the app."]
        func block(_ title: String, _ rows: [String]) {
            guard !rows.isEmpty else { return }
            lines.append("")
            lines.append("# \(title)")
            lines += rows
        }
        func row(_ kind: String, _ e: PackageEntry) -> String {
            "\(kind) \"\(e.name)\"" + (e.comment.map { " # \($0)" } ?? "")
        }
        block("Taps", packages.taps.map { "tap \"\($0)\"" })
        block("Formulae", packages.brews.map { row("brew", $0) })
        block("Casks", packages.casks.map { row("cask", $0) })
        block("Mac App Store", packages.mas.map { "mas \"\($0.name)\", id: \($0.id)" })
        block("VS Code extensions", packages.vscode.map { row("vscode", $0) })
        return lines.joined(separator: "\n") + "\n"
    }
}

public enum Mas {
    public static var isInstalled: Bool { Shell.which("mas") }

    public static func installed() -> [MasEntry] {
        parse(Shell.run("mas", ["list"]).out)
    }

    public static func search(_ query: String) -> [MasEntry] {
        parse(Shell.run("mas", ["search", query]).out)
    }

    private static func parse(_ text: String) -> [MasEntry] {
        text.components(separatedBy: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let space = trimmed.firstIndex(of: " "), let id = Int(trimmed[..<space]) else { return nil }
            var name = trimmed[trimmed.index(after: space)...].trimmingCharacters(in: .whitespaces)
            if let paren = name.lastIndex(of: "("), name.hasSuffix(")") {
                name = name[..<paren].trimmingCharacters(in: .whitespaces)
            }
            return MasEntry(id: id, name: name)
        }
    }

    @discardableResult
    public static func install(_ id: Int, log: @escaping (String) -> Void) -> ShellResult {
        Shell.run("mas", ["install", String(id)], onLine: log)
    }

    /// `mas uninstall` needs administrator rights.
    @discardableResult
    public static func uninstall(_ id: Int) -> ShellResult {
        let path = Shell.run("which", ["mas"]).out
        guard !path.isEmpty else { return ShellResult(status: 127, out: "", err: "mas is not installed") }
        return Shell.runPrivileged("\(Shell.quote(path)) uninstall \(id)")
    }
}
