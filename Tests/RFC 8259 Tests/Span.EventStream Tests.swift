/// Span.EventStream Tests.swift
/// swift-rfc-8259
///
/// Tests for `RFC_8259.Span.EventStream` — the pull-driven event
/// cursor introduced by Phase A1 of the streaming-deserialize arc
/// (`swift-institute/Research/streaming-json-deserialize-comparative-analysis.md`
/// v1.0.1, Option B / pattern γ).
///
/// Coverage:
/// - All 11 non-payload `Token.Kind` cases emit correctly via `next()`
/// - `currentString()` / `currentNumber()` decode payloads in order
/// - `isPristine` state transitions correctly
/// - `skipValue()` walks balanced across nested containers
/// - Surrogate-pair handling, escape sequences, depth tracking
/// - Malformed inputs throw `RFC_8259.Error` appropriately

import Testing
@testable import RFC_8259

@Suite("Span.EventStream Tests")
struct SpanEventStreamTests {

    // MARK: - Token.Kind emission

    @Test
    func `next emits objectStart and objectEnd for empty object`() throws {
        let bytes: [UInt8] = Swift.Array("{}".utf8)
        try bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) throws(RFC_8259.Error) in
            let span = buf.span
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            #expect(try stream.next() == .objectStart)
            #expect(try stream.next() == .objectEnd)
            #expect(try stream.next() == nil)
        }
    }

    @Test
    func `next emits arrayStart and arrayEnd for empty array`() throws {
        let bytes: [UInt8] = Swift.Array("[]".utf8)
        try bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) throws(RFC_8259.Error) in
            let span = buf.span
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            #expect(try stream.next() == .arrayStart)
            #expect(try stream.next() == .arrayEnd)
            #expect(try stream.next() == nil)
        }
    }

    @Test
    func `next emits comma colon string number sequence`() throws {
        let bytes: [UInt8] = Swift.Array(#"{"a":1,"b":2}"#.utf8)
        try bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) throws(RFC_8259.Error) in
            let span = buf.span
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            #expect(try stream.next() == .objectStart)
            #expect(try stream.next() == .string)
            #expect(try stream.currentString() == "a")
            #expect(try stream.next() == .colon)
            #expect(try stream.next() == .number)
            #expect(try stream.currentNumber().int64 == 1)
            #expect(try stream.next() == .comma)
            #expect(try stream.next() == .string)
            #expect(try stream.currentString() == "b")
            #expect(try stream.next() == .colon)
            #expect(try stream.next() == .number)
            #expect(try stream.currentNumber().int64 == 2)
            #expect(try stream.next() == .objectEnd)
        }
    }

    @Test
    func `next emits null`() throws {
        let bytes: [UInt8] = Swift.Array("null".utf8)
        try bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) throws(RFC_8259.Error) in
            let span = buf.span
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            #expect(try stream.next() == .null)
            #expect(try stream.next() == nil)
        }
    }

    @Test
    func `next emits true`() throws {
        let bytes: [UInt8] = Swift.Array("true".utf8)
        try bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) throws(RFC_8259.Error) in
            let span = buf.span
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            #expect(try stream.next() == .`true`)
        }
    }

    @Test
    func `next emits false`() throws {
        let bytes: [UInt8] = Swift.Array("false".utf8)
        try bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) throws(RFC_8259.Error) in
            let span = buf.span
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            #expect(try stream.next() == .`false`)
        }
    }

    // MARK: - currentString

    @Test
    func `currentString decodes ASCII payload`() throws {
        let bytes: [UInt8] = Swift.Array(#""hello""#.utf8)
        try bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) throws(RFC_8259.Error) in
            let span = buf.span
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            #expect(try stream.next() == .string)
            #expect(try stream.currentString() == "hello")
        }
    }

    @Test
    func `currentString decodes escape sequences`() throws {
        let bytes: [UInt8] = Swift.Array(#""a\nb\tc\"d""#.utf8)
        try bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) throws(RFC_8259.Error) in
            let span = buf.span
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            #expect(try stream.next() == .string)
            #expect(try stream.currentString() == "a\nb\tc\"d")
        }
    }

    @Test
    func `currentString decodes unicode escape`() throws {
        let bytes: [UInt8] = Swift.Array(#""é""#.utf8) // é
        try bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) throws(RFC_8259.Error) in
            let span = buf.span
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            #expect(try stream.next() == .string)
            #expect(try stream.currentString() == "é")
        }
    }

    @Test
    func `currentString decodes surrogate pair`() throws {
        // U+1F600 (😀) encoded as surrogate pair 😀
        let bytes: [UInt8] = Swift.Array(#""😀""#.utf8)
        try bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) throws(RFC_8259.Error) in
            let span = buf.span
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            #expect(try stream.next() == .string)
            #expect(try stream.currentString() == "😀")
        }
    }

    // MARK: - currentNumber

    @Test
    func `currentNumber decodes integer`() throws {
        let bytes: [UInt8] = Swift.Array("42".utf8)
        try bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) throws(RFC_8259.Error) in
            let span = buf.span
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            #expect(try stream.next() == .number)
            #expect(try stream.currentNumber().int64 == 42)
        }
    }

    @Test
    func `currentNumber decodes negative integer`() throws {
        let bytes: [UInt8] = Swift.Array("-123".utf8)
        try bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) throws(RFC_8259.Error) in
            let span = buf.span
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            #expect(try stream.next() == .number)
            #expect(try stream.currentNumber().int64 == -123)
        }
    }

    @Test
    func `currentNumber decodes floating point`() throws {
        let bytes: [UInt8] = Swift.Array("3.14".utf8)
        try bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) throws(RFC_8259.Error) in
            let span = buf.span
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            #expect(try stream.next() == .number)
            #expect(try stream.currentNumber().double == 3.14)
        }
    }

    @Test
    func `currentNumber decodes scientific notation`() throws {
        let bytes: [UInt8] = Swift.Array("1.5e10".utf8)
        try bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) throws(RFC_8259.Error) in
            let span = buf.span
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            #expect(try stream.next() == .number)
            #expect(try stream.currentNumber().double == 1.5e10)
        }
    }

    // MARK: - isPristine

    @Test
    func `isPristine true at init`() throws {
        let bytes: [UInt8] = Swift.Array(#"{"a":1}"#.utf8)
        bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) in
            let span = buf.span
            let stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            #expect(stream.isPristine == true)
        }
    }

    @Test
    func `isPristine false after next`() throws {
        let bytes: [UInt8] = Swift.Array(#"{"a":1}"#.utf8)
        try bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) throws(RFC_8259.Error) in
            let span = buf.span
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            #expect(stream.isPristine == true)
            _ = try stream.next()
            #expect(stream.isPristine == false)
        }
    }

    @Test
    func `isPristine false after skipValue`() throws {
        let bytes: [UInt8] = Swift.Array(#"{"a":1}"#.utf8)
        try bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) throws(RFC_8259.Error) in
            let span = buf.span
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            #expect(stream.isPristine == true)
            try stream.skip()
            #expect(stream.isPristine == false)
        }
    }

    // MARK: - skipValue

    @Test
    func `skipValue skips a string`() throws {
        let bytes: [UInt8] = Swift.Array(#""skip me",42"#.utf8)
        try bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) throws(RFC_8259.Error) in
            let span = buf.span
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            try stream.skip()
            #expect(try stream.next() == .comma)
            #expect(try stream.next() == .number)
            #expect(try stream.currentNumber().int64 == 42)
        }
    }

    @Test
    func `skipValue skips a number`() throws {
        let bytes: [UInt8] = Swift.Array(#"3.14,"after""#.utf8)
        try bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) throws(RFC_8259.Error) in
            let span = buf.span
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            try stream.skip()
            #expect(try stream.next() == .comma)
            #expect(try stream.next() == .string)
            #expect(try stream.currentString() == "after")
        }
    }

    @Test
    func `skipValue skips a literal`() throws {
        let bytes: [UInt8] = Swift.Array(#"null,true,false,42"#.utf8)
        try bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) throws(RFC_8259.Error) in
            let span = buf.span
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            try stream.skip() // null
            #expect(try stream.next() == .comma)
            try stream.skip() // true
            #expect(try stream.next() == .comma)
            try stream.skip() // false
            #expect(try stream.next() == .comma)
            #expect(try stream.next() == .number)
            #expect(try stream.currentNumber().int64 == 42)
        }
    }

    @Test
    func `skipValue skips a nested object`() throws {
        let bytes: [UInt8] = Swift.Array(#"{"nested":{"a":1,"b":[1,2,3]}},42"#.utf8)
        try bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) throws(RFC_8259.Error) in
            let span = buf.span
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            try stream.skip() // skips the whole {...}
            #expect(try stream.next() == .comma)
            #expect(try stream.next() == .number)
            #expect(try stream.currentNumber().int64 == 42)
        }
    }

    @Test
    func `skipValue inside object skips remaining members`() throws {
        // After consuming objectStart, skipValue should walk to the
        // matching objectEnd.
        let bytes: [UInt8] = Swift.Array(#"{"a":1,"b":2,"c":3},42"#.utf8)
        try bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) throws(RFC_8259.Error) in
            let span = buf.span
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            #expect(try stream.next() == .objectStart)
            // Read first key/value pair.
            #expect(try stream.next() == .string)
            #expect(try stream.currentString() == "a")
            #expect(try stream.next() == .colon)
            #expect(try stream.next() == .number)
            #expect(try stream.currentNumber().int64 == 1)
            // Now skip the rest of the object (",b:2,c:3}").
            #expect(try stream.next() == .comma)
            // Skip the rest of the object by walking key/skip-value pairs is
            // not what we test here; we test that skipValue can consume the
            // remaining {b:2,c:3} once we've returned to seeing the
            // brace's CLOSE position. Practical use case: after the
            // wedge schema reads its declared fields, it can call
            // skipValue() repeatedly on values it doesn't want.
            #expect(try stream.next() == .string)
            #expect(try stream.currentString() == "b")
            #expect(try stream.next() == .colon)
            try stream.skip() // skips "2"
            #expect(try stream.next() == .comma)
            #expect(try stream.next() == .string)
            #expect(try stream.currentString() == "c")
            #expect(try stream.next() == .colon)
            try stream.skip() // skips "3"
            #expect(try stream.next() == .objectEnd)
            #expect(try stream.next() == .comma)
            #expect(try stream.next() == .number)
            #expect(try stream.currentNumber().int64 == 42)
        }
    }

    @Test
    func `skipValue handles nested arrays`() throws {
        let bytes: [UInt8] = Swift.Array(#"[[1,2],[3,[4,5]]],99"#.utf8)
        try bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) throws(RFC_8259.Error) in
            let span = buf.span
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            try stream.skip() // the whole outer array
            #expect(try stream.next() == .comma)
            #expect(try stream.next() == .number)
            #expect(try stream.currentNumber().int64 == 99)
        }
    }

    @Test
    func `skipValue handles escaped quote in string`() throws {
        let bytes: [UInt8] = Swift.Array(#""skip \"this\" too",42"#.utf8)
        try bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) throws(RFC_8259.Error) in
            let span = buf.span
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            try stream.skip()
            #expect(try stream.next() == .comma)
            #expect(try stream.next() == .number)
            #expect(try stream.currentNumber().int64 == 42)
        }
    }

    // MARK: - Depth

    @Test
    func `depth exceeded throws`() throws {
        let bytes: [UInt8] = Swift.Array("[[[[[]]]]]".utf8)
        bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) in
            let span = buf.span
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span, limit: 3)
            do {
                _ = try stream.next() // depth 1
                _ = try stream.next() // depth 2
                _ = try stream.next() // depth 3
                _ = try stream.next() // depth 4 — throw
                Issue.record("Expected depthExceeded error")
            } catch let error as RFC_8259.Error {
                if case .depthExceeded(_, let limit) = error {
                    #expect(limit == 3)
                } else {
                    Issue.record("Wrong error: \(error)")
                }
            } catch {
                Issue.record("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - Malformed inputs

    @Test
    func `malformed null throws`() throws {
        let bytes: [UInt8] = Swift.Array("nulX".utf8)
        bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) in
            let span = buf.span
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            do {
                _ = try stream.next()
                Issue.record("Expected error")
            } catch let error as RFC_8259.Error {
                if case .unexpectedToken = error {
                    // Pass — we got an unexpectedToken on the byte mismatch.
                } else {
                    Issue.record("Wrong error: \(error)")
                }
            } catch {
                Issue.record("Wrong error type: \(error)")
            }
        }
    }

    @Test
    func `malformed number throws`() throws {
        // Leading zero is forbidden by RFC 8259.
        let bytes: [UInt8] = Swift.Array("007".utf8)
        bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) in
            let span = buf.span
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            do {
                _ = try stream.next()
                _ = try stream.currentNumber()
                Issue.record("Expected leadingZeros error")
            } catch let error as RFC_8259.Error {
                if case .invalidNumber(_, let reason) = error, reason == .leadingZeros {
                    // Pass
                } else {
                    Issue.record("Wrong error: \(error)")
                }
            } catch {
                Issue.record("Wrong error type: \(error)")
            }
        }
    }

    @Test
    func `unterminated string throws`() throws {
        let bytes: [UInt8] = Swift.Array(#""unterminated"#.utf8)
        bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) in
            let span = buf.span
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            do {
                _ = try stream.next()
                _ = try stream.currentString()
                Issue.record("Expected unterminated error")
            } catch let error as RFC_8259.Error {
                if case .invalidString(_, let reason) = error, reason == .unterminated {
                    // Pass
                } else {
                    Issue.record("Wrong error: \(error)")
                }
            } catch {
                Issue.record("Wrong error type: \(error)")
            }
        }
    }

    @Test
    func `unknown byte throws`() throws {
        let bytes: [UInt8] = Swift.Array("@".utf8)
        bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) in
            let span = buf.span
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            do {
                _ = try stream.next()
                Issue.record("Expected unexpectedToken error")
            } catch let error as RFC_8259.Error {
                if case .unexpectedToken(_, let found, _) = error {
                    if case .unknown(let byte) = found {
                        #expect(byte == UInt8(ascii: "@"))
                    } else {
                        Issue.record("Wrong kind: \(found)")
                    }
                } else {
                    Issue.record("Wrong error: \(error)")
                }
            } catch {
                Issue.record("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - Whitespace handling

    @Test
    func `next skips leading whitespace`() throws {
        let bytes: [UInt8] = Swift.Array("   \n\t  null".utf8)
        try bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) throws(RFC_8259.Error) in
            let span = buf.span
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            #expect(try stream.next() == .null)
        }
    }

    @Test
    func `next skips whitespace between tokens`() throws {
        let bytes: [UInt8] = Swift.Array(#"{   "key"   :   42   }"#.utf8)
        try bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) throws(RFC_8259.Error) in
            let span = buf.span
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            #expect(try stream.next() == .objectStart)
            #expect(try stream.next() == .string)
            #expect(try stream.currentString() == "key")
            #expect(try stream.next() == .colon)
            #expect(try stream.next() == .number)
            #expect(try stream.currentNumber().int64 == 42)
            #expect(try stream.next() == .objectEnd)
        }
    }

    // MARK: - Empty input

    @Test
    func `next on empty input returns nil`() throws {
        let bytes: [UInt8] = []
        try bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) throws(RFC_8259.Error) in
            let span = buf.span
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            #expect(try stream.next() == nil)
        }
    }

    @Test
    func `next on whitespace-only returns nil`() throws {
        let bytes: [UInt8] = Swift.Array("   \n   ".utf8)
        try bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) throws(RFC_8259.Error) in
            let span = buf.span
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            #expect(try stream.next() == nil)
        }
    }

    // MARK: - Token.Kind storage cross-check (A0 §9.1 premise 1)

    @Test
    func `Token Kind unknown payload variant flows through next`() throws {
        // The .unknown(UInt8) case is reached via the default branch of
        // next()'s byte switch. Exercise it with a byte that is neither
        // structural nor literal.
        let bytes: [UInt8] = [0xFF]
        bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) in
            let span = buf.span
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            do {
                _ = try stream.next()
                Issue.record("Expected unexpectedToken")
            } catch let error as RFC_8259.Error {
                if case .unexpectedToken(_, let found, _) = error,
                   case .unknown(let byte) = found {
                    #expect(byte == 0xFF)
                } else {
                    Issue.record("Wrong error: \(error)")
                }
            } catch {
                Issue.record("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - consumeAsParseValue short-circuit (§4.3 mitigation 1)

    @Test
    func `consumeAsParseValue produces same value as Parser parse`() throws {
        let input = #"{"a":1,"b":[1,2,3],"c":{"nested":true}}"#
        let bytes: [UInt8] = Swift.Array(input.utf8)
        try bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) throws(RFC_8259.Error) in
            let span = buf.span
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            #expect(stream.isPristine == true)
            let viaStream = try Lexer.Pull.Assemble.from(&stream, strategy: RFC_8259.Pull.Assemble.self)
            #expect(stream.isPristine == false)

            let viaParser = try RFC_8259.Decode.Implementation.parse(span, maxDepth: 512)
            #expect(viaStream == viaParser)
        }
    }
}
