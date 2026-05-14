/// RFC_8259.Span.EventStream.swift
/// swift-rfc-8259
///
/// Pull-driven event cursor for JSON parsing.
///
/// Phase A1 of the streaming-deserialize work
/// (`swift-institute/Research/streaming-json-deserialize-comparative-analysis.md`).
/// Option B (event-emitting Span parser γ) — the per-token cursor
/// over `Swift.Span<UInt8>` that lets consumers drive a partial-shape
/// decode without materialising a full `RFC_8259.Value` tree.
///
/// Mirrors the System.Text.Json `Utf8JsonReader` shape (forward-only,
/// pull-driven, structural-skip primitive) translated into swift-json's
/// substrate (`~Copyable & ~Escapable`, `@_lifetime` annotated, typed
/// throws). Shares `RFC_8259.Span.Lexer` with `RFC_8259.Span.Parser` —
/// same byte-level cursor, different emission contract.
///
/// ## Token kind storage
///
/// `next()` returns `RFC_8259.Token.Kind` (the payload-free variant)
/// rather than `RFC_8259.Token` (with `String` / `RFC_8259.Number`
/// payloads). The Token-with-payload storage triggered a Swift compiler
/// bug ("copy of noncopyable typed value") in earlier toolchains —
/// see the storage-shape note on `RFC_8259.Span.Parser`. `Token.Kind`
/// carries at most a `UInt8` payload on `.unknown(UInt8)` per
/// `RFC_8259.Token.Kind.swift:23`. The A0 spike `check-token-kind-storage`
/// confirmed this composes cleanly on Swift 6.3.2 (commit `0953628`
/// in `Experiments/streaming-deserialize-a0-feasibility/`).
///
/// String and number payloads are accessed via dedicated
/// `currentString()` / `currentNumber()` methods after `next()` returns
/// `.string` / `.number`, mirroring `Utf8JsonReader.GetString()` /
/// `GetInt32()`.
///
/// ## Lifecycle
///
/// `~Copyable & ~Escapable` per the cursor lifetime contract. The
/// stream's lifetime is bound to the borrowed `Swift.Span<UInt8>` via
/// `@_lifetime(borrow bytes)` at the initialiser; the compiler enforces
/// that the stream cannot escape the scope of its bytes.
///
/// ## Short-circuit detection (§4.3 A0-binding constraint)
///
/// Per `streaming-json-deserialize-comparative-analysis.md` v1.0.1
/// §9.3, the stream MUST expose an `isUnforkedAtPositionZero` property
/// that returns `true` until the first mutating call advances the
/// cursor. This enables `JSON.Assemble.from(_:)` to short-circuit to
/// `RFC_8259.Span.Parser.parse(_:)` on the default-fallback path,
/// avoiding the 4.48× silent-regression risk measured in the A0
/// spike's `check-lifetime-inout-protocol` target.

extension RFC_8259.Span {
    /// Pull-driven event cursor over a contiguous-bytes JSON input.
    ///
    /// Forward-only token-kind sequence; the consumer drives `next()`
    /// and accesses string / number payloads via dedicated methods.
    /// Structural skip via `skipValue()` walks the byte stream without
    /// materialising intermediate values.
    ///
    /// `~Copyable & ~Escapable` per the cursor lifetime contract.
    /// `@safe` documents that the type performs no unsafe operations —
    /// backing storage uses only `Swift.Span<UInt8>`, a stdlib safe type.
    // SAFETY: Safe by construction — backing storage uses only stdlib
    // SAFETY: safe types; `@safe` documents that this type performs no
    // SAFETY: unsafe operations.
    @safe
    public struct EventStream: ~Copyable, ~Escapable {
        @usableFromInline
        internal var lexer: RFC_8259.Span.Lexer

        /// Current nesting depth (0 at top-level, increments on each
        /// `.objectStart` / `.arrayStart`).
        @usableFromInline
        internal var depth: Int

