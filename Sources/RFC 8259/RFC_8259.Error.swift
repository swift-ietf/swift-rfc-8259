/// RFC_8259.Error.swift
/// swift-rfc-8259
///
/// Structured error types for JSON parsing and encoding

public import Byte_Primitives

extension RFC_8259 {
    /// Parse error with structured context.
    ///
    /// All errors include positional information for precise diagnostics.
    /// Use typed throws (`throws(RFC_8259.Error)`) for exhaustive handling.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// Encountered an unexpected token during parsing.
        case unexpectedToken(at: Position, found: Token.Kind, expected: Expected)

        /// Reached end of input while expecting more content.
        case unexpectedEndOfInput(at: Position, expected: Expected)

        /// Number format violates RFC 8259 Section 6.
        case invalidNumber(at: Position, reason: Number)

        /// String format violates RFC 8259 Section 7.
        case invalidString(at: Position, reason: String)

        /// Invalid UTF-8 byte sequence encountered.
        case invalidUTF8(at: Position, byte: Byte)

        /// Nesting depth exceeded the configured limit.
        case depthExceeded(at: Position, limit: Int)

        /// Non-whitespace content found after the JSON value.
        case trailingContent(at: Position)
    }
}

// MARK: - Error CustomStringConvertible

extension RFC_8259.Error: CustomStringConvertible {
    public var description: Swift.String {
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
            return "Invalid UTF-8 byte 0x\(Swift.String(byte, radix: 16)) at \(pos)"
        case .depthExceeded(let pos, let limit):
            return "Nesting depth exceeded \(limit) at \(pos)"
        case .trailingContent(let pos):
            return "Unexpected content after JSON value at \(pos)"
        }
    }
}
