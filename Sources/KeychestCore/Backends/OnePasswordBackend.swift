import Foundation

/// Reads secrets through the 1Password CLI (`op`). Read-only: manage values in 1Password itself.
///
/// Each account maps to a field of one item: `op://<vault>/<item>/<account>`.
public struct OnePasswordBackend: SecretBackend {
    public let vault: String
    public let item: String

    public init(vault: String, item: String) {
        self.vault = vault
        self.item = item
    }

    public var name: String { "1Password" }

    public func read(account: String) throws -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["op", "read", "--no-newline", "op://\(vault)/\(item)/\(account)"]

        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err

        do {
            try process.run()
        } catch {
            throw KeychestError.backendFailure(backend: name, message: "Could not launch `op`: \(error.localizedDescription)")
        }
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let message = String(data: errData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "exit code \(process.terminationStatus)"
            // `op` reports a missing field as an error; treat that as "not found".
            if message.lowercased().contains("isn't a field") || message.lowercased().contains("could not be found") {
                return nil
            }
            throw KeychestError.backendFailure(backend: name, message: message)
        }
        let value = String(data: outData, encoding: .utf8) ?? ""
        return value.isEmpty ? nil : value
    }

    public func write(account: String, value: String) throws {
        throw KeychestError.unsupportedOperation(backend: name, operation: "set")
    }

    public func delete(account: String) throws {
        throw KeychestError.unsupportedOperation(backend: name, operation: "remove")
    }
}