        /// Maximum allowed nesting depth — matches `RFC_8259.Span.Parser`.
        @usableFromInline
        internal let maxDepth: Int

        /// Reusable scratch buffer for `currentString`'s byte
        /// accumulation. Mirrors the `RFC_8259.Span.Parser.stringScratch`
        /// pattern — one owned per stream, `removeAll(keepingCapacity:
        /// true)` between strings amortises allocation.
        @usableFromInline
        internal var stringScratch: [UInt8]

        /// `true` until the first mutating call advances the cursor —
        /// the §4.3 short-circuit detection primitive locked in by
        /// A0 §9.3.
        ///
        /// Init sets `true`; `next()` / `currentString()` /
        /// `currentNumber()` / `skipValue()` each clear it on first
        /// call. `JSON.Assemble.from(_:)` reads this to decide whether
        /// to short-circuit to `RFC_8259.Span.Parser.parse(_:)`.
        @usableFromInline
        internal var isUnforkedAtPositionZeroStorage: Bool

        @inlinable
        @_lifetime(borrow bytes)
        public init(_ bytes: borrowing Swift.Span<UInt8>, maxDepth: Int = 512) {
            self.lexer = RFC_8259.Span.Lexer(bytes)
            self.depth = 0
            self.maxDepth = maxDepth
            var scratch: [UInt8] = []
            scratch.reserveCapacity(64)
            self.stringScratch = scratch
            self.isUnforkedAtPositionZeroStorage = true
        }
    }
}

// MARK: - Short-circuit detection

extension RFC_8259.Span.EventStream {
    /// Whether the stream is at the start of the input with no mutating
    /// calls yet made.
    ///
    /// `true` immediately after `init`; becomes `false` after the first
    /// call to `next()` / `currentString()` / `currentNumber()` /
    /// `skipValue()`. Used by `JSON.Assemble.from(_:)` to short-circuit
    /// to the existing tree-building path when no events have been
    /// consumed.
    ///
    /// Per the streaming-deserialize-comparative-analysis v1.0.1 §9.3:
    /// this primitive is REQUIRED for the §4.3 implementation-side
    /// mitigation of the default-fallback timing regression.
    @inlinable
    public var isUnforkedAtPositionZero: Bool {
        isUnforkedAtPositionZeroStorage
    }

    /// Short-circuit primitive: consume the entire unfork-at-position-0
    /// stream as a single `RFC_8259.Value` via the established Span
    /// parser path. Equivalent to `RFC_8259.Span.Parser.parse(_:)` over
    /// the bytes the stream borrows.
    ///
    /// ## Contract
    ///
    /// Caller MUST verify `isUnforkedAtPositionZero == true` before
    /// invoking this. Calling on a stream that has already advanced
    /// produces undefined behaviour: the parser re-parses from position
    /// 0 regardless of where the stream actually is, returning a value
    /// inconsistent with the caller's expected position. The cursor is
    /// left FULLY ADVANCED (position set to `totalCount`) after the
    /// call; subsequent `next()` / `currentString()` / `currentNumber()`
    /// will return `nil` / throw end-of-input.
    ///
    /// ## Why public, not SPI
    ///
    /// This primitive is internal coupling between `swift-rfc-8259` and
    /// `swift-json`'s `JSON.Assemble.from(_:)` to route the streaming-
    /// deserialize-comparative-analysis v1.0.1 §4.3 default-fallback
    /// short-circuit through the existing tree builder without paying
    /// the event-pull-then-rebuild cost measured at 4.48× in the A0
    /// spike (see `Experiments/streaming-deserialize-a0-feasibility/`).
    ///
    /// The SPI form (`@_spi(StreamingDeserialize)`) was evaluated and
    /// REJECTED at A1: `@_spi` does NOT compose with `@inlinable` at
    /// the cross-module consumer site. Verbatim Swift 6.3.2 compiler
    /// error: *"instance method 'consumeAsParseValue()' cannot be used
    /// in an '@inlinable' function because it is an SPI imported from
    /// 'RFC_8259'"*. The consumer (`JSON.Assemble.from`) MUST be
    /// `@inlinable` to allow the default-fallback short-circuit chain
    /// to inline at every opt-out conformer site; without inlining,
    /// the protocol-dispatch chain adds witness-table overhead and the
    /// 5.3 % noise-floor non-regression measurement at A2 axis (b)
    /// would widen.
    ///
    /// The naming pre-empts misuse: "consume as parse value" makes
    /// clear the cursor is left fully advanced after the call.
    ///
    /// External consumers should NOT need this primitive directly; if
    /// a future consumer thinks they do, they probably want the public
    /// `RFC_8259.parse(_:)` API instead. The primitive exists only
    /// because the §4.3 short-circuit needs a tightly-coupled fast path
    /// between `JSON.Span.EventStream`'s position-0 state and the
    /// existing Span.Parser surface.
    @inlinable
    @_lifetime(self: copy self)
    public mutating func consumeAsParseValue() throws(RFC_8259.Error) -> RFC_8259.Value {
        // We KNOW we're unforked at position 0; consume the whole
        // document via the established Span.Parser path and mark
        // ourselves consumed.
        let value = try RFC_8259.Span.Parser.parse(lexer.bytes, maxDepth: maxDepth)
        isUnforkedAtPositionZeroStorage = false
        lexer.position = lexer.totalCount
        return value
    }

