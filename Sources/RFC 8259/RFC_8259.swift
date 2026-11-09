public enum RFC_8259 {}

extension RFC_8259 {

    @usableFromInline
    static let whitespace: Swift::Set<UInt8> = [
        .ascii.sp,
        .ascii.htab,
        .ascii.lf,
        .ascii.cr,
    ]

    @inlinable
    public static func isWhitespace(_ byte: UInt8) -> Bool {
        whitespace.contains(byte)
    }
}

extension RFC_8259 {

    static func quoted(_ string: String) -> String {
        var result = "\""
        for scalar in string.unicodeScalars {
            switch scalar {
            case "\"": result += "\\\""
            case "\\": result += "\\\\"
            case "\u{08}": result += "\\b"
            case "\u{0C}": result += "\\f"
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            case "\u{00}"..."\u{1F}":
                let hex = String(scalar.value, radix: 16, uppercase: true)
                result += "\\u" + String(repeating: "0", count: 4 - hex.count) + hex
            default:
                result.unicodeScalars.append(scalar)
            }
        }
        result += "\""
        return result
    }
}
