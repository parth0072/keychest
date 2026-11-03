import Foundation

public struct ResolvedSecret: Equatable {
    public let key: String
    public let value: String
}

/// All secret values needed to generate code, grouped by scope.
public struct ResolvedSecrets: Equatable {
    public var global: [ResolvedSecret]
    /// Ordered as declared in the config.
    public var environments: [(name: String, secrets: [ResolvedSecret])]

    public static func == (lhs: ResolvedSecrets, rhs: ResolvedSecrets) -> Bool {
        lhs.global == rhs.global
            && lhs.environments.count == rhs.environments.count
            && zip(lhs.environments, rhs.environments).allSatisfy { $0.name == $1.name && $0.secrets == $1.secrets }
    }
}

public enum SecretResolver {
    /// Fetches every required secret. If any are missing, throws a single error listing all of them,
    /// so users can fix everything in one pass.
    public static func resolve(config: Config,
                               backend: SecretBackend,
                               environments only: [String]? = nil) throws -> ResolvedSecrets {
        if let only {
            let unknown = only.filter { !config.environments.contains($0) }
            if !unknown.isEmpty {
                throw KeychestError.invalidConfig("Unknown environment(s): \(unknown.joined(separator: ", ")). Declared: \(config.environments.joined(separator: ", ")).")
            }
        }

        var missing: [String] = []

        func fetch(_ key: String, environment: String?) throws -> ResolvedSecret? {
            let account = Naming.account(key: key, environment: environment)
            guard let value = try backend.read(account: account) else {
                missing.append(account)
                return nil
            }
            return ResolvedSecret(key: key, value: value)
        }

        let global = try config.globalSecrets.compactMap { try fetch($0, environment: nil) }
        var perEnvironment: [(name: String, secrets: [ResolvedSecret])] = []
        for env in config.environments where only?.contains(env) ?? true {
            let secrets = try config.environmentSecrets.compactMap { try fetch($0, environment: env) }
            perEnvironment.append((env, secrets))
        }

        guard missing.isEmpty else {
            throw KeychestError.missingSecrets(accounts: missing, backend: backend.name)
        }
        return ResolvedSecrets(global: global, environments: perEnvironment)
    }

    /// Reports which required accounts exist, without exposing any values.
    public static func audit(config: Config,
                             backend: SecretBackend,
                             environments only: [String]? = nil) throws -> [(account: String, present: Bool)] {
        try config.requiredAccounts(environments: only).map { account in
            (account, try backend.read(account: account) != nil)
        }
    }
}