    /// Lazy position for error reporting.
    @inlinable
    @_lifetime(self: copy self)
    public mutating func position() -> RFC_8259.Position {
        lexer.materializedPosition()
    }

    /// Peeks at the next non-whitespace byte without consuming a token.
    ///
    /// Used by container-decoders that need to detect empty-container
    /// cases (`[]` / `{}`) before delegating to a child decoder's
    /// `deserialize(events:)`. The child's `next()` will see the same
    /// byte the peek returned (and will skip the same whitespace again
    /// as a no-op).
    ///
    /// Does NOT clear `isUnforkedAtPositionZero` — peeking is
    /// idempotent and the short-circuit semantics are preserved:
    /// from `Span.Parser`'s perspective, an unconsumed whitespace skip
    /// followed by a `parse()` produces the same result as `parse()`
    /// from position 0.
    ///
    /// Returns `nil` at end of input.
    @inlinable
    @_lifetime(self: copy self)
    public mutating func peekStructural() -> UInt8? {
        skipWhitespace()
        return lexer.peek
    }
}

// MARK: - Entry: next()

extension RFC_8259.Span.EventStream {
    /// Advances past whitespace and returns the next token kind.
    ///
    /// Returns `nil` at end of input (after a complete value has been
    /// emitted) — callers iterating over containers must already be
    /// inside a `.objectStart` / `.arrayStart` to receive structural
    /// follow-up tokens.
    ///
    /// Depth tracking: increments `depth` on `.objectStart` /
    /// `.arrayStart`, decrements on `.objectEnd` / `.arrayEnd`.
    /// Throws `.depthExceeded` if `depth > maxDepth`.
    ///
    /// String / number payloads are NOT decoded here — callers use
    /// `currentString()` / `currentNumber()` to materialise the value
    /// when needed. For literals (`null`, `true`, `false`), this method
    /// validates the full literal byte sequence before returning.
    @inlinable
    @_lifetime(self: copy self)
    public mutating func next() throws(RFC_8259.Error) -> RFC_8259.Token.Kind? {
        isUnforkedAtPositionZeroStorage = false
        skipWhitespace()

        guard let byte = lexer.peek else {
            return nil
        }

        switch byte {
        case UInt8.ascii.leftBrace:              // {
            lexer.advance()
            depth &+= 1
            if depth > maxDepth {
                throw .depthExceeded(at: lexer.materializedPosition(), limit: maxDepth)
            }
            return .objectStart

        case UInt8.ascii.rightBrace:             // }
            lexer.advance()
            depth &-= 1
            return .objectEnd

        case UInt8.ascii.leftBracket:            // [
            lexer.advance()
            depth &+= 1
            if depth > maxDepth {
                throw .depthExceeded(at: lexer.materializedPosition(), limit: maxDepth)
            }
            return .arrayStart

        case UInt8.ascii.rightBracket:           // ]
            lexer.advance()
            depth &-= 1
            return .arrayEnd

        case UInt8.ascii.colon:                  // :
            lexer.advance()
            return .colon

        case UInt8.ascii.comma:                  // ,
            lexer.advance()
            return .comma

        case UInt8.ascii.quotationMark:          // "
            // Token start only — payload deferred to currentString().
            return .string

        case UInt8.ascii.n:                      // n (null)
            try expectLiteral([.ascii.n, .ascii.u, .ascii.l, .ascii.l])
            return .null

        case UInt8.ascii.t:                      // t (true)
            try expectLiteral([.ascii.t, .ascii.r, .ascii.u, .ascii.e])
            return .`true`

        case UInt8.ascii.f:                      // f (false)
            try expectLiteral([.ascii.f, .ascii.a, .ascii.l, .ascii.s, .ascii.e])
            return .`false`

        case UInt8.ascii.hyphen,                 // -
             UInt8.ascii.`0`...UInt8.ascii.`9`:  // 0-9
            // Token start only — payload deferred to currentNumber().
            return .number

        default:
            throw .unexpectedToken(
                at: lexer.materializedPosition(),
                found: .unknown(byte),
                expected: .value
            )
        }
    }
}

