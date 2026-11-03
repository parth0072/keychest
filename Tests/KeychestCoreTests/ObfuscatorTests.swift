import XCTest
@testable import KeychestCore

final class ObfuscatorTests: XCTestCase {
    func testRoundTrip() {
        for value in ["", "a", "sk_live_abc123", "p@ss $word \\ \" ' `", "héllo 🔑 世界", String(repeating: "x", count: 500)] {
            let encoded = Obfuscator.encode(value, salt: fixedSalt)
            XCTAssertEqual(Obfuscator.decode(encoded, salt: fixedSalt), value)
        }
    }

    func testEncodedBytesDifferFromPlaintext() {
        let value = "sk_live_abc123"
        XCTAssertNotEqual(Obfuscator.encode(value, salt: fixedSalt), Array(value.utf8))
    }

    func testDifferentSaltsProduceDifferentOutput() {
        let other = fixedSalt.map { $0 ^ 0xFF }
        XCTAssertNotEqual(Obfuscator.encode("secret", salt: fixedSalt), Obfuscator.encode("secret", salt: other))
    }

    func testRandomSaltHasExpectedLengthAndVaries() {
        XCTAssertEqual(Obfuscator.randomSalt().count, Obfuscator.saltLength)
        XCTAssertNotEqual(Obfuscator.randomSalt(), Obfuscator.randomSalt())
    }
}
