/// RFC_8259.Parser.Span.swift
/// swift-rfc-8259
///
/// Span-specialized JSON parser for the contiguous-bytes case.
///
/// Phase A1 of the Tier-4 parse-performance work
/// (`swift-foundations/swift-json/Research/parse-performance-architecture.md`),
/// rebased onto `Lexer.Scanner` from swift-lexer-primitives per the
/// streaming-deserialize placement audit's Ticket T-1
/// (`swift-institute/Audits/streaming-deserialize-placement-audit.md`).
///
/// Internal type — exposed only to the `RFC_8259.Decode` dispatch
/// fork. Emits the same `RFC_8259.Value` / `RFC_8259.Token` shape as
/// the existing generic `RFC_8259.Parser<Input>` so the public API is
/// preserved byte-for-byte.
///
/// File name preserves the architecture doc's wording — the type
/// itself lives at `RFC_8259.Span.Parser`, see the namespace note in
/// `RFC_8259.Lexer.Span.swift`.
///
/// ## Storage-shape note
///
/// The generic `RFC_8259.Parser<Input>` carries `var lookahead:
/// Token?` to implement a 1-token pushback pattern for empty-collection
/// detection. Storing `Optional<RFC_8259.Token>` (and indirectly
/// `String` / `RFC_8259.Number`) inside a `~Copyable & ~Escapable`
/// struct triggers a known Swift compiler internal-bug
/// ("copy of noncopyable typed value") on the current toolchain
/// (Swift 6.3+ as of 2026-05-13). The Span parser sidesteps this by
/// doing the empty-collection check at the byte level (`peek` for
/// `]` / `}`) rather than at the token level, which preserves the
/// semantics without storing a buffered token.

public import Lexer_Primitives
@_spi(Unsafe) public import Array_Primitives

extension RFC_8259.Span {
    /// Span-specialised JSON parser.
    ///
    /// `~Copyable & ~Escapable` per the cursor it owns
    /// (`RFC_8259.Span.Lexer`). Drives the lexer + value-tree
    /// construction in one pass; reuses the public `RFC_8259.Value`,
    /// `RFC_8259.Object`, `RFC_8259.Array`, `RFC_8259.Number`, and
    /// `RFC_8259.Token` types verbatim.
    ///
    /// Not a public type. The static `parse(_:maxDepth:)` entry point
    /// is the only call site from `RFC_8259.Decode`.
    @safe
    @usableFromInline
    internal struct Parser: ~Copyable, ~Escapable {
        @usableFromInline
        internal var lexer: RFC_8259.Span.Lexer

        /// Current nesting depth.
        @usableFromInline
        internal var depth: Int

        /// Maximum allowed nesting depth.
        @usableFromInline
        internal let maxDepth: Int

        /// Reusable scratch buffer for `lexString`'s byte accumulation.
        ///
        /// One owned per parse; `removeAll(keepingCapacity: true)`
        /// between strings amortises the per-string allocation across
        /// the whole parse.
        @usableFromInline
        internal var stringScratch: [UInt8]

        @inlinable
        @_lifetime(borrow bytes)
        internal init(_ bytes: borrowing Swift.Span<UInt8>, maxDepth: Int) {
            self.lexer = RFC_8259.Span.Lexer(bytes)
            self.depth = 0
            self.maxDepth = maxDepth
            var scratch: [UInt8] = []
            scratch.reserveCapacity(64)
            self.stringScratch = scratch
        }
    }
}

// MARK: - Entry point

extension RFC_8259.Span.Parser {
    /// Parses the span and returns a JSON value.
    @inlinable
    internal static func parse(
        _ bytes: borrowing Swift.Span<UInt8>,
        maxDepth: Int
    ) throws(RFC_8259.Error) -> RFC_8259.Value {
        var parser = RFC_8259.Span.Parser(bytes, maxDepth: maxDepth)
        let value = try parser.parse()
        return value
    }

    /// Parses the input and returns a JSON value.
    @inlinable
    @_lifetime(self: copy self)
    internal mutating func parse() throws(RFC_8259.Error) -> RFC_8259.Value {
        let value = try parseValue()

        // Ensure no trailing content (except whitespace).
        skipWhitespace()
        if !lexer.scanner.isAtEnd {
            throw .trailingContent(at: currentPosition())
        }

        return value
    }
}

// MARK: - Current-position helper

extension RFC_8259.Span.Parser {
    /// Builds `RFC_8259.Position` from the lexer's current cursor +
    /// location. O(1) — the Scanner's tracker maintains line:column
    /// incrementally, so no scan is required at error sites.
    @inlinable
    internal func currentPosition() -> RFC_8259.Position {
        RFC_8259.Position(offset: lexer.scanner.position, location: lexer.scanner.location)
    }
}

