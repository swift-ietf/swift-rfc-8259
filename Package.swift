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
            url: "https://github.com/swift-atoms/swift-standard-library-extensions.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-atoms/swift-parser.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-lexer.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-atoms/swift-binary.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-array.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-atoms/swift-ascii.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-atoms/swift-text.git",
            branch: "main"
        ),
        .package(url: "https://github.com/swift-atoms/swift-buffer.git", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-buffer-linear.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-index.git", branch: "main"),
        .package(
            url: "https://github.com/swift-atoms/swift-storage.git",
            branch: "main",
            traits: ["Generational", "Memory"]
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-memory-allocation.git",
            branch: "main",
            traits: ["MemorySmall", "MemoryAllocatorArena", "MemoryInline"]
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
                .product(name: "Array Small Primitive", package: "swift-array"),
                .product(name: "Buffer", package: "swift-buffer"),
                .product(name: "Buffer Linear", package: "swift-buffer-linear"),
                .product(name: "Buffer Linear Primitive", package: "swift-buffer-linear"),
                .product(name: "Index", package: "swift-index"),
                .product(name: "Storage", package: "swift-storage"),
                .product(name: "Memory Allocator", package: "swift-memory-allocation"),
                .product(name: "Memory Small", package: "swift-memory-allocation"),
            ]
        ),
        .testTarget(
            name: "RFC 8259 Tests",
            dependencies: [
                .target(name: "RFC 8259")
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    target.swiftSettings =
        (target.swiftSettings ?? []) + [
            .strictMemorySafety(),
            .enableUpcomingFeature("ExistentialAny"),
            .enableUpcomingFeature("InternalImportsByDefault"),
            .enableUpcomingFeature("MemberImportVisibility"),
            .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            .enableUpcomingFeature("InferIsolatedConformances"),
            .enableExperimentalFeature("Lifetimes"),
            .treatAllWarnings(as: .error),
        ]
}
