extension RFC_8259 {

    public struct Array: Sendable, Hashable {

        @usableFromInline
        internal var _storage: [Value]

        public init() {
            _storage = []
        }

        public init(_ elements: [Value]) {
            _storage = elements
        }
    }
}

extension RFC_8259.Array: Swift.RandomAccessCollection, Swift.MutableCollection {
    public typealias Index = Int
    public typealias Element = RFC_8259.Value

    public var startIndex: Int { _storage.startIndex }
    public var endIndex: Int { _storage.endIndex }

    public func index(after i: Int) -> Int {
        _storage.index(after: i)
    }

    public func index(before i: Int) -> Int {
        _storage.index(before: i)
    }

    public subscript(position: Int) -> RFC_8259.Value {
        get { _storage[position] }
        set { _storage[position] = newValue }
    }
}

extension RFC_8259.Array: Swift.RangeReplaceableCollection {
    public mutating func replaceSubrange<C>(
        _ subrange: Range<Int>,
        with newElements: C
    ) where C: Swift.Collection, C.Element == RFC_8259.Value {
        _storage.replaceSubrange(subrange, with: newElements)
    }
}

extension RFC_8259.Array: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: RFC_8259.Value...) {
        _storage = elements
    }
}

extension RFC_8259.Array: CustomStringConvertible {
    public var description: String {
        "[\(_storage.map { $0.description }.joined(separator: ", "))]"
    }
}
