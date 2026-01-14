/// RFC_8259.Encode.swift
/// swift-rfc-8259
///
/// JSON encoding (Value → bytes)

extension RFC_8259 {
    /// Encodes a JSON value to UTF-8 bytes.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let value: RFC_8259.Value = ["name": "John", "age": 30]
    ///
    /// // Compact encoding
    /// let bytes = value.encode()
    ///
    /// // Pretty-printed
    /// let pretty = value.encode(options: .init(prettyPrint: true))
    ///
    /// // Encode into existing buffer
    /// var buffer: [UInt8] = []
    /// value.encode(into: &buffer)
    /// ```
    public struct Encode: Sendable {
        /// The value to encode.
        public let value: Value

        @usableFromInline
        internal init(_ value: Value) {
            self.value = value
        }

        /// Encodes the value to a byte array.
        ///
        /// - Parameter options: Encoding options.
        /// - Returns: UTF-8 encoded JSON bytes.
        @inlinable
        public func callAsFunction(options: Options = Options()) -> [UInt8] {
            var buffer: [UInt8] = []
            buffer.reserveCapacity(size())
            callAsFunction(into: &buffer, options: options)
            return buffer
        }

        /// Encodes the value into an existing buffer.
        ///
        /// - Parameters:
        ///   - buffer: The buffer to append to.
        ///   - options: Encoding options.
        @inlinable
        public func callAsFunction<Buffer: RangeReplaceableCollection>(
            into buffer: inout Buffer,
            options: Options = Options()
        ) where Buffer.Element == UInt8 {
            var encoder = Encoder(options: options)
            encoder.encode(value, into: &buffer)
        }
    }
}

// MARK: - Size Estimation

extension RFC_8259.Encode {
    /// Estimates serialized size for buffer preallocation.
    public struct Size: Sendable {
        public let value: RFC_8259.Value

        @usableFromInline
        internal init(_ value: RFC_8259.Value) {
            self.value = value
        }

        /// Returns estimated byte count.
        @inlinable
        public func callAsFunction() -> Int {
            estimate(value)
        }

        @usableFromInline
        func estimate(_ value: RFC_8259.Value) -> Int {
            switch value {
            case .null:
                return 4
            case .bool:
                return 5
            case .number(let n):
                return n.original.bytes.count
            case .string(let s):
                // quotes + string length + ~12% for escapes
                return s.utf8.count + 2 + (s.utf8.count / 8)
            case .array(let a):
                // brackets + elements + commas
                var size = 2
                for element in a {
                    size += estimate(element) + 1
                }
                return size
            case .object(let o):
                // braces + keys + colons + values + commas
                var size = 2
                for (key, val) in o {
                    size += key.utf8.count + 3 + estimate(val) + 1
                }
                return size
            }
        }
    }

    /// Accessor for size estimation.
    public var size: Size { Size(value) }
}

// MARK: - Encode Options

extension RFC_8259 {
    /// Options for JSON encoding.
    public struct Options: Sendable {
        /// Whether to format with indentation and newlines.
        public var prettyPrint: Bool

        /// Whether to sort object keys alphabetically.
        ///
        /// When enabled, keys are sorted by UTF-8 byte order (lexicographic),
        /// which is language-agnostic and matches JCS (JSON Canonicalization Scheme).
        public var sortKeys: Bool

        /// Whether to escape forward slashes (for embedding in HTML).
        public var escapeSlashes: Bool

        /// Indentation string (used when prettyPrint is true).
        public var indent: String

        /// Maximum nesting depth (default 512, matching parser).
        ///
        /// Exceeding this depth triggers a precondition failure.
        public var maxDepth: Int

        /// Creates default encoding options.
        public init(
            prettyPrint: Bool = false,
            sortKeys: Bool = false,
            escapeSlashes: Bool = false,
            indent: String = "  ",
            maxDepth: Int = 512
        ) {
            self.prettyPrint = prettyPrint
            self.sortKeys = sortKeys
            self.escapeSlashes = escapeSlashes
            self.indent = indent
            self.maxDepth = maxDepth
        }
    }
}

// MARK: - Internal Encoder

extension RFC_8259 {
    /// Internal encoder state.
    @usableFromInline
    internal struct Encoder {
        @usableFromInline
        let options: Options

        @usableFromInline
        let indent: [UInt8]

        @usableFromInline
        var depth: Int

        @usableFromInline
        init(options: Options) {
            self.options = options
            self.indent = Swift.Array(options.indent.utf8)
            self.depth = 0
        }
    }
}

// MARK: - Encoder Constants

extension RFC_8259.Encoder {
    /// Hex digit lookup table (0-15 → '0'-'9', 'a'-'f').
    @usableFromInline
    static let hexDigits: [UInt8] = [
        .ascii.`0`, .ascii.`1`, .ascii.`2`, .ascii.`3`,
        .ascii.`4`, .ascii.`5`, .ascii.`6`, .ascii.`7`,
        .ascii.`8`, .ascii.`9`, .ascii.a, .ascii.b,
        .ascii.c, .ascii.d, .ascii.e, .ascii.f
    ]