// MARK: - String payload

extension RFC_8259.Span.EventStream {
    /// Decodes the string at the current position. Called after
    /// `next()` returned `.string` and BEFORE any subsequent
    /// `next()` / `skipValue()` call.
    ///
    /// Reuses `stringScratch` between calls; amortises allocation
    /// across the whole stream. Returns the decoded `Swift.String`
    /// (UTF-8); handles escape sequences per RFC 8259 §7 including
    /// surrogate pairs.
    @inlinable
    @_lifetime(self: copy self)
    public mutating func currentString() throws(RFC_8259.Error) -> String {
        isUnforkedAtPositionZeroStorage = false
        return try lexStringValue()
    }
}

// MARK: - Number payload

extension RFC_8259.Span.EventStream {
    /// Decodes the number at the current position. Called after
    /// `next()` returned `.number` and BEFORE any subsequent
    /// `next()` / `skipValue()` call.
    @inlinable
    @_lifetime(self: copy self)
    public mutating func currentNumber() throws(RFC_8259.Error) -> RFC_8259.Number {
        isUnforkedAtPositionZeroStorage = false
        return try lexNumberValue()
    }
}

// MARK: - Skip primitive (§4.4)

extension RFC_8259.Span.EventStream {
    /// Skips the value at the current position.
    ///
    /// Called when `next()` returned `.objectStart` / `.arrayStart` /
    /// `.string` / `.number` / `.true` / `.false` / `.null` — i.e.,
    /// after a token has been emitted but not yet consumed. Advances
    /// past the entire value (including all nested containers and
    /// payloads) without materialising intermediate values.
    ///
    /// **NOTE**: skipping is parse-then-discard per §4.4. The byte-walk
    /// cost is paid (so this is O(bytes-in-skipped-value)) but no
    /// allocations are made for strings, numbers, arrays, or objects.
    /// The discarded materialisation work is the wedge the streaming
    /// architecture closes vs the tree-then-extract path.
    ///
    /// For `.objectStart` / `.arrayStart`, the depth counter is already
    /// incremented by the preceding `next()` call. `skipValue()` walks
    /// to the matching close brace / bracket and the depth returns to
    /// its starting value.
    @inlinable
    @_lifetime(self: copy self)
    public mutating func skipValue() throws(RFC_8259.Error) {
        isUnforkedAtPositionZeroStorage = false

        // The preceding `next()` call already advanced past structural
        // open tokens and incremented depth. So we may be inside a
        // container we need to walk to the matching close, OR we may
        // be looking at a literal / string / number that next() hasn't
        // consumed yet.
        //
        // Strategy: detect the situation by checking depth vs the
        // depth we'd be at if we'd consumed the current position. The
        // simplest correct shape: track a target depth and walk forward,
        // counting opens/closes balanced on quoted strings.
        skipWhitespace()
        guard let byte = lexer.peek else {
            return
        }

        switch byte {
        case UInt8.ascii.quotationMark:          // "
            // Skip a string (we haven't consumed it; we're at the
            // opening quote).
            try skipStringValue()

        case UInt8.ascii.hyphen,                 // -
             UInt8.ascii.`0`...UInt8.ascii.`9`:  // 0-9
            // Skip a number — same lex as currentNumber but discard.
            _ = try lexNumberValue()

        case UInt8.ascii.n:                      // n
            try expectLiteral([.ascii.n, .ascii.u, .ascii.l, .ascii.l])

        case UInt8.ascii.t:                      // t
            try expectLiteral([.ascii.t, .ascii.r, .ascii.u, .ascii.e])

        case UInt8.ascii.f:                      // f
            try expectLiteral([.ascii.f, .ascii.a, .ascii.l, .ascii.s, .ascii.e])

        case UInt8.ascii.leftBrace,              // {
             UInt8.ascii.leftBracket:            // [
            // We're at an unconsumed opener — walk forward balancing.
            try skipContainerBalanced()

        case UInt8.ascii.rightBrace,             // }
             UInt8.ascii.rightBracket:           // ]
            // We're inside an already-opened container. next() returned
            // .objectStart / .arrayStart for us and incremented depth;
            // skipValue here means "skip this entire container body to
            // the matching close." Balance.
            try skipContainerBodyBalanced()

        default:
            throw .unexpectedToken(
                at: lexer.materializedPosition(),
                found: .unknown(byte),
                expected: .value
            )
        }
    }

