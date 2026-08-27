// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "swift-rfc-8259",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [
        .library(name: "RFC 8259", targets: ["RFC 8259"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/swift-molecules/swift-standard-library-extensions.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-parser.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-lexer.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-binary.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-array.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-ascii.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-text.git",
            branch: "main"
        ),
    ],
    targets: [
        .target(
            name: "RFC 8259",
            dependencies: [
                .product(
                    name: "Standard Library Extensions",
                    package: "swift-standard-library-extensions"
                ),
                .product(name: "Parser", package: "swift-parser"),
                .product(name: "Lexer", package: "swift-lexer"),
                .product(name: "Binary", package: "swift-binary"),
                .product(name: "Array", package: "swift-array"),
                .product(name: "ASCII", package: "swift-ascii"),
                .product(name: "Text", package: "swift-text"),
            ]
        ),
        .testTarget(
            name: "RFC 8259 Tests",
            dependencies: [
                "RFC 8259"
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("Lifetimes"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
