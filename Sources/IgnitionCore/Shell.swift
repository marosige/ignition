import Foundation

public struct ShellResult {
    public let status: Int32
    public let out: String
    public let err: String
    public var ok: Bool { status == 0 }
    public var combined: String { [out, err].filter { !$0.isEmpty }.joined(separator: "\n") }
}

public enum Shell {
    public static let brewPaths = ["/opt/homebrew/bin", "/usr/local/bin"]

    public static var environment: [String: String] {
        var env = ProcessInfo.processInfo.environment
        let extra = brewPaths.joined(separator: ":")
        env["PATH"] = extra + ":/usr/bin:/bin:/usr/sbin:/sbin:" + (env["PATH"] ?? "")
        return env
    }

    /// Runs a command through `/usr/bin/env` so Homebrew binaries are found.
    @discardableResult
    public static func run(
        _ command: String,
        _ args: [String] = [],
        env: [String: String] = [:],
        cwd: URL? = nil,
        onLine: ((String) -> Void)? = nil
    ) -> ShellResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + args
        var merged = environment
        for (k, v) in env { merged[k] = v }
        process.environment = merged
        if let cwd { process.currentDirectoryURL = cwd }

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        let lock = NSLock()
        var outData = Data()
        var errData = Data()
        var outBuffer = ""

        func flushLines(_ chunk: Data) {
            guard let onLine, let text = String(data: chunk, encoding: .utf8) else { return }
            lock.lock()
            outBuffer += text
            var lines = outBuffer.components(separatedBy: "\n")
            outBuffer = lines.removeLast()
            lock.unlock()
            for line in lines where !line.isEmpty { onLine(line) }
        }

        outPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty { return }
            lock.lock(); outData.append(data); lock.unlock()
            flushLines(data)
        }
        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty { return }
            lock.lock(); errData.append(data); lock.unlock()
            flushLines(data)
        }

        // Block on a semaphore instead of waitUntilExit(), which spins the run loop and
        // can re-enter SwiftUI view updates when called on the main thread.
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        do {
            try process.run()
        } catch {
            return ShellResult(status: 127, out: "", err: "\(error.localizedDescription)")
        }
        finished.wait()
        outPipe.fileHandleForReading.readabilityHandler = nil
        errPipe.fileHandleForReading.readabilityHandler = nil
        outData.append(outPipe.fileHandleForReading.readDataToEndOfFile())
        errData.append(errPipe.fileHandleForReading.readDataToEndOfFile())
        if let onLine, !outBuffer.isEmpty { onLine(outBuffer) }

        return ShellResult(
            status: process.terminationStatus,
            out: String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            err: String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        )
    }

    /// Runs a shell script as administrator (shows the macOS password prompt).
    @discardableResult
    public static func runPrivileged(_ script: String) -> ShellResult {
        let escaped = script
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return run("osascript", ["-e", "do shell script \"\(escaped)\" with administrator privileges"])
    }

    public static func which(_ tool: String) -> Bool {
        run("which", [tool]).ok
    }

    public static func quote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

public func expandTilde(_ path: String) -> String {
    (path as NSString).expandingTildeInPath
}
