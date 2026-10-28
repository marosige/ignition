import Foundation

/// Reads and writes macOS preferences, including the few settings that are
/// not plain `defaults` keys.
public enum DefaultsService {

    // MARK: Read

    public static func read(_ def: PreferenceDef) -> PrefValue? {
        if let custom = def.custom { return readCustom(custom) }
        if def.scope == .system || def.domain.hasPrefix("/") {
            return readViaCLI(def)
        }
        let app: CFString = def.domain == "NSGlobalDomain" ? kCFPreferencesAnyApplication : (def.domain as CFString)
        let host: CFString = def.scope == .currentHost ? kCFPreferencesCurrentHost : kCFPreferencesAnyHost
        guard let raw = CFPreferencesCopyValue(def.key as CFString, app, kCFPreferencesCurrentUser, host) else {
            return nil
        }
        if let n = raw as? NSNumber {
            if CFGetTypeID(n) == CFBooleanGetTypeID() { return .bool(n.boolValue) }
            if CFNumberIsFloatType(n as CFNumber) { return .double(n.doubleValue) }
            return .int(n.intValue)
        }
        if let s = raw as? String { return .string(s) }
        return nil
    }

    private static func readViaCLI(_ def: PreferenceDef) -> PrefValue? {
        let result = Shell.run("defaults", ["read", def.domain, def.key])
        guard result.ok else { return nil }
        let text = result.out
        switch def.osDefault {
        case .bool?: return .bool(text == "1" || text.lowercased() == "true")
        case .int?: return Int(text).map(PrefValue.int)
        case .double?: return Double(text).map(PrefValue.double)
        default:
            if let i = Int(text), def.control == .toggle { return .bool(i != 0) }
            return .string(text)
        }
    }

    // MARK: Write

    /// Arguments for `defaults write`.
    public static func writeArguments(_ def: PreferenceDef, _ value: PrefValue) -> [String] {
        var args = def.scope == .currentHost ? ["-currentHost"] : []
        args += ["write", def.domain, def.key]
        switch value {
        case .bool(let v): args += ["-bool", v ? "true" : "false"]
        case .int(let v): args += ["-int", String(v)]
        case .double(let v): args += ["-float", String(v)]
        case .string(let v): args += ["-string", v]
        }
        return args
    }

    public static func deleteArguments(_ def: PreferenceDef) -> [String] {
        (def.scope == .currentHost ? ["-currentHost"] : []) + ["delete", def.domain, def.key]
    }

    @discardableResult
    public static func write(_ def: PreferenceDef, _ value: PrefValue) -> ShellResult {
        if let custom = def.custom { return writeCustom(custom, value) }
        if def.scope == .system {
            let cmd = (["defaults"] + writeArguments(def, value)).map(Shell.quote).joined(separator: " ")
            return Shell.runPrivileged(cmd)
        }
        return Shell.run("defaults", writeArguments(def, value))
    }

    /// Removes the key so macOS falls back to its own default for this OS version.
    @discardableResult
    public static func reset(_ def: PreferenceDef) -> ShellResult {
        if let custom = def.custom { return resetCustom(custom) }
        if def.scope == .system {
            let cmd = (["defaults"] + deleteArguments(def)).map(Shell.quote).joined(separator: " ")
            return Shell.runPrivileged(cmd)
        }
        return Shell.run("defaults", deleteArguments(def))
    }

    public static func restart(_ processes: Set<ProcessToRestart>) {
        for p in processes { Shell.run("killall", [p.rawValue]) }
    }

    // MARK: Custom settings

    private static func readCustom(_ custom: PrefCustom) -> PrefValue? {
        switch custom {
        case .timezone:
            let r = Shell.run("readlink", ["/etc/localtime"])
            guard r.ok, let range = r.out.range(of: "zoneinfo/") else { return nil }
            return .string(String(r.out[range.upperBound...]))
        case .networkTime:
            let r = Shell.run("systemsetup", ["-getusingnetworktime"])
            return r.ok ? .bool(r.out.lowercased().hasSuffix("on")) : nil
        case .showLibrary:
            let r = Shell.run("ls", ["-ldO", expandTilde("~/Library")])
            return .bool(!r.out.contains("hidden"))
        case .inputSource:
            let r = Shell.run("defaults", ["read", "com.apple.HIToolbox", "AppleEnabledInputSources"])
            for line in r.out.components(separatedBy: "\n") where line.contains("KeyboardLayout Name") {
                let name = line.components(separatedBy: "=").last?
                    .trimmingCharacters(in: CharacterSet(charactersIn: " ;\""))
                if let name, !name.isEmpty, name != "U.S." { return .string(name) }
            }
            return nil
        case .defaultShell:
            let r = Shell.run("dscl", [".", "-read", expandTilde("~"), "UserShell"])
            guard let path = r.out.components(separatedBy: " ").last else { return nil }
            return .string((path as NSString).lastPathComponent)
        }
    }

    private static func writeCustom(_ custom: PrefCustom, _ value: PrefValue) -> ShellResult {
        switch custom {
        case .timezone:
            return Shell.runPrivileged("systemsetup -settimezone \(Shell.quote(value.stringValue ?? "UTC"))")
        case .networkTime:
            return Shell.runPrivileged("systemsetup -setusingnetworktime \(value.boolValue == true ? "on" : "off")")
        case .showLibrary:
            return Shell.run("chflags", [value.boolValue == true ? "nohidden" : "hidden", expandTilde("~/Library")])
        case .inputSource:
            guard let name = value.stringValue, !name.isEmpty else { return resetCustom(.inputSource) }
            _ = Shell.run("defaults", ["delete", "com.apple.HIToolbox", "AppleEnabledInputSources"])
            let entry = "<dict><key>InputSourceKind</key><string>Keyboard Layout</string><key>KeyboardLayout ID</key><integer>1111</integer><key>KeyboardLayout Name</key><string>\(name)</string></dict>"
            return Shell.run("defaults", ["write", "com.apple.HIToolbox", "AppleEnabledInputSources", "-array-add", entry])
        case .defaultShell:
            let name = value.stringValue ?? "zsh"
            return setDefaultShell(name)
        }
    }

    private static func resetCustom(_ custom: PrefCustom) -> ShellResult {
        switch custom {
        case .timezone, .networkTime: return ShellResult(status: 0, out: "", err: "")
        case .showLibrary: return Shell.run("chflags", ["hidden", expandTilde("~/Library")])
        case .inputSource: return Shell.run("defaults", ["delete", "com.apple.HIToolbox", "AppleEnabledInputSources"])
        case .defaultShell: return setDefaultShell("zsh")
        }
    }

    private static func setDefaultShell(_ name: String) -> ShellResult {
        let which = Shell.run("which", [name])
        guard which.ok, !which.out.isEmpty else {
            return ShellResult(status: 1, out: "", err: "Shell '\(name)' is not installed")
        }
        let path = which.out
        // Homebrew shells have to be listed in /etc/shells first.
        let script = "grep -qx \(Shell.quote(path)) /etc/shells || echo \(Shell.quote(path)) >> /etc/shells; chsh -s \(Shell.quote(path)) \(NSUserName())"
        return Shell.runPrivileged(script)
    }
}
