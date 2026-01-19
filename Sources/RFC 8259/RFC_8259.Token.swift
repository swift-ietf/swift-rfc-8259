/// RFC_8259.Token.swift
/// swift-rfc-8259
///
/// Lexer token types for JSON parsing

import Parser_Primitives

extension RFC_8259 {
    /// Tokens produced by the JSON lexer.
    ///
    /// These represent the atomic units of JSON syntax as defined in RFC 8259.
    /// The lexer produces a stream of these tokens for the parser to consume.
    public enum Token: Sendable, Hashable {
        /// `{` - Begin object (RFC 8259 §4)
        case objectStart

        /// `}` - End object (RFC 8259 §4)
        case objectEnd

        /// `[` - Begin array (RFC 8259 §5)
        case arrayStart

        /// `]` - End array (RFC 8259 §5)
        case arrayEnd

        /// `:` - Name separator in objects (RFC 8259 §4)
        case colon

        /// `,` - Value separator (RFC 8259 §4, §5)
        case comma

        /// `null` literal (RFC 8259 §3)
        case null

        /// `true` literal (RFC 8259 §3)
        case `true`

        /// `false` literal (RFC 8259 §3)
        case `false`

        /// String value (RFC 8259 §7)
        case string(String)

        /// Number value (RFC 8259 §6)
        case number(Number)
    }
}

// MARK: - Token to TokenKind

extension RFC_8259.Token {
    /// Converts this token to a TokenKind for error reporting.
    public var kind: RFC_8259.TokenKind {
        switch self {
        case .objectStart: return .objectStart
        case .objectEnd: return .objectEnd
        case .arrayStart: return .arrayStart
        case .arrayEnd: return .arrayEnd
        case .colon: return .colon
        case .comma: return .comma
        case .null: return .null
        case .true: return .true
        case .false: return .false
        case .string: return .string
        case .number: return .number
        }
    }
}

// MARK: - Token CustomStringConvertible

extension RFC_8259.Token: CustomStringConvertible {
    public var description: String {
        switch self {
        case .objectStart: return "{"
        case .objectEnd: return "}"
        case .arrayStart: return "["
        case .arrayEnd: return "]"
        case .colon: return ":"
        case .comma: return ","
        case .null: return "null"
        case .true: return "true"
        case .false: return "false"
        case .string(let s): return "\"\(s)\""
        case .number(let n): return n.description
        }
    }
}
