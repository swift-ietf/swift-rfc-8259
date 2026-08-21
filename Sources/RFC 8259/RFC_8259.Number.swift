extension RFC_8259 {

    public struct Number: Sendable, Hashable {

        public let parsed: Parsed

        public let original: Original

        public init(_ value: Int64, original: Original) {
            self.parsed = .integer(value)
            self.original = original
        }

        public init(_ value: UInt64, original: Original) {
            self.parsed = .unsigned(value)
            self.original = original
        }

        public init(_ value: Double, original: Original) {
            self.parsed = .float(value)
            self.original = original
        }
    }
}

extension RFC_8259.Number {

    public var int64: Int64? {
        guard case .integer(let v) = parsed else { return nil }
        return v
    }

    public var uint64: UInt64? {
        guard case .unsigned(let v) = parsed else { return nil }
        return v
    }

    public var int: Int? {
        switch parsed {
        case .integer(let v):
            return Int(exactly: v)

        case .unsigned(let v):
            return Int(exactly: v)

        case .float(let v):
            guard v == v.rounded() else { return nil }
            return Int(exactly: v)
        }
    }

    public var double: Double {
        switch parsed {
        case .integer(let v): return Double(v)
        case .unsigned(let v): return Double(v)
        case .float(let v): return v
        }
    }

    public var isFloatingPoint: Bool {
        guard case .float = parsed else { return false }
        return true
    }

    public var isInteger: Bool {
        switch parsed {
        case .integer, .unsigned:
            return true

        case .float(let v):
            return v == v.rounded() && v.isFinite
        }
    }
}

extension RFC_8259.Number: CustomStringConvertible {
    public var description: String {
        original.string
    }
}

extension RFC_8259.Number {

    public init(_ value: Int) {
        let str = String(value)
        self.init(Int64(value), original: Original(Swift.Array(str.utf8)))
    }

    public init(_ value: Double) {
        let str = String(value)
        self.init(value, original: Original(Swift.Array(str.utf8)))
    }
}