// MARK: - Value parsing

extension RFC_8259.Span.Parser {
    /// Parses a JSON value.
    ///
    /// Reads the next non-whitespace byte and dispatches by ASCII byte
    /// — no token-level lookahead, no `Optional<Token>` storage.
    @inlinable
    @_lifetime(self: copy self)
    internal mutating func parseValue() throws(RFC_8259.Error) -> RFC_8259.Value {
        skipWhitespace()

        guard let byte = lexer.scanner.peek() else {
            throw .unexpectedEndOfInput(at: currentPosition(), expected: .value)
        }

        switch byte {
        case UInt8.ascii.leftBrace:              // {
            lexer.scanner.advance()
            return try parseObject()

        case UInt8.ascii.leftBracket:            // [
            lexer.scanner.advance()
            return try parseArray()

        case UInt8.ascii.quotationMark:          // "
            let s = try lexStringValue()
            return .string(s)

        case UInt8.ascii.n:                      // n (null)
            try expectLiteral([.ascii.n, .ascii.u, .ascii.l, .ascii.l])
            return .null

        case UInt8.ascii.t:                      // t (true)
            try expectLiteral([.ascii.t, .ascii.r, .ascii.u, .ascii.e])
            return .bool(true)

        case UInt8.ascii.f:                      // f (false)
            try expectLiteral([.ascii.f, .ascii.a, .ascii.l, .ascii.s, .ascii.e])
            return .bool(false)

        case UInt8.ascii.hyphen,                 // -
             UInt8.ascii.`0`...UInt8.ascii.`9`:  // 0-9
            let n = try lexNumberValue()
            return .number(n)

        default:
            throw .unexpectedToken(
                at: currentPosition(),
                found: .unknown(byte),
                expected: .value
            )
        }
    }
}

// MARK: - Array parsing (called after `[` is consumed)

extension RFC_8259.Span.Parser {
    @inlinable
    @_lifetime(self: copy self)
    internal mutating func parseArray() throws(RFC_8259.Error) -> RFC_8259.Value {
        depth += 1
        if depth > maxDepth {
            throw .depthExceeded(at: currentPosition(), limit: maxDepth)
        }
        defer { depth -= 1 }

        var elements: [RFC_8259.Value] = []

        skipWhitespace()
        // Empty array: `[ ]`.
        if lexer.scanner.peek() == UInt8.ascii.rightBracket {
            lexer.scanner.advance()
            return .array(RFC_8259.Array(elements))
        }

        // First value.
        elements.append(try parseValue())

        // Subsequent values.
        while true {
            skipWhitespace()
            guard let byte = lexer.scanner.peek() else {
                throw .unexpectedEndOfInput(at: currentPosition(), expected: .arrayEnd)
            }
            switch byte {
            case UInt8.ascii.rightBracket:
                lexer.scanner.advance()
                return .array(RFC_8259.Array(elements))
            case UInt8.ascii.comma:
                lexer.scanner.advance()
                elements.append(try parseValue())
            default:
                throw .unexpectedToken(
                    at: currentPosition(),
                    found: .unknown(byte),
                    expected: .commaOrEnd
                )
            }
        }
    }
}

// MARK: - Object parsing (called after `{` is consumed)

extension RFC_8259.Span.Parser {
    @inlinable
    @_lifetime(self: copy self)
    internal mutating func parseObject() throws(RFC_8259.Error) -> RFC_8259.Value {
        depth += 1
        if depth > maxDepth {
            throw .depthExceeded(at: currentPosition(), limit: maxDepth)
        }
        defer { depth -= 1 }

        var members: [(key: String, value: RFC_8259.Value)] = []

        skipWhitespace()
        // Empty object: `{ }`.
        if lexer.scanner.peek() == UInt8.ascii.rightBrace {
            lexer.scanner.advance()
            return .object(RFC_8259.Object(members))
        }

        // First member.
        members.append(try parseMember())

        // Subsequent members.
        while true {
            skipWhitespace()
            guard let byte = lexer.scanner.peek() else {
                throw .unexpectedEndOfInput(at: currentPosition(), expected: .objectEnd)
            }
            switch byte {
            case UInt8.ascii.rightBrace:
                lexer.scanner.advance()
                return .object(RFC_8259.Object(members))
            case UInt8.ascii.comma:
                lexer.scanner.advance()
                members.append(try parseMember())
            default:
                throw .unexpectedToken(
                    at: currentPosition(),
                    found: .unknown(byte),
                    expected: .commaOrEnd
                )
            }
        }
    }

