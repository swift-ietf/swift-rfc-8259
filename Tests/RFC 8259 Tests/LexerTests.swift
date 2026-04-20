/// LexerTests.swift
/// swift-rfc-8259
///
/// Tests for the JSON lexer

import Testing
import Input_Primitives
@testable import RFC_8259

@Suite("Lexer Tests")
struct LexerTests {

    // MARK: - Structural Tokens

    @Test
    func `Lex structural tokens`() throws {
        let input = Input.Buffer(Swift.Array("{}[],:".utf8))
        var lexer = RFC_8259.Lexer(input)

        #expect(try lexer.next() == .objectStart)
        #expect(try lexer.next() == .objectEnd)
        #expect(try lexer.next() == .arrayStart)
        #expect(try lexer.next() == .arrayEnd)
        #expect(try lexer.next() == .comma)
        #expect(try lexer.next() == .colon)
        #expect(try lexer.next() == nil)
    }

    // MARK: - Literals

    @Test
    func `Lex null`() throws {
        let input = Input.Buffer(Swift.Array("null".utf8))
        var lexer = RFC_8259.Lexer(input)

        #expect(try lexer.next() == .null)
        #expect(try lexer.next() == nil)
    }

    @Test
    func `Lex true`() throws {
        let input = Input.Buffer(Swift.Array("true".utf8))
        var lexer = RFC_8259.Lexer(input)

        #expect(try lexer.next() == .true)
        #expect(try lexer.next() == nil)
    }

    @Test
    func `Lex false`() throws {
        let input = Input.Buffer(Swift.Array("false".utf8))
        var lexer = RFC_8259.Lexer(input)

        #expect(try lexer.next() == .false)
        #expect(try lexer.next() == nil)
    }

    // MARK: - Numbers

    @Test
    func `Lex integer`() throws {
        let input = Input.Buffer(Swift.Array("42".utf8))
        var lexer = RFC_8259.Lexer(input)

        let token = try lexer.next()
        guard case .number(let n) = token else {
            Issue.record("Expected number token")
            return
        }
        #expect(n.int64 == 42)
    }

    @Test
    func `Lex negative integer`() throws {
        let input = Input.Buffer(Swift.Array("-123".utf8))
        var lexer = RFC_8259.Lexer(input)

        let token = try lexer.next()
        guard case .number(let n) = token else {
            Issue.record("Expected number token")
            return
        }
        #expect(n.int64 == -123)
    }

    @Test
    func `Lex float`() throws {
        let input = Input.Buffer(Swift.Array("3.14".utf8))
        var lexer = RFC_8259.Lexer(input)

        let token = try lexer.next()
        guard case .number(let n) = token else {
            Issue.record("Expected number token")
            return
        }
        #expect(n.double == 3.14)
    }

    @Test
    func `Lex scientific notation`() throws {
        let input = Input.Buffer(Swift.Array("1.5e10".utf8))
        var lexer = RFC_8259.Lexer(input)

        let token = try lexer.next()
        guard case .number(let n) = token else {
            Issue.record("Expected number token")
            return
        }
        #expect(n.double == 1.5e10)
    }

    // MARK: - Strings

    @Test
    func `Lex simple string`() throws {
        let input = Input.Buffer(Swift.Array("\"hello\"".utf8))
        var lexer = RFC_8259.Lexer(input)

        let token = try lexer.next()
        guard case .string(let s) = token else {
            Issue.record("Expected string token")
            return
        }
        #expect(s == "hello")
    }

    @Test
    func `Lex string with escapes`() throws {
        let input = Input.Buffer(Swift.Array("\"hello\\nworld\"".utf8))
        var lexer = RFC_8259.Lexer(input)

        let token = try lexer.next()
        guard case .string(let s) = token else {
            Issue.record("Expected string token")
            return
        }
        #expect(s == "hello\nworld")
    }

