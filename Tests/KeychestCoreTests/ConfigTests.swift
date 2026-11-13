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

    func testPlatformsDefaultToSwiftAndKotlinHasDefaults() throws {
        let config = try Config.parse(sampleYAML)
        XCTAssertEqual(config.platforms, [.swift])
        XCTAssertEqual(config.kotlin, Config.Kotlin())
    }

    func testParsesPlatformsAndKotlinSettings() throws {
        let config = try Config.parse(sampleYAML + """

        platforms: [swift, kotlin]
        kotlin:
          path: android/keys
          package: com.acme.app.keys
          type_name: Keys
          gitignore: false
        """)
        XCTAssertEqual(config.platforms, [.swift, .kotlin])
        XCTAssertEqual(config.kotlin, Config.Kotlin(path: "android/keys", packageName: "com.acme.app.keys",
                                                    typeName: "Keys", gitignore: false))
    }

    func testRejectsUnknownEmptyOrDuplicatePlatforms() {
        for platforms in ["[java]", "[]", "[kotlin, kotlin]"] {
            XCTAssertThrowsError(try Config.parse(sampleYAML + "\nplatforms: \(platforms)"), platforms)
        }
    }

    func testUnknownPlatformMessageIsReadable() {
        XCTAssertThrowsError(try Config.parse(sampleYAML + "\nplatforms: [java]")) { error in
            XCTAssertEqual(error as? KeychestError, .invalidConfig("Unknown platform 'java'. Use swift or kotlin."))
        }
    }

    func testRejectsInvalidKotlinSettings() {
        for setting in ["package: com..keys", "package: 1com.keys", "package: com.example.class",
                        "package: com.example.new", "type_name: object", "type_name: 'my-type'"] {
            XCTAssertThrowsError(try Config.parse(sampleYAML + "\nkotlin:\n  \(setting)"), setting)
        }
    }

    func testRejectsKeysThatBecomeTheSameProperty() {
        for global in ["[API_KEY, apiKey]", "[Foo, foo]", "[API_KEY, API__KEY]"] {
            XCTAssertThrowsError(try Config.parse("backend: env\nglobal_secrets: \(global)"), global)
        }
        XCTAssertThrowsError(try Config.parse("backend: env\nenvironments: [Debug]\nenvironment_secrets: [API_KEY, apiKey]"))
    }

    func testCollisionMessageNamesBothKeys() {
        XCTAssertThrowsError(try Config.parse("backend: env\nglobal_secrets: [API_KEY, apiKey]")) { error in
            XCTAssertEqual(error as? KeychestError,
                           .invalidConfig("'API_KEY' and 'apiKey' both become the property 'apiKey'. Rename one of them."))
        }
    }

    func testGlobalAndEnvironmentSecretsMayShareAPropertyName() {
        // They live in different generated types, so the names cannot clash.
        XCTAssertNoThrow(try Config.parse("backend: env\nenvironments: [Debug]\nenvironment_secrets: [API_KEY]\nglobal_secrets: [apiKey]"))
    }

    func testMissingFileReportsNotFound() {
        XCTAssertThrowsError(try Config.load(from: "/definitely/not/here.yml")) { error in
            XCTAssertEqual(error as? KeychestError, .configNotFound("/definitely/not/here.yml"))
        }
    }
}
