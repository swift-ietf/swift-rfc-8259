extension RFC_8259.Object {
    public struct Iterator: Swift.IteratorProtocol {
        @usableFromInline
        internal var base: IndexingIterator<[(key: String, value: RFC_8259.Value)]>

        @usableFromInline
        internal init(_ storage: [(key: String, value: RFC_8259.Value)]) {
            self.base = storage.makeIterator()
        }
    }
}

extension RFC_8259.Object.Iterator {
    @inlinable
    public mutating func next() -> (key: String, value: RFC_8259.Value)? {
        base.next()
    }
}
