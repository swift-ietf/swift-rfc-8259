/// RFC_8259.Pull.Tokens.swift
/// swift-rfc-8259
///
/// JSON witness for the L1 ``Lexer/Pull`` structural-event cohort.
///
/// Implements ``Lexer/Pull/Tokens`` for RFC 8259 JSON. Supplies:
///
/// - `Kind` = ``RFC_8259/Token/Kind`` (the JSON token vocabulary).
/// - `Error` = ``RFC_8259/Error``.
/// - `Scratch` = `[UInt8]` (reusable buffer for `currentString`'s
///   escape-decoding; lives on the generic stream's `scratch` field
///   per the L1 protocol's `initial()`/`Scratch` contract).
/// - Per-byte dispatch in `next(scanner:depth:limit:)` covering
///   `{` / `}` / `[` / `]` / `:` / `,` / `"` / `n` / `t` / `f` /
///   `-` / `0...9` per RFC 8259 §§ 2–5.
/// - Per-kind value-skip in `skip(value:depth:limit:)` covering
///   strings, numbers, literals, and balanced containers.
/// - Whitespace classification in `skip(whitespace:)` over the four
///   bytes admitted by RFC 8259 §2 (0x20 / 0x09 / 0x0A / 0x0D).

@_spi(Unsafe) public import Array_Primitives

extension RFC_8259.Pull {
    public enum Tokens: Lexer_Primitives.Lexer.Pull.Tokens {
        public typealias Kind = RFC_8259.Token.Kind
        public typealias Error = RFC_8259.Error
        public typealias Scratch = [UInt8]

        @inlinable
        public static func initial() -> [UInt8] {
            var scratch: [UInt8] = []
            scratch.reserveCapacity(64)
            return scratch
        }

        @inlinable
        public static func delta(for kind: Kind) -> Int {
            switch kind {
            case .objectStart, .arrayStart: return 1
            case .objectEnd, .arrayEnd: return -1
            default: return 0
            }
        }

        @inlinable
        public static func skip(whitespace scanner: inout Lexer_Primitives.Lexer.Scanner) {
            while let byte = scanner.peek() {
                switch byte {
                case 0x20, 0x09, 0x0A, 0x0D:
                    scanner.advance()
                default:
                    return
                }
            }
        }

        @inlinable
        public static func next(
            scanner: inout Lexer_Primitives.Lexer.Scanner,
            depth: inout Int,
            limit: Int
        ) throws(Error) -> Kind? {
            skip(whitespace: &scanner)
            guard let byte = scanner.peek() else { return nil }

            switch byte {
            case UInt8.ascii.leftBrace:              // {
                scanner.advance()
                depth &+= 1
                if depth > limit {
                    throw .depthExceeded(at: position(at: scanner.position, scanner: scanner), limit: limit)
                }
                return .objectStart
            case UInt8.ascii.rightBrace:             // }
                scanner.advance()
                depth &-= 1
                return .objectEnd
            case UInt8.ascii.leftBracket:            // [
                scanner.advance()
                depth &+= 1
                if depth > limit {
                    throw .depthExceeded(at: position(at: scanner.position, scanner: scanner), limit: limit)
                }
                return .arrayStart
            case UInt8.ascii.rightBracket:           // ]
                scanner.advance()
                depth &-= 1
                return .arrayEnd
            case UInt8.ascii.colon:                  // :
                scanner.advance()
                return .colon
            case UInt8.ascii.comma:                  // ,
                scanner.advance()
                return .comma
            case UInt8.ascii.quotationMark:          // "
                // Token start — payload deferred to currentString().
                return .string
            case UInt8.ascii.n:                      // null
                try expectLiteral(scanner: &scanner, [.ascii.n, .ascii.u, .ascii.l, .ascii.l])
                return .null
            case UInt8.ascii.t:                      // true
                try expectLiteral(scanner: &scanner, [.ascii.t, .ascii.r, .ascii.u, .ascii.e])
                return .`true`
            case UInt8.ascii.f:                      // false
                try expectLiteral(scanner: &scanner, [.ascii.f, .ascii.a, .ascii.l, .ascii.s, .ascii.e])
                return .`false`
            case UInt8.ascii.hyphen,                 // -
                 UInt8.ascii.`0`...UInt8.ascii.`9`:  // 0-9
                // Token start — payload deferred to currentNumber().
                return .number
            default:
                throw .unexpectedToken(
                    at: position(at: scanner.position, scanner: scanner),
                    found: .unknown(byte),
                    expected: .value
                )
            }
        }

