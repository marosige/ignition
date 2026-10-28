import Foundation

/// Syncs the private config repository through the `git` CLI, authenticated
/// with a fine-grained personal access token.
public struct GitSync {
    public let remote: String
    public let token: String
    public let deviceName: String
    public var dir: URL { AppPaths.repo }

    public init(repository: String, token: String, deviceName: String) {
        self.remote = GitSync.normalize(repository)
        self.token = token
        self.deviceName = deviceName
    }

    /// Accepts `owner/repo` or any GitHub URL.
    public static func normalize(_ input: String) -> String {
        var s = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return "" }
        if s.hasPrefix("git@github.com:") { s = "https://github.com/" + s.dropFirst("git@github.com:".count) }
        if !s.contains("://") { s = "https://github.com/" + s }
        if !s.hasSuffix(".git") { s += ".git" }
        return s
    }

    private var askPass: URL {
        let url = AppPaths.support.appendingPathComponent("git-askpass.sh")
        let script = "#!/bin/sh\ncase \"$1\" in\n  Username*) echo x-access-token ;;\n  *) echo \"$IGNITION_GIT_TOKEN\" ;;\nesac\n"
        try? script.write(to: url, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        return url
    }

    private var env: [String: String] {
        [
            "GIT_ASKPASS": askPass.path,
            "GIT_TERMINAL_PROMPT": "0",
            "IGNITION_GIT_TOKEN": token,
        ]
    }

    private var identity: [String] {
        let slug = deviceName.lowercased().filter { $0.isLetter || $0.isNumber }
        return ["-c", "user.name=Ignition (\(deviceName))", "-c", "user.email=\(slug.isEmpty ? "mac" : slug)@ignition.local"]
    }

    @discardableResult
    private func git(_ args: [String], cwd: URL? = nil) -> ShellResult {
        Shell.run("git", identity + args, env: env, cwd: cwd ?? dir)
    }

    public var isCloned: Bool {
        FileManager.default.fileExists(atPath: dir.appendingPathComponent(".git").path)
    }

    /// Clones when needed, otherwise makes sure the remote URL is current.
    public func connect() -> ShellResult {
        let fm = FileManager.default
        if isCloned {
            return git(["remote", "set-url", "origin", remote])
        }
        try? fm.removeItem(at: dir)
        let result = Shell.run("git", identity + ["clone", remote, dir.path], env: env, cwd: AppPaths.support)
        guard result.ok else { return result }
        // An empty repository has no branch yet.
        if !git(["rev-parse", "--verify", "HEAD"]).ok { git(["checkout", "-B", "main"]) }
        return result
    }

    public var hasCommits: Bool { git(["rev-parse", "--verify", "HEAD"]).ok }

    public func pull() -> ShellResult {
        guard hasCommits else { return ShellResult(status: 0, out: "Repository is empty", err: "") }
        let fetch = git(["fetch", "origin"])
        guard fetch.ok else { return fetch }
        let branch = git(["rev-parse", "--abbrev-ref", "HEAD"]).out
        if !git(["rev-parse", "--verify", "origin/\(branch)"]).ok {
            return ShellResult(status: 0, out: "Nothing to pull yet", err: "")
        }
        return git(["pull", "--rebase", "--autostash", "origin", branch])
    }

    public func changedFiles() -> [String] {
        git(["status", "--porcelain"]).out
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .map { String($0.dropFirst(3)) }
    }

    /// "[Mac mini] Update base: dock, preferences" style summary.
    public func commitMessage(for files: [String]) -> String {
        var perProfile: [String: Set<String>] = [:]
        for file in files {
            let parts = file.replacingOccurrences(of: "\"", with: "").components(separatedBy: "/")
            guard parts.count >= 4, parts[0] == "ignition", parts[1] == "profiles" else { continue }
            let area = parts[3] == "dotfiles" ? "dotfiles" : "settings"
            perProfile[parts[2], default: []].insert(area)
        }
        let summary = perProfile.keys.sorted()
            .map { "\($0) (\(perProfile[$0]!.sorted().joined(separator: ", ")))" }
            .joined(separator: ", ")
        return "[\(deviceName)] Update " + (summary.isEmpty ? "configuration" : summary) + "\n\nDevice: \(deviceName)"
    }

    public func commitAndPush(message: String? = nil) -> ShellResult {
        let files = changedFiles()
        if !files.isEmpty {
            let add = git(["add", "-A"])
            guard add.ok else { return add }
            let commit = git(["commit", "-m", message ?? commitMessage(for: files)])
            guard commit.ok else { return commit }
        }
        let pull = self.pull()
        guard pull.ok else { return pull }
        return git(["push", "-u", "origin", "HEAD"])
    }

    public func log(limit: Int = 20) -> [String] {
        guard hasCommits else { return [] }
        return git(["log", "-\(limit)", "--pretty=format:%h  %s  (%ar)"]).out
            .components(separatedBy: "\n").filter { !$0.isEmpty }
    }
}
