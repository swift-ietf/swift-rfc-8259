/// RFC_8259.Object.swift
/// swift-rfc-8259
///
/// JSON object type preserving insertion order

extension RFC_8259 {
    /// A JSON object preserving insertion order.
    ///
    /// Per RFC 8259 Section 4:
    /// > An object is an unordered collection of zero or more name/value pairs
    ///
    /// While JSON objects are semantically unordered, this implementation
    /// preserves insertion order for usability and deterministic output.
    ///
    /// ## RFC 8259 Section 4 Grammar
    ///
    /// ```
    /// object = begin-object [ member *( value-separator member ) ] end-object
    /// member = string name-separator value
    /// ```
    public struct Object: Sendable, Hashable {
        /// Internal storage preserving insertion order.
        @usableFromInline
        internal var _storage: [(key: String, value: Value)]

        /// Creates an empty object.
        public init() {
            _storage = []
        }

        /// Creates an object from key-value pairs.
        ///
        /// - Parameter elements: Key-value pairs in insertion order.
        public init(_ elements: [(key: String, value: Value)]) {
            _storage = elements
        }
    }
}

// MARK: - Object Computed Properties

extension RFC_8259.Object {
    /// The number of key-value pairs.
    public var count: Int {
        _storage.count
    }

    /// True if the object has no members.
    public var isEmpty: Bool {
        _storage.isEmpty
    }

    /// All keys in insertion order.
    public var keys: [String] {
        _storage.map { $0.key }
    }

    /// All values in insertion order.
    public var values: [Value] {
        _storage.map { $0.value }
    }
}

// MARK: - Object Subscript

extension RFC_8259.Object {
    /// Access a value by key.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: The value if present, nil otherwise.
    ///
    /// Get is O(n). For frequent lookups, consider converting to a Dictionary.
    public subscript(_ key: String) -> RFC_8259.Value? {
        get {
            _storage.first { $0.key == key }?.value
        }
        set {
            if let newValue = newValue {
                if let index = _storage.firstIndex(where: { $0.key == key }) {
                    _storage[index] = (key, newValue)
                } else {
                    _storage.append((key, newValue))
                }
            } else {
                _storage.removeAll { $0.key == key }
            }
        }
    }
}

// MARK: - Object Sequence

extension RFC_8259.Object: Swift.Sequence {
    public typealias Element = (key: String, value: RFC_8259.Value)

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(_storage)
    }
}

// MARK: - Object Collection

extension RFC_8259.Object: Swift.Collection {
    public typealias Index = Int

    public var startIndex: Int { _storage.startIndex }
    public var endIndex: Int { _storage.endIndex }

    public func index(after i: Int) -> Int {
        _storage.index(after: i)
    }

    public subscript(position: Int) -> Element {
        _storage[position]
    }
}

// MARK: - Object ExpressibleByDictionaryLiteral

extension RFC_8259.Object: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, RFC_8259.Value)...) {
        _storage = elements.map { (key: $0.0, value: $0.1) }
    }
}

// MARK: - Object CustomStringConvertible

extension RFC_8259.Object: CustomStringConvertible {
    public var description: String {
        let pairs = _storage.map { "\"\($0.key)\": \($0.value)" }
        return "{\(pairs.joined(separator: ", "))}"
    }
}

// MARK: - Object Hashable Fix

extension RFC_8259.Object {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_storage.count)
        for (key, value) in _storage {
            hasher.combine(key)
            hasher.combine(value)
        }
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs._storage.count == rhs._storage.count else { return false }
        for i in lhs._storage.indices {
            guard lhs._storage[i].key == rhs._storage[i].key,
                lhs._storage[i].value == rhs._storage[i].value
            else {
                return false
            }
        }
        return true
    }
}
