import XCTest
@testable import KeychestCore

final class ConfigTests: XCTestCase {
    func testParsesValidConfigWithDefaults() throws {
        let config = try Config.parse(sampleYAML)
        XCTAssertEqual(config.backend, .keychain)
        XCTAssertEqual(config.service, "com.example.test")
        XCTAssertEqual(config.environments, ["Debug", "Release"])
        XCTAssertEqual(config.output, Config.Output())
    }

    func testBundledTemplateIsValid() throws {
        XCTAssertNoThrow(try Config.parse(ConfigTemplate.contents))
    }

    func testKeychainBackendRequiresService() {
        let yaml = "global_secrets: [a]"
        XCTAssertThrowsError(try Config.parse(yaml))
    }

    func testOnePasswordBackendRequiresSection() {
        XCTAssertThrowsError(try Config.parse("backend: 1password\nglobal_secrets: [a]"))
        XCTAssertNoThrow(try Config.parse("""
        backend: 1password
        onepassword: { vault: Dev, item: App }
        global_secrets: [a]
        """))
    }

    func testEnvBackendNeedsNoService() throws {
        let config = try Config.parse("backend: env\nglobal_secrets: [a]")
        XCTAssertEqual(config.backend, .env)
    }

    func testRejectsEnvironmentSecretsWithoutEnvironments() {
        XCTAssertThrowsError(try Config.parse("backend: env\nenvironment_secrets: [a]"))
    }

    func testRejectsNoSecrets() {
        XCTAssertThrowsError(try Config.parse("backend: env"))
    }

    func testRejectsDuplicatesAcrossScopes() {
        XCTAssertThrowsError(try Config.parse("""
        backend: env
        environments: [Debug]
        environment_secrets: [a]
        global_secrets: [a]
        """))
    }

    func testRejectsReservedGlobalEnvironmentName() {
        XCTAssertThrowsError(try Config.parse("""
        backend: env
        environments: [Global]
        environment_secrets: [a]
        """))
    }

    func testRejectsInvalidKeyNames() {
        XCTAssertThrowsError(try Config.parse("backend: env\nglobal_secrets: ['bad-name']"))
    }

    func testRequiredAccounts() throws {
        let config = try Config.parse(sampleYAML)
        XCTAssertEqual(config.requiredAccounts(), ["clientID", "apiKeyDebug", "apiKeyRelease"])
        XCTAssertEqual(config.requiredAccounts(environments: ["Debug"]), ["clientID", "apiKeyDebug"])
    }

    func testMissingFileReportsNotFound() {
        XCTAssertThrowsError(try Config.load(from: "/definitely/not/here.yml")) { error in
            XCTAssertEqual(error as? KeychestError, .configNotFound("/definitely/not/here.yml"))
        }
    }
}