    // Keywords
    @usableFromInline static let keywordNull: [UInt8] = [.ascii.n, .ascii.u, .ascii.l, .ascii.l]
    @usableFromInline static let keywordTrue: [UInt8] = [.ascii.t, .ascii.r, .ascii.u, .ascii.e]
    @usableFromInline static let keywordFalse: [UInt8] = [.ascii.f, .ascii.a, .ascii.l, .ascii.s, .ascii.e]

    // Escape sequences (static to avoid allocating arrays in hot path)
    @usableFromInline static let escapeQuote: [UInt8] = [.ascii.reverseSlant, .ascii.quotationMark]
    @usableFromInline static let escapeBackslash: [UInt8] = [.ascii.reverseSlant, .ascii.reverseSlant]
    @usableFromInline static let escapeSlash: [UInt8] = [.ascii.reverseSlant, .ascii.solidus]
    @usableFromInline static let escapeBackspace: [UInt8] = [.ascii.reverseSlant, .ascii.b]
    @usableFromInline static let escapeFormfeed: [UInt8] = [.ascii.reverseSlant, .ascii.f]
    @usableFromInline static let escapeNewline: [UInt8] = [.ascii.reverseSlant, .ascii.n]
    @usableFromInline static let escapeCarriageReturn: [UInt8] = [.ascii.reverseSlant, .ascii.r]
    @usableFromInline static let escapeTab: [UInt8] = [.ascii.reverseSlant, .ascii.t]
    @usableFromInline static let escapeUnicodePrefix: [UInt8] = [.ascii.reverseSlant, .ascii.u]
}

extension RFC_8259.Encoder {
    /// Encodes a value into the buffer.
    @inlinable
    mutating func encode<Buffer: RangeReplaceableCollection>(
        _ value: RFC_8259.Value,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        switch value {
        case .null:
            buffer.append(contentsOf: Self.keywordNull)

        case .bool(true):
            buffer.append(contentsOf: Self.keywordTrue)

        case .bool(false):
            buffer.append(contentsOf: Self.keywordFalse)

        case .number(let n):
            // Use original bytes for lossless round-trip
            buffer.append(contentsOf: n.original.bytes)

        case .string(let s):
            encodeString(s, into: &buffer)

        case .array(let a):
            encodeArray(a, into: &buffer)

        case .object(let o):
            encodeObject(o, into: &buffer)
        }
    }

    /// Encodes a string with proper escaping.
    @inlinable
    mutating func encodeString<Buffer: RangeReplaceableCollection>(
        _ string: String,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        buffer.append(.ascii.quotationMark) // "

        for scalar in string.unicodeScalars {
            let value = scalar.value

            switch value {
            case UInt32(UInt8.ascii.quotationMark):
                buffer.append(contentsOf: Self.escapeQuote)

            case UInt32(UInt8.ascii.reverseSlant):
                buffer.append(contentsOf: Self.escapeBackslash)

            case UInt32(UInt8.ascii.solidus) where options.escapeSlashes:
                buffer.append(contentsOf: Self.escapeSlash)

            case UInt32(UInt8.ascii.bs):
                buffer.append(contentsOf: Self.escapeBackspace)

            case UInt32(UInt8.ascii.ff):
                buffer.append(contentsOf: Self.escapeFormfeed)

            case UInt32(UInt8.ascii.lf):
                buffer.append(contentsOf: Self.escapeNewline)

            case UInt32(UInt8.ascii.cr):
                buffer.append(contentsOf: Self.escapeCarriageReturn)

            case UInt32(UInt8.ascii.htab):
                buffer.append(contentsOf: Self.escapeTab)

            case 0x00...0x1F: // Other control characters → \uXXXX
                buffer.append(contentsOf: Self.escapeUnicodePrefix)
                encodeHex(UInt16(value), into: &buffer)

            default:
                encodeScalarUTF8(scalar, into: &buffer)
            }
        }

        buffer.append(.ascii.quotationMark) // "
    }

