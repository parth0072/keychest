import Foundation

/// Rudimentary XOR obfuscation with a per-run random salt.
///
/// This is **obfuscation, not encryption**. It only prevents secrets from appearing as
/// plain text in `strings` output. Anyone who can run your app can recover them.
/// See docs/THREAT_MODEL.md.
public enum Obfuscator {
    public static let saltLength = 32

    public static func randomSalt<G: RandomNumberGenerator>(using generator: inout G) -> [UInt8] {
        (0..<saltLength).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
    }

    public static func randomSalt() -> [UInt8] {
        var generator = SystemRandomNumberGenerator()
        return randomSalt(using: &generator)
    }

    public static func encode(_ value: String, salt: [UInt8]) -> [UInt8] {
        precondition(!salt.isEmpty, "salt must not be empty")
        return value.utf8.enumerated().map { index, byte in byte ^ salt[index % salt.count] }
    }

    public static func decode(_ encoded: [UInt8], salt: [UInt8]) -> String {
        precondition(!salt.isEmpty, "salt must not be empty")
        let bytes = encoded.enumerated().map { index, byte in byte ^ salt[index % salt.count] }
        return String(decoding: bytes, as: UTF8.self)
    }
}
