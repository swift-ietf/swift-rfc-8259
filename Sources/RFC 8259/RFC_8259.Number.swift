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
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let num = value.number!
    /// print(num.doubleValue)    // Computed Double
    /// print(num.int64Value)     // Optional Int64 if integer
    /// print(num.original.bytes) // Original UTF-8 for encoding
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

// MARK: - Number.Parsed

extension RFC_8259.Number {
    /// The parsed numeric value for computation.
    public enum Parsed: Sendable, Hashable {
        /// Signed integer value (fits in Int64).
        case integer(Int64)

        /// Unsigned integer value (fits in UInt64 but not Int64).
        case unsigned(UInt64)

        /// Floating-point value (has fraction or exponent, or too large for integers).
        case float(Double)
    }
}

// MARK: - Number.Original

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

        /// Creates an Original from a byte collection.
        public init<Bytes: Swift.Collection>(_ bytes: Bytes) where Bytes.Element == UInt8 {
            let array = Swift.Array(bytes)
            if array.count <= 23 {
                self.storage = .inline(InlineBytes(array))
            } else {
                self.storage = .heap(array)
            }
        }

        /// The original bytes as an array.
        public var bytes: [UInt8] {
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
}

// MARK: - Number.Original.Storage

extension RFC_8259.Number.Original {
    @usableFromInline
    internal enum Storage: Sendable, Hashable {
        case inline(InlineBytes)
        case heap([UInt8])
    }
}

// MARK: - Number.Original.InlineBytes

extension RFC_8259.Number.Original {
    /// Inline storage for up to 23 bytes.
    ///
    /// Most JSON numbers are short (e.g., "123", "-45.67", "1e10"),
    /// so inline storage avoids heap allocation in the common case.
    @usableFromInline
    internal struct InlineBytes: Sendable, Hashable {
        // 23 bytes of storage + 1 byte for count = 24 bytes total
        @usableFromInline internal var b0: UInt8 = 0
        @usableFromInline internal var b1: UInt8 = 0
        @usableFromInline internal var b2: UInt8 = 0
        @usableFromInline internal var b3: UInt8 = 0
        @usableFromInline internal var b4: UInt8 = 0
        @usableFromInline internal var b5: UInt8 = 0
        @usableFromInline internal var b6: UInt8 = 0
        @usableFromInline internal var b7: UInt8 = 0
        @usableFromInline internal var b8: UInt8 = 0
        @usableFromInline internal var b9: UInt8 = 0
        @usableFromInline internal var b10: UInt8 = 0
        @usableFromInline internal var b11: UInt8 = 0
        @usableFromInline internal var b12: UInt8 = 0
        @usableFromInline internal var b13: UInt8 = 0
        @usableFromInline internal var b14: UInt8 = 0
        @usableFromInline internal var b15: UInt8 = 0
        @usableFromInline internal var b16: UInt8 = 0
        @usableFromInline internal var b17: UInt8 = 0
        @usableFromInline internal var b18: UInt8 = 0
        @usableFromInline internal var b19: UInt8 = 0
        @usableFromInline internal var b20: UInt8 = 0
        @usableFromInline internal var b21: UInt8 = 0
        @usableFromInline internal var b22: UInt8 = 0
        @usableFromInline internal var count: UInt8 = 0

        @usableFromInline
        internal init(_ bytes: [UInt8]) {
            precondition(bytes.count <= 23, "InlineBytes can hold at most 23 bytes")
            count = UInt8(bytes.count)
            if bytes.count > 0 { b0 = bytes[0] }
            if bytes.count > 1 { b1 = bytes[1] }
            if bytes.count > 2 { b2 = bytes[2] }
            if bytes.count > 3 { b3 = bytes[3] }
            if bytes.count > 4 { b4 = bytes[4] }
            if bytes.count > 5 { b5 = bytes[5] }
            if bytes.count > 6 { b6 = bytes[6] }
            if bytes.count > 7 { b7 = bytes[7] }
            if bytes.count > 8 { b8 = bytes[8] }
            if bytes.count > 9 { b9 = bytes[9] }
            if bytes.count > 10 { b10 = bytes[10] }
            if bytes.count > 11 { b11 = bytes[11] }
            if bytes.count > 12 { b12 = bytes[12] }
            if bytes.count > 13 { b13 = bytes[13] }
            if bytes.count > 14 { b14 = bytes[14] }
            if bytes.count > 15 { b15 = bytes[15] }
            if bytes.count > 16 { b16 = bytes[16] }
            if bytes.count > 17 { b17 = bytes[17] }
            if bytes.count > 18 { b18 = bytes[18] }
            if bytes.count > 19 { b19 = bytes[19] }
            if bytes.count > 20 { b20 = bytes[20] }
            if bytes.count > 21 { b21 = bytes[21] }
            if bytes.count > 22 { b22 = bytes[22] }
        }

        @usableFromInline
        internal var bytes: [UInt8] {
            var result: [UInt8] = []
            result.reserveCapacity(Int(count))
            if count > 0 { result.append(b0) }
            if count > 1 { result.append(b1) }
            if count > 2 { result.append(b2) }
            if count > 3 { result.append(b3) }
            if count > 4 { result.append(b4) }
            if count > 5 { result.append(b5) }
            if count > 6 { result.append(b6) }
            if count > 7 { result.append(b7) }
            if count > 8 { result.append(b8) }
            if count > 9 { result.append(b9) }
            if count > 10 { result.append(b10) }
            if count > 11 { result.append(b11) }
            if count > 12 { result.append(b12) }
            if count > 13 { result.append(b13) }
            if count > 14 { result.append(b14) }
            if count > 15 { result.append(b15) }
            if count > 16 { result.append(b16) }
            if count > 17 { result.append(b17) }
            if count > 18 { result.append(b18) }
            if count > 19 { result.append(b19) }
            if count > 20 { result.append(b20) }
            if count > 21 { result.append(b21) }
            if count > 22 { result.append(b22) }
            return result
        }
    }
}

// MARK: - Number Accessors

extension RFC_8259.Number {
    /// The number as Int64 if it was parsed as a signed integer.
    public var int64Value: Int64? {
        guard case .integer(let v) = parsed else { return nil }
        return v
    }

    /// The number as UInt64 if it was parsed as an unsigned integer.
    public var uint64Value: UInt64? {
        guard case .unsigned(let v) = parsed else { return nil }
        return v
    }

    /// The number as Int if it fits.
    public var intValue: Int? {
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
    public var doubleValue: Double {
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
