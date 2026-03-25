/// RFC_8259.Number.Original.swift
/// swift-rfc-8259
///
/// Original UTF-8 representation of a JSON number for lossless round-tripping

extension RFC_8259.Number {
    /// Original UTF-8 representation of the number.
    ///
    /// Uses inline storage for small numbers (up to 23 bytes),
    /// falling back to heap allocation for larger representations.
    public struct Original: Sendable, Hashable {
        @usableFromInline
        internal let storage: Storage

        @usableFromInline
        internal init(storage: Storage) {
            self.storage = storage
        }
    }
}

extension RFC_8259.Number.Original {
    /// Creates an Original from a byte collection.
    public init<Bytes: Swift.Collection>(_ bytes: Bytes) where Bytes.Element == UInt8 {
        let array = Swift.Array(bytes)
        if array.count <= 23 {
            self.init(storage: .inline(Inline(array)))
        } else {
            self.init(storage: .heap(array))
        }
    }

    /// The original bytes as an array.
    public var bytes: [UInt8] {
        switch storage {
        case .inline(let inline):
            return inline.bytes
        case .heap(let array):
            return array
        }
    }

    /// The original bytes as a String.
    public var string: String {
        String(decoding: bytes, as: UTF8.self)
    }
}