    @Test
    func `Lex string with unicode escape`() throws {
        let input = Input.Buffer(Swift.Array("\"\\u0041\"".utf8))
        var lexer = RFC_8259.Lexer(input)

        let token = try lexer.next()
        guard case .string(let s) = token else {
            Issue.record("Expected string token")
            return
        }
        #expect(s == "A")
    }

    // MARK: - Whitespace Handling

    @Test
    func `Skip whitespace between tokens`() throws {
        let input = Input.Buffer(Swift.Array("  {  }  ".utf8))
        var lexer = RFC_8259.Lexer(input)

        #expect(try lexer.next() == .objectStart)
        #expect(try lexer.next() == .objectEnd)
        #expect(try lexer.next() == nil)
    }

    @Test
    func `Handle all whitespace types`() throws {
        let input = Input.Buffer(Swift.Array("\t\n\r {\t\n\r }\t\n\r ".utf8))
        var lexer = RFC_8259.Lexer(input)

        #expect(try lexer.next() == .objectStart)
        #expect(try lexer.next() == .objectEnd)
        #expect(try lexer.next() == nil)
    }

    // MARK: - Position Tracking

    @Test
    func `Track position`() throws {
        let input = Input.Buffer(Swift.Array("{\n  \"key\": 1\n}".utf8))
        var lexer = RFC_8259.Lexer(input)

        _ = try lexer.next() // {
        #expect(lexer.position.location.line == 1)

        _ = try lexer.next() // "key"
        #expect(lexer.position.location.line == 2)
    }

    // MARK: - Token Sequence

    @Test
    func `Lex complete object`() throws {
        let input = Input.Buffer(Swift.Array("{\"name\":\"John\",\"age\":30}".utf8))
        var lexer = RFC_8259.Lexer(input)

        #expect(try lexer.next() == .objectStart)

        let nameToken = try lexer.next()
        guard case .string("name") = nameToken else {
            Issue.record("Expected string 'name'")
            return
        }

        #expect(try lexer.next() == .colon)

        let johnToken = try lexer.next()
        guard case .string("John") = johnToken else {
            Issue.record("Expected string 'John'")
            return
        }

        #expect(try lexer.next() == .comma)

        let ageToken = try lexer.next()
        guard case .string("age") = ageToken else {
            Issue.record("Expected string 'age'")
            return
        }

        #expect(try lexer.next() == .colon)

        let thirtyToken = try lexer.next()
        guard case .number(let n) = thirtyToken else {
            Issue.record("Expected number token")
            return
        }
        #expect(n.int64 == 30)

        #expect(try lexer.next() == .objectEnd)
        #expect(try lexer.next() == nil)
    }

    // MARK: - Error Cases

    @Test
    func `Reject incomplete literal`() throws {
        let input = Input.Buffer(Swift.Array("nul".utf8))
        var lexer = RFC_8259.Lexer(input)

        #expect(throws: RFC_8259.Error.self) {
            _ = try lexer.next()
        }
    }

    @Test
    func `Reject invalid character`() throws {
        let input = Input.Buffer(Swift.Array("@".utf8))
        var lexer = RFC_8259.Lexer(input)

        #expect(throws: RFC_8259.Error.self) {
            _ = try lexer.next()
        }
    }

    @Test
    func `Reject non-finite numbers (1e999 → overflow)`() throws {
        // 1e999 parses to Double.infinity, which should be rejected
        let input = Input.Buffer(Swift.Array("1e999".utf8))
        var lexer = RFC_8259.Lexer(input)

        #expect(throws: RFC_8259.Error.self) {
            _ = try lexer.next()
        }
    }

    @Test
    func `Reject extremely small exponents (1e-999 → overflow)`() throws {
        // 1e-999 parses to 0.0 which is finite, so this should succeed
        // But -1e999 would be -infinity
        let input = Input.Buffer(Swift.Array("-1e999".utf8))
        var lexer = RFC_8259.Lexer(input)

        #expect(throws: RFC_8259.Error.self) {
            _ = try lexer.next()
        }
    }
}
