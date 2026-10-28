import Foundation

/// Loads and saves profiles and the device file.
public enum ConfigStore {
    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return e
    }()

    public static func loadDevice() -> DeviceConfig {
        if let data = try? Data(contentsOf: AppPaths.device),
           let device = try? JSONDecoder().decode(DeviceConfig.self, from: data) {
            return device
        }
        return DeviceConfig(deviceName: Host.current().localizedName ?? "Mac")
    }

    public static func saveDevice(_ device: DeviceConfig) {
        guard let data = try? encoder.encode(device) else { return }
        try? data.write(to: AppPaths.device, options: .atomic)
    }

    public static func profileNames() -> [String] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: AppPaths.profiles, includingPropertiesForKeys: nil)) ?? []
        return urls
            .filter { FileManager.default.fileExists(atPath: $0.appendingPathComponent("profile.json").path) }
            .map(\.lastPathComponent)
            .sorted { a, b in a == "base" ? true : (b == "base" ? false : a < b) }
    }

    public static func loadProfile(_ name: String) -> Profile? {
        guard let data = try? Data(contentsOf: AppPaths.profileFile(name)) else { return nil }
        return try? JSONDecoder().decode(Profile.self, from: data)
    }

    public static func saveProfile(_ profile: Profile, name: String) throws {
        try FileManager.default.createDirectory(at: AppPaths.profileDir(name), withIntermediateDirectories: true)
        try encoder.encode(profile).write(to: AppPaths.profileFile(name), options: .atomic)
    }

    public static func deleteProfile(_ name: String) throws {
        try FileManager.default.removeItem(at: AppPaths.profileDir(name))
    }

    /// Copies the bundled starter config into the repo if there is none yet.
    public static func installSeed() throws {
        guard let seed = AppPaths.seed else {
            throw NSError(domain: "Ignition", code: 1, userInfo: [NSLocalizedDescriptionKey: "Starter configuration not found in the app bundle."])
        }
        let fm = FileManager.default
        let dest = AppPaths.configRoot
        try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
        try fm.copyItem(at: seed.appendingPathComponent("ignition"), to: dest)
    }
}
