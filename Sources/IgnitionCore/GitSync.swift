import Foundation

public struct CommitInfo: Equatable {
    public let hash: String
    public let subject: String
    public let author: String
    public let date: Date

    /// "Mac mini" from the commit identity "Ignition (Mac mini)".
    public var device: String {
        if author.hasPrefix("Ignition ("), author.hasSuffix(")") {
            return String(author.dropFirst("Ignition (".count).dropLast())
        }
        return author
    }
}

public enum SyncKind: Equatable {
    case unconfigured, notConnected, upToDate, needsPush, needsPull, diverged, conflict, error
}

public struct SyncInfo {
    public var branch = ""
    public var ahead = 0
    public var behind = 0
    public var changedFiles: [String] = []
    public var conflicts: [String] = []
    public var merging = false
    public var local: CommitInfo?
    public var remote: CommitInfo?
    public var remoteBranchExists = false
    public var checkedAt = Date()
    public var error: String?

    public init() {}

    public var kind: SyncKind {
        if error != nil { return .error }
        if merging || !conflicts.isEmpty { return .conflict }
        let hasLocal = ahead > 0 || !changedFiles.isEmpty
        if behind > 0 && hasLocal { return .diverged }
        if behind > 0 { return .needsPull }
        if hasLocal { return .needsPush }
        return .upToDate
    }
}

public enum SyncOutcome {
    case done
    case conflicts([String])
    case failed(String)
}

public struct FileDiff: Identifiable {
    public let path: String
    public let text: String
    public var id: String { path }
}

/// Syncs the private config repository through the `git` CLI, authenticated
/// with a fine-grained personal access token.
public struct GitSync {
    public let remote: String
    public let token: String
    public let deviceName: String
    public let branch: String
    public let configFolder: String
    public var dir: URL { AppPaths.repo }

    public init(repository: String, token: String, deviceName: String, branch: String = "", configFolder: String = "ignition") {
        self.remote = GitSync.normalize(repository)
        self.token = token
        self.deviceName = deviceName
        self.branch = branch.trimmingCharacters(in: .whitespaces)
        self.configFolder = AppPaths.normalizeFolder(configFolder)
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
        return ["-c", "user.name=Ignition (\(deviceName))", "-c", "user.email=\(slug.isEmpty ? "mac" : slug)@ignition.local", "-c", "core.editor=true"]
    }

    @discardableResult
    private func git(_ args: [String]) -> ShellResult {
        Shell.run("git", identity + args, env: env, cwd: dir)
    }

    public var isCloned: Bool {
        FileManager.default.fileExists(atPath: dir.appendingPathComponent(".git").path)
    }

    public var isMerging: Bool {
        FileManager.default.fileExists(atPath: dir.appendingPathComponent(".git/MERGE_HEAD").path)
    }

    public var hasCommits: Bool { git(["rev-parse", "--verify", "HEAD"]).ok }

    public var currentBranch: String {
        let r = git(["rev-parse", "--abbrev-ref", "HEAD"])
        return r.ok && r.out != "HEAD" ? r.out : (branch.isEmpty ? "main" : branch)
    }

    // MARK: Connect

    /// Clones when needed, otherwise makes sure the remote URL is current, then selects the branch.
    public func connect() -> ShellResult {
        let fm = FileManager.default
        if isCloned {
            let r = git(["remote", "set-url", "origin", remote])
            guard r.ok else { return r }
        } else {
            try? fm.removeItem(at: dir)
            let result = Shell.run("git", identity + ["clone", remote, dir.path], env: env, cwd: AppPaths.support)
            guard result.ok else { return result }
        }
        return selectBranch()
    }

    private func selectBranch() -> ShellResult {
        let fetch = git(["fetch", "origin"])
        guard fetch.ok else { return fetch }
        let wanted = branch
        if wanted.isEmpty {
            // Repository default; an empty repository has no branch yet.
            if !hasCommits { return git(["checkout", "-B", "main"]) }
            return ShellResult(status: 0, out: "", err: "")
        }
        if git(["rev-parse", "--verify", "origin/\(wanted)"]).ok {
            return git(["checkout", "-B", wanted, "--track", "origin/\(wanted)"])
        }
        // New branch: created from the current state, published on the first save.
        return git(["checkout", "-B", wanted])
    }

    // MARK: Status