    /// Helper: skip a string at the current position (cursor at opening
    /// quote), without materialising the decoded value. Walks the byte
    /// stream handling escape sequences.
    @inlinable
    @_lifetime(self: copy self)
    internal mutating func skipStringValue() throws(RFC_8259.Error) {
        let startOffset = lexer.position
        lexer.advance() // Consume opening `"`.

        while let byte = lexer.peek {
            switch byte {
            case UInt8.ascii.quotationMark:      // " - closing quote
                lexer.advance()
                return

            case UInt8.ascii.reverseSlant:       // \ - escape sequence
                lexer.advance()
                // Skip the escape character; for \uXXXX, skip the 4
                // hex bytes plus any surrogate continuation.
                guard let esc = lexer.peek else {
                    throw .invalidString(at: lexer.materializedPosition(), reason: .unterminated)
                }
                lexer.advance()
                if esc == UInt8.ascii.u {
                    // Skip 4 hex digits.
                    for _ in 0..<4 {
                        guard let b = lexer.peek, b.ascii.isHexDigit else {
                            throw .invalidString(at: lexer.materializedPosition(), reason: .invalidUnicodeEscape)
                        }
                        lexer.advance()
                    }
                    // Optional surrogate pair continuation.
                    if lexer.peek == UInt8.ascii.reverseSlant,
                       lexer.peek(offset: 1) == UInt8.ascii.u {
                        lexer.advance() // \
                        lexer.advance() // u
                        for _ in 0..<4 {
                            guard let b = lexer.peek, b.ascii.isHexDigit else {
                                throw .invalidString(at: lexer.materializedPosition(), reason: .invalidUnicodeEscape)
                            }
                            lexer.advance()
                        }
                    }
                }

            case 0x00...0x1F:                    // Control characters
                throw .invalidString(at: lexer.materializedPosition(), reason: .controlCharacter(byte))

            default:
                lexer.advance()
            }
        }

        // EOF before closing quote.
        let startPos = lexer.positionAt(byteOffset: startOffset)
        throw .invalidString(at: startPos, reason: .unterminated)
    }

