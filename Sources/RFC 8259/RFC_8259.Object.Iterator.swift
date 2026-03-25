/// RFC_8259.Object.Iterator.swift
/// swift-rfc-8259
///
/// Iterator for JSON object key-value pairs

extension RFC_8259.Object {
    public struct Iterator: Swift.IteratorProtocol {
        @usableFromInline
        internal var base: IndexingIterator<[(key: String, value: RFC_8259.Value)]>

        @usableFromInline
        internal init(_ storage: [(key: String, value: RFC_8259.Value)]) {
            self.base = storage.makeIterator()
        }

        @inlinable
        public mutating func next() -> (key: String, value: RFC_8259.Value)? {
            base.next()
        }
    }
}
