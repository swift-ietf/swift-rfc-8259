extension RFC_8259.Error {

    public enum Expected: Sendable, Hashable {

        case value

        case objectKey

        case colon

        case commaOrEnd

        case arrayEnd

        case objectEnd

        case endOfInput
    }
}

extension RFC_8259.Error.Expected: CustomStringConvertible {
    public var description: Swift.String {
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