    /// Skips a container at the current position (cursor at `{` or `[`).
    /// Walks balanced.
    @inlinable
    @_lifetime(self: copy self)
    internal mutating func skipContainerBalanced() throws(RFC_8259.Error) {
        let opener = lexer.peek!
        let closer: UInt8 =
            (opener == UInt8.ascii.leftBrace) ? UInt8.ascii.rightBrace : UInt8.ascii.rightBracket
        lexer.advance() // Consume the opener.

        var balance = 1
        let startDepth = depth
        depth &+= 1
        if depth > maxDepth {
            throw .depthExceeded(at: lexer.materializedPosition(), limit: maxDepth)
        }
        defer { depth = startDepth }

        while balance > 0 {
            skipWhitespace()
            guard let byte = lexer.peek else {
                throw .unexpectedEndOfInput(
                    at: lexer.materializedPosition(),
                    expected: (closer == UInt8.ascii.rightBrace) ? .objectEnd : .arrayEnd
                )
            }

            switch byte {
            case UInt8.ascii.quotationMark:      // string
                try skipStringValue()

            case UInt8.ascii.leftBrace, UInt8.ascii.leftBracket:
                lexer.advance()
                balance &+= 1
                depth &+= 1
                if depth > maxDepth {
                    throw .depthExceeded(at: lexer.materializedPosition(), limit: maxDepth)
                }

            case UInt8.ascii.rightBrace, UInt8.ascii.rightBracket:
                lexer.advance()
                balance &-= 1
                depth &-= 1

            default:
                lexer.advance()
            }
        }
    }

    /// Skips a container body when `next()` already consumed the
    /// opener. Walks forward until the matching close at the current
    /// depth level.
    @inlinable
    @_lifetime(self: copy self)
    internal mutating func skipContainerBodyBalanced() throws(RFC_8259.Error) {
        // The current depth reflects that we're inside a container
        // (the opener already incremented it). Walk forward until
        // we see the close brace/bracket that returns depth to one
        // less than current.
        let targetDepth = depth - 1

        while depth > targetDepth {
            skipWhitespace()
            guard let byte = lexer.peek else {
                throw .unexpectedEndOfInput(
                    at: lexer.materializedPosition(),
                    expected: .commaOrEnd
                )
            }

            switch byte {
            case UInt8.ascii.quotationMark:      // string
                try skipStringValue()

            case UInt8.ascii.leftBrace, UInt8.ascii.leftBracket:
                lexer.advance()
                depth &+= 1
                if depth > maxDepth {
                    throw .depthExceeded(at: lexer.materializedPosition(), limit: maxDepth)
                }

            case UInt8.ascii.rightBrace, UInt8.ascii.rightBracket:
                lexer.advance()
                depth &-= 1

            default:
                lexer.advance()
            }
        }
    }
}

// MARK: - Whitespace (shared style with Span.Parser)

extension RFC_8259.Span.EventStream {
    /// Inline whitespace skip — same branchless four-way check as
    /// `RFC_8259.Span.Parser.skipWhitespace` per the post-A1 profile.
    @inlinable
    @_lifetime(self: copy self)
    internal mutating func skipWhitespace() {
        while let byte = lexer.peek {
            if byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D {
                lexer.advance()
            } else {
                return
            }
        }
    }
}

// MARK: - Literal expect helper