        @inlinable
        public static func skip(
            value scanner: inout Lexer_Primitives.Lexer.Scanner,
            depth: inout Int,
            limit: Int
        ) throws(Error) {
            skip(whitespace: &scanner)
            guard let byte = scanner.peek() else { return }

            switch byte {
            case UInt8.ascii.quotationMark:          // "
                try skipString(scanner: &scanner)
            case UInt8.ascii.hyphen,                 // -
                 UInt8.ascii.`0`...UInt8.ascii.`9`:  // 0-9
                try skipNumber(scanner: &scanner)
            case UInt8.ascii.n:
                try expectLiteral(scanner: &scanner, [.ascii.n, .ascii.u, .ascii.l, .ascii.l])
            case UInt8.ascii.t:
                try expectLiteral(scanner: &scanner, [.ascii.t, .ascii.r, .ascii.u, .ascii.e])
            case UInt8.ascii.f:
                try expectLiteral(scanner: &scanner, [.ascii.f, .ascii.a, .ascii.l, .ascii.s, .ascii.e])
            case UInt8.ascii.leftBrace,              // {
                 UInt8.ascii.leftBracket:            // [
                try skipContainerBalanced(scanner: &scanner, depth: &depth, limit: limit)
            case UInt8.ascii.rightBrace,             // }
                 UInt8.ascii.rightBracket:           // ]
                try skipContainerBodyBalanced(scanner: &scanner, depth: &depth, limit: limit)
            default:
                throw .unexpectedToken(
                    at: position(at: scanner.position, scanner: scanner),
                    found: .unknown(byte),
                    expected: .value
                )
            }
        }
    }
}

// MARK: - Position helpers

extension RFC_8259.Pull.Tokens {
    @inlinable
    internal static func position(
        at cursor: Text.Position,
        scanner: borrowing Lexer_Primitives.Lexer.Scanner
    ) -> RFC_8259.Position {
        RFC_8259.Position(offset: cursor, location: scanner.location(at: cursor))
    }
}

// MARK: - Literal expect helper

extension RFC_8259.Pull.Tokens {
    @inlinable
    internal static func expectLiteral(
        scanner: inout Lexer_Primitives.Lexer.Scanner,
        _ expected: [UInt8]
    ) throws(Error) {
        let startCursor = scanner.position
        for expectedByte in expected {
            guard let byte = scanner.peek() else {
                throw .unexpectedEndOfInput(
                    at: position(at: scanner.position, scanner: scanner),
                    expected: .value
                )
            }
            guard byte == expectedByte else {
                throw .unexpectedToken(
                    at: position(at: startCursor, scanner: scanner),
                    found: .unknown(byte),
                    expected: .value
                )
            }
            scanner.advance()
        }
    }
}

// MARK: - String skip (no payload decode)

extension RFC_8259.Pull.Tokens {
    @inlinable
    internal static func skipString(
        scanner: inout Lexer_Primitives.Lexer.Scanner
    ) throws(Error) {
        let startCursor = scanner.position
        scanner.advance() // Consume opening `"`.

        while let byte = scanner.peek() {
            switch byte {
            case UInt8.ascii.quotationMark:
                scanner.advance()
                return
            case UInt8.ascii.reverseSlant:
                scanner.advance()
                guard let esc = scanner.peek() else {
                    throw .invalidString(at: position(at: scanner.position, scanner: scanner), reason: .unterminated)
                }
                scanner.advance()
                if esc == UInt8.ascii.u {
                    for _ in 0..<4 {
                        guard let b = scanner.peek(), b.ascii.isHexDigit else {
                            throw .invalidString(at: position(at: scanner.position, scanner: scanner), reason: .invalidUnicodeEscape)
                        }
                        scanner.advance()
                    }
                    // Optional surrogate pair continuation.
                    if scanner.peek() == UInt8.ascii.reverseSlant,
                       scanner.peek(at: .one) == UInt8.ascii.u {
                        scanner.advance() // \
                        scanner.advance() // u
                        for _ in 0..<4 {
                            guard let b = scanner.peek(), b.ascii.isHexDigit else {
                                throw .invalidString(at: position(at: scanner.position, scanner: scanner), reason: .invalidUnicodeEscape)
                            }
                            scanner.advance()
                        }
                    }
                }
            case 0x00...0x1F:
                throw .invalidString(at: position(at: scanner.position, scanner: scanner), reason: .controlCharacter(byte))
            default:
                scanner.advance()
            }
        }

        throw .invalidString(
            at: position(at: startCursor, scanner: scanner),
            reason: .unterminated
        )
    }
}

// MARK: - Number skip (no payload decode)

