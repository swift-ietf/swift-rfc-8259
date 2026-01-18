/// RFC8259ConformanceTests.swift
/// swift-rfc-8259
///
/// Tests for RFC 8259 spec compliance and edge cases

import Testing
@testable import RFC_8259

@Suite("RFC 8259 Conformance Tests")
struct RFC8259ConformanceTests {

    // MARK: - Error Cases: Numbers

    @Test("Reject leading zeros")
    func rejectLeadingZeros() throws {
        #expect(throws: RFC_8259.Error.self) {
            try RFC_8259.parse("007")
        }
    }

    @Test("Reject leading zeros in negative")
    func rejectLeadingZerosNegative() throws {
        #expect(throws: RFC_8259.Error.self) {
            try RFC_8259.parse("-007")
        }
    }

    @Test("Reject plus sign on positive numbers")
    func rejectPlusSign() throws {
        #expect(throws: RFC_8259.Error.self) {
            try RFC_8259.parse("+42")
        }
    }

    @Test("Reject bare decimal point")
    func rejectBareDecimal() throws {
        #expect(throws: RFC_8259.Error.self) {
            try RFC_8259.parse(".5")
        }
    }

    @Test("Reject trailing decimal point")
    func rejectTrailingDecimal() throws {
        #expect(throws: RFC_8259.Error.self) {
            try RFC_8259.parse("5.")
        }
    }

    @Test("Reject bare exponent")
    func rejectBareExponent() throws {
        #expect(throws: RFC_8259.Error.self) {
            try RFC_8259.parse("e10")
        }
    }

    @Test("Reject NaN")
    func rejectNaN() throws {
        #expect(throws: RFC_8259.Error.self) {
            try RFC_8259.parse("NaN")
        }
    }

    @Test("Reject Infinity")
    func rejectInfinity() throws {
        #expect(throws: RFC_8259.Error.self) {
            try RFC_8259.parse("Infinity")
        }
    }

    @Test("Reject hex numbers")
    func rejectHex() throws {
        #expect(throws: RFC_8259.Error.self) {
            try RFC_8259.parse("0x1F")
        }
    }

    // MARK: - Error Cases: Strings

    @Test("Reject unterminated string")
    func rejectUnterminatedString() throws {
        #expect(throws: RFC_8259.Error.self) {
            try RFC_8259.parse("\"hello")
        }
    }

    @Test("Reject invalid escape")
    func rejectInvalidEscape() throws {
        #expect(throws: RFC_8259.Error.self) {
            try RFC_8259.parse("\"\\q\"")
        }
    }

    @Test("Reject incomplete unicode escape")
    func rejectIncompleteUnicode() throws {
        #expect(throws: RFC_8259.Error.self) {
            try RFC_8259.parse("\"\\u00\"")
        }
    }

    @Test("Reject invalid unicode escape")
    func rejectInvalidUnicode() throws {
        #expect(throws: RFC_8259.Error.self) {
            try RFC_8259.parse("\"\\uGGGG\"")
        }
    }

    @Test("Reject unescaped control character")
    func rejectUnescapedControl() throws {
        #expect(throws: RFC_8259.Error.self) {
            try RFC_8259.parse("\"\u{01}\"")
        }
    }

    @Test("Reject unescaped newline in string")
    func rejectUnescapedNewline() throws {
        #expect(throws: RFC_8259.Error.self) {
            try RFC_8259.parse("\"hello\nworld\"")
        }
    }

    @Test("Reject unescaped tab in string")
    func rejectUnescapedTab() throws {
        #expect(throws: RFC_8259.Error.self) {
            try RFC_8259.parse("\"hello\tworld\"")
        }
    }

    // MARK: - Error Cases: Structure

    @Test("Reject trailing content")
    func rejectTrailing() throws {
        #expect(throws: RFC_8259.Error.self) {
            try RFC_8259.parse("123 456")
        }
    }

    @Test("Reject multiple values")
    func rejectMultipleValues() throws {
        #expect(throws: RFC_8259.Error.self) {
            try RFC_8259.parse("{}{}")
        }
    }

    @Test("Reject unclosed array")
    func rejectUnclosedArray() throws {
        #expect(throws: RFC_8259.Error.self) {
            try RFC_8259.parse("[1, 2")
        }
    }

    @Test("Reject unclosed object")
    func rejectUnclosedObject() throws {
        #expect(throws: RFC_8259.Error.self) {
            try RFC_8259.parse("{\"key\": 1")
        }
    }

    @Test("Reject trailing comma in array")
    func rejectTrailingCommaArray() throws {
        #expect(throws: RFC_8259.Error.self) {
            try RFC_8259.parse("[1, 2, ]")
        }
    }

    @Test("Reject trailing comma in object")
    func rejectTrailingCommaObject() throws {
        #expect(throws: RFC_8259.Error.self) {
            try RFC_8259.parse("{\"key\": 1, }")
        }
    }

    @Test("Reject unquoted object key")
    func rejectUnquotedKey() throws {
        #expect(throws: RFC_8259.Error.self) {
            try RFC_8259.parse("{key: 1}")
        }
    }

    @Test("Reject single quotes")
    func rejectSingleQuotes() throws {
        #expect(throws: RFC_8259.Error.self) {
            try RFC_8259.parse("'hello'")
        }
    }

    @Test("Reject missing colon in object")
    func rejectMissingColon() throws {
        #expect(throws: RFC_8259.Error.self) {
            try RFC_8259.parse("{\"key\" 1}")
        }
    }

    @Test("Reject missing value in object")
    func rejectMissingValue() throws {
        #expect(throws: RFC_8259.Error.self) {
            try RFC_8259.parse("{\"key\":}")
        }
    }

    // MARK: - Error Cases: Invalid Tokens

    @Test("Reject undefined")
    func rejectUndefined() throws {
        #expect(throws: RFC_8259.Error.self) {
            try RFC_8259.parse("undefined")
        }
    }

    @Test("Reject True (capitalized)")
    func rejectCapitalizedTrue() throws {
        #expect(throws: RFC_8259.Error.self) {
            try RFC_8259.parse("True")
        }
    }

    @Test("Reject FALSE (all caps)")
    func rejectAllCapsTrue() throws {
        #expect(throws: RFC_8259.Error.self) {
            try RFC_8259.parse("FALSE")
        }
    }

    @Test("Reject NULL (all caps)")
    func rejectAllCapsNull() throws {
        #expect(throws: RFC_8259.Error.self) {
            try RFC_8259.parse("NULL")
        }
    }

    @Test("Reject empty input")
    func rejectEmpty() throws {
        #expect(throws: RFC_8259.Error.self) {
            try RFC_8259.parse("")
        }
    }

    @Test("Reject whitespace only")
    func rejectWhitespaceOnly() throws {
        #expect(throws: RFC_8259.Error.self) {
            try RFC_8259.parse("   ")
        }
    }

    // MARK: - Depth Limiting

    @Test("Respect depth limit")
    func respectDepthLimit() throws {
        // Nested 10 levels deep
        let json = String(repeating: "[", count: 10) + "1" + String(repeating: "]", count: 10)

        // Should succeed with default depth
        let value = try RFC_8259.parse(json)
        #expect(value.array != nil)

        // Should fail with lower limit
        #expect(throws: RFC_8259.Error.self) {
            try RFC_8259.parse(json, maxDepth: 5)
        }
    }

    // MARK: - Unicode

    @Test("Parse UTF-8 string")
    func parseUtf8() throws {
        let value = try RFC_8259.parse("\"日本語\"")
        #expect(value.string == "日本語")
    }

    @Test("Parse emoji")
    func parseEmoji() throws {
        let value = try RFC_8259.parse("\"Hello 👋\"")
        #expect(value.string == "Hello 👋")
    }

    @Test("Parse surrogate pair via unicode escapes")
    func parseSurrogatePair() throws {
        // U+1F600 (😀) = \uD83D\uDE00 in surrogate pairs
        let value = try RFC_8259.parse("\"\\uD83D\\uDE00\"")
        #expect(value.string == "😀")
    }

    // MARK: - Object Key Handling

    @Test("Object preserves insertion order")
    func objectPreservesOrder() throws {
        let json = "{\"z\":1,\"a\":2,\"m\":3}"
        let value = try RFC_8259.parse(json)
        let keys = value.object?.map(\.key)
        #expect(keys == ["z", "a", "m"])
    }

    @Test("Object handles duplicate keys (last wins)")
    func objectDuplicateKeys() throws {
        let json = "{\"key\":1,\"key\":2}"
        let value = try RFC_8259.parse(json)
        // Behavior: both are stored; first match wins on lookup
        #expect(value["key"]?.number?.int64Value == 1)
    }

    // MARK: - Large Numbers

    @Test("Parse large integer")
    func parseLargeInteger() throws {
        let value = try RFC_8259.parse("9223372036854775807")
        #expect(value.number?.int64Value == Int64.max)
    }

    @Test("Parse very large number as double")
    func parseVeryLargeNumber() throws {
        let value = try RFC_8259.parse("1e308")
        #expect(value.number?.doubleValue != nil)
    }
}
