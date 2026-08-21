public import Byte_Primitives

extension RFC_8259.Number {

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

    public init<Bytes: Swift.Collection>(_ bytes: Bytes) where Bytes.Element == Byte {
        let array = Swift.Array(bytes)
        if array.count <= 23 {
            self.init(storage: .inline(Inline(array)))
        } else {
            self.init(storage: .heap(array))
        }
    }

    @inlinable
    public init(_ bytes: borrowing Swift.Span<Byte>) {
        if bytes.count <= 23 {
            self.init(storage: .inline(Inline(bytes)))
        } else {

            var heap: [Byte] = []
            heap.reserveCapacity(bytes.count)
            bytes.indices.forEach { heap.append(bytes[$0]) }
            self.init(storage: .heap(heap))
        }
    }

    public var bytes: [Byte] {
        switch storage {
        case .inline(let inline):
            return inline.bytes

        case .heap(let array):
            return array
        }
    }

    public var string: String {
        String(decoding: bytes, as: UTF8.self)
    }
}
