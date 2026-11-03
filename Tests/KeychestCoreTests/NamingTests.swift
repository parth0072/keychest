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

    func testAccountNaming() {
        XCTAssertEqual(Naming.account(key: "apiKey", environment: "Debug"), "apiKeyDebug")
        XCTAssertEqual(Naming.account(key: "clientID", environment: nil), "clientID")
    }
}
