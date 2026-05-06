/// RFC_8259.Lexer.swift
/// swift-rfc-8259
///
/// Zero-copy JSON lexer (~Copyable)

@_spi(Unsafe) public import Array_Primitives
import Parser_Primitives

extension RFC_8259 {
    /// Zero-copy JSON lexer.
    ///
    /// The lexer tokenizes UTF-8 byte input into JSON tokens.
    /// It is `~Copyable` to prevent accidental state copies.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// var input = Parser_Primitives.Parser.CollectionInput(bytes)
    /// var lexer = RFC_8259.Lexer(consume input)
    /// while let token = try lexer.next() {
    ///     print(token)
    /// }
    /// ```
    public struct Lexer<Input: Parser_Primitives.Parser.Input.`Protocol` & ~Copyable>: ~Copyable
    where Input.Element == UInt8 {
        /// The input being lexed.
        @usableFromInline
        internal var input: Input

        /// Current position for error reporting.
        @usableFromInline
        internal var _position: RFC_8259.Position

        /// Creates a lexer for the given input.
        ///
        /// - Parameter input: The UTF-8 byte input to lex.
        @inlinable
        public init(_ input: consuming Input) {
            self.input = input
            self._position = RFC_8259.Position(
                offset: .zero,
                location: Text.Location(line: 1, column: .one)
            )
        }
    }
}

// MARK: - Lexer Public API

extension RFC_8259.Lexer where Input: ~Copyable {
    /// The current position in the input.
    public var position: RFC_8259.Position {
        _position
    }
}

// MARK: - Lexer Peek & Advance

extension RFC_8259.Lexer where Input: ~Copyable {
    /// Peeks at the next byte without consuming it.
    @inlinable
    internal var peek: UInt8? {
        mutating get {
            guard !input.isEmpty else { return nil }
            let cp = input.checkpoint
            let byte = try! input.advance()
            input.setPosition(to: cp)
            return byte
        }
    }

    /// Advances by one byte, updating position. Returns the consumed byte.
    @inlinable @discardableResult
    internal mutating func advance() -> UInt8 {
        let byte = try! input.advance()
        let isNewline = byte == .ascii.lf
        _position = RFC_8259.Position(
            offset: _position.offset.successor.saturating(),
            location: isNewline
                ? Text.Location(
                    line: Text.Line.Number(_position.location.line.underlying &+ 1),
                    column: .one
                  )
                : Text.Location(
                    line: _position.location.line,
                    column: Text.Line.Column(Cardinal(_position.location.column.underlying.rawValue &+ 1))
                  )
        )
        return byte
    }

    /// Advances by n bytes, updating position.
    @inlinable
    internal mutating func advance(_ n: Int) {
        for _ in 0..<n {
            advance()
        }
    }
}

// MARK: - Lexer Core Methods

extension RFC_8259.Lexer where Input: ~Copyable {
    /// Returns the next token, or nil if at end of input.
    ///
    /// - Throws: `RFC_8259.Error` if the input is malformed.
    @inlinable
    public mutating func next() throws(RFC_8259.Error) -> RFC_8259.Token? {
        skipWhitespace()

        guard let byte = peek else {
            return nil
        }

        switch byte {
        case .ascii.leftBrace:              // {
            advance()
            return .objectStart

        case .ascii.rightBrace:             // }
            advance()
            return .objectEnd

        case .ascii.leftBracket:            // [
            advance()
            return .arrayStart

        case .ascii.rightBracket:           // ]
            advance()
            return .arrayEnd

        case .ascii.colon:                  // :
            advance()
            return .colon

        case .ascii.comma:                  // ,
            advance()
            return .comma

        case .ascii.quotationMark:          // "
            return try lexString()

        case .ascii.n:                      // n (null)
            return try lexNull()

        case .ascii.t:                      // t (true)
            return try lexTrue()

        case .ascii.f:                      // f (false)
            return try lexFalse()

        case .ascii.hyphen,                 // -
             .ascii.`0`...(.ascii.`9`):     // 0-9
            return try lexNumber()

        default:
            throw .unexpectedToken(
                at: _position,
                found: .unknown(byte),
                expected: .value
            )
        }
    }
}

// MARK: - Lexer Whitespace

extension RFC_8259.Lexer where Input: ~Copyable {
    /// Skips whitespace bytes.
    @inlinable
    internal mutating func skipWhitespace() {
        while let byte = peek, RFC_8259.isWhitespace(byte) {
            advance()
        }
    }
}

// MARK: - Lexer Literals

