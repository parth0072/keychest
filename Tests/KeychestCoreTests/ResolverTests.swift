import XCTest
@testable import KeychestCore

final class ResolverTests: XCTestCase {
    let allSecrets = ["clientID": "cid", "apiKeyDebug": "dbg", "apiKeyRelease": "rel"]

    func testResolvesEverything() throws {
        let config = try Config.parse(sampleYAML)
        let resolved = try SecretResolver.resolve(config: config, backend: InMemoryBackend(allSecrets))
        XCTAssertEqual(resolved.global, [ResolvedSecret(key: "clientID", value: "cid")])
        XCTAssertEqual(resolved.environments.map(\.name), ["Debug", "Release"])
        XCTAssertEqual(resolved.environments[1].secrets, [ResolvedSecret(key: "apiKey", value: "rel")])
    }

    func testReportsAllMissingSecretsAtOnce() throws {
        let config = try Config.parse(sampleYAML)
        XCTAssertThrowsError(try SecretResolver.resolve(config: config, backend: InMemoryBackend(["clientID": "cid"]))) { error in
            XCTAssertEqual(error as? KeychestError,
                           .missingSecrets(accounts: ["apiKeyDebug", "apiKeyRelease"], backend: "memory"))
        }
    }

    func testEnvironmentFilterSkipsOtherEnvironments() throws {
        let config = try Config.parse(sampleYAML)
        // Release secret is absent, but we only ask for Debug.
        let backend = InMemoryBackend(["clientID": "cid", "apiKeyDebug": "dbg"])
        let resolved = try SecretResolver.resolve(config: config, backend: backend, environments: ["Debug"])
        XCTAssertEqual(resolved.environments.map(\.name), ["Debug"])
    }

    func testUnknownEnvironmentIsRejected() throws {
        let config = try Config.parse(sampleYAML)
        XCTAssertThrowsError(try SecretResolver.resolve(config: config, backend: InMemoryBackend(allSecrets), environments: ["Nope"]))
    }

    func testAuditNeverReturnsValues() throws {
        let config = try Config.parse(sampleYAML)
        let report = try SecretResolver.audit(config: config, backend: InMemoryBackend(["clientID": "cid"]))
        XCTAssertEqual(report.map(\.account), ["clientID", "apiKeyDebug", "apiKeyRelease"])
        XCTAssertEqual(report.map(\.present), [true, false, false])
    }

    func testEnvironmentBackendReadsOnlyNonEmptyValues() throws {
        let backend = EnvironmentBackend(environment: ["A": "1", "B": ""])
        XCTAssertEqual(try backend.read(account: "A"), "1")
        XCTAssertNil(try backend.read(account: "B"))
        XCTAssertNil(try backend.read(account: "C"))
        XCTAssertThrowsError(try backend.write(account: "A", value: "x"))
    }
}
