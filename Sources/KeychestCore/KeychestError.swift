import Foundation

/// Errors surfaced by Keychest. Messages are written for humans running the CLI.
public enum KeychestError: Error, CustomStringConvertible, Equatable {
    case configNotFound(String)
    case invalidConfig(String)
    case invalidKeyName(String)
    case missingSecrets(accounts: [String], backend: String)
    case backendFailure(backend: String, message: String)
    case unsupportedBackend(String)
    case unsupportedOperation(backend: String, operation: String)
    case writeFailure(String)

    public var description: String {
        switch self {
        case .configNotFound(let path):
            return "Config file not found at '\(path)'. Run `keychest init` to create one."
        case .invalidConfig(let reason):
            return "Invalid config: \(reason)"
        case .invalidKeyName(let name):
            return "'\(name)' is not a valid key name. Use ASCII letters, digits and underscores, starting with a letter."
        case .missingSecrets(let accounts, let backend):
            let list = accounts.map { "  - \($0)" }.joined(separator: "\n")
            return "Missing \(accounts.count) secret(s) in the \(backend) backend:\n\(list)\nAdd one with `keychest set <name>`."
        case .backendFailure(let backend, let message):
            return "\(backend) backend error: \(message)"
        case .unsupportedBackend(let name):
            return "The '\(name)' backend is not available on this platform."
        case .unsupportedOperation(let backend, let operation):
            return "The \(backend) backend is read-only and does not support '\(operation)'."
        case .writeFailure(let reason):
            return "Could not write file: \(reason)"
        }
    }
}
