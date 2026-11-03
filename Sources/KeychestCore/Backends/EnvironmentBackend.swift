import Foundation

/// Reads secrets from process environment variables. Useful on CI, where the
/// platform injects secrets as env vars. Read-only.
public struct EnvironmentBackend: SecretBackend {
    private let environment: [String: String]

    public init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.environment = environment
    }

    public var name: String { "environment" }

    public func read(account: String) throws -> String? {
        guard let value = environment[account], !value.isEmpty else { return nil }
        return value
    }

    public func write(account: String, value: String) throws {
        throw KeychestError.unsupportedOperation(backend: name, operation: "set")
    }

    public func delete(account: String) throws {
        throw KeychestError.unsupportedOperation(backend: name, operation: "remove")
    }
}
