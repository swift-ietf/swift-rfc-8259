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
        var depth: Int = 0

        @usableFromInline
        init(options: Options) {
            self.options = options
        }
    }
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
            buffer.append(contentsOf: [.ascii.n, .ascii.u, .ascii.l, .ascii.l]) // null

        case .bool(true):
            buffer.append(contentsOf: [.ascii.t, .ascii.r, .ascii.u, .ascii.e]) // true

        case .bool(false):
            buffer.append(contentsOf: [.ascii.f, .ascii.a, .ascii.l, .ascii.s, .ascii.e]) // false

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
            case UInt32(UInt8.ascii.quotationMark): // "
                buffer.append(contentsOf: [.ascii.reverseSlant, .ascii.quotationMark]) // \"

            case UInt32(UInt8.ascii.reverseSlant): // \
                buffer.append(contentsOf: [.ascii.reverseSlant, .ascii.reverseSlant]) // \\

            case UInt32(UInt8.ascii.solidus) where options.escapeSlashes: // /
                buffer.append(contentsOf: [.ascii.reverseSlant, .ascii.solidus]) // \/

            case UInt32(UInt8.ascii.bs): // backspace
                buffer.append(contentsOf: [.ascii.reverseSlant, .ascii.b]) // \b

            case UInt32(UInt8.ascii.ff): // form feed
                buffer.append(contentsOf: [.ascii.reverseSlant, .ascii.f]) // \f

            case UInt32(UInt8.ascii.lf): // newline
                buffer.append(contentsOf: [.ascii.reverseSlant, .ascii.n]) // \n

            case UInt32(UInt8.ascii.cr): // carriage return
                buffer.append(contentsOf: [.ascii.reverseSlant, .ascii.r]) // \r

            case UInt32(UInt8.ascii.htab): // tab
                buffer.append(contentsOf: [.ascii.reverseSlant, .ascii.t]) // \t

            case 0x00...0x1F: // Other control characters
                // \uXXXX
                buffer.append(contentsOf: [.ascii.reverseSlant, .ascii.u]) // \u
                encodeHex(UInt16(value), into: &buffer)

            default:
                // Regular UTF-8 character - encode directly without String allocation
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
            buffer.append(UInt8(0xC0 | (v >> 6)))
            buffer.append(UInt8(0x80 | (v & 0x3F)))
        case 0x800...0xFFFF:
            // 3-byte: 1110xxxx 10xxxxxx 10xxxxxx
            buffer.append(UInt8(0xE0 | (v >> 12)))
            buffer.append(UInt8(0x80 | ((v >> 6) & 0x3F)))
            buffer.append(UInt8(0x80 | (v & 0x3F)))
        default:
            // 4-byte: 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx (0x10000...0x10FFFF)
            buffer.append(UInt8(0xF0 | (v >> 18)))
            buffer.append(UInt8(0x80 | ((v >> 12) & 0x3F)))
            buffer.append(UInt8(0x80 | ((v >> 6) & 0x3F)))
            buffer.append(UInt8(0x80 | (v & 0x3F)))
        }
    }

    /// Encodes a 16-bit value as 4 hex digits.
    @inlinable
    func encodeHex<Buffer: RangeReplaceableCollection>(
        _ value: UInt16,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        let hexDigits: [UInt8] = [
            .ascii.`0`, .ascii.`1`, .ascii.`2`, .ascii.`3`,
            .ascii.`4`, .ascii.`5`, .ascii.`6`, .ascii.`7`,
            .ascii.`8`, .ascii.`9`, .ascii.a, .ascii.b,
            .ascii.c, .ascii.d, .ascii.e, .ascii.f
        ]
        buffer.append(hexDigits[Int((value >> 12) & 0x0F)])
        buffer.append(hexDigits[Int((value >> 8) & 0x0F)])
        buffer.append(hexDigits[Int((value >> 4) & 0x0F)])
        buffer.append(hexDigits[Int(value & 0x0F)])
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

        let members: [(key: String, value: RFC_8259.Value)]
        if options.sortKeys {
            // Sort by UTF-8 bytes (lexicographic), not Unicode collation
            members = object.sorted { lhs, rhs in
                lhs.key.utf8.lexicographicallyPrecedes(rhs.key.utf8)
            }
        } else {
            members = Swift.Array(object)
        }

        var first = true
        for (key, value) in members {
            if !first {
                buffer.append(.ascii.comma) // ,
            }
            first = false

            if options.prettyPrint {
                buffer.append(.ascii.lf) // newline
                appendIndent(into: &buffer)
            }

            encodeString(key, into: &buffer)
            buffer.append(.ascii.colon) // :

            if options.prettyPrint {
                buffer.append(.ascii.sp) // space
            }

            encode(value, into: &buffer)
        }

        depth -= 1

        if !object.isEmpty && options.prettyPrint {
            buffer.append(.ascii.lf) // newline
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
            buffer.append(contentsOf: options.indent.utf8)
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
