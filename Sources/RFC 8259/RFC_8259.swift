public enum RFC_8259 {}

extension RFC_8259 {

    @usableFromInline
    static let whitespace: Swift.Set<UInt8> = [
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
