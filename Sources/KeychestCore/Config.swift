import Foundation
import Yams

/// Where secret values are fetched from at generation time.
public enum BackendKind: String, Decodable {
    case keychain
    case env
    case onepassword = "1password"
}

/// Parsed `.keychest.yml`. The config only ever contains key *names*, never values,
/// so it is safe to commit.
public struct Config: Equatable {
    public struct Output: Equatable {
        /// Directory the generated Swift package is written to.
        public var path: String
        /// Name of the generated Swift package / library product (what you `import`).
        public var packageName: String
        /// Name of the top-level generated namespace, e.g. `Secrets`.
        public var typeName: String
        /// Write a `.gitignore` into the output directory so generated code is never committed.
        public var gitignore: Bool

        public init(path: String = "KeychestKeys",
                    packageName: String = "KeychestKeys",
                    typeName: String = "Secrets",
                    gitignore: Bool = true) {
            self.path = path
            self.packageName = packageName
            self.typeName = typeName
            self.gitignore = gitignore
        }
    }

    public struct OnePassword: Equatable, Decodable {
        public var vault: String
        public var item: String
        public init(vault: String, item: String) {
            self.vault = vault
            self.item = item
        }
    }

    public var backend: BackendKind
    /// Keychain service name (keychain backend only). Reverse-DNS is recommended.
    public var service: String?
    public var onePassword: OnePassword?
    /// Build configurations, e.g. `Debug`, `Release`, `Staging`.
    public var environments: [String]
    /// Secrets that have a different value per environment. Stored as `<key><Environment>`.
    public var environmentSecrets: [String]
    /// Secrets shared by every environment. Stored as `<key>`.
    public var globalSecrets: [String]
    public var output: Output

    public init(backend: BackendKind = .keychain,
                service: String? = nil,
                onePassword: OnePassword? = nil,
                environments: [String] = [],
                environmentSecrets: [String] = [],
                globalSecrets: [String] = [],
                output: Output = Output()) {
        self.backend = backend
        self.service = service
        self.onePassword = onePassword
        self.environments = environments
        self.environmentSecrets = environmentSecrets
        self.globalSecrets = globalSecrets
        self.output = output
    }
}

extension Config: Decodable {
    private enum CodingKeys: String, CodingKey {
        case backend, service, onepassword, environments, output
        case environmentSecrets = "environment_secrets"
        case globalSecrets = "global_secrets"
    }

    private struct OutputDTO: Decodable {
        var path: String?
        var packageName: String?
        var typeName: String?
        var gitignore: Bool?
        enum CodingKeys: String, CodingKey {
            case path, gitignore
            case packageName = "package_name"
            case typeName = "type_name"
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.backend = try c.decodeIfPresent(BackendKind.self, forKey: .backend) ?? .keychain
        self.service = try c.decodeIfPresent(String.self, forKey: .service)
        self.onePassword = try c.decodeIfPresent(OnePassword.self, forKey: .onepassword)
        self.environments = try c.decodeIfPresent([String].self, forKey: .environments) ?? []
        self.environmentSecrets = try c.decodeIfPresent([String].self, forKey: .environmentSecrets) ?? []
        self.globalSecrets = try c.decodeIfPresent([String].self, forKey: .globalSecrets) ?? []
        let defaults = Output()
        if let o = try c.decodeIfPresent(OutputDTO.self, forKey: .output) {
            self.output = Output(
                path: o.path ?? defaults.path,
                packageName: o.packageName ?? defaults.packageName,
                typeName: o.typeName ?? defaults.typeName,
                gitignore: o.gitignore ?? defaults.gitignore
            )
        } else {
            self.output = defaults
        }
    }
}

// MARK: - Loading & validation

extension Config {
    public static let defaultFileName = ".keychest.yml"

    public static func load(from path: String) throws -> Config {
        guard let data = FileManager.default.contents(atPath: path),
              let text = String(data: data, encoding: .utf8) else {
            throw KeychestError.configNotFound(path)
        }
        return try parse(text)
    }

    public static func parse(_ yaml: String) throws -> Config {
        let config: Config
        do {
            config = try YAMLDecoder().decode(Config.self, from: yaml)
        } catch {
            throw KeychestError.invalidConfig("\(error)")
        }
        try config.validate()
        return config
    }

    /// Throws `KeychestError.invalidConfig` / `.invalidKeyName` when the config is unusable.
    public func validate() throws {
        for name in globalSecrets + environmentSecrets + environments {
            try Naming.validate(name)
        }
        try Self.requireUnique(globalSecrets + environmentSecrets, label: "secret")
        try Self.requireUnique(environments, label: "environment")

        if environments.contains("Global") {
            throw KeychestError.invalidConfig("'Global' is reserved and cannot be used as an environment name.")
        }
        if !environmentSecrets.isEmpty && environments.isEmpty {
            throw KeychestError.invalidConfig("`environment_secrets` requires at least one entry in `environments`.")
        }
        if globalSecrets.isEmpty && environmentSecrets.isEmpty {
            throw KeychestError.invalidConfig("Declare at least one secret under `global_secrets` or `environment_secrets`.")
        }

        try Naming.validate(output.packageName)
        try Naming.validate(output.typeName)

        switch backend {
        case .keychain:
            guard let service, !service.isEmpty else {
                throw KeychestError.invalidConfig("The keychain backend requires a `service` (e.g. com.example.myapp).")
            }
        case .onepassword:
            guard onePassword != nil else {
                throw KeychestError.invalidConfig("The 1password backend requires an `onepassword:` section with `vault` and `item`.")
            }
        case .env:
            break
        }
    }

    private static func requireUnique(_ names: [String], label: String) throws {
        var seen = Set<String>()
        for name in names where !seen.insert(name).inserted {
            throw KeychestError.invalidConfig("Duplicate \(label) name '\(name)'.")
        }
    }

    /// Every backend account this config needs, optionally limited to some environments.
    public func requiredAccounts(environments only: [String]? = nil) -> [String] {
        var accounts = globalSecrets.map { Naming.account(key: $0, environment: nil) }
        for env in environments where only?.contains(env) ?? true {
            accounts += environmentSecrets.map { Naming.account(key: $0, environment: env) }
        }
        return accounts
    }
}
