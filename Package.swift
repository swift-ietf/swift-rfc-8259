// swift-tools-version: 6.2
import PackageDescription

// RFC 8259: The JavaScript Object Notation (JSON) Data Interchange Format
let package = Package(
    name: "swift-rfc-8259",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(name: "RFC 8259", targets: ["RFC 8259"])
    ],
    dependencies: [
        .package(path: "../../swift-primitives/swift-standard-library-extensions"),
        .package(path: "../../swift-primitives/swift-parser-primitives"),
        .package(path: "../../swift-primitives/swift-binary-primitives"),
        .package(path: "../../swift-primitives/swift-array-primitives"),
        .package(path: "../../swift-primitives/swift-ascii-primitives")
    ],
    targets: [
        .target(
            name: "RFC 8259",
            dependencies: [
                .product(name: "Standard Library Extensions", package: "swift-standard-library-extensions"),
                .product(name: "Parser Primitives", package: "swift-parser-primitives"),
                .product(name: "Binary Primitives", package: "swift-binary-primitives"),
                .product(name: "Array Primitives", package: "swift-array-primitives"),
                .product(name: "ASCII Primitives", package: "swift-ascii-primitives")
            ]
        )
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
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
