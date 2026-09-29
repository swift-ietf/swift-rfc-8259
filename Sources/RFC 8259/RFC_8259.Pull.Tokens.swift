@_spi(Unsafe) public import Array

extension RFC_8259.Pull {
    public enum Tokens: Lexer::Lexer.Pull.Tokens {}
}

extension RFC_8259.Pull.Tokens {
    public typealias Kind = RFC_8259.Token.Kind
    public typealias Error = RFC_8259.Error
    public typealias Scratch = [UInt8]
}

extension RFC_8259.Pull.Tokens {
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
    public static func skip(whitespace scanner: inout Lexer::Lexer.Scanner) {
        while let byte = scanner.peek() {
            switch byte.bitPattern {
            case 0x20, 0x09, 0x0A, 0x0D:
                scanner.advance()

            default:
                return
            }
        }
    }

    @inlinable
    public static func next(
        scanner: inout Lexer::Lexer.Scanner,
        depth: inout Int,
        limit: Int
    ) throws(Error) -> Kind? {
        skip(whitespace: &scanner)

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
        case .leftBrace:
            scanner.advance()
            depth &+= 1
            if depth > limit {

                throw .depthExceeded(
                    at: position(at: scanner.position, scanner: scanner),
                    limit: limit
                )
            }
            return .objectStart

        case .rightBrace:
            scanner.advance()
            depth &-= 1
            return .objectEnd

        case .leftBracket:
            scanner.advance()
            depth &+= 1
            if depth > limit {

                throw .depthExceeded(
                    at: position(at: scanner.position, scanner: scanner),
                    limit: limit
                )
            }
            return .arrayStart

        case .rightBracket:
            scanner.advance()
            depth &-= 1
            return .arrayEnd

        case .colon:
            scanner.advance()
            return .colon

        case .comma:
            scanner.advance()
            return .comma

        case .quotationMark:

            return .string

        case .n:
            try expectLiteral(scanner: &scanner, [.n, .u, .l, .l])
            return .null

        case .t:
            try expectLiteral(scanner: &scanner, [.t, .r, .u, .e])
            return .`true`

        case .f:
            try expectLiteral(scanner: &scanner, [.f, .a, .l, .s, .e])
            return .`false`

        case .hyphen,
            .`0`...ASCII.Code.`9`:

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
        value scanner: inout Lexer::Lexer.Scanner,
        depth: inout Int,
        limit: Int
    ) throws(Error) {
        skip(whitespace: &scanner)

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
        case .quotationMark:
            try skipString(scanner: &scanner)

        case .hyphen,
            .`0`...ASCII.Code.`9`:
            try skipNumber(scanner: &scanner)

        case .n:
            try expectLiteral(scanner: &scanner, [.n, .u, .l, .l])

        case .t:
            try expectLiteral(scanner: &scanner, [.t, .r, .u, .e])

        case .f:
            try expectLiteral(scanner: &scanner, [.f, .a, .l, .s, .e])

        case .leftBrace,
            .leftBracket:
            try skipContainerBalanced(scanner: &scanner, depth: &depth, limit: limit)

        case .rightBrace,
            .rightBracket:
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

extension RFC_8259.Pull.Tokens {
    @inlinable
    package static func position(
        at cursor: Text.Position,
        scanner: borrowing Lexer::Lexer.Scanner
    ) -> RFC_8259.Position {
        RFC_8259.Position(offset: cursor, location: scanner.location(at: cursor))
    }
}

extension RFC_8259.Pull.Tokens {
    @inlinable
    package static func expectLiteral(
        scanner: inout Lexer::Lexer.Scanner,
        _ expected: [ASCII.Code]
    ) throws(Error) {

        let startCursor = scanner.position
        for expectedCode in expected {
            guard let code = scanner.peek().map(ASCII.Code.init(unchecked:)) else {
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

extension RFC_8259.Pull.Tokens {
    @inlinable
    package static func skipString(
        scanner: inout Lexer::Lexer.Scanner
    ) throws(Error) {

        let startCursor = scanner.position
        scanner.advance()

        while let byte: Byte = scanner.peek() {
            guard byte.underlying < 0x80 else {

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
                guard let esc = scanner.peek().map(ASCII.Code.init(unchecked:)) else {

                    throw .invalidString(
                        at: position(at: scanner.position, scanner: scanner),
                        reason: .unterminated
                    )
                }
                scanner.advance()
                if esc == .u {
                    for _ in 0..<4 {
                        guard let b = scanner.peek().map(ASCII.Code.init(unchecked:)), b.isHexDigit else {

                            throw .invalidString(
                                at: position(at: scanner.position, scanner: scanner),
                                reason: .invalidUnicodeEscape
                            )
                        }
                        scanner.advance()
                    }

                    if let next = scanner.peek().map(ASCII.Code.init(unchecked:)), next == .reverseSlant,
                        let after = scanner.peek(at: .one).map(ASCII.Code.init(unchecked:)), after == .u
                    {
                        scanner.advance()
                        scanner.advance()
                        for _ in 0..<4 {
                            guard let b = scanner.peek().map(ASCII.Code.init(unchecked:)), b.isHexDigit else {

                                throw .invalidString(
                                    at: position(at: scanner.position, scanner: scanner),
                                    reason: .invalidUnicodeEscape
                                )
                            }
                            scanner.advance()
                        }
                    }
                }

            case .nul...ASCII.Code.us:

                throw .invalidString(
                    at: position(at: scanner.position, scanner: scanner),
                    reason: .controlCharacter(code)
                )

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

extension RFC_8259.Pull.Tokens {
    @inlinable
    package static func skipNumber(
        scanner: inout Lexer::Lexer.Scanner
    ) throws(Error) {

        let startCursor = scanner.position

        if let b = scanner.peek().map(ASCII.Code.init(unchecked:)), b == .hyphen {
            scanner.advance()
        }

        guard let firstDigit = scanner.peek().map(ASCII.Code.init(unchecked:)), firstDigit.isDigit else {
            throw .invalidNumber(
                at: position(at: startCursor, scanner: scanner),
                reason: .missingDigits(context: "integer part")
            )
        }
        if firstDigit == .`0` {
            scanner.advance()
            if let next = scanner.peek().map(ASCII.Code.init(unchecked:)), next.isDigit {
                throw .invalidNumber(
                    at: position(at: startCursor, scanner: scanner),
                    reason: .leadingZeros
                )
            }
        } else {
            while let code = scanner.peek().map(ASCII.Code.init(unchecked:)), code.isDigit {
                scanner.advance()
            }
        }

        if let b = scanner.peek().map(ASCII.Code.init(unchecked:)), b == .period {
            scanner.advance()
            guard let firstFracDigit = scanner.peek().map(ASCII.Code.init(unchecked:)), firstFracDigit.isDigit else {
                throw .invalidNumber(
                    at: position(at: startCursor, scanner: scanner),
                    reason: .missingDigits(context: "fraction")
                )
            }
            while let code = scanner.peek().map(ASCII.Code.init(unchecked:)), code.isDigit {
                scanner.advance()
            }
        }

        if let e = scanner.peek().map(ASCII.Code.init(unchecked:)), e == .e || e == .E {
            scanner.advance()
            if let sign = scanner.peek().map(ASCII.Code.init(unchecked:)), sign == .plusSign || sign == .hyphen {
                scanner.advance()
            }
            guard let firstExpDigit = scanner.peek().map(ASCII.Code.init(unchecked:)), firstExpDigit.isDigit else {
                throw .invalidNumber(
                    at: position(at: startCursor, scanner: scanner),
                    reason: .missingDigits(context: "exponent")
                )
            }
            while let code = scanner.peek().map(ASCII.Code.init(unchecked:)), code.isDigit {
                scanner.advance()
            }
        }
    }
}

extension RFC_8259.Pull.Tokens {
    @inlinable
    package static func skipContainerBalanced(
        scanner: inout Lexer::Lexer.Scanner,
        depth: inout Int,
        limit: Int
    ) throws(Error) {
        let opener = scanner.peek().map(ASCII.Code.init(unchecked:))!
        let closer: ASCII.Code = opener == .leftBrace ? .rightBrace : .rightBracket
        scanner.advance()

        var balance = 1
        let startDepth = depth
        depth &+= 1
        if depth > limit {

            throw .depthExceeded(at: position(at: scanner.position, scanner: scanner), limit: limit)
        }
        defer { depth = startDepth }

        while balance > 0 {
            skip(whitespace: &scanner)
            guard let code = scanner.peek().map(ASCII.Code.init(unchecked:)) else {
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

                    throw .depthExceeded(
                        at: position(at: scanner.position, scanner: scanner),
                        limit: limit
                    )
                }
                var innerBalance = 1
                while innerBalance > 0 {
                    skip(whitespace: &scanner)
                    guard let ib = scanner.peek().map(ASCII.Code.init(unchecked:)) else {
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

                            throw .depthExceeded(
                                at: position(at: scanner.position, scanner: scanner),
                                limit: limit
                            )
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
    package static func skipContainerBodyBalanced(
        scanner: inout Lexer::Lexer.Scanner,
        depth: inout Int,
        limit: Int
    ) throws(Error) {

        let startDepth = depth
        defer { depth = startDepth - 1 }

        while depth >= startDepth {
            skip(whitespace: &scanner)
            guard let code = scanner.peek().map(ASCII.Code.init(unchecked:)) else {
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

                    throw .depthExceeded(
                        at: position(at: scanner.position, scanner: scanner),
                        limit: limit
                    )
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
