import ArgumentParser
import Foundation
import KeychestCore

@main
struct Keychest: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "keychest",
        abstract: "Keep app secrets out of your repo. Pull them from Keychain (or 1Password, or env vars) and generate obfuscated Swift accessors at build time.",
        version: "1.0.0",
        subcommands: [Init.self, Set.self, Remove.self, Generate.self, Check.self]
    )
}

// MARK: - Shared options

struct ConfigOptions: ParsableArguments {
    @Option(name: [.short, .customLong("config")], help: "Path to the config file.")
    var configPath: String = Config.defaultFileName

    func load() throws -> Config { try Config.load(from: configPath) }
}

/// Prints a friendly error and exits non-zero instead of dumping a Swift error description.
func reportingErrors(_ body: () throws -> Void) throws {
    do {
        try body()
    } catch let error as KeychestError {
        FileHandle.standardError.write(Data("error: \(error)\n".utf8))
        throw ExitCode.failure
    }
}

/// Reads one line from the terminal without echoing it. Falls back to a plain read when stdin is not a TTY.
func readHiddenLine(prompt: String) -> String {
    let isTTY = isatty(STDIN_FILENO) == 1
    var original = termios()
    if isTTY {
        FileHandle.standardError.write(Data(prompt.utf8))
        tcgetattr(STDIN_FILENO, &original)
        var silent = original
        silent.c_lflag &= ~tcflag_t(ECHO)
        tcsetattr(STDIN_FILENO, TCSANOW, &silent)
    }
    defer {
        if isTTY {
            tcsetattr(STDIN_FILENO, TCSANOW, &original)
            FileHandle.standardError.write(Data("\n".utf8))
        }
    }
    return readLine(strippingNewline: true) ?? ""
}

func splitList(_ value: String?) -> [String]? {
    guard let value, !value.isEmpty else { return nil }
    return value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
}

/// `android/keychest-keys` -> `:android:keychest-keys`, the Gradle path of a module folder.
func gradleProject(for directory: String) -> String {
    ":" + directory.split(separator: "/").filter { $0 != "." }.joined(separator: ":")
}

// MARK: - init

extension Keychest {
    struct Init: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Create a starter .keychest.yml.")

        @Option(name: [.short, .customLong("config")], help: "Where to write the config file.")
        var configPath: String = Config.defaultFileName

        @Flag(help: "Overwrite an existing file.")
        var force = false

        func run() throws {
            try reportingErrors {
                if FileManager.default.fileExists(atPath: configPath) && !force {
                    throw KeychestError.writeFailure("\(configPath) already exists. Use --force to overwrite.")
                }
                try Data(ConfigTemplate.contents.utf8).write(to: URL(fileURLWithPath: configPath), options: .atomic)
                print("Created \(configPath). Edit it, then store your secrets with `keychest set <name>`.")
            }
        }
    }
}

// MARK: - set

extension Keychest {
    struct Set: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Store a secret in the configured backend (value is prompted for, never passed as an argument).")

        @OptionGroup var options: ConfigOptions

        @Argument(help: "Secret name as declared in the config, e.g. apiKey.")
        var name: String

        @Option(name: .shortAndLong, help: "Environment (e.g. Debug). Omit to be prompted for every environment.")
        var environment: String?

        @Flag(help: "Read the value from standard input instead of prompting (for scripts).")
        var stdin = false

        func run() throws {
            try reportingErrors {
                let config = try options.load()
                let backend = try BackendFactory.make(for: config)
                let isEnvironmentSecret = config.environmentSecrets.contains(name)

                guard isEnvironmentSecret || config.globalSecrets.contains(name) else {
                    throw KeychestError.invalidConfig("'\(name)' is not declared in \(options.configPath).")
                }

                var targets: [String?]
                if isEnvironmentSecret {
                    if let environment {
                        guard config.environments.contains(environment) else {
                            throw KeychestError.invalidConfig("Unknown environment '\(environment)'.")
                        }
                        targets = [environment]
                    } else {
                        targets = config.environments
                    }
                } else {
                    if environment != nil {
                        throw KeychestError.invalidConfig("'\(name)' is a global secret; do not pass --environment.")
                    }
                    targets = [nil]
                }

                for env in targets {
                    let account = Naming.account(key: name, environment: env)
                    let value = try readValue(prompt: "Value for \(account): ")
                    guard !value.isEmpty else {
                        throw KeychestError.invalidConfig("Empty value for '\(account)'; nothing stored.")
                    }
                    try backend.write(account: account, value: value)
                    print("Stored \(account) in \(backend.name).")
                }
            }
        }