extension RFC_8259.Span.EventStream {
    /// Expects an exact byte sequence at the cursor (e.g., `null`).
    @inlinable
    @_lifetime(self: copy self)
    internal mutating func expectLiteral(_ expected: [UInt8]) throws(RFC_8259.Error) {
        let startOffset = lexer.position
        for expectedByte in expected {
            guard let byte = lexer.peek else {
                throw .unexpectedEndOfInput(
                    at: lexer.positionAt(byteOffset: lexer.position),
                    expected: .value
                )
            }
            guard byte == expectedByte else {
                throw .unexpectedToken(
                    at: lexer.positionAt(byteOffset: startOffset),
                    found: .unknown(byte),
                    expected: .value
                )
            }
            lexer.advance()
        }
    }
}

// MARK: - String lexing (mirrors Span.Parser.lexStringValue)

extension RFC_8259.Span.EventStream {
    /// Lexes a JSON string at the current position. Mirrors
    /// `RFC_8259.Span.Parser.lexStringValue` — cursor at opening quote,
    /// returns the decoded `String`, reuses `stringScratch`.
    @inlinable
    @_lifetime(self: copy self)
    internal mutating func lexStringValue() throws(RFC_8259.Error) -> String {
        let startOffset = lexer.position

        lexer.advance() // Consume opening `"`.

        stringScratch.removeAll(keepingCapacity: true)
        var isASCII = true

        while let byte = lexer.peek {
            switch byte {
            case UInt8.ascii.quotationMark:      // " - closing quote
                lexer.advance()
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
                lexer.advance()
                let escapeBytes = try lexEscapeSequence()
                for b in escapeBytes {
                    if b > 0x7F { isASCII = false }
                    stringScratch.append(b)
                }

            case 0x00...0x1F:                    // Control characters (C0 range)
                throw .invalidString(at: lexer.materializedPosition(), reason: .controlCharacter(byte))

            default:
                if byte > 0x7F { isASCII = false }
                stringScratch.append(byte)
                lexer.advance()
            }
        }

        let startPos = lexer.positionAt(byteOffset: startOffset)
        throw .invalidString(at: startPos, reason: .unterminated)
    }

