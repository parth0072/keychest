import XCTest
@testable import KeychestCore

final class CodeGeneratorTests: XCTestCase {
    private func generate(secrets: [String: String] = ["clientID": "super-secret-client", "apiKeyDebug": "debug-key-123", "apiKeyRelease": "release-key-456"],
                          yaml: String = sampleYAML) throws -> [GeneratedFile] {
        let config = try Config.parse(yaml)
        let resolved = try SecretResolver.resolve(config: config, backend: InMemoryBackend(secrets))
        return CodeGenerator(config: config, salt: fixedSalt).generate(from: resolved)
    }

    func testProducesManifestSourceAndGitignore() throws {
        let files = try generate()
        XCTAssertEqual(files.map(\.path), ["Package.swift", "Sources/KeychestKeys/Secrets.swift", ".gitignore"])
    }

    func testGitignoreCanBeDisabled() throws {
        let files = try generate(yaml: sampleYAML + "\noutput:\n  gitignore: false")
        XCTAssertFalse(files.contains { $0.path == ".gitignore" })
    }

    func testNoPlaintextSecretsAppearInOutput() throws {
        let files = try generate()
        for file in files {
            for secret in ["super-secret-client", "debug-key-123", "release-key-456"] {
                XCTAssertFalse(file.contents.contains(secret), "\(file.path) leaks \(secret)")
            }
        }
    }

    func testSourceContainsExpectedAPI() throws {
        let source = try XCTUnwrap(generate().first { $0.path.hasSuffix("Secrets.swift") }).contents
        XCTAssertTrue(source.contains("public protocol SecretsGlobalProtocol"))
        XCTAssertTrue(source.contains("public protocol SecretsEnvironmentProtocol"))
        XCTAssertTrue(source.contains("public struct Global: SecretsGlobalProtocol"))
        XCTAssertTrue(source.contains("public struct Debug: SecretsEnvironmentProtocol"))
        XCTAssertTrue(source.contains("public struct Release: SecretsEnvironmentProtocol"))
        XCTAssertTrue(source.contains("public var clientID: String"))
        XCTAssertTrue(source.contains("public var apiKey: String"))
    }

    func testOutputIsDeterministicForAFixedSalt() throws {
        XCTAssertEqual(try generate(), try generate())
    }

    func testDifferentSaltsChangeTheOutput() throws {
        let config = try Config.parse(sampleYAML)
        let resolved = try SecretResolver.resolve(config: config, backend: InMemoryBackend(["clientID": "c", "apiKeyDebug": "d", "apiKeyRelease": "r"]))
        let a = CodeGenerator(config: config, salt: fixedSalt).generate(from: resolved)
        let b = CodeGenerator(config: config, salt: fixedSalt.map { $0 ^ 1 }).generate(from: resolved)
        XCTAssertNotEqual(a, b)
    }

    func testCustomNamesAreHonoured() throws {
        let yaml = sampleYAML + "\noutput:\n  package_name: AppKeys\n  type_name: Keys"
        let files = try generate(yaml: yaml)
        XCTAssertTrue(files.contains { $0.path == "Sources/AppKeys/Keys.swift" })
        let manifest = try XCTUnwrap(files.first { $0.path == "Package.swift" }).contents
        XCTAssertTrue(manifest.contains("name: \"AppKeys\""))
    }

    func testGlobalOnlyConfigOmitsEnvironmentProtocol() throws {
        let files = try generate(secrets: ["a": "1"], yaml: "backend: env\nglobal_secrets: [a]")
        let source = try XCTUnwrap(files.first { $0.path.hasSuffix(".swift") && $0.path != "Package.swift" }).contents
        XCTAssertFalse(source.contains("EnvironmentProtocol"))
    }

    func testScreamingSnakeCaseKeysBecomeCamelCaseProperties() throws {
        let files = try generate(secrets: ["MAPS_API_KEY": "m", "API_TOKENDebug": "t"],
                                 yaml: "backend: env\nenvironments: [Debug]\nenvironment_secrets: [API_TOKEN]\nglobal_secrets: [MAPS_API_KEY]")
        let source = try XCTUnwrap(files.first { $0.path.hasSuffix("Secrets.swift") }).contents
        XCTAssertTrue(source.contains("public var mapsApiKey: String"))
        XCTAssertTrue(source.contains("public var apiToken: String"))
        XCTAssertFalse(source.contains("mAPS_API_KEY"))
        XCTAssertFalse(source.contains("aPI_TOKEN"))
    }

    func testEnvironmentsWithoutEnvironmentSecretsDoNotReferenceAMissingProtocol() throws {
        let files = try generate(secrets: ["a": "1"], yaml: "backend: env\nenvironments: [Debug, Release]\nglobal_secrets: [a]")
        let source = try XCTUnwrap(files.first { $0.path.hasSuffix("Secrets.swift") }).contents
        XCTAssertFalse(source.contains("EnvironmentProtocol"))
        XCTAssertFalse(source.contains("struct Debug"))
    }

    func testWriterWritesFilesAndLeavesOthersAlone() throws {
        let dir = NSTemporaryDirectory() + "keychest-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: dir) }
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try "keep".write(toFile: dir + "/unrelated.txt", atomically: true, encoding: .utf8)

        let written = try OutputWriter.write(try generate(), to: dir)
        XCTAssertEqual(written.count, 3)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir + "/Sources/KeychestKeys/Secrets.swift"))
        XCTAssertEqual(try String(contentsOfFile: dir + "/unrelated.txt"), "keep")
    }
}
