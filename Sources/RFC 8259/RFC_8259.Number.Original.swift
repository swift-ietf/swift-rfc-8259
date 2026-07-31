/// RFC_8259.Number.Original.swift
/// swift-rfc-8259
///
/// Original UTF-8 representation of a JSON number for lossless round-tripping

public import Byte_Primitives

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
    public init<Bytes: Swift.Collection>(_ bytes: Bytes) where Bytes.Element == Byte {
        let array = Swift.Array(bytes)
        if array.count <= 23 {
            self.init(storage: .inline(Inline(array)))
        } else {
            self.init(storage: .heap(array))
        }
    }

    /// Creates an Original from a contiguous byte span.
    ///
    /// Hot-path variant of `init<Bytes: Collection>(_:)` that avoids
    /// the intermediate `Swift.Array(bytes)` allocation when the source
    /// is already a contiguous `Swift.Span<Byte>`. For numbers fitting
    /// in inline storage (≤ 23 bytes — virtually all JSON numbers in
    /// practice), this saves a heap allocation per Number.
    @inlinable
    public init(_ bytes: borrowing Swift.Span<Byte>) {
        if bytes.count <= 23 {
            self.init(storage: .inline(Inline(bytes)))
        } else {
            // Rare path (number > 23 bytes). Materialize once into heap.
            var heap: [Byte] = []
            heap.reserveCapacity(bytes.count)
            bytes.indices.forEach { heap.append(bytes[$0]) }
            self.init(storage: .heap(heap))
        }
    }

    /// The original bytes as an array.
    public var bytes: [Byte] {
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
