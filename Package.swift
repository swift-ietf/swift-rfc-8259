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
        .visionOS(.v26),
    ],
    products: [
        .library(name: "RFC 8259", targets: ["RFC 8259"]),
    ],
    dependencies: [
        .package(path: "../../swift-primitives/swift-standard-library-extensions"),
        .package(path: "../../swift-primitives/swift-parsing-primitives"),
        .package(path: "../../swift-primitives/swift-binary-primitives"),
        .package(path: "../swift-incits-4-1986"),
    ],
    targets: [
        .target(
            name: "RFC 8259",
            dependencies: [
                .product(name: "Standard Library Extensions", package: "swift-standard-library-extensions"),
                .product(name: "Parsing Primitives", package: "swift-parsing-primitives"),
                .product(name: "Binary Primitives", package: "swift-binary-primitives"),
                .product(name: "INCITS 4 1986", package: "swift-incits-4-1986"),
            ]
        ),
        .testTarget(
            name: "RFC 8259 Tests",
            dependencies: ["RFC 8259"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
