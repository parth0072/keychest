import Foundation

#if canImport(Security)
import Security

/// Stores secrets as generic-password items in the macOS login keychain.
public struct KeychainBackend: SecretBackend {
    public let service: String

    public init(service: String) throws {
        self.service = service
    }

    public var name: String { "Keychain" }

    private func query(for account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private func failure(_ status: OSStatus) -> KeychestError {
        let message = (SecCopyErrorMessageString(status, nil) as String?) ?? "OSStatus \(status)"
        return .backendFailure(backend: name, message: message)
    }

    public func read(account: String) throws -> String? {
        var q = query(for: account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
                throw KeychestError.backendFailure(backend: name, message: "'\(account)' is not valid UTF-8 text.")
            }
            return value
        case errSecItemNotFound:
            return nil
        default:
            throw failure(status)
        }
    }

    public func write(account: String, value: String) throws {
        let data = Data(value.utf8)
        let status = SecItemUpdate(query(for: account) as CFDictionary,
                                   [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var attributes = query(for: account)
            attributes[kSecValueData as String] = data
            let addStatus = SecItemAdd(attributes as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw failure(addStatus) }
        } else if status != errSecSuccess {
            throw failure(status)
        }
    }

    public func delete(account: String) throws {
        let status = SecItemDelete(query(for: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw failure(status) }
    }
}

#else

/// Placeholder so the package still builds on Linux (used for CI of the core logic).
public struct KeychainBackend: SecretBackend {
    public init(service: String) throws {
        throw KeychestError.unsupportedBackend("keychain")
    }
    public var name: String { "Keychain" }
    public func read(account: String) throws -> String? { throw KeychestError.unsupportedBackend("keychain") }
    public func write(account: String, value: String) throws { throw KeychestError.unsupportedBackend("keychain") }
    public func delete(account: String) throws { throw KeychestError.unsupportedBackend("keychain") }
}

#endif
