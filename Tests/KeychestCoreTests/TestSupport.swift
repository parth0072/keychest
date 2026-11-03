import Foundation
@testable import KeychestCore

/// In-memory backend for tests.
final class InMemoryBackend: SecretBackend {
    var store: [String: String]
    init(_ store: [String: String] = [:]) { self.store = store }
    var name: String { "memory" }
    func read(account: String) throws -> String? { store[account] }
    func write(account: String, value: String) throws { store[account] = value }
    func delete(account: String) throws { store[account] = nil }
}

let sampleYAML = """
backend: keychain
service: com.example.test
environments: [Debug, Release]
environment_secrets: [apiKey]
global_secrets: [clientID]
"""

let fixedSalt: [UInt8] = (0..<32).map { UInt8(($0 * 37 + 11) % 256) }
