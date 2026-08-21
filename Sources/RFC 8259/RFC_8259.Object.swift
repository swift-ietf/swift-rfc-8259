extension RFC_8259 {

    public struct Object: Sendable, Hashable {

        @usableFromInline
        internal var _storage: [(key: String, value: Value)]

        public init() {
            _storage = []
        }

        public init(_ elements: [(key: String, value: Value)]) {
            _storage = elements
        }
    }
}

extension RFC_8259.Object {

    public var count: Int {
        _storage.count
    }

    public var isEmpty: Bool {
        _storage.isEmpty
    }

    public var keys: [String] {
        _storage.map { $0.key }
    }

    public var values: [Value] {
        _storage.map { $0.value }
    }
}

extension RFC_8259.Object {

    public subscript(_ key: String) -> RFC_8259.Value? {
        get {
            _storage.first { $0.key == key }?.value
        }
        set {
            if let newValue {
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

extension RFC_8259.Object: Swift.Sequence {
    public typealias Element = (key: String, value: RFC_8259.Value)

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(_storage)
    }
}

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

extension RFC_8259.Object: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, RFC_8259.Value)...) {
        _storage = elements.map { (key: $0.0, value: $0.1) }
    }
}

extension RFC_8259.Object: CustomStringConvertible {
    public var description: String {
        let pairs = _storage.map { "\"\($0.key)\": \($0.value)" }
        return "{\(pairs.joined(separator: ", "))}"
    }
}

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
