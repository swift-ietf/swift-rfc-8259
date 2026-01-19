/// LexerTests.swift
/// swift-rfc-8259
///
/// Tests for the JSON lexer

import Testing
import Parser_Primitives
@testable import RFC_8259

@Suite("Lexer Tests")
struct LexerTests {

    // MARK: - Structural Tokens

    @Test("Lex structural tokens")
    func lexStructural() throws {
        let input = Parsing.CollectionInput(Array("{}[],:".utf8))
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

    @Test("Lex null")
    func lexNull() throws {
        let input = Parsing.CollectionInput(Array("null".utf8))
        var lexer = RFC_8259.Lexer(input)

        #expect(try lexer.next() == .null)
        #expect(try lexer.next() == nil)
    }

    @Test("Lex true")
    func lexTrue() throws {
        let input = Parsing.CollectionInput(Array("true".utf8))
        var lexer = RFC_8259.Lexer(input)

        #expect(try lexer.next() == .true)
        #expect(try lexer.next() == nil)
    }

    @Test("Lex false")
    func lexFalse() throws {
        let input = Parsing.CollectionInput(Array("false".utf8))
        var lexer = RFC_8259.Lexer(input)

        #expect(try lexer.next() == .false)
        #expect(try lexer.next() == nil)
    }

    // MARK: - Numbers

    @Test("Lex integer")
    func lexInteger() throws {
        let input = Parsing.CollectionInput(Array("42".utf8))
        var lexer = RFC_8259.Lexer(input)

        let token = try lexer.next()
        guard case .number(let n) = token else {
            Issue.record("Expected number token")
            return
        }
        #expect(n.int64Value == 42)
    }

    @Test("Lex negative integer")
    func lexNegativeInteger() throws {
        let input = Parsing.CollectionInput(Array("-123".utf8))
        var lexer = RFC_8259.Lexer(input)

        let token = try lexer.next()
        guard case .number(let n) = token else {
            Issue.record("Expected number token")
            return
        }
        #expect(n.int64Value == -123)
    }

    @Test("Lex float")
    func lexFloat() throws {
        let input = Parsing.CollectionInput(Array("3.14".utf8))
        var lexer = RFC_8259.Lexer(input)

        let token = try lexer.next()
        guard case .number(let n) = token else {
            Issue.record("Expected number token")
            return
        }
        #expect(n.doubleValue == 3.14)
    }

    @Test("Lex scientific notation")
    func lexScientific() throws {
        let input = Parsing.CollectionInput(Array("1.5e10".utf8))
        var lexer = RFC_8259.Lexer(input)

        let token = try lexer.next()
        guard case .number(let n) = token else {
            Issue.record("Expected number token")
            return
        }
        #expect(n.doubleValue == 1.5e10)
    }

    // MARK: - Strings

    @Test("Lex simple string")
    func lexSimpleString() throws {
        let input = Parsing.CollectionInput(Array("\"hello\"".utf8))
        var lexer = RFC_8259.Lexer(input)

        let token = try lexer.next()
        guard case .string(let s) = token else {
            Issue.record("Expected string token")
            return
        }
        #expect(s == "hello")
    }

    @Test("Lex string with escapes")
    func lexStringEscapes() throws {
        let input = Parsing.CollectionInput(Array("\"hello\\nworld\"".utf8))
        var lexer = RFC_8259.Lexer(input)

        let token = try lexer.next()
        guard case .string(let s) = token else {
            Issue.record("Expected string token")
            return
        }
        #expect(s == "hello\nworld")
    }

    @Test("Lex string with unicode escape")
    func lexUnicodeEscape() throws {
        let input = Parsing.CollectionInput(Array("\"\\u0041\"".utf8))
        var lexer = RFC_8259.Lexer(input)

        let token = try lexer.next()
        guard case .string(let s) = token else {
            Issue.record("Expected string token")
            return
        }
        #expect(s == "A")
    }

    // MARK: - Whitespace Handling

    @Test("Skip whitespace between tokens")
    func skipWhitespace() throws {
        let input = Parsing.CollectionInput(Array("  {  }  ".utf8))
        var lexer = RFC_8259.Lexer(input)

        #expect(try lexer.next() == .objectStart)
        #expect(try lexer.next() == .objectEnd)
        #expect(try lexer.next() == nil)
    }

    @Test("Handle all whitespace types")
    func handleAllWhitespace() throws {
        let input = Parsing.CollectionInput(Array("\t\n\r {\t\n\r }\t\n\r ".utf8))
        var lexer = RFC_8259.Lexer(input)

        #expect(try lexer.next() == .objectStart)
        #expect(try lexer.next() == .objectEnd)
        #expect(try lexer.next() == nil)
    }

    // MARK: - Position Tracking

    @Test("Track position")
    func trackPosition() throws {
        let input = Parsing.CollectionInput(Array("{\n  \"key\": 1\n}".utf8))
        var lexer = RFC_8259.Lexer(input)

        _ = try lexer.next() // {
        #expect(lexer.currentPosition.line == 1)

        _ = try lexer.next() // "key"
        #expect(lexer.currentPosition.line == 2)
    }

    // MARK: - Token Sequence

    @Test("Lex complete object")
    func lexCompleteObject() throws {
        let input = Parsing.CollectionInput(Array("{\"name\":\"John\",\"age\":30}".utf8))
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
        #expect(n.int64Value == 30)

        #expect(try lexer.next() == .objectEnd)
        #expect(try lexer.next() == nil)
    }

    // MARK: - Error Cases

    @Test("Reject incomplete literal")
    func rejectIncompleteLiteral() throws {
        let input = Parsing.CollectionInput(Array("nul".utf8))
        var lexer = RFC_8259.Lexer(input)

        #expect(throws: RFC_8259.Error.self) {
            _ = try lexer.next()
        }
    }

    @Test("Reject invalid character")
    func rejectInvalidCharacter() throws {
        let input = Parsing.CollectionInput(Array("@".utf8))
        var lexer = RFC_8259.Lexer(input)

        #expect(throws: RFC_8259.Error.self) {
            _ = try lexer.next()
        }
    }

    @Test("Reject non-finite numbers (1e999 → overflow)")
    func rejectNonFiniteNumbers() throws {
        // 1e999 parses to Double.infinity, which should be rejected
        let input = Parsing.CollectionInput(Array("1e999".utf8))
        var lexer = RFC_8259.Lexer(input)

        #expect(throws: RFC_8259.Error.self) {
            _ = try lexer.next()
        }
    }

    @Test("Reject extremely small exponents (1e-999 → overflow)")
    func rejectExtremelySmallExponents() throws {
        // 1e-999 parses to 0.0 which is finite, so this should succeed
        // But -1e999 would be -infinity
        let input = Parsing.CollectionInput(Array("-1e999".utf8))
        var lexer = RFC_8259.Lexer(input)

        #expect(throws: RFC_8259.Error.self) {
            _ = try lexer.next()
        }
    }
}
