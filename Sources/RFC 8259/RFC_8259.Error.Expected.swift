/// RFC_8259.Error.Expected.swift
/// swift-rfc-8259
///
/// Expected token descriptions for error reporting

extension RFC_8259.Error {
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
