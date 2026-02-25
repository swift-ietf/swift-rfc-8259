/// RFC_8259.Array.swift
/// swift-rfc-8259
///
/// JSON array type

extension RFC_8259 {
    /// A JSON array - an ordered collection of values.
    ///
    /// Per RFC 8259 Section 5:
    /// > An array is an ordered sequence of zero or more values.
    ///
    /// ## RFC 8259 Section 5 Grammar
    ///
    /// ```
    /// array = begin-array [ value *( value-separator value ) ] end-array
    /// ```
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let arr = value.array!
    /// print(arr[0])  // First element
    /// print(arr.count)  // Number of elements
    ///
    /// for item in arr {
    ///     print(item)
    /// }
    /// ```
    public struct Array: Sendable, Hashable {
        /// Internal storage.
        @usableFromInline
        internal var _storage: [Value]

        /// Creates an empty array.
        public init() {
            _storage = []
        }

        /// Creates an array from values.
        public init(_ elements: [Value]) {
            _storage = elements
        }
    }
}

// MARK: - Array RandomAccessCollection + MutableCollection

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

// MARK: - Array RangeReplaceableCollection

extension RFC_8259.Array: Swift.RangeReplaceableCollection {
    public mutating func replaceSubrange<C>(
        _ subrange: Range<Int>,
        with newElements: C
    ) where C: Swift.Collection, C.Element == RFC_8259.Value {
        _storage.replaceSubrange(subrange, with: newElements)
    }
}

// MARK: - Array ExpressibleByArrayLiteral

extension RFC_8259.Array: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: RFC_8259.Value...) {
        _storage = elements
    }
}

// MARK: - Array CustomStringConvertible

extension RFC_8259.Array: CustomStringConvertible {
    public var description: String {
        "[\(_storage.map { $0.description }.joined(separator: ", "))]"
    }
}
