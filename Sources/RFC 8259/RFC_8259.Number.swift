/// RFC_8259.Number.swift
/// swift-rfc-8259
///
/// JSON number type preserving original representation for lossless round-tripping

extension RFC_8259 {
    /// A JSON number preserving its original representation.
    ///
    /// Per RFC 8259 Section 6, JSON numbers have no precision or range limits.
    /// This type preserves both the parsed value AND the original UTF-8 bytes
    /// to enable lossless round-tripping (e.g., `1e10` stays `1e10`).
    ///
    /// ## RFC 8259 Section 6 Grammar
    ///
    /// ```
    /// number = [ minus ] int [ frac ] [ exp ]
    /// int = zero / ( digit1-9 *DIGIT )
    /// frac = decimal-point 1*DIGIT
    /// exp = e [ minus / plus ] 1*DIGIT
    /// ```
    public struct Number: Sendable, Hashable {
        /// The parsed numeric value.
        public let parsed: Parsed

        /// Original UTF-8 representation for lossless round-trip.
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

// MARK: - Number Accessors

extension RFC_8259.Number {
    /// The number as Int64 if it was parsed as a signed integer.
    public var int64: Int64? {
        guard case .integer(let v) = parsed else { return nil }
        return v
    }

    /// The number as UInt64 if it was parsed as an unsigned integer.
    public var uint64: UInt64? {
        guard case .unsigned(let v) = parsed else { return nil }
        return v
    }

    /// The number as Int if it fits.
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

    /// The number as Double (always succeeds, may lose precision).
    public var double: Double {
        switch parsed {
        case .integer(let v): return Double(v)
        case .unsigned(let v): return Double(v)
        case .float(let v): return v
        }
    }

    /// True if this number has a fractional part or exponent.
    public var isFloatingPoint: Bool {
        guard case .float = parsed else { return false }
        return true
    }

    /// True if this number is a whole number (no fraction).
    public var isInteger: Bool {
        switch parsed {
        case .integer, .unsigned:
            return true
        case .float(let v):
            return v == v.rounded() && v.isFinite
        }
    }
}

// MARK: - Number CustomStringConvertible

extension RFC_8259.Number: CustomStringConvertible {
    public var description: String {
        original.string
    }
}

// MARK: - Number Convenience Initializers

extension RFC_8259.Number {
    /// Creates a Number from an integer.
    public init(_ value: Int) {
        let str = String(value)
        self.init(Int64(value), original: Original(Swift.Array(str.utf8)))
    }

    /// Creates a Number from a Double.
    ///
    /// Note: This may not preserve the exact representation.
    /// For lossless encoding, parse from the original JSON bytes.
    public init(_ value: Double) {
        let str = String(value)
        self.init(value, original: Original(Swift.Array(str.utf8)))
    }
}