    /// Encodes a Unicode scalar directly to UTF-8 bytes.
    ///
    /// This avoids the intermediate `String` allocation that would occur with
    /// `String(scalar).utf8`.
    @inlinable
    func encodeScalarUTF8<Buffer: RangeReplaceableCollection>(
        _ scalar: Unicode.Scalar,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        let v = scalar.value
        switch v {
        case 0x00...0x7F:
            // 1-byte: 0xxxxxxx
            buffer.append(UInt8(v))
        case 0x80...0x7FF:
            // 2-byte: 110xxxxx 10xxxxxx
            buffer.append(contentsOf: [
                UInt8(0xC0 | (v >> 6)),
                UInt8(0x80 | (v & 0x3F))
            ])
        case 0x800...0xFFFF:
            // 3-byte: 1110xxxx 10xxxxxx 10xxxxxx
            buffer.append(contentsOf: [
                UInt8(0xE0 | (v >> 12)),
                UInt8(0x80 | ((v >> 6) & 0x3F)),
                UInt8(0x80 | (v & 0x3F))
            ])
        default:
            // 4-byte: 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx (0x10000...0x10FFFF)
            buffer.append(contentsOf: [
                UInt8(0xF0 | (v >> 18)),
                UInt8(0x80 | ((v >> 12) & 0x3F)),
                UInt8(0x80 | ((v >> 6) & 0x3F)),
                UInt8(0x80 | (v & 0x3F))
            ])
        }
    }

    /// Encodes a 16-bit value as 4 hex digits.
    @inlinable
    func encodeHex<Buffer: RangeReplaceableCollection>(
        _ value: UInt16,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        buffer.append(Self.hexDigits[Int((value >> 12) & 0x0F)])
        buffer.append(Self.hexDigits[Int((value >> 8) & 0x0F)])
        buffer.append(Self.hexDigits[Int((value >> 4) & 0x0F)])
        buffer.append(Self.hexDigits[Int(value & 0x0F)])
    }

    /// Encodes an array.
    @inlinable
    mutating func encodeArray<Buffer: RangeReplaceableCollection>(
        _ array: RFC_8259.Array,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        buffer.append(.ascii.leftBracket) // [

        precondition(depth < options.maxDepth, "JSON encoding exceeded maximum depth of \(options.maxDepth)")
        depth += 1

        var first = true
        for element in array {
            if !first {
                buffer.append(.ascii.comma) // ,
            }
            first = false

            if options.prettyPrint {
                buffer.append(.ascii.lf) // newline
                appendIndent(into: &buffer)
            }

            encode(element, into: &buffer)
        }

        depth -= 1

        if !array.isEmpty && options.prettyPrint {
            buffer.append(.ascii.lf) // newline
            appendIndent(into: &buffer)
        }

        buffer.append(.ascii.rightBracket) // ]
    }

    /// Encodes an object.
    @inlinable
    mutating func encodeObject<Buffer: RangeReplaceableCollection>(
        _ object: RFC_8259.Object,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        buffer.append(.ascii.leftBrace) // {

        precondition(depth < options.maxDepth, "JSON encoding exceeded maximum depth of \(options.maxDepth)")
        depth += 1

        var first = true

        if options.sortKeys {
            // Sort by UTF-8 bytes (lexicographic), not Unicode collation
            for (key, value) in object.sorted(by: { $0.key.utf8.lexicographicallyPrecedes($1.key.utf8) }) {
                if !first { buffer.append(.ascii.comma) }
                first = false
                if options.prettyPrint {
                    buffer.append(.ascii.lf)
                    appendIndent(into: &buffer)
                }
                encodeString(key, into: &buffer)
                buffer.append(.ascii.colon)
                if options.prettyPrint { buffer.append(.ascii.sp) }
                encode(value, into: &buffer)
            }
        } else {
            // Direct iteration - no Array copy
            for (key, value) in object {
                if !first { buffer.append(.ascii.comma) }
                first = false
                if options.prettyPrint {
                    buffer.append(.ascii.lf)
                    appendIndent(into: &buffer)
                }
                encodeString(key, into: &buffer)
                buffer.append(.ascii.colon)
                if options.prettyPrint { buffer.append(.ascii.sp) }
                encode(value, into: &buffer)
            }
        }

        depth -= 1

        if !object.isEmpty && options.prettyPrint {
            buffer.append(.ascii.lf)
            appendIndent(into: &buffer)
        }

        buffer.append(.ascii.rightBrace) // }
    }

    /// Appends indentation for the current depth.
    @inlinable
    func appendIndent<Buffer: RangeReplaceableCollection>(
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        for _ in 0..<depth {
            buffer.append(contentsOf: indent)
        }
    }
}

// MARK: - Value.encode Extension

extension RFC_8259.Value {
    /// Creates an encoder for this value.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let bytes = value.encode()
    /// let pretty = value.encode(options: .init(prettyPrint: true))
    /// ```
    public var encode: RFC_8259.Encode {
        RFC_8259.Encode(self)
    }
}

// MARK: - Binary.Serializable Conformance

extension RFC_8259.Value: Binary.Serializable {
    /// Serializes a JSON value to UTF-8 bytes.
    ///
    /// Uses compact encoding (no pretty-printing, no sorted keys).
    /// For custom formatting, use `value.encode(options:)` instead.
    ///
    /// - Parameters:
    ///   - value: The JSON value to serialize.
    ///   - buffer: The buffer to append bytes to.
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        var encoder = RFC_8259.Encoder(options: RFC_8259.Options())
        encoder.encode(value, into: &buffer)
    }
}