    /// Parses a single object member (key: value).
    @inlinable
    @_lifetime(self: copy self)
    internal mutating func parseMember() throws(RFC_8259.Error) -> (key: String, value: RFC_8259.Value) {
        skipWhitespace()
        guard let firstByte = lexer.scanner.peek() else {
            throw .unexpectedEndOfInput(at: currentPosition(), expected: .objectKey)
        }
        guard firstByte == UInt8.ascii.quotationMark else {
            throw .unexpectedToken(
                at: currentPosition(),
                found: .unknown(firstByte),
                expected: .objectKey
            )
        }
        let key = try lexStringValue()

        // Expect colon.
        skipWhitespace()
        guard let colonByte = lexer.scanner.peek() else {
            throw .unexpectedEndOfInput(at: currentPosition(), expected: .colon)
        }
        guard colonByte == UInt8.ascii.colon else {
            throw .unexpectedToken(
                at: currentPosition(),
                found: .unknown(colonByte),
                expected: .colon
            )
        }
        lexer.scanner.advance()

        // Parse value.
        let value = try parseValue()
        return (key: key, value: value)
    }
}

// MARK: - Whitespace

extension RFC_8259.Span.Parser {
    /// Skips whitespace bytes.
    ///
    /// Uses an inlined four-way comparison against the four JSON
    /// whitespace bytes (space, tab, CR, LF) instead of the
    /// `RFC_8259.isWhitespace` Set lookup. The post-A1 profile
    /// (10 × 86 MB) showed `Hasher._hash(seed:bytes:count:)` as a
    /// significant cost under `skipWhitespace` — the Set-backed
    /// predicate hashes every byte. Direct equality checks are
    /// branchless on ARM64 after constant folding.
    ///
    /// Newlines update the Scanner's `Text.Location.Tracker` so that
    /// subsequent error-site position queries report correct
    /// line:column. JSON tokens (strings, numbers, literals) cannot
    /// contain raw 0x0A / 0x0D — they MUST be escaped per RFC 8259 §7
    /// — so newline tracking only fires here, in inter-token whitespace.
    @inlinable
    @_lifetime(self: copy self)
    internal mutating func skipWhitespace() {
        while let byte = lexer.scanner.peek() {
            // Inline the whitespace check: space (0x20), tab (0x09),
            // LF (0x0A), CR (0x0D). RFC 8259 §2.
            switch byte {
            case 0x20, 0x09:
                lexer.scanner.advance()
            case 0x0A:
                lexer.scanner.newline(at: lexer.scanner.position)
                lexer.scanner.advance()
            case 0x0D:
                lexer.scanner.newline(at: lexer.scanner.position)
                lexer.scanner.advance()
                // CRLF: consume the LF without re-counting the newline.
                if lexer.scanner.peek() == 0x0A {
                    lexer.scanner.advance()
                }
            default:
                return
            }
        }
    }
}

// MARK: - Literals

extension RFC_8259.Span.Parser {
    /// Expects the given literal bytes (called after the first byte
    /// has been peeked but NOT advanced).
    ///
    /// Position computation is deferred to error sites only — the
    /// hot path doesn't materialise `RFC_8259.Position` per literal.
    /// The literal start (cursor + location) is captured before the
    /// first byte; on mismatch we report the captured position so the
    /// diagnostic points at the start of the failed literal rather
    /// than the failing byte.
    @inlinable
    @_lifetime(self: copy self)
    internal mutating func expectLiteral(_ expected: [UInt8]) throws(RFC_8259.Error) {
        let startCursor = lexer.scanner.position
        let startLocation = lexer.scanner.location
        for expectedByte in expected {
            guard let byte = lexer.scanner.peek() else {
                throw .unexpectedEndOfInput(
                    at: currentPosition(),
                    expected: .value
                )
            }
            guard byte == expectedByte else {
                throw .unexpectedToken(
                    at: RFC_8259.Position(offset: startCursor, location: startLocation),
                    found: .unknown(byte),
                    expected: .value
                )
            }
            lexer.scanner.advance()
        }
    }
}

// MARK: - Strings (returns String directly — no Token wrapping)

