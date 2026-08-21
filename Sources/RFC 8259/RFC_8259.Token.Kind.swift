public import ASCII_Primitives

extension RFC_8259.Token {

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

        case unknown(Byte)
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
        case .unknown(let code): return "0x\(String(code.underlying, radix: 16))"
        }
    }
}
