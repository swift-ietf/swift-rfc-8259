/// RFC_8259.Token.Kind.swift
/// swift-rfc-8259
///
/// Simplified token kind for error reporting

extension RFC_8259.Token {
    /// Token kind for error messages.
    ///
    /// This is a simplified representation used in error reporting,
    /// not the full `Token` enum used by the lexer.
    public enum Kind: Sendable, Hashable {
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

extension RFC_8259.Token.Kind: CustomStringConvertible {
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