extension RFC_8259.Span.Parser {
    /// Lexes a JSON string (after the leading `"` has been peeked but
    /// NOT advanced). Returns the decoded `String` directly. The Token
    /// wrapping that the generic lexer produces is bypassed — the
    /// Parser.Span doesn't need it.
    ///
    /// Position computation is deferred to error sites only — the
    /// hot path doesn't materialise `RFC_8259.Position` per string.
    @inlinable
    @_lifetime(self: copy self)
    internal mutating func lexStringValue() throws(RFC_8259.Error) -> String {
        let startCursor = lexer.scanner.position
        let startLocation = lexer.scanner.location

        lexer.scanner.advance() // Consume opening `"`.

        stringScratch.removeAll(keepingCapacity: true)
        var isASCII = true

        while let byte = lexer.scanner.peek() {
            switch byte {
            case UInt8.ascii.quotationMark:      // " - closing quote
                lexer.scanner.advance()
                if isASCII {
                    let count = stringScratch.count
                    let result = stringScratch.withUnsafeBufferPointer { src -> String in
                        String(unsafeUninitializedCapacity: count) { dst in
                            if count > 0 {
                                dst.baseAddress!.update(from: src.baseAddress!, count: count)
                            }
                            return count
                        }
                    }
                    return result
                }
                return String(decoding: stringScratch, as: UTF8.self)

            case UInt8.ascii.reverseSlant:       // \ - escape sequence
                lexer.scanner.advance()
                let escapeBytes = try lexEscapeSequence()
                for b in escapeBytes {
                    if b > 0x7F { isASCII = false }
                    stringScratch.append(b)
                }

            case 0x00...0x1F:                    // Control characters (C0 range)
                throw .invalidString(at: currentPosition(), reason: .controlCharacter(byte))

            default:
                if byte > 0x7F { isASCII = false }
                stringScratch.append(byte)
                lexer.scanner.advance()
            }
        }

        // Report the position at the start of the (now-unterminated) string.
        throw .invalidString(
            at: RFC_8259.Position(offset: startCursor, location: startLocation),
            reason: .unterminated
        )
    }

    /// Lexes an escape sequence after the backslash.
    @inlinable
    @_lifetime(self: copy self)
    internal mutating func lexEscapeSequence() throws(RFC_8259.Error) -> [UInt8] {
        guard let byte = lexer.scanner.peek() else {
            throw .unexpectedEndOfInput(at: currentPosition(), expected: .value)
        }

        lexer.scanner.advance()

        switch byte {
        case UInt8.ascii.quotationMark:  return [.ascii.quotationMark]   // \"
        case UInt8.ascii.reverseSlant:   return [.ascii.reverseSlant]    // \\
        case UInt8.ascii.solidus:        return [.ascii.solidus]         // \/
        case UInt8.ascii.b:              return [.ascii.bs]              // \b
        case UInt8.ascii.f:              return [.ascii.ff]              // \f
        case UInt8.ascii.n:              return [.ascii.lf]              // \n
        case UInt8.ascii.r:              return [.ascii.cr]              // \r
        case UInt8.ascii.t:              return [.ascii.htab]            // \t
        case UInt8.ascii.u:              return try lexUnicodeEscape()   // \uXXXX
        default:
            throw .invalidString(at: currentPosition(), reason: .invalidEscape(byte))
        }
    }

