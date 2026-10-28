import Foundation

/// A few facts about this Mac for the device card.
public struct HardwareInfo {
    public let chip: String
    public let memoryGB: Int
    public let osVersion: String
    public let isLaptop: Bool

    public static let current = read()

    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }

    private static func read() -> HardwareInfo {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        let os = "macOS \(v.majorVersion).\(v.minorVersion)" + (v.patchVersion > 0 ? ".\(v.patchVersion)" : "")
        let battery = Shell.run("pmset", ["-g", "batt"]).out.contains("InternalBattery")
        return HardwareInfo(
            chip: sysctlString("machdep.cpu.brand_string") ?? "Mac",
            memoryGB: Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824),
            osVersion: os,
            isLaptop: battery)
    }

    /// SF Symbol that fits the device (guessing desktop models from the name).
    public func symbol(forName name: String) -> String {
        let n = name.lowercased()
        if isLaptop { return "laptopcomputer" }
        if n.contains("mini") { return "macmini" }
        if n.contains("studio") { return "macstudio" }
        return "desktopcomputer"
    }
}
