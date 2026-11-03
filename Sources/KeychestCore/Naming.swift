import Foundation

/// Helpers for turning config key names into Swift identifiers and backend account names.
public enum Naming {
    /// Swift keywords that cannot be used as bare property names.
    private static let reserved: Set<String> = [
        "associatedtype", "class", "deinit", "enum", "extension", "fileprivate", "func",
        "import", "init", "inout", "internal", "let", "open", "operator", "private",
        "protocol", "public", "rethrows", "static", "struct", "subscript", "typealias",
        "var", "break", "case", "continue", "default", "defer", "do", "else", "fallthrough",
        "for", "guard", "if", "in", "repeat", "return", "switch", "where", "while", "as",
        "Any", "catch", "false", "is", "nil", "super", "self", "Self", "throw", "throws",
        "true", "try",
    ]

    /// Validates a key name: ASCII letter first, then letters/digits/underscores.
    public static func validate(_ name: String) throws {
        guard let first = name.unicodeScalars.first,
              first.isASCII, CharacterSet.letters.contains(first) else {
            throw KeychestError.invalidKeyName(name)
        }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        guard name.unicodeScalars.allSatisfy({ $0.isASCII && allowed.contains($0) }) else {
            throw KeychestError.invalidKeyName(name)
        }
    }

    /// Lowercases only the first character: `MySecretAPIKey` -> `mySecretAPIKey`.
    public static func propertyName(_ key: String) -> String {
        guard let first = key.first else { return key }
        let name = first.lowercased() + key.dropFirst()
        return reserved.contains(name) ? "`\(name)`" : name
    }

    /// Account name used in a backend for a secret scoped to an environment.
    /// `apiKey` + `Debug` -> `apiKeyDebug` (same convention as Arkana).
    public static func account(key: String, environment: String?) -> String {
        guard let environment else { return key }
        return key + environment
    }
}
