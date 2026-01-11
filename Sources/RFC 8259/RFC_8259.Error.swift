/// RFC_8259.Error.swift
/// swift-rfc-8259
///
/// Structured error types for JSON parsing and encoding

extension RFC_8259 {
    /// Parse error with structured context.
    ///
    /// All errors include positional information for precise diagnostics.
    /// Use typed throws (`throws(RFC_8259.Error)`) for exhaustive handling.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// Encountered an unexpected token during parsing.
        case unexpectedToken(at: Position, found: TokenKind, expected: Expected)

        /// Reached end of input while expecting more content.
        case unexpectedEndOfInput(at: Position, expected: Expected)

        /// Number format violates RFC 8259 Section 6.
        case invalidNumber(at: Position, reason: NumberError)

        /// String format violates RFC 8259 Section 7.
        case invalidString(at: Position, reason: StringError)

        /// Invalid UTF-8 byte sequence encountered.
        case invalidUTF8(at: Position, byte: UInt8)

        /// Nesting depth exceeded the configured limit.
        case depthExceeded(at: Position, limit: Int)

        /// Non-whitespace content found after the JSON value.
        case trailingContent(at: Position)
    }
}

// MARK: - Position

extension RFC_8259 {
    /// Position within the JSON input for error reporting.
    ///
    /// All indices are for the UTF-8 byte representation.
    public struct Position: Sendable, Hashable {
        /// Byte offset from start of input (0-indexed).
        public let offset: Int

        /// Line number (1-indexed).
        public let line: Int

        /// Column number within the line (1-indexed, byte column).
        public let column: Int

        public init(offset: Int, line: Int, column: Int) {
            self.offset = offset
            self.line = line
            self.column = column
        }
    }
}

extension RFC_8259.Position: CustomStringConvertible {
    public var description: String {
        "line \(line), column \(column) (byte \(offset))"
    }
}

// MARK: - TokenKind (for error messages)

extension RFC_8259 {
    /// Token kind for error messages.
    ///
    /// This is a simplified representation used in error reporting,
    /// not the full `Token` enum used by the lexer.
    public enum TokenKind: Sendable, Hashable {
        case objectStart
        case objectEnd
        case arrayStart
        case arrayEnd
        case colon
        case comma
        case null
        case `true`
        case `false`
        case string
        case number
        case unknown(UInt8)
    }
}

extension RFC_8259.TokenKind: CustomStringConvertible {
    public var description: String {
        switch self {
        case .objectStart: return "'{'"
        case .objectEnd: return "'}'"
        case .arrayStart: return "'['"
        case .arrayEnd: return "']'"
        case .colon: return "':'"
        case .comma: return "','"
        case .null: return "'null'"
        case .true: return "'true'"
        case .false: return "'false'"
        case .string: return "string"
        case .number: return "number"
        case .unknown(let byte): return "0x\(String(byte, radix: 16))"
        }
    }
}

// MARK: - Expected

extension RFC_8259 {
    /// What the parser expected at an error location.
    public enum Expected: Sendable, Hashable {
        /// Expected any JSON value.
        case value

        /// Expected an object key (string).
        case objectKey

        /// Expected ':' after object key.
        case colon

        /// Expected ',' or end of container.
        case commaOrEnd

        /// Expected ']' to close array.
        case arrayEnd

        /// Expected '}' to close object.
        case objectEnd

        /// Expected end of input.
        case endOfInput
    }
}

extension RFC_8259.Expected: CustomStringConvertible {
    public var description: String {
        switch self {
        case .value: return "JSON value"
        case .objectKey: return "object key (string)"
        case .colon: return "':'"
        case .commaOrEnd: return "',' or end of container"
        case .arrayEnd: return "']'"
        case .objectEnd: return "'}'"
        case .endOfInput: return "end of input"
        }
    }
}

// MARK: - NumberError

extension RFC_8259 {
    /// Number parsing errors per RFC 8259 Section 6.
    public enum NumberError: Sendable, Hashable {
        /// Leading zeros are not permitted (e.g., "007").
        case leadingZeros

        /// Missing digits where required (e.g., "-", "1.", "1e").
        case missingDigits(context: String)

        /// Invalid character in exponent.
        case invalidExponent

        /// Number exceeds representable range.
        case overflow

        /// Empty number.
        case empty
    }
}

extension RFC_8259.NumberError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .leadingZeros:
            return "leading zeros not permitted"
        case .missingDigits(let context):
            return "missing digits in \(context)"
        case .invalidExponent:
            return "invalid exponent format"
        case .overflow:
            return "number overflow"
        case .empty:
            return "empty number"
        }
    }
}

// MARK: - StringError

extension RFC_8259 {
    /// String parsing errors per RFC 8259 Section 7.
    public enum StringError: Sendable, Hashable {
        /// Invalid escape sequence (e.g., "\q").
        case invalidEscape(UInt8)

        /// Invalid \uXXXX escape (e.g., "\uGGGG").
        case invalidUnicodeEscape

        /// String not terminated with closing quote.
        case unterminated

        /// Unescaped control character (0x00-0x1F).
        case controlCharacter(UInt8)
    }
}

extension RFC_8259.StringError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalidEscape(let byte):
            return "invalid escape sequence '\\\\' + 0x\(String(byte, radix: 16))"
        case .invalidUnicodeEscape:
            return "invalid \\uXXXX escape sequence"
        case .unterminated:
            return "unterminated string"
        case .controlCharacter(let byte):
            return "unescaped control character 0x\(String(byte, radix: 16))"
        }
    }
}

// MARK: - Error CustomStringConvertible

extension RFC_8259.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unexpectedToken(let pos, let found, let expected):
            return "Unexpected \(found) at \(pos), expected \(expected)"
        case .unexpectedEndOfInput(let pos, let expected):
            return "Unexpected end of input at \(pos), expected \(expected)"
        case .invalidNumber(let pos, let reason):
            return "Invalid number at \(pos): \(reason)"
        case .invalidString(let pos, let reason):
            return "Invalid string at \(pos): \(reason)"
        case .invalidUTF8(let pos, let byte):
            return "Invalid UTF-8 byte 0x\(String(byte, radix: 16)) at \(pos)"
        case .depthExceeded(let pos, let limit):
            return "Nesting depth exceeded \(limit) at \(pos)"
        case .trailingContent(let pos):
            return "Unexpected content after JSON value at \(pos)"
        }
    }
}
