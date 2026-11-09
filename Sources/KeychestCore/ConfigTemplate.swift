import Foundation

public enum ConfigTemplate {
    public static let contents = """
    # Keychest configuration. This file contains only key NAMES, never values, so it is safe to commit.
    # Docs: https://github.com/parth0072/keychest

    # Where secret values come from at generation time: keychain | env | 1password
    backend: keychain

    # Keychain service name (keychain backend). Reverse-DNS of your app is a good choice.
    service: com.example.myapp

    # onepassword:            # only for `backend: 1password`
    #   vault: Development
    #   item: MyApp

    # Build configurations that get their own values.
    environments:
      - Debug
      - Release

    # Secrets with a different value per environment.
    # Stored as <name><Environment>, e.g. `apiKeyDebug`, `apiKeyRelease`.
    environment_secrets:
      - apiKey

    # Secrets shared by every environment. Stored as <name>.
    global_secrets:
      - clientID

    output:
      path: KeychestKeys          # directory of the generated Swift package
      package_name: KeychestKeys  # what you `import`
      type_name: Secrets          # top-level namespace: Secrets.Debug().apiKey
      gitignore: true             # write a .gitignore so generated code is never committed

    # Which code to generate: swift, kotlin (default: swift).
    # platforms: [swift, kotlin]

    # kotlin:                     # Android / JVM: a Gradle module you depend on
    #   path: keychest-keys
    #   package: com.example.keys
    #   type_name: Secrets
    #   gitignore: true

    """
}
