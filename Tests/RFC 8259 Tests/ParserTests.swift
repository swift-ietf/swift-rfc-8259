/// ParserTests.swift
/// swift-rfc-8259
///
/// Tests for JSON parsing

import Testing
@testable import RFC_8259

@Suite("Parser Tests")
struct ParserTests {

    // MARK: - Simple Values

    @Test
    func `Parse null`() throws {
        let value = try RFC_8259.parse("null")
        #expect(value.isNull)
    }

    @Test
    func `Parse true`() throws {
        let value = try RFC_8259.parse("true")
        #expect(value.bool == true)
    }

    @Test
    func `Parse false`() throws {
        let value = try RFC_8259.parse("false")
        #expect(value.bool == false)
    }

    // MARK: - Numbers

    @Test
    func `Parse integer`() throws {
        let value = try RFC_8259.parse("42")
        #expect(value.number?.int64 == 42)
    }

    @Test
    func `Parse negative integer`() throws {
        let value = try RFC_8259.parse("-123")
        #expect(value.number?.int64 == -123)
    }

    @Test
    func `Parse floating point`() throws {
        let value = try RFC_8259.parse("3.14")
        #expect(value.number?.double == 3.14)
    }

    @Test
    func `Parse scientific notation`() throws {
        let value = try RFC_8259.parse("1.5e10")
        #expect(value.number?.double == 1.5e10)
    }

    @Test
    func `Parse zero`() throws {
        let value = try RFC_8259.parse("0")
        #expect(value.number?.int64 == 0)
    }

    @Test
    func `Parse negative zero`() throws {
        let value = try RFC_8259.parse("-0")
        #expect(value.number?.double == 0)
    }

    @Test
    func `Parse exponent with plus sign`() throws {
        let value = try RFC_8259.parse("1e+10")
        #expect(value.number?.double == 1e10)
    }

    @Test
    func `Parse exponent with minus sign`() throws {
        let value = try RFC_8259.parse("1e-10")
        #expect(value.number?.double == 1e-10)
    }

    @Test
    func `Parse uppercase exponent`() throws {
        let value = try RFC_8259.parse("1E10")
        #expect(value.number?.double == 1e10)
    }

    // MARK: - Strings

    @Test
    func `Parse simple string`() throws {
        let value = try RFC_8259.parse("\"hello\"")
        #expect(value.string == "hello")
    }

    @Test
    func `Parse empty string`() throws {
        let value = try RFC_8259.parse("\"\"")
        #expect(value.string == "")
    }

    @Test
    func `Parse string with escapes`() throws {
        let value = try RFC_8259.parse("\"hello\\nworld\"")
        #expect(value.string == "hello\nworld")
    }

    @Test
    func `Parse all escape sequences`() throws {
        let value = try RFC_8259.parse("\"\\\"\\\\\\b\\f\\n\\r\\t\"")
        #expect(value.string == "\"\\\u{08}\u{0C}\n\r\t")
    }

    @Test
    func `Parse unicode escape`() throws {
        let value = try RFC_8259.parse("\"\\u0041\"")
        #expect(value.string == "A")
    }

    @Test
    func `Parse unicode escape for emoji base`() throws {
        let value = try RFC_8259.parse("\"\\u263A\"")
        #expect(value.string == "\u{263A}")
    }

    @Test
    func `Parse solidus escape`() throws {
        let value = try RFC_8259.parse("\"\\/\"")
        #expect(value.string == "/")
    }

    // MARK: - Arrays

    @Test
    func `Parse empty array`() throws {
        let value = try RFC_8259.parse("[]")
        #expect(value.array?.count == 0)
    }

    @Test
    func `Parse array with single value`() throws {
        let value = try RFC_8259.parse("[42]")
        #expect(value.array?.count == 1)
        #expect(value[0]?.number?.int64 == 42)
    }

    @Test
    func `Parse array with values`() throws {
        let value = try RFC_8259.parse("[1, 2, 3]")
        let array = value.array
        #expect(array?.count == 3)
        #expect(array?[0].number?.int64 == 1)
        #expect(array?[1].number?.int64 == 2)
        #expect(array?[2].number?.int64 == 3)
    }

    @Test
    func `Parse array with mixed types`() throws {
        let value = try RFC_8259.parse("[1, \"two\", true, null]")
        #expect(value[0]?.number?.int64 == 1)
        #expect(value[1]?.string == "two")
        #expect(value[2]?.bool == true)
        #expect(value[3]?.isNull == true)
    }

    // MARK: - Objects

    @Test
    func `Parse empty object`() throws {
        let value = try RFC_8259.parse("{}")
        #expect(value.object?.count == 0)
    }

    @Test
    func `Parse object with single member`() throws {
        let value = try RFC_8259.parse("{\"key\": \"value\"}")
        #expect(value["key"]?.string == "value")
    }

    @Test
    func `Parse object with members`() throws {
        let value = try RFC_8259.parse("{\"name\": \"John\", \"age\": 30}")
        #expect(value["name"]?.string == "John")
        #expect(value["age"]?.number?.int64 == 30)
    }

    // MARK: - Nested Structures

    @Test
    func `Parse nested structure`() throws {
        let json = """
        {
            "users": [
                {"name": "Alice", "active": true},
                {"name": "Bob", "active": false}
            ]
        }
        """
        let value = try RFC_8259.parse(json)
        #expect(value["users"]?[0]?["name"]?.string == "Alice")
        #expect(value["users"]?[0]?["active"]?.bool == true)
        #expect(value["users"]?[1]?["name"]?.string == "Bob")
        #expect(value["users"]?[1]?["active"]?.bool == false)
    }

    @Test
    func `Parse deeply nested arrays`() throws {
        let value = try RFC_8259.parse("[[[1]]]")
        #expect(value[0]?[0]?[0]?.number?.int64 == 1)
    }

    @Test
    func `Parse deeply nested objects`() throws {
        let value = try RFC_8259.parse("{\"a\":{\"b\":{\"c\":1}}}")
        #expect(value["a"]?["b"]?["c"]?.number?.int64 == 1)
    }

    // MARK: - Whitespace

    @Test
    func `Handle whitespace`() throws {
        let value = try RFC_8259.parse("  { \"key\" : \"value\" }  ")
        #expect(value["key"]?.string == "value")
    }

    @Test
    func `Handle all whitespace types`() throws {
        let json = "[\t\n\r 1\t\n\r ,\t\n\r 2\t\n\r ]"
        let value = try RFC_8259.parse(json)
        #expect(value[0]?.number?.int64 == 1)
        #expect(value[1]?.number?.int64 == 2)
    }
}
