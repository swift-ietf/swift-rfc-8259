public import ASCII_Primitives

extension RFC_8259.Error {

    public enum String: Sendable, Hashable {

        case invalidEscape(ASCII.Code)

        case invalidUnicodeEscape

        case unterminated

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
