// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Keychest",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "keychest", targets: ["keychest"]),
        .library(name: "KeychestCore", targets: ["KeychestCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/jpsim/Yams", from: "5.1.0"),
    ],
    targets: [
        .target(
            name: "KeychestCore",
            dependencies: [.product(name: "Yams", package: "Yams")]
        ),
        .executableTarget(
            name: "keychest",
            dependencies: [
                "KeychestCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "KeychestCoreTests",
            dependencies: ["KeychestCore"]
        ),
    ]
)
