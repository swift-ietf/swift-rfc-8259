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
            // Peek the RAW byte. A byte >= 0x80 is a real (unexpected) token,
            // NOT end-of-input — the typed `peek<ASCII.Code>` overload collapses
            // both EOF and >= 0x80 to nil, which would mis-report a non-ASCII
            // byte as EOF. Lift to ASCII.Code only for the structural dispatch
            // (JSON value-starts are strict ASCII); a non-ASCII byte falls to
            // the unknown-token case carrying the raw Byte ([API-BYTE-004]).
            guard let byte: Byte = scanner.peek() else { return nil }
            guard byte.underlying < 0x80 else {
                throw .unexpectedToken(
                    at: position(at: scanner.position, scanner: scanner),
                    found: .unknown(byte),
                    expected: .value
                )
            }
            let code = ASCII.Code(unchecked: byte)

            switch code {
            case .leftBrace:  // {
                scanner.advance()
                depth &+= 1
                if depth > limit {
                    throw .depthExceeded(at: position(at: scanner.position, scanner: scanner), limit: limit)
                }
                return .objectStart
            case .rightBrace:  // }
                scanner.advance()
                depth &-= 1
                return .objectEnd
            case .leftBracket:  // [
                scanner.advance()
                depth &+= 1
                if depth > limit {
                    throw .depthExceeded(at: position(at: scanner.position, scanner: scanner), limit: limit)
                }
                return .arrayStart
            case .rightBracket:  // ]
                scanner.advance()
                depth &-= 1
                return .arrayEnd
            case .colon:  // :
                scanner.advance()
                return .colon
            case .comma:  // ,
                scanner.advance()
                return .comma
            case .quotationMark:  // "
                // Token start — payload deferred to currentString().
                return .string
            case .n:  // null
                try expectLiteral(scanner: &scanner, [.n, .u, .l, .l])
                return .null
            case .t:  // true
                try expectLiteral(scanner: &scanner, [.t, .r, .u, .e])
                return .`true`
            case .f:  // false
                try expectLiteral(scanner: &scanner, [.f, .a, .l, .s, .e])
                return .`false`
            case .hyphen,  // -
                .`0`...ASCII.Code.`9`:  // 0-9
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
            // Peek the RAW byte (see `next` above): distinguish genuine EOF from
            // a non-ASCII byte. A byte >= 0x80 is an unexpected token, not end-
            // of-input; lift to ASCII.Code only for the structural dispatch.
            guard let byte: Byte = scanner.peek() else { return }
            guard byte.underlying < 0x80 else {
                throw .unexpectedToken(
                    at: position(at: scanner.position, scanner: scanner),
                    found: .unknown(byte),
                    expected: .value
                )
            }
            let code = ASCII.Code(unchecked: byte)

            switch code {
            case .quotationMark:  // "
                try skipString(scanner: &scanner)
            case .hyphen,  // -
                .`0`...ASCII.Code.`9`:  // 0-9
                try skipNumber(scanner: &scanner)
            case .n:
                try expectLiteral(scanner: &scanner, [.n, .u, .l, .l])
            case .t:
                try expectLiteral(scanner: &scanner, [.t, .r, .u, .e])
            case .f:
                try expectLiteral(scanner: &scanner, [.f, .a, .l, .s, .e])
            case .leftBrace,  // {
                .leftBracket:  // [
                try skipContainerBalanced(scanner: &scanner, depth: &depth, limit: limit)
            case .rightBrace,  // }
                .rightBracket:  // ]
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
        _ expected: [ASCII.Code]
    ) throws(Error) {
        let startCursor = scanner.position
        for expectedCode in expected {
            guard let code: ASCII.Code = scanner.peek() else {
                throw .unexpectedEndOfInput(
                    at: position(at: scanner.position, scanner: scanner),
                    expected: .value
                )
            }
            guard code == expectedCode else {
                throw .unexpectedToken(
                    at: position(at: startCursor, scanner: scanner),
                    found: .unknown(code.byte),
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
        scanner.advance()  // Consume opening `"`.

        while let byte: Byte = scanner.peek() {
            guard byte.underlying < 0x80 else {
                // Multi-byte UTF-8 content byte (>= 0x80) — skip it. The typed
                // peek used previously exited the loop on the first such byte,
                // mis-reporting any string with non-ASCII content as
                // unterminated. ([API-BYTE-004])
                scanner.advance()
                continue
            }
            let code = ASCII.Code(unchecked: byte)
            switch code {
            case .quotationMark:
                scanner.advance()
                return
            case .reverseSlant:
                scanner.advance()
                guard let esc: ASCII.Code = scanner.peek() else {
                    throw .invalidString(at: position(at: scanner.position, scanner: scanner), reason: .unterminated)
                }
                scanner.advance()
                if esc == .u {
                    for _ in 0..<4 {
                        guard let b: ASCII.Code = scanner.peek(), b.isHexDigit else {
                            throw .invalidString(at: position(at: scanner.position, scanner: scanner), reason: .invalidUnicodeEscape)
                        }
                        scanner.advance()
                    }
                    // Optional surrogate pair continuation.
                    if let next: ASCII.Code = scanner.peek(), next == .reverseSlant,
                        let after: ASCII.Code = scanner.peek(at: .one), after == .u
                    {
                        scanner.advance()  // \
                        scanner.advance()  // u
                        for _ in 0..<4 {
                            guard let b: ASCII.Code = scanner.peek(), b.isHexDigit else {
                                throw .invalidString(at: position(at: scanner.position, scanner: scanner), reason: .invalidUnicodeEscape)
                            }
                            scanner.advance()
                        }
                    }
                }
            case .nul...ASCII.Code.us:  // 0x00...0x1F (per ASCII.Code Control range)
                throw .invalidString(at: position(at: scanner.position, scanner: scanner), reason: .controlCharacter(code))
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
        if let b: ASCII.Code = scanner.peek(), b == .hyphen {
            scanner.advance()
        }

        // Integer part.
        guard let firstDigit: ASCII.Code = scanner.peek(), firstDigit.isDigit else {
            throw .invalidNumber(
                at: position(at: startCursor, scanner: scanner),
                reason: .missingDigits(context: "integer part")
            )
        }
        if firstDigit == .`0` {
            scanner.advance()
            if let next: ASCII.Code = scanner.peek(), next.isDigit {
                throw .invalidNumber(
                    at: position(at: startCursor, scanner: scanner),
                    reason: .leadingZeros
                )
            }
        } else {
            while let code: ASCII.Code = scanner.peek(), code.isDigit {
                scanner.advance()
            }
        }

        // Optional fraction.
        if let b: ASCII.Code = scanner.peek(), b == .period {
            scanner.advance()
            guard let firstFracDigit: ASCII.Code = scanner.peek(), firstFracDigit.isDigit else {
                throw .invalidNumber(
                    at: position(at: startCursor, scanner: scanner),
                    reason: .missingDigits(context: "fraction")
                )
            }
            while let code: ASCII.Code = scanner.peek(), code.isDigit {
                scanner.advance()
            }
        }

        // Optional exponent.
        if let e: ASCII.Code = scanner.peek(), e == .e || e == .E {
            scanner.advance()
            if let sign: ASCII.Code = scanner.peek(), sign == .plusSign || sign == .hyphen {
                scanner.advance()
            }
            guard let firstExpDigit: ASCII.Code = scanner.peek(), firstExpDigit.isDigit else {
                throw .invalidNumber(
                    at: position(at: startCursor, scanner: scanner),
                    reason: .missingDigits(context: "exponent")
                )
            }
            while let code: ASCII.Code = scanner.peek(), code.isDigit {
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
        let opener: ASCII.Code = scanner.peek()!
        let closer: ASCII.Code = opener == .leftBrace ? .rightBrace : .rightBracket
        scanner.advance()  // Consume opener.

        var balance = 1
        let startDepth = depth
        depth &+= 1
        if depth > limit {
            throw .depthExceeded(at: position(at: scanner.position, scanner: scanner), limit: limit)
        }
        defer { depth = startDepth }

        while balance > 0 {
            skip(whitespace: &scanner)
            guard let code: ASCII.Code = scanner.peek() else {
                throw .unexpectedEndOfInput(
                    at: position(at: scanner.position, scanner: scanner),
                    expected: closer == .rightBrace ? .objectEnd : .arrayEnd
                )
            }

            switch code {
            case .quotationMark:
                try skipString(scanner: &scanner)
            case .leftBrace, .leftBracket:
                let inner = code
                let innerCloser: ASCII.Code = inner == .leftBrace ? .rightBrace : .rightBracket
                scanner.advance()
                depth &+= 1
                if depth > limit {
                    throw .depthExceeded(at: position(at: scanner.position, scanner: scanner), limit: limit)
                }
                var innerBalance = 1
                while innerBalance > 0 {
                    skip(whitespace: &scanner)
                    guard let ib: ASCII.Code = scanner.peek() else {
                        throw .unexpectedEndOfInput(
                            at: position(at: scanner.position, scanner: scanner),
                            expected: innerCloser == .rightBrace ? .objectEnd : .arrayEnd
                        )
                    }
                    if ib == .quotationMark {
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
            guard let code: ASCII.Code = scanner.peek() else {
                throw .unexpectedEndOfInput(
                    at: position(at: scanner.position, scanner: scanner),
                    expected: .value
                )
            }
            switch code {
            case .quotationMark:
                try skipString(scanner: &scanner)
            case .leftBrace, .leftBracket:
                scanner.advance()
                depth &+= 1
                if depth > limit {
                    throw .depthExceeded(at: position(at: scanner.position, scanner: scanner), limit: limit)
                }
            case .rightBrace, .rightBracket:
                scanner.advance()
                depth &-= 1
            default:
                scanner.advance()
            }
        }
    }
}