        private func readValue(prompt: String) throws -> String {
            if stdin {
                return readLine(strippingNewline: true) ?? ""
            }
            return readHiddenLine(prompt: prompt)
        }
    }
}

// MARK: - remove

extension Keychest {
    struct Remove: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Delete a secret from the configured backend.")

        @OptionGroup var options: ConfigOptions

        @Argument(help: "Secret name as declared in the config.")
        var name: String

        @Option(name: .shortAndLong, help: "Environment. Omit to remove it from every environment.")
        var environment: String?

        func run() throws {
            try reportingErrors {
                let config = try options.load()
                let backend = try BackendFactory.make(for: config)
                let targets: [String?]
                if config.environmentSecrets.contains(name) {
                    targets = environment.map { [$0] } ?? config.environments
                } else if config.globalSecrets.contains(name) {
                    targets = [nil]
                } else {
                    throw KeychestError.invalidConfig("'\(name)' is not declared in \(options.configPath).")
                }
                for env in targets {
                    let account = Naming.account(key: name, environment: env)
                    try backend.delete(account: account)
                    print("Removed \(account) from \(backend.name).")
                }
            }
        }
    }
}

// MARK: - generate

extension Keychest {
    struct Generate: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Fetch secrets and generate the Swift package and/or Kotlin module.")

        @OptionGroup var options: ConfigOptions

        @Option(help: "Comma-separated environments to include, e.g. Debug. Defaults to all. Useful to keep Release secrets off dev machines.")
        var environments: String?

        @Option(help: "Comma-separated platforms to generate: swift, kotlin. Defaults to `platforms` in the config (swift if unset).")
        var platforms: String?

        @Option(name: .customLong("output"), help: "Override the output directory from the config. Only valid when generating one platform.")
        var outputPath: String?

        func run() throws {
            try reportingErrors {
                let config = try options.load()
                let backend = try BackendFactory.make(for: config)
                let only = splitList(environments)
                var seen = Swift.Set<Platform>()
                let targets = (try splitList(platforms).map(Platform.parse) ?? config.platforms)
                    .filter { seen.insert($0).inserted }
                guard !targets.isEmpty else {
                    throw KeychestError.invalidConfig("No platforms selected. Use swift, kotlin or both.")
                }
                if outputPath != nil && targets.count > 1 {
                    throw KeychestError.invalidConfig("--output can only be used with one platform. Pass --platforms swift or --platforms kotlin.")
                }

                let resolved = try SecretResolver.resolve(config: config, backend: backend, environments: only)
                for platform in targets {
                    switch platform {
                    case .swift:
                        let directory = outputPath ?? config.output.path
                        let files = CodeGenerator(config: config).generate(from: resolved)
                        let written = try OutputWriter.write(files, to: directory)
                        print("Generated \(config.output.packageName) (Swift) in \(directory) from \(backend.name):")
                        written.forEach { print("  \($0)") }
                        print("Add it as a local Swift package and `import \(config.output.packageName)`.")
                    case .kotlin:
                        let directory = outputPath ?? config.kotlin.path
                        let files = KotlinCodeGenerator(config: config).generate(from: resolved)
                        let written = try OutputWriter.write(files, to: directory)
                        let module = gradleProject(for: directory)
                        print("Generated \(config.kotlin.packageName) (Kotlin) in \(directory) from \(backend.name):")
                        written.forEach { print("  \($0)") }
                        print("Add `include(\"\(module)\")` to settings.gradle.kts and depend on it with `implementation(project(\"\(module)\"))`.")
                    }
                }
            }
        }
    }
}

// MARK: - check

extension Keychest {
    struct Check: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Verify every declared secret exists in the backend. Never prints values. Exits 1 if any are missing.")

        @OptionGroup var options: ConfigOptions

        @Option(help: "Comma-separated environments to check. Defaults to all.")
        var environments: String?

        func run() throws {
            try reportingErrors {
                let config = try options.load()
                let backend = try BackendFactory.make(for: config)
                let report = try SecretResolver.audit(config: config, backend: backend, environments: splitList(environments))

                for entry in report {
                    print("\(entry.present ? "ok     " : "MISSING") \(entry.account)")
                }
                let missing = report.filter { !$0.present }.count
                if missing > 0 {
                    FileHandle.standardError.write(Data("\n\(missing) secret(s) missing in \(backend.name).\n".utf8))
                    throw ExitCode.failure
                }
                print("\nAll \(report.count) secret(s) present in \(backend.name).")
            }
        }
    }
}
