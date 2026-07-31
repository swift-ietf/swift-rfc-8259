/// RFC_8259.Error.String.swift
/// swift-rfc-8259
///
/// String parsing sub-errors per RFC 8259 Section 7

public import ASCII_Primitives

extension RFC_8259.Error {
    /// String parsing errors per RFC 8259 Section 7.
    public enum String: Sendable, Hashable {
        /// Invalid escape sequence (e.g., "\q").
        case invalidEscape(ASCII.Code)

        /// Invalid \uXXXX escape (e.g., "\uGGGG").
        case invalidUnicodeEscape

        /// String not terminated with closing quote.
        case unterminated

        /// Unescaped control character (0x00-0x1F).
        case controlCharacter(ASCII.Code)
    }
}

extension RFC_8259.Error.String: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .invalidEscape(let code):
            return "invalid escape sequence '\\\\' + 0x\(Swift.String(code, radix: 16))"

        case .invalidUnicodeEscape:
            return "invalid \\uXXXX escape sequence"

        case .unterminated:
            return "unterminated string"

        case .controlCharacter(let code):
            return "unescaped control character 0x\(Swift.String(code, radix: 16))"
        }
    }
}