extension RFC_8259.Pull.Tokens {
    @inlinable
    internal static func skipNumber(
        scanner: inout Lexer_Primitives.Lexer.Scanner
    ) throws(Error) {
        let startCursor = scanner.position

        // Optional minus.
        if scanner.peek() == UInt8.ascii.hyphen {
            scanner.advance()
        }

        // Integer part.
        guard let firstDigit = scanner.peek(), firstDigit.ascii.isDigit else {
            throw .invalidNumber(
                at: position(at: startCursor, scanner: scanner),
                reason: .missingDigits(context: "integer part")
            )
        }
        if firstDigit == UInt8.ascii.`0` {
            scanner.advance()
            if let next = scanner.peek(), next.ascii.isDigit {
                throw .invalidNumber(
                    at: position(at: startCursor, scanner: scanner),
                    reason: .leadingZeros
                )
            }
        } else {
            while let byte = scanner.peek(), byte.ascii.isDigit {
                scanner.advance()
            }
        }

        // Optional fraction.
        if scanner.peek() == UInt8.ascii.period {
            scanner.advance()
            guard let firstFracDigit = scanner.peek(), firstFracDigit.ascii.isDigit else {
                throw .invalidNumber(
                    at: position(at: startCursor, scanner: scanner),
                    reason: .missingDigits(context: "fraction")
                )
            }
            while let byte = scanner.peek(), byte.ascii.isDigit {
                scanner.advance()
            }
        }

        // Optional exponent.
        if let e = scanner.peek(), e == UInt8.ascii.e || e == UInt8.ascii.E {
            scanner.advance()
            if let sign = scanner.peek(), sign == UInt8.ascii.plusSign || sign == UInt8.ascii.hyphen {
                scanner.advance()
            }
            guard let firstExpDigit = scanner.peek(), firstExpDigit.ascii.isDigit else {
                throw .invalidNumber(
                    at: position(at: startCursor, scanner: scanner),
                    reason: .missingDigits(context: "exponent")
                )
            }
            while let byte = scanner.peek(), byte.ascii.isDigit {
                scanner.advance()
            }
        }
    }
}

// MARK: - Container balanced skip

extension RFC_8259.Pull.Tokens {
    @inlinable
    internal static func skipContainerBalanced(
        scanner: inout Lexer_Primitives.Lexer.Scanner,
        depth: inout Int,
        limit: Int
    ) throws(Error) {
        let opener = scanner.peek()!
        let closer: UInt8 = (opener == UInt8.ascii.leftBrace)
            ? UInt8.ascii.rightBrace
            : UInt8.ascii.rightBracket
        scanner.advance() // Consume opener.

        var balance = 1
        let startDepth = depth
        depth &+= 1
        if depth > limit {
            throw .depthExceeded(at: position(at: scanner.position, scanner: scanner), limit: limit)
        }
        defer { depth = startDepth }

        while balance > 0 {
            skip(whitespace: &scanner)
            guard let byte = scanner.peek() else {
                throw .unexpectedEndOfInput(
                    at: position(at: scanner.position, scanner: scanner),
                    expected: (closer == UInt8.ascii.rightBrace) ? .objectEnd : .arrayEnd
                )
            }

            switch byte {
            case UInt8.ascii.quotationMark:
                try skipString(scanner: &scanner)
            case UInt8.ascii.leftBrace, UInt8.ascii.leftBracket:
                let inner = byte
                let innerCloser: UInt8 = (inner == UInt8.ascii.leftBrace)
                    ? UInt8.ascii.rightBrace
                    : UInt8.ascii.rightBracket
                scanner.advance()
                depth &+= 1
                if depth > limit {
                    throw .depthExceeded(at: position(at: scanner.position, scanner: scanner), limit: limit)
                }
                var innerBalance = 1
                while innerBalance > 0 {
                    skip(whitespace: &scanner)
                    guard let ib = scanner.peek() else {
                        throw .unexpectedEndOfInput(
                            at: position(at: scanner.position, scanner: scanner),
                            expected: (innerCloser == UInt8.ascii.rightBrace) ? .objectEnd : .arrayEnd
                        )
                    }
                    if ib == UInt8.ascii.quotationMark {
                        try skipString(scanner: &scanner)
                    } else if ib == inner {
                        scanner.advance()
                        depth &+= 1
                        if depth > limit {
                            throw .depthExceeded(at: position(at: scanner.position, scanner: scanner), limit: limit)
                        }
                        innerBalance &+= 1
                    } else if ib == innerCloser {
                        scanner.advance()
                        depth &-= 1
                        innerBalance &-= 1
                    } else {
                        scanner.advance()
                    }
                }
            case closer:
                scanner.advance()
                balance &-= 1
            default:
                scanner.advance()
            }
        }
    }

    @inlinable
    internal static func skipContainerBodyBalanced(
        scanner: inout Lexer_Primitives.Lexer.Scanner,
        depth: inout Int,
        limit: Int
    ) throws(Error) {
        // Cursor is at a close byte; the enclosing container was opened
        // by a preceding next() call which incremented depth. Walk
        // forward until depth returns to (startDepth - 1).
        let startDepth = depth
        defer { depth = startDepth - 1 }

        while depth >= startDepth {
            skip(whitespace: &scanner)
            guard let byte = scanner.peek() else {
                throw .unexpectedEndOfInput(
                    at: position(at: scanner.position, scanner: scanner),
                    expected: .value
                )
            }
            switch byte {
            case UInt8.ascii.quotationMark:
                try skipString(scanner: &scanner)
            case UInt8.ascii.leftBrace, UInt8.ascii.leftBracket:
                scanner.advance()
                depth &+= 1
                if depth > limit {
                    throw .depthExceeded(at: position(at: scanner.position, scanner: scanner), limit: limit)
                }
            case UInt8.ascii.rightBrace, UInt8.ascii.rightBracket:
                scanner.advance()
                depth &-= 1
            default:
                scanner.advance()
            }
        }
    }
}
