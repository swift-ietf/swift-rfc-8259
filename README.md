# swift-rfc-8259

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

Parsing and serialization of JSON as specified in RFC 8259.

## Standard Reference

- **RFC**: 8259
- **Title**: The JavaScript Object Notation (JSON) Data Interchange Format

## Installation

Add the package to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/swift-ietf/swift-rfc-8259.git", from: "0.0.1")
]
```

Add the product to a target that needs it:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "RFC 8259", package: "swift-rfc-8259")
    ]
)
```

## License

Apache 2.0. See [LICENSE.md](LICENSE.md).