    /// Lexes a \uXXXX Unicode escape.
    @inlinable
    @_lifetime(self: copy self)
    internal mutating func lexUnicodeEscape() throws(RFC_8259.Error) -> [UInt8] {
        var hex: [UInt8] = []
        hex.reserveCapacity(4)

        for _ in 0..<4 {
            guard let byte = lexer.scanner.peek() else {
                throw .invalidString(at: currentPosition(), reason: .invalidUnicodeEscape)
            }
            guard byte.ascii.isHexDigit else {
                throw .invalidString(at: currentPosition(), reason: .invalidUnicodeEscape)
            }
            hex.append(byte)
            lexer.scanner.advance()
        }

        guard let codePoint = parseHex(hex) else {
            throw .invalidString(at: currentPosition(), reason: .invalidUnicodeEscape)
        }

        // Handle surrogate pairs.
        if codePoint >= 0xD800 && codePoint <= 0xDBFF {
            guard lexer.scanner.peek() == UInt8.ascii.reverseSlant else {
                throw .invalidString(at: currentPosition(), reason: .invalidUnicodeEscape)
            }
            lexer.scanner.advance()
            guard lexer.scanner.peek() == UInt8.ascii.u else {
                throw .invalidString(at: currentPosition(), reason: .invalidUnicodeEscape)
            }
            lexer.scanner.advance()

            var lowHex: [UInt8] = []
            lowHex.reserveCapacity(4)
            for _ in 0..<4 {
                guard let byte = lexer.scanner.peek(), byte.ascii.isHexDigit else {
                    throw .invalidString(at: currentPosition(), reason: .invalidUnicodeEscape)
                }
                lowHex.append(byte)
                lexer.scanner.advance()
            }

            guard let lowCodePoint = parseHex(lowHex),
                  lowCodePoint >= 0xDC00 && lowCodePoint <= 0xDFFF else {
                throw .invalidString(at: currentPosition(), reason: .invalidUnicodeEscape)
            }

            let combined = 0x10000 + ((codePoint - 0xD800) << 10) + (lowCodePoint - 0xDC00)
            guard let combinedScalar = Unicode.Scalar(combined) else {
                throw .invalidString(at: currentPosition(), reason: .invalidUnicodeEscape)
            }
            return Swift.Array(String(combinedScalar).utf8)
        }

        guard let scalar = Unicode.Scalar(codePoint) else {
            throw .invalidString(at: currentPosition(), reason: .invalidUnicodeEscape)
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

// MARK: - Numbers

extension RFC_8259.Span.Parser {
    /// Lexes a JSON number (called after the first byte has been
    /// peeked but NOT advanced). Returns `RFC_8259.Number` directly —
    /// no Token wrapping.
    @inlinable
    @_lifetime(self: copy self)
    internal mutating func lexNumberValue() throws(RFC_8259.Error) -> RFC_8259.Number {
        let startCursor = lexer.scanner.position
        let startLocation = lexer.scanner.location
        var bytes = Array_Primitives.Array<UInt8>.Small<24>()

        // Optional minus
        if lexer.scanner.peek() == UInt8.ascii.hyphen {
            bytes.append(lexer.consume())
        }

        // Integer part
        guard let firstDigit = lexer.scanner.peek(), firstDigit.ascii.isDigit else {
            throw .invalidNumber(
                at: RFC_8259.Position(offset: startCursor, location: startLocation),
                reason: .missingDigits(context: "integer part")
            )
        }

        if firstDigit == UInt8.ascii.`0` { // Leading zero
            bytes.append(lexer.consume())

            if let next = lexer.scanner.peek(), next.ascii.isDigit {
                throw .invalidNumber(
                    at: RFC_8259.Position(offset: startCursor, location: startLocation),
                    reason: .leadingZeros
                )
            }
        } else {
            while let byte = lexer.scanner.peek(), byte.ascii.isDigit {
                bytes.append(lexer.consume())
            }
        }

        var isFloat = false

        // Optional fraction
        if lexer.scanner.peek() == UInt8.ascii.period {
            isFloat = true
            bytes.append(lexer.consume())

            guard let firstFracDigit = lexer.scanner.peek(), firstFracDigit.ascii.isDigit else {
                throw .invalidNumber(
                    at: RFC_8259.Position(offset: startCursor, location: startLocation),
                    reason: .missingDigits(context: "fraction")
                )
            }

            while let byte = lexer.scanner.peek(), byte.ascii.isDigit {
                bytes.append(lexer.consume())
            }
        }

        // Optional exponent
        if let e = lexer.scanner.peek(), e == UInt8.ascii.e || e == UInt8.ascii.E {
            isFloat = true
            bytes.append(lexer.consume())

            if let sign = lexer.scanner.peek(), sign == UInt8.ascii.plusSign || sign == UInt8.ascii.hyphen {
                bytes.append(lexer.consume())
            }

            guard let firstExpDigit = lexer.scanner.peek(), firstExpDigit.ascii.isDigit else {
                throw .invalidNumber(
                    at: RFC_8259.Position(offset: startCursor, location: startLocation),
                    reason: .missingDigits(context: "exponent")
                )
            }

            while let byte = lexer.scanner.peek(), byte.ascii.isDigit {
                bytes.append(lexer.consume())
            }
        }

        let span = bytes.span
        let byteArray: [UInt8] = .init(unsafeUninitializedCapacity: span.count) { dst, initialized in
            for i in 0..<span.count {
                dst[i] = span[i]
            }
            initialized = span.count
        }
        let original = RFC_8259.Number.Original(byteArray)
        let numStr = String(decoding: byteArray, as: UTF8.self)

        if isFloat {
            guard let value = Double(numStr), value.isFinite else {
                throw .invalidNumber(
                    at: RFC_8259.Position(offset: startCursor, location: startLocation),
                    reason: .overflow
                )
            }
            return RFC_8259.Number(value, original: original)
        } else {
            if let value = Int64(numStr) {
                return RFC_8259.Number(value, original: original)
            } else if let value = UInt64(numStr) {
                return RFC_8259.Number(value, original: original)
            } else if let value = Double(numStr), value.isFinite {
                return RFC_8259.Number(value, original: original)
            } else {
                throw .invalidNumber(
                    at: RFC_8259.Position(offset: startCursor, location: startLocation),
                    reason: .overflow
                )
            }
        }
    }
}
