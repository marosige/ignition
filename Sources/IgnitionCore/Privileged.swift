import Foundation

/// Runs commands as root through `sudo -S`. The password comes from `passwordProvider`
/// (a dialog in the app), is asked once and only lives in memory until the app quits.
public enum Privileged {
    /// Asks the user for their password. `retry` is true after a wrong one.
    public static var passwordProvider: ((_ retry: Bool) -> String?)?

    private static var password: String?
    private static let lock = NSLock()

    public static func forget() {
        lock.lock(); password = nil; lock.unlock()
    }

    public static func run(_ script: String) -> ShellResult {
        guard let provider = passwordProvider else { return Shell.runPrivilegedViaOsascript(script) }
        var retry = false
        for _ in 0..<3 {
            lock.lock(); var current = password; lock.unlock()
            if current == nil {
                guard let entered = provider(retry), !entered.isEmpty else {
                    return ShellResult(status: 1, out: "", err: "Cancelled")
                }
                lock.lock(); password = entered; lock.unlock()
                current = entered
            }
            let result = Shell.run("sudo", ["-S", "-p", "", "/bin/sh", "-c", script], input: (current ?? "") + "\n")
            if result.ok { return result }
            let text = result.err.lowercased()
            if text.contains("incorrect password") || text.contains("try again") || text.contains("sorry") {
                forget()
                retry = true
                continue
            }
            return result
        }
        return ShellResult(status: 1, out: "", err: "Wrong password")
    }
}
