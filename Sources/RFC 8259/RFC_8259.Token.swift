extension RFC_8259 {

    public enum Token: Sendable, Hashable {

        case objectStart

        case objectEnd

        case arrayStart

        case arrayEnd

        case colon

        case comma

        case null

        case `true`

        case `false`

        case string(String)

        case number(Number)
    }
}

extension RFC_8259.Token {

    public var kind: Kind {
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
