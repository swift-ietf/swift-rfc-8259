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
        var result: [UInt8] = [UInt8(ascii: "\"")]
        for byte in string.utf8 {
            switch byte {
            case UInt8(ascii: "\""): result += Array(#"\""#.utf8)
            case UInt8(ascii: "\\"): result += Array(#"\\"#.utf8)
            case 0x08: result += Array(#"\b"#.utf8)
            case 0x0C: result += Array(#"\f"#.utf8)
            case UInt8(ascii: "\n"): result += Array(#"\n"#.utf8)
            case UInt8(ascii: "\r"): result += Array(#"\r"#.utf8)
            case UInt8(ascii: "\t"): result += Array(#"\t"#.utf8)
            case 0x00...0x1F:
                let hex = String(byte, radix: 16, uppercase: true)
                result += Array(#"\u"#.utf8)
                result += Array(repeating: UInt8(ascii: "0"), count: 4 - hex.utf8.count)
                result += Array(hex.utf8)
            default:
                result.append(byte)
            }
        }
        result.append(UInt8(ascii: "\""))
        return String(decoding: result, as: UTF8.self)
    }
}
