import Foundation
import Security

/// Where the API key lives. The app uses the Keychain; tests use memory.
/// The key is never written to UserDefaults, a file, or a log.
protocol SecretStore: Sendable {
    func read(_ account: String) -> String?
    func write(_ value: String, for account: String) throws
    func delete(_ account: String)
}

struct KeychainSecretStore: SecretStore {
    let service: String

    init(service: String = "com.tonywen.reportingbuilder.assistant") {
        self.service = service
    }

    private func query(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    func read(_ account: String) -> String? {
        var query = query(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func write(_ value: String, for account: String) throws {
        let data = Data(value.utf8)
        let status: OSStatus
        if read(account) != nil {
            status = SecItemUpdate(query(account) as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        } else {
            var attributes = query(account)
            attributes[kSecValueData as String] = data
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemAdd(attributes as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw AssistantError.notConfigured("The key could not be saved to the Keychain (\(status)).")
        }
    }

    func delete(_ account: String) {
        SecItemDelete(query(account) as CFDictionary)
    }
}

final class InMemorySecretStore: SecretStore, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: String] = [:]

    func read(_ account: String) -> String? {
        lock.withLock { values[account] }
    }

    func write(_ value: String, for account: String) throws {
        lock.withLock { values[account] = value }
    }

    func delete(_ account: String) {
        lock.withLock { values[account] = nil }
    }
}
