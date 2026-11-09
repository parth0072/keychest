import XCTest
@testable import KeychestCore

final class KotlinCodeGeneratorTests: XCTestCase {
    private let defaultSecrets = ["clientID": "super-secret-client", "apiKeyDebug": "debug-key-123", "apiKeyRelease": "release-key-456"]

    private func generate(secrets: [String: String]? = nil,
                          yaml: String = sampleYAML,
                          salt: [UInt8] = fixedSalt) throws -> [GeneratedFile] {
        let config = try Config.parse(yaml)
        let resolved = try SecretResolver.resolve(config: config, backend: InMemoryBackend(secrets ?? defaultSecrets))
        return KotlinCodeGenerator(config: config, salt: salt).generate(from: resolved)
    }

    private func source(_ files: [GeneratedFile]) throws -> String {
        try XCTUnwrap(files.first { $0.path.hasSuffix(".kt") }).contents
    }

    // MARK: - Layout

    func testProducesBuildScriptSourceAndGitignore() throws {
        let files = try generate()
        XCTAssertEqual(files.map(\.path), ["build.gradle.kts", "src/main/kotlin/keychest/keys/Secrets.kt", ".gitignore"])
    }

    func testGitignoreCanBeDisabled() throws {
        let files = try generate(yaml: sampleYAML + "\nkotlin:\n  gitignore: false")
        XCTAssertFalse(files.contains { $0.path == ".gitignore" })
    }

    func testCustomNamesAreHonoured() throws {
        let files = try generate(yaml: sampleYAML + "\nkotlin:\n  package: com.acme.keys\n  type_name: Keys")
        XCTAssertTrue(files.contains { $0.path == "src/main/kotlin/com/acme/keys/Keys.kt" })
        let text = try source(files)
        XCTAssertTrue(text.contains("package com.acme.keys"))
        XCTAssertTrue(text.contains("interface KeysGlobal {"))
        XCTAssertTrue(text.contains("interface KeysEnvironment {"))
        XCTAssertTrue(text.contains("object Keys {"))
        XCTAssertTrue(text.contains("internal object _KeysDecoder {"))
    }

    func testBuildScriptTargetsJava11AndDeclaresNoRepositories() throws {
        let script = try XCTUnwrap(generate().first { $0.path == "build.gradle.kts" }).contents
        XCTAssertTrue(script.contains("kotlin(\"jvm\")"))
        XCTAssertTrue(script.contains("JvmTarget.JVM_11"))
        XCTAssertTrue(script.contains("JavaVersion.VERSION_11"))
        XCTAssertFalse(script.contains("repositories"))
    }

    // MARK: - Source

    func testSourceContainsExpectedAPI() throws {
        let text = try source(generate())
        for expected in [
            "package keychest.keys",
            "interface SecretsGlobal {",
            "interface SecretsEnvironment {",
            "object Secrets {",
            "object Global : SecretsGlobal {",
            "object Debug : SecretsEnvironment {",
            "object Release : SecretsEnvironment {",
            "val clientID: String",
            "override val apiKey: String",
            "internal object _SecretsDecoder {",
        ] {
            XCTAssertTrue(text.contains(expected), "missing: \(expected)")
        }
    }

    func testNoPlaintextSecretsAppearInOutput() throws {
        for file in try generate() {
            for secret in defaultSecrets.values {
                XCTAssertFalse(file.contents.contains(secret), "\(file.path) leaks \(secret)")
            }
        }
    }

    func testOutputIsDeterministicForAFixedSalt() throws {
        XCTAssertEqual(try generate(), try generate())
    }

    func testDifferentSaltsChangeTheOutput() throws {
        XCTAssertNotEqual(try generate(), try generate(salt: fixedSalt.map { $0 ^ 1 }))
    }

    func testKotlinKeywordsAreEscaped() throws {
        let yaml = """
        backend: env
        environments: [if]
        environment_secrets: [val]
        global_secrets: [object, Fun]
        """
        let text = try source(generate(secrets: ["object": "1", "Fun": "2", "valif": "3"], yaml: yaml))
        XCTAssertTrue(text.contains("val `object`: String"))
        XCTAssertTrue(text.contains("override val `fun`: String"))
        XCTAssertTrue(text.contains("override val `val`: String"))
        XCTAssertTrue(text.contains("object `if` : SecretsEnvironment {"))
    }

    func testGlobalOnlyConfigOmitsEnvironmentInterface() throws {
        let text = try source(generate(secrets: ["a": "1"], yaml: "backend: env\nglobal_secrets: [a]"))
        XCTAssertFalse(text.contains("SecretsEnvironment"))
    }

    func testEnvironmentsWithoutEnvironmentSecretsDoNotReferenceAMissingInterface() throws {
        let text = try source(generate(secrets: ["a": "1"],
                                       yaml: "backend: env\nenvironments: [Debug, Release]\nglobal_secrets: [a]"))
        XCTAssertFalse(text.contains("SecretsEnvironment"))
        XCTAssertFalse(text.contains("object Debug"))
    }

    // MARK: - Round trip

    /// Reads the `\u00XX` escapes of a string expression back into bytes. The expression ends
    /// at the first `)` because the escapes themselves never contain one.
    private func escapes(in text: Substring) -> [UInt8] {
        String(text.prefix { $0 != ")" })
            .components(separatedBy: "\\u00")
            .dropFirst()
            .compactMap { UInt8($0.prefix(2), radix: 16) }
    }

    private func saltBytes(in source: String) throws -> [UInt8] {
        let start = try XCTUnwrap(source.range(of: "private val salt: ByteArray =")).upperBound
        return escapes(in: source[start...])
    }

    private func literalBytes(of property: String, inObject object: String, in source: String) throws -> [UInt8] {
        let objectStart = try XCTUnwrap(source.range(of: "object \(object) :")).upperBound
        let propertyStart = try XCTUnwrap(source[objectStart...].range(of: "override val \(property): String")).upperBound
        let callStart = try XCTUnwrap(source[propertyStart...].range(of: "decode(")).upperBound
        return escapes(in: source[callStart...])
    }

    func testEncodedLiteralsDecodeBackToTheOriginalValues() throws {
        let secrets = [
            "clientID": "héllo 🔑 \"q\" $x \\ `",
            "apiKeyDebug": String(repeating: "x", count: 500),
            "apiKeyRelease": "plain",
        ]
        let text = try source(generate(secrets: secrets))
        let salt = try saltBytes(in: text)
        XCTAssertEqual(salt, fixedSalt)

        XCTAssertEqual(decode(try literalBytes(of: "clientID", inObject: "Global", in: text), salt: salt), secrets["clientID"])
        XCTAssertEqual(decode(try literalBytes(of: "apiKey", inObject: "Debug", in: text), salt: salt), secrets["apiKeyDebug"])
        XCTAssertEqual(decode(try literalBytes(of: "apiKey", inObject: "Release", in: text), salt: salt), secrets["apiKeyRelease"])
        // Long values are split over several constant-folded string pieces.
        XCTAssertTrue(text.contains("\" +\n"))
    }

    // MARK: - Writing

    func testWriterCreatesTheNestedPackageDirectories() throws {
        let dir = NSTemporaryDirectory() + "keychest-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let written = try OutputWriter.write(try generate(), to: dir)
        XCTAssertEqual(written.count, 3)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir + "/src/main/kotlin/keychest/keys/Secrets.kt"))
    }
}
