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

    /// Kotlin hard keywords: these cannot be used as names without backticks.
    private static let kotlinReserved: Set<String> = [
        "as", "break", "class", "continue", "do", "else", "false", "for", "fun", "if", "in",
        "interface", "is", "null", "object", "package", "return", "super", "this", "throw",
        "true", "try", "typealias", "typeof", "val", "var", "when", "while",
    ]

    /// Java keywords, which would make a package unusable from Java code.
    private static let javaReserved: Set<String> = [
        "abstract", "assert", "boolean", "byte", "case", "catch", "char", "const", "default",
        "double", "enum", "extends", "final", "finally", "float", "goto", "implements", "import",
        "instanceof", "int", "long", "native", "new", "private", "protected", "public", "short",
        "static", "strictfp", "switch", "synchronized", "throws", "transient", "void", "volatile",
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
        let name = lowercasedFirst(key)
        return reserved.contains(name) ? "`\(name)`" : name
    }

    /// Same naming as `propertyName`, escaping Kotlin hard keywords instead of Swift ones.
    public static func kotlinPropertyName(_ key: String) -> String {
        kotlinIdentifier(lowercasedFirst(key))
    }

    /// Wraps a Kotlin hard keyword in backticks so it can be used as a name.
    public static func kotlinIdentifier(_ name: String) -> String {
        kotlinReserved.contains(name) ? "`\(name)`" : name
    }

    /// Validates a Kotlin/Java package such as `com.example.keys`: dot-separated ASCII
    /// names that start with a letter and are not Kotlin or Java keywords.
    public static func validatePackage(_ name: String) throws {
        let segments = name.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        for segment in segments {
            guard (try? validate(segment)) != nil,
                  !kotlinReserved.contains(segment), !javaReserved.contains(segment) else {
                throw KeychestError.invalidConfig("'\(name)' is not a valid Kotlin package. Use dot-separated names of ASCII letters, digits and underscores, such as com.example.keys.")
            }
        }
    }

    /// Validates the name of the generated Kotlin object.
    public static func validateKotlinTypeName(_ name: String) throws {
        try validate(name)
        if kotlinReserved.contains(name) {
            throw KeychestError.invalidConfig("'\(name)' is a Kotlin keyword and cannot be used as the Kotlin `type_name`.")
        }
    }

    private static func lowercasedFirst(_ key: String) -> String {
        guard let first = key.first else { return key }
        return first.lowercased() + key.dropFirst()
    }

    /// Account name used in a backend for a secret scoped to an environment.
    /// `apiKey` + `Debug` -> `apiKeyDebug` (same convention as Arkana).
    public static func account(key: String, environment: String?) -> String {
        guard let environment else { return key }
        return key + environment
    }
}
