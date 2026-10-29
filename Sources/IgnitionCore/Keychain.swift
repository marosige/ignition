import Foundation
import Security

/// Stores secrets in the login keychain. The app is ad-hoc signed, so a normal per-app
/// keychain entry asks for the login password again after every build; items are saved
/// with an open access list instead (still encrypted, readable while you are logged in),
/// and each secret is read at most once per launch.
public enum Keychain {
    private static let service = "me.marosi.ignition"
    private static let lock = NSLock()
    private static var cache: [String: String?] = [:]

    private static func openAccount(_ account: String) -> String { account + ".open" }

    public static func save(_ value: String, account: String) {
        lock.lock(); defer { lock.unlock() }
        cache[account] = value
        delete(openAccount(account))
        guard !value.isEmpty else { return }
        var item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: openAccount(account),
            kSecValueData as String: Data(value.utf8),
        ]
        var access: SecAccess?
        // A nil trusted-application list means "any application may use this item".
        if SecAccessCreate("Ignition" as CFString, nil, &access) == errSecSuccess, let access {
            item[kSecAttrAccess as String] = access
        }
        SecItemAdd(item as CFDictionary, nil)
    }

    public static func load(account: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        if let cached = cache[account] { return cached }
        var found = read(openAccount(account))
        if found == nil, let legacy = read(account) {
            // Older versions stored it under the plain name: move it once.
            found = legacy
            lock.unlock()
            save(legacy, account: account)
            lock.lock()
            delete(account)
        }
        cache[account] = found
        return found
    }

    private static func read(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func delete(_ account: String) {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ] as CFDictionary)
    }
}
