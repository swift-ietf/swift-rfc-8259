/// ParserTests.swift
/// swift-rfc-8259
///
/// Tests for JSON parsing

import Testing
@testable import RFC_8259

@Suite("Parser Tests")
struct ParserTests {

    // MARK: - Simple Values

    @Test("Parse null")
    func parseNull() throws {
        let value = try RFC_8259.parse("null")
        #expect(value.isNull)
    }

    @Test("Parse true")
    func parseTrue() throws {
        let value = try RFC_8259.parse("true")
        #expect(value.bool == true)
    }

    @Test("Parse false")
    func parseFalse() throws {
        let value = try RFC_8259.parse("false")
        #expect(value.bool == false)
    }

    // MARK: - Numbers

    @Test("Parse integer")
    func parseInteger() throws {
        let value = try RFC_8259.parse("42")
        #expect(value.number?.int64Value == 42)
    }

    @Test("Parse negative integer")
    func parseNegativeInteger() throws {
        let value = try RFC_8259.parse("-123")
        #expect(value.number?.int64Value == -123)
    }

    @Test("Parse floating point")
    func parseFloat() throws {
        let value = try RFC_8259.parse("3.14")
        #expect(value.number?.doubleValue == 3.14)
    }

    @Test("Parse scientific notation")
    func parseScientific() throws {
        let value = try RFC_8259.parse("1.5e10")
        #expect(value.number?.doubleValue == 1.5e10)
    }

    @Test("Parse zero")
    func parseZero() throws {
        let value = try RFC_8259.parse("0")
        #expect(value.number?.int64Value == 0)
    }

    @Test("Parse negative zero")
    func parseNegativeZero() throws {
        let value = try RFC_8259.parse("-0")
        #expect(value.number?.doubleValue == 0)
    }

    @Test("Parse exponent with plus sign")
    func parseExponentPlus() throws {
        let value = try RFC_8259.parse("1e+10")
        #expect(value.number?.doubleValue == 1e10)
    }

    @Test("Parse exponent with minus sign")
    func parseExponentMinus() throws {
        let value = try RFC_8259.parse("1e-10")
        #expect(value.number?.doubleValue == 1e-10)
    }

    @Test("Parse uppercase exponent")
    func parseUppercaseExponent() throws {
        let value = try RFC_8259.parse("1E10")
        #expect(value.number?.doubleValue == 1e10)
    }

    // MARK: - Strings

    @Test("Parse simple string")
    func parseString() throws {
        let value = try RFC_8259.parse("\"hello\"")
        #expect(value.string == "hello")
    }

    @Test("Parse empty string")
    func parseEmptyString() throws {
        let value = try RFC_8259.parse("\"\"")
        #expect(value.string == "")
    }

    @Test("Parse string with escapes")
    func parseStringEscapes() throws {
        let value = try RFC_8259.parse("\"hello\\nworld\"")
        #expect(value.string == "hello\nworld")
    }

    @Test("Parse all escape sequences")
    func parseAllEscapes() throws {
        let value = try RFC_8259.parse("\"\\\"\\\\\\b\\f\\n\\r\\t\"")
        #expect(value.string == "\"\\\u{08}\u{0C}\n\r\t")
    }

    @Test("Parse unicode escape")
    func parseUnicodeEscape() throws {
        let value = try RFC_8259.parse("\"\\u0041\"")
        #expect(value.string == "A")
    }

    @Test("Parse unicode escape for emoji base")
    func parseUnicodeEscapeEmoji() throws {
        let value = try RFC_8259.parse("\"\\u263A\"")
        #expect(value.string == "\u{263A}")
    }

    @Test("Parse solidus escape")
    func parseSolidusEscape() throws {
        let value = try RFC_8259.parse("\"\\/\"")
        #expect(value.string == "/")
    }

    // MARK: - Arrays

    @Test("Parse empty array")
    func parseEmptyArray() throws {
        let value = try RFC_8259.parse("[]")
        #expect(value.array?.count == 0)
    }

    @Test("Parse array with single value")
    func parseArraySingleValue() throws {
        let value = try RFC_8259.parse("[42]")
        #expect(value.array?.count == 1)
        #expect(value[0]?.number?.int64Value == 42)
    }

    @Test("Parse array with values")
    func parseArray() throws {
        let value = try RFC_8259.parse("[1, 2, 3]")
        let array = value.array
        #expect(array?.count == 3)
        #expect(array?[0].number?.int64Value == 1)
        #expect(array?[1].number?.int64Value == 2)
        #expect(array?[2].number?.int64Value == 3)
    }

    @Test("Parse array with mixed types")
    func parseArrayMixed() throws {
        let value = try RFC_8259.parse("[1, \"two\", true, null]")
        #expect(value[0]?.number?.int64Value == 1)
        #expect(value[1]?.string == "two")
        #expect(value[2]?.bool == true)
        #expect(value[3]?.isNull == true)
    }

    // MARK: - Objects

    @Test("Parse empty object")
    func parseEmptyObject() throws {
        let value = try RFC_8259.parse("{}")
        #expect(value.object?.count == 0)
    }

    @Test("Parse object with single member")
    func parseObjectSingleMember() throws {
        let value = try RFC_8259.parse("{\"key\": \"value\"}")
        #expect(value["key"]?.string == "value")
    }

    @Test("Parse object with members")
    func parseObject() throws {
        let value = try RFC_8259.parse("{\"name\": \"John\", \"age\": 30}")
        #expect(value["name"]?.string == "John")
        #expect(value["age"]?.number?.int64Value == 30)
    }

    // MARK: - Nested Structures

    @Test("Parse nested structure")
    func parseNested() throws {
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

    @Test("Parse deeply nested arrays")
    func parseDeeplyNestedArrays() throws {
        let value = try RFC_8259.parse("[[[1]]]")
        #expect(value[0]?[0]?[0]?.number?.int64Value == 1)
    }

    @Test("Parse deeply nested objects")
    func parseDeeplyNestedObjects() throws {
        let value = try RFC_8259.parse("{\"a\":{\"b\":{\"c\":1}}}")
        #expect(value["a"]?["b"]?["c"]?.number?.int64Value == 1)
    }

    // MARK: - Whitespace

    @Test("Handle whitespace")
    func handleWhitespace() throws {
        let value = try RFC_8259.parse("  { \"key\" : \"value\" }  ")
        #expect(value["key"]?.string == "value")
    }

    @Test("Handle all whitespace types")
    func handleAllWhitespace() throws {
        let json = "[\t\n\r 1\t\n\r ,\t\n\r 2\t\n\r ]"
        let value = try RFC_8259.parse(json)
        #expect(value[0]?.number?.int64Value == 1)
        #expect(value[1]?.number?.int64Value == 2)
    }
}
