#if canImport(Security)
import XCTest
@testable import KeychestCore

/// Talks to the real macOS keychain, so it is opt-in:
///   KEYCHEST_KEYCHAIN_TESTS=1 swift test --filter KeychainBackendIntegrationTests
/// CI runs it against a throwaway keychain (see .github/workflows/ci.yml).
final class KeychainBackendIntegrationTests: XCTestCase {
    func testWriteReadUpdateDeleteRoundTrip() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["KEYCHEST_KEYCHAIN_TESTS"] == "1",
            "Set KEYCHEST_KEYCHAIN_TESTS=1 to run against the real keychain."
        )
        let backend = try KeychainBackend(service: "dev.keychest.tests.\(UUID().uuidString)")
        let account = "roundTrip"
        defer { try? backend.delete(account: account) }

        XCTAssertNil(try backend.read(account: account))
        try backend.write(account: account, value: "one")
        XCTAssertEqual(try backend.read(account: account), "one")
        try backend.write(account: account, value: "two") // exercises the update path
        XCTAssertEqual(try backend.read(account: account), "two")
        try backend.delete(account: account)
        XCTAssertNil(try backend.read(account: account))
    }
}
#endif