extension RFC_8259.Lexer where Input: ~Copyable {
    /// Lexes `null`.
    @inlinable
    internal mutating func lexNull() throws(RFC_8259.Error) -> RFC_8259.Token {
        try expectLiteral([.ascii.n, .ascii.u, .ascii.l, .ascii.l])
        return .null
    }

    /// Lexes `true`.
    @inlinable
    internal mutating func lexTrue() throws(RFC_8259.Error) -> RFC_8259.Token {
        try expectLiteral([.ascii.t, .ascii.r, .ascii.u, .ascii.e])
        return .true
    }

    /// Lexes `false`.
    @inlinable
    internal mutating func lexFalse() throws(RFC_8259.Error) -> RFC_8259.Token {
        try expectLiteral([.ascii.f, .ascii.a, .ascii.l, .ascii.s, .ascii.e])
        return .false
    }

    /// Expects the given literal bytes.
    @inlinable
    internal mutating func expectLiteral(_ expected: [UInt8]) throws(RFC_8259.Error) {
        let startPos = _position
        for expectedByte in expected {
            guard let byte = peek else {
                throw .unexpectedEndOfInput(at: _position, expected: .value)
            }
            guard byte == expectedByte else {
                throw .unexpectedToken(at: startPos, found: .unknown(byte), expected: .value)
            }
            advance()
        }
    }
}

// MARK: - Lexer String

extension RFC_8259.Lexer where Input: ~Copyable {
    /// Lexes a JSON string.
    @inlinable
    internal mutating func lexString() throws(RFC_8259.Error) -> RFC_8259.Token {
        let startPos = _position

        // Consume opening quote
        advance() // Skip "

        var result: [UInt8] = []

        while let byte = peek {
            switch byte {
            case .ascii.quotationMark:      // " - closing quote
                advance()
                return .string(String(decoding: result, as: UTF8.self))

            case .ascii.reverseSlant:       // \ - escape sequence
                advance()
                try result.append(contentsOf: lexEscapeSequence())

            case 0x00...0x1F:               // Control characters (C0 range)
                throw .invalidString(at: _position, reason: .controlCharacter(byte))

            default:
                // Regular character - validate UTF-8
                result.append(byte)
                advance()
            }
        }

        throw .invalidString(at: startPos, reason: .unterminated)
    }

    /// Lexes an escape sequence after the backslash.
    @inlinable
    internal mutating func lexEscapeSequence() throws(RFC_8259.Error) -> [UInt8] {
        guard let byte = peek else {
            throw .unexpectedEndOfInput(at: _position, expected: .value)
        }

        advance()

        switch byte {
        case .ascii.quotationMark:  return [.ascii.quotationMark]   // \"
        case .ascii.reverseSlant:   return [.ascii.reverseSlant]    // \\
        case .ascii.solidus:        return [.ascii.solidus]         // \/
        case .ascii.b:              return [.ascii.bs]              // \b
        case .ascii.f:              return [.ascii.ff]              // \f
        case .ascii.n:              return [.ascii.lf]              // \n
        case .ascii.r:              return [.ascii.cr]              // \r
        case .ascii.t:              return [.ascii.htab]            // \t
        case .ascii.u:              return try lexUnicodeEscape()   // \uXXXX
        default:
            throw .invalidString(at: _position, reason: .invalidEscape(byte))
        }
    }

    /// Lexes a \uXXXX Unicode escape.
    @inlinable
    internal mutating func lexUnicodeEscape() throws(RFC_8259.Error) -> [UInt8] {
        var hex: [UInt8] = []
        hex.reserveCapacity(4)

        for _ in 0..<4 {
            guard let byte = peek else {
                throw .invalidString(at: _position, reason: .invalidUnicodeEscape)
            }
            guard byte.ascii.isHexDigit else {
                throw .invalidString(at: _position, reason: .invalidUnicodeEscape)
            }
            hex.append(byte)
            advance()
        }

        guard let codePoint = parseHex(hex) else {
            throw .invalidString(at: _position, reason: .invalidUnicodeEscape)
        }

        // Handle surrogate pairs - check BEFORE trying to create Unicode.Scalar
        // since surrogates (0xD800-0xDFFF) are not valid scalar values
        if codePoint >= 0xD800 && codePoint <= 0xDBFF {
            // High surrogate - expect low surrogate
            guard peek == .ascii.reverseSlant else {
                throw .invalidString(at: _position, reason: .invalidUnicodeEscape)
            }
            advance()
            guard peek == .ascii.u else {
                throw .invalidString(at: _position, reason: .invalidUnicodeEscape)
            }
            advance()

            var lowHex: [UInt8] = []
            lowHex.reserveCapacity(4)
            for _ in 0..<4 {
                guard let byte = peek, byte.ascii.isHexDigit else {
                    throw .invalidString(at: _position, reason: .invalidUnicodeEscape)
                }
                lowHex.append(byte)
                advance()
            }

            guard let lowCodePoint = parseHex(lowHex),
                  lowCodePoint >= 0xDC00 && lowCodePoint <= 0xDFFF else {
                throw .invalidString(at: _position, reason: .invalidUnicodeEscape)
            }

            // Combine surrogate pair
            let combined = 0x10000 + ((codePoint - 0xD800) << 10) + (lowCodePoint - 0xDC00)
            guard let combinedScalar = Unicode.Scalar(combined) else {
                throw .invalidString(at: _position, reason: .invalidUnicodeEscape)
            }
            return Swift.Array(String(combinedScalar).utf8)
        }

        // Not a surrogate - create scalar directly
        guard let scalar = Unicode.Scalar(codePoint) else {
            throw .invalidString(at: _position, reason: .invalidUnicodeEscape)
        }
        return Swift.Array(String(scalar).utf8)
    }