    public func changedFiles() -> [String] {
        git(["status", "--porcelain"]).out
            .components(separatedBy: "\n")
            .compactMap { line -> String? in
                let t = line.trimmingCharacters(in: .whitespaces)
                guard let space = t.firstIndex(of: " ") else { return nil }
                return String(t[space...]).trimmingCharacters(in: CharacterSet(charactersIn: " \""))
            }
    }

    public func conflicts() -> [String] {
        git(["diff", "--name-only", "--diff-filter=U"]).out
            .components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    private func commit(of rev: String) -> CommitInfo? {
        let r = git(["log", "-1", "--pretty=format:%h%x1f%s%x1f%an%x1f%at", rev])
        guard r.ok else { return nil }
        let f = r.out.components(separatedBy: "\u{1f}")
        guard f.count == 4, let t = TimeInterval(f[3]) else { return nil }
        return CommitInfo(hash: f[0], subject: f[1], author: f[2], date: Date(timeIntervalSince1970: t))
    }

    /// Compares this Mac with GitHub. Fetches first unless told not to.
    public func check(fetch: Bool) -> SyncInfo {
        var info = SyncInfo()
        info.branch = currentBranch
        if fetch {
            let f = git(["fetch", "origin"])
            if !f.ok { info.error = f.combined.isEmpty ? "Cannot reach GitHub" : f.combined }
        }
        info.changedFiles = changedFiles()
        info.conflicts = conflicts()
        info.merging = isMerging
        info.local = commit(of: "HEAD")
        let remoteRef = "origin/\(info.branch)"
        if git(["rev-parse", "--verify", remoteRef]).ok {
            info.remoteBranchExists = true
            info.remote = commit(of: remoteRef)
            if info.local == nil {
                info.behind = Int(git(["rev-list", "--count", remoteRef]).out) ?? 0
            } else {
                let counts = git(["rev-list", "--left-right", "--count", "HEAD...\(remoteRef)"]).out
                    .components(separatedBy: .whitespaces).compactMap(Int.init)
                if counts.count == 2 { info.ahead = counts[0]; info.behind = counts[1] }
            }
        } else if info.local != nil {
            info.ahead = Int(git(["rev-list", "--count", "HEAD"]).out) ?? 1
        }
        return info
    }

    // MARK: Sync

    /// Commits local changes, merges what is on GitHub and (optionally) pushes.
    public func sync(push: Bool) -> SyncOutcome {
        if isMerging {
            let c = conflicts()
            return c.isEmpty ? finishMerge() : .conflicts(c)
        }
        let files = changedFiles()
        if !files.isEmpty {
            let add = git(["add", "-A"])
            guard add.ok else { return .failed(add.combined) }
            let commit = git(["commit", "-m", commitMessage(for: files)])
            guard commit.ok else { return .failed(commit.combined) }
        }
        let fetch = git(["fetch", "origin"])
        guard fetch.ok else { return .failed(fetch.combined) }
        let branch = currentBranch
        if git(["rev-parse", "--verify", "origin/\(branch)"]).ok {
            if !hasCommits {
                let r = git(["reset", "--hard", "origin/\(branch)"])
                guard r.ok else { return .failed(r.combined) }
            } else {
                let counts = git(["rev-list", "--count", "HEAD..origin/\(branch)"]).out
                if (Int(counts) ?? 0) > 0 {
                    let m = git(["merge", "--no-edit", "--allow-unrelated-histories", "-m", "[\(deviceName)] Merge changes from GitHub", "origin/\(branch)"])
                    if !m.ok {
                        let c = conflicts()
                        return c.isEmpty ? .failed(m.combined) : .conflicts(c)
                    }
                }
            }
        }
        guard push, hasCommits else { return .done }
        let p = git(["push", "-u", "origin", "HEAD"])
        return p.ok ? .done : .failed(p.combined)
    }

    /// "[Mac mini] Update base (settings, dotfiles)" style summary.
    public func commitMessage(for files: [String]) -> String {
        let prefixCount = configFolder.split(separator: "/").count
        var perProfile: [String: Set<String>] = [:]
        for file in files {
            let parts = file.components(separatedBy: "/")
            guard parts.count > prefixCount + 2, parts[prefixCount] == "profiles" else { continue }
            let area = parts[prefixCount + 2] == "dotfiles" ? "dotfiles" : "settings"
            perProfile[parts[prefixCount + 1], default: []].insert(area)
        }
        let summary = perProfile.keys.sorted()
            .map { "\($0) (\(perProfile[$0]!.sorted().joined(separator: ", ")))" }
            .joined(separator: ", ")
        return "[\(deviceName)] Update " + (summary.isEmpty ? "configuration" : summary) + "\n\nDevice: \(deviceName)"
    }

    // MARK: Conflicts

    public func conflictVersions(_ file: String) -> (mine: String, theirs: String) {
        (git(["show", ":2:\(file)"]).out, git(["show", ":3:\(file)"]).out)
    }

    public func resolve(_ file: String, useMine: Bool) {
        git(["checkout", useMine ? "--ours" : "--theirs", "--", file])
        git(["add", "--", file])
    }

    public func finishMerge() -> SyncOutcome {
        let c = git(["commit", "--no-edit"])
        guard c.ok else { return .failed(c.combined) }
        let p = git(["push", "-u", "origin", "HEAD"])
        return p.ok ? .done : .failed(p.combined)
    }

    public func abortMerge() {
        git(["merge", "--abort"])
    }

    // MARK: Diffs

    /// What this Mac changed and GitHub does not have yet.
    public func localDiff() -> [FileDiff] {
        git(["add", "-N", "."])
        return parse(git(hasCommits ? ["diff", "HEAD"] : ["diff"]).out)
    }

    /// What GitHub has and this Mac does not.
    public func incomingDiff() -> [FileDiff] {
        let base = hasCommits ? "HEAD" : "4b825dc642cb6eb9a060e54bf8d69288fbee4904"
        return parse(git(["diff", "\(base)...origin/\(currentBranch)"]).out)
    }

    private func parse(_ text: String) -> [FileDiff] {
        var out: [FileDiff] = []
        var path = ""
        var lines: [String] = []
        func flush() {
            if !path.isEmpty { out.append(FileDiff(path: path, text: lines.joined(separator: "\n"))) }
            lines = []
        }
        for line in text.components(separatedBy: "\n") {
            if line.hasPrefix("diff --git ") {
                flush()
                path = line.components(separatedBy: " b/").last ?? line
            } else if !line.hasPrefix("index ") && !line.hasPrefix("--- ") && !line.hasPrefix("+++ ") {
                lines.append(line)
            }
        }
        flush()
        return out
    }

    // MARK: Semantic diffs

    public enum DiffSide { case mine, theirs }
    public enum Revision { case head, working, remote, base }

    private static let emptyTree = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"

    /// Common ancestor of this Mac and GitHub (empty tree when there is none).
    private func mergeBase() -> String {
        guard hasCommits else { return GitSync.emptyTree }
        let r = git(["merge-base", "HEAD", "origin/\(currentBranch)"])
        return r.ok && !r.out.isEmpty ? r.out : GitSync.emptyTree
    }

    /// Files that changed on one side: (status letter, path).
    public func changedPaths(_ side: DiffSide) -> [(status: String, path: String)] {
        let out: String
        switch side {
        case .mine:
            git(["add", "-N", "."])
            out = git(hasCommits ? ["diff", "HEAD", "--name-status"] : ["diff", "--name-status"]).out
        case .theirs:
            out = git(["diff", mergeBase(), "origin/\(currentBranch)", "--name-status"]).out
        }
        return out.components(separatedBy: "\n").compactMap { line in
            let parts = line.components(separatedBy: "\t")
            guard parts.count >= 2 else { return nil }
            return (String(parts[0].prefix(1)), parts[parts.count - 1])
        }
    }

    /// A file's content at a revision.
    public func fileData(_ path: String, at rev: Revision) -> Data? {
        switch rev {
        case .working:
            return try? Data(contentsOf: dir.appendingPathComponent(path))
        case .head:
            return committedFile(path)
        case .remote:
            let r = git(["show", "origin/\(currentBranch):\(path)"])
            return r.ok ? r.out.data(using: .utf8) : nil
        case .base:
            let base = mergeBase()
            guard base != GitSync.emptyTree else { return nil }
            let r = git(["show", "\(base):\(path)"])
            return r.ok ? r.out.data(using: .utf8) : nil
        }
    }

    /// A file as stored in the last commit on this Mac.
    public func committedFile(_ path: String) -> Data? {
        let r = git(["show", "HEAD:\(path)"])
        return r.ok ? r.out.data(using: .utf8) : nil
    }

    public func log(limit: Int = 20) -> [String] {
        guard hasCommits else { return [] }
        return git(["log", "-\(limit)", "--pretty=format:%h  %s  (%ar)"]).out
            .components(separatedBy: "\n").filter { !$0.isEmpty }
    }
}
