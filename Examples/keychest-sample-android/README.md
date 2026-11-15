# keychest-sample-android

A minimal Android app showing how to use [Keychest](../../README.md) to keep API keys out of a repository. The real values live in your macOS Keychain. This folder only contains their *names*.

It uses the same secret names and Keychain service as the [iOS sample](../keychest-sample), so if you already ran that one, your values are stored and you can skip to `keychest generate`.

## Run it

You need Keychest, a JDK 17 or newer, and the Android SDK with platform 36 and build-tools 36 (Android Studio installs these):

```bash
brew install parth0072/tap/keychest
```

Clone Keychest and move into this folder:

```bash
cd Examples/keychest-sample-android
```

Typing is hidden, so press Return after each value. Use fake values: the app prints them on screen.

```bash
keychest set apiKey
```

`apiKey` is asked twice, for Debug and then Release.

```bash
keychest set clientID
```

```bash
keychest generate
```

Open this folder in Android Studio and run the `app` configuration, or, with an emulator or device connected:

```bash
./gradlew installDebug
```

The screen shows `clientID` and the `apiKey` for the build type. Switch the build variant to `release` to see the Release value.

## How it fits together

- `.keychest.yml` lists the secret names and environments, and asks for the Kotlin output (`platforms: [kotlin]`). No values, so it is safe to commit.
- `keychest-keys/` is created by `keychest generate`. It is git-ignored on purpose. It is a plain Kotlin/JVM Gradle module, and `settings.gradle.kts` includes it. Until you have run `generate`, Gradle stops and tells you so.
- The root `build.gradle.kts` declares the Kotlin plugin once, because the generated module applies `kotlin("jvm")` without a version. The Android module needs no Kotlin plugin: Android Gradle plugin 9 has built-in Kotlin.
- `app/build.gradle.kts` depends on `:keychest-keys` and turns on `buildConfig`.
- `MainActivity.kt` picks `Secrets.Debug` or `Secrets.Release` from `BuildConfig.DEBUG`.

## Notes

- Built with Android Gradle plugin 9.5.1, Gradle 9.6.0 (the wrapper downloads it) and Kotlin 2.4.21 for the generated module. The release build uses R8, and is signed with the debug key so you can install it.
- Values are stored in your login Keychain under the service `com.example.myapp`. Remove them with `keychest remove apiKey` and `keychest remove clientID`.
- Anything shipped inside an app can be extracted: tools such as jadx can recover these values from the APK. See the [threat model](../../docs/THREAT_MODEL.md).

Part of Keychest, released under the [MIT License](../../LICENSE).