    /// Parses 4 hex bytes to a UInt32.
    @inlinable
    internal func parseHex(_ bytes: [UInt8]) -> UInt32? {
        guard bytes.count == 4 else { return nil }
        var result: UInt32 = 0
        for byte in bytes {
            guard let digit = byte.ascii.hexValue else { return nil }
            result = result * 16 + UInt32(digit)
        }
        return result
    }
}

// MARK: - Lexer Number

extension RFC_8259.Lexer where Input: ~Copyable {
    /// Lexes a JSON number.
    ///
    /// Uses `Array.Small<24>` for inline storage of number bytes,
    /// avoiding heap allocation for typical JSON numbers (< 24 bytes).
    @inlinable
    internal mutating func lexNumber() throws(RFC_8259.Error) -> RFC_8259.Token {
        let startPos = _position
        var bytes = Array_Primitives.Array<UInt8>.Small<24>()

        // Optional minus
        if peek == .ascii.hyphen {
            bytes.append(advance())
        }

        // Integer part
        guard let firstDigit = peek, firstDigit.ascii.isDigit else {
            throw .invalidNumber(at: startPos, reason: .missingDigits(context: "integer part"))
        }

        if firstDigit == .ascii.`0` { // Leading zero
            bytes.append(advance())

            // Check for leading zeros (invalid in JSON)
            if let next = peek, next.ascii.isDigit {
                throw .invalidNumber(at: startPos, reason: .leadingZeros)
            }
        } else {
            // digit1-9 followed by more digits
            while let byte = peek, byte.ascii.isDigit {
                bytes.append(advance())
            }
        }

        var isFloat = false

        // Optional fraction
        if peek == .ascii.period {
            isFloat = true
            bytes.append(advance())

            guard let firstFracDigit = peek, firstFracDigit.ascii.isDigit else {
                throw .invalidNumber(at: startPos, reason: .missingDigits(context: "fraction"))
            }

            while let byte = peek, byte.ascii.isDigit {
                bytes.append(advance())
            }
        }

        // Optional exponent
        if let e = peek, e == .ascii.e || e == .ascii.E {
            isFloat = true
            bytes.append(advance())

            // Optional sign
            if let sign = peek, sign == .ascii.plusSign || sign == .ascii.hyphen {
                bytes.append(advance())
            }

            guard let firstExpDigit = peek, firstExpDigit.ascii.isDigit else {
                throw .invalidNumber(at: startPos, reason: .missingDigits(context: "exponent"))
            }

            while let byte = peek, byte.ascii.isDigit {
                bytes.append(advance())
            }
        }

        // Extract bytes for Original and String conversion
        let byteArray: [UInt8] = {
            let span = bytes.span
            var arr: [UInt8] = []
            arr.reserveCapacity(span.count)
            for i in 0..<span.count {
                arr.append(span[i])
            }
            return arr
        }()
        let original = RFC_8259.Number.Original(byteArray)
        let numStr = String(decoding: byteArray, as: UTF8.self)

        if isFloat {
            guard let value = Double(numStr), value.isFinite else {
                throw .invalidNumber(at: startPos, reason: .overflow)
            }
            return .number(RFC_8259.Number(value, original: original))
        } else {
            // Try Int64 first, then UInt64, then Double
            if let value = Int64(numStr) {
                return .number(RFC_8259.Number(value, original: original))
            } else if let value = UInt64(numStr) {
                return .number(RFC_8259.Number(value, original: original))
            } else if let value = Double(numStr), value.isFinite {
                return .number(RFC_8259.Number(value, original: original))
            } else {
                throw .invalidNumber(at: startPos, reason: .overflow)
            }
        }
    }
}
