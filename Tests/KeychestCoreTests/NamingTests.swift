import XCTest
@testable import KeychestCore

final class NamingTests: XCTestCase {
    func testValidNames() throws {
        for name in ["apiKey", "API_KEY", "key2", "MySecretAPIKey"] {
            XCTAssertNoThrow(try Naming.validate(name), name)
        }
    }

    func testInvalidNames() {
        for name in ["", "1key", "_key", "my-key", "my key", "clé", "a.b"] {
            XCTAssertThrowsError(try Naming.validate(name), name)
        }
    }

    func testPropertyNameLowercasesOnlyFirstCharacter() {
        XCTAssertEqual(Naming.propertyName("MySecretAPIKey"), "mySecretAPIKey")
        XCTAssertEqual(Naming.propertyName("apiKey"), "apiKey")
    }

    func testReservedWordsAreEscaped() {
        XCTAssertEqual(Naming.propertyName("Default"), "`default`")
        XCTAssertEqual(Naming.propertyName("Class"), "`class`")
    }

    func testKotlinKeywordsAreEscaped() {
        XCTAssertEqual(Naming.kotlinPropertyName("Object"), "`object`")
        XCTAssertEqual(Naming.kotlinPropertyName("In"), "`in`")
        XCTAssertEqual(Naming.kotlinPropertyName("apiKey"), "apiKey")
        XCTAssertEqual(Naming.kotlinPropertyName("MySecretAPIKey"), "mySecretAPIKey")
        XCTAssertEqual(Naming.kotlinIdentifier("if"), "`if`")
        XCTAssertEqual(Naming.kotlinIdentifier("Debug"), "Debug")
        // Swift-only keywords are ordinary names in Kotlin.
        XCTAssertEqual(Naming.kotlinPropertyName("Default"), "default")
        XCTAssertEqual(Naming.kotlinPropertyName("Let"), "let")
    }

    func testPackageValidation() {
        for name in ["com.example.keys", "keychest.keys", "app", "a1.b_2"] {
            XCTAssertNoThrow(try Naming.validatePackage(name), name)
        }
        for name in ["", ".", "com..x", "com.example.", "1com", "com.my-app", "com.example.class", "com.example.new", "com.clé"] {
            XCTAssertThrowsError(try Naming.validatePackage(name), name)
        }
    }

    func testAccountNaming() {
        XCTAssertEqual(Naming.account(key: "apiKey", environment: "Debug"), "apiKeyDebug")
        XCTAssertEqual(Naming.account(key: "clientID", environment: nil), "clientID")
    }
}