    /// Lexes an escape sequence after the backslash.
    @inlinable
    @_lifetime(self: copy self)
    internal mutating func lexEscapeSequence() throws(RFC_8259.Error) -> [UInt8] {
        guard let byte = lexer.peek else {
            throw .unexpectedEndOfInput(at: lexer.materializedPosition(), expected: .value)
        }

        lexer.advance()

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
            throw .invalidString(at: lexer.materializedPosition(), reason: .invalidEscape(byte))
        }
    }

    /// Lexes a \uXXXX Unicode escape, including surrogate pairs.
    @inlinable
    @_lifetime(self: copy self)
    internal mutating func lexUnicodeEscape() throws(RFC_8259.Error) -> [UInt8] {
        var hex: [UInt8] = []
        hex.reserveCapacity(4)

        for _ in 0..<4 {
            guard let byte = lexer.peek else {
                throw .invalidString(at: lexer.materializedPosition(), reason: .invalidUnicodeEscape)
            }
            guard byte.ascii.isHexDigit else {
                throw .invalidString(at: lexer.materializedPosition(), reason: .invalidUnicodeEscape)
            }
            hex.append(byte)
            lexer.advance()
        }

        guard let codePoint = parseHex(hex) else {
            throw .invalidString(at: lexer.materializedPosition(), reason: .invalidUnicodeEscape)
        }

        // Handle surrogate pairs.
        if codePoint >= 0xD800 && codePoint <= 0xDBFF {
            guard lexer.peek == UInt8.ascii.reverseSlant else {
                throw .invalidString(at: lexer.materializedPosition(), reason: .invalidUnicodeEscape)
            }
            lexer.advance()
            guard lexer.peek == UInt8.ascii.u else {
                throw .invalidString(at: lexer.materializedPosition(), reason: .invalidUnicodeEscape)
            }
            lexer.advance()

            var lowHex: [UInt8] = []
            lowHex.reserveCapacity(4)
            for _ in 0..<4 {
                guard let byte = lexer.peek, byte.ascii.isHexDigit else {
                    throw .invalidString(at: lexer.materializedPosition(), reason: .invalidUnicodeEscape)
                }
                lowHex.append(byte)
                lexer.advance()
            }

            guard let lowCodePoint = parseHex(lowHex),
                  lowCodePoint >= 0xDC00 && lowCodePoint <= 0xDFFF else {
                throw .invalidString(at: lexer.materializedPosition(), reason: .invalidUnicodeEscape)
            }

            let combined = 0x10000 + ((codePoint - 0xD800) << 10) + (lowCodePoint - 0xDC00)
            guard let combinedScalar = Unicode.Scalar(combined) else {
                throw .invalidString(at: lexer.materializedPosition(), reason: .invalidUnicodeEscape)
            }
            return Swift.Array(String(combinedScalar).utf8)
        }

        guard let scalar = Unicode.Scalar(codePoint) else {
            throw .invalidString(at: lexer.materializedPosition(), reason: .invalidUnicodeEscape)
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

// MARK: - Number lexing (mirrors Span.Parser.lexNumberValue)

extension RFC_8259.Span.EventStream {
    /// Lexes a JSON number at the current position. Mirrors
    /// `RFC_8259.Span.Parser.lexNumberValue`. Returns the decoded
    /// `RFC_8259.Number` with original-byte preservation.
    @inlinable
    @_lifetime(self: copy self)
    internal mutating func lexNumberValue() throws(RFC_8259.Error) -> RFC_8259.Number {
        let startOffset = lexer.position
        var bytes: [UInt8] = []
        bytes.reserveCapacity(24)

        // Optional minus
        if lexer.peek == UInt8.ascii.hyphen {
            bytes.append(lexer.advance())
        }

        // Integer part
        guard let firstDigit = lexer.peek, firstDigit.ascii.isDigit else {
            throw .invalidNumber(at: lexer.positionAt(byteOffset: startOffset), reason: .missingDigits(context: "integer part"))
        }

        if firstDigit == UInt8.ascii.`0` { // Leading zero
            bytes.append(lexer.advance())

            if let next = lexer.peek, next.ascii.isDigit {
                throw .invalidNumber(at: lexer.positionAt(byteOffset: startOffset), reason: .leadingZeros)
            }
        } else {
            while let byte = lexer.peek, byte.ascii.isDigit {
                bytes.append(lexer.advance())
            }
        }

        var isFloat = false

        // Optional fraction
        if lexer.peek == UInt8.ascii.period {
            isFloat = true
            bytes.append(lexer.advance())

            guard let firstFracDigit = lexer.peek, firstFracDigit.ascii.isDigit else {
                throw .invalidNumber(at: lexer.positionAt(byteOffset: startOffset), reason: .missingDigits(context: "fraction"))
            }

            while let byte = lexer.peek, byte.ascii.isDigit {
                bytes.append(lexer.advance())
            }
        }

        // Optional exponent
        if let e = lexer.peek, e == UInt8.ascii.e || e == UInt8.ascii.E {
            isFloat = true
            bytes.append(lexer.advance())

            if let sign = lexer.peek, sign == UInt8.ascii.plusSign || sign == UInt8.ascii.hyphen {
                bytes.append(lexer.advance())
            }

            guard let firstExpDigit = lexer.peek, firstExpDigit.ascii.isDigit else {
                throw .invalidNumber(at: lexer.positionAt(byteOffset: startOffset), reason: .missingDigits(context: "exponent"))
            }

            while let byte = lexer.peek, byte.ascii.isDigit {
                bytes.append(lexer.advance())
            }
        }

        let original = RFC_8259.Number.Original(bytes)
        let numStr = String(decoding: bytes, as: UTF8.self)

        if isFloat {
            guard let value = Double(numStr), value.isFinite else {
                throw .invalidNumber(at: lexer.positionAt(byteOffset: startOffset), reason: .overflow)
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
                throw .invalidNumber(at: lexer.positionAt(byteOffset: startOffset), reason: .overflow)
            }
        }
    }
}
