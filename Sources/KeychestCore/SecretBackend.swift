import Foundation

/// A place secrets can be read from (and, for some backends, written to).
///
/// To add a new backend (Bitwarden, Vault, AWS Secrets Manager, ...), conform to this
/// protocol and register it in `BackendFactory`.
public protocol SecretBackend {
    /// Human-readable name used in messages.
    var name: String { get }
    /// Returns `nil` when the account simply does not exist.
    func read(account: String) throws -> String?
    func write(account: String, value: String) throws
    func delete(account: String) throws
}

public enum BackendFactory {
    public static func make(for config: Config) throws -> SecretBackend {
        switch config.backend {
        case .keychain:
            // `validate()` guarantees `service` is set for this backend.
            return try KeychainBackend(service: config.service ?? "")
        case .env:
            return EnvironmentBackend()
        case .onepassword:
            guard let op = config.onePassword else {
                throw KeychestError.invalidConfig("Missing `onepassword:` section.")
            }
            return OnePasswordBackend(vault: op.vault, item: op.item)
        }
    }
}
