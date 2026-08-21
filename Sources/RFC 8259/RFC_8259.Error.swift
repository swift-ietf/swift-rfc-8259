public import Byte_Primitives

extension RFC_8259 {

    public enum Error: Swift.Error, Sendable, Equatable {

        case unexpectedToken(at: Position, found: Token.Kind, expected: Expected)

        case unexpectedEndOfInput(at: Position, expected: Expected)

        case invalidNumber(at: Position, reason: Number)

        case invalidString(at: Position, reason: String)

        case invalidUTF8(at: Position, byte: Byte)

        case depthExceeded(at: Position, limit: Int)

        case trailingContent(at: Position)
    }
}

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
