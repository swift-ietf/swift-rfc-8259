/// RFC_8259.Number.Original.Inline.swift
/// swift-rfc-8259
///
/// Inline storage for up to 23 bytes (renamed from InlineBytes)

extension RFC_8259.Number.Original {
    /// Inline storage for up to 23 bytes.
    ///
    /// Most JSON numbers are short (e.g., "123", "-45.67", "1e10"),
    /// so inline storage avoids heap allocation in the common case.
    @usableFromInline
    internal struct Inline: Sendable, Hashable {
        // 23 bytes of storage + 1 byte for count = 24 bytes total
        @usableFromInline internal var b0: UInt8 = 0
        @usableFromInline internal var b1: UInt8 = 0
        @usableFromInline internal var b2: UInt8 = 0
        @usableFromInline internal var b3: UInt8 = 0
        @usableFromInline internal var b4: UInt8 = 0
        @usableFromInline internal var b5: UInt8 = 0
        @usableFromInline internal var b6: UInt8 = 0
        @usableFromInline internal var b7: UInt8 = 0
        @usableFromInline internal var b8: UInt8 = 0
        @usableFromInline internal var b9: UInt8 = 0
        @usableFromInline internal var b10: UInt8 = 0
        @usableFromInline internal var b11: UInt8 = 0
        @usableFromInline internal var b12: UInt8 = 0
        @usableFromInline internal var b13: UInt8 = 0
        @usableFromInline internal var b14: UInt8 = 0
        @usableFromInline internal var b15: UInt8 = 0
        @usableFromInline internal var b16: UInt8 = 0
        @usableFromInline internal var b17: UInt8 = 0
        @usableFromInline internal var b18: UInt8 = 0
        @usableFromInline internal var b19: UInt8 = 0
        @usableFromInline internal var b20: UInt8 = 0
        @usableFromInline internal var b21: UInt8 = 0
        @usableFromInline internal var b22: UInt8 = 0
        @usableFromInline internal var count: UInt8 = 0

        @usableFromInline
        internal init(_ bytes: [UInt8]) {
            precondition(bytes.count <= 23, "Inline can hold at most 23 bytes")
            count = UInt8(bytes.count)
            if bytes.count > 0 { b0 = bytes[0] }
            if bytes.count > 1 { b1 = bytes[1] }
            if bytes.count > 2 { b2 = bytes[2] }
            if bytes.count > 3 { b3 = bytes[3] }
            if bytes.count > 4 { b4 = bytes[4] }
            if bytes.count > 5 { b5 = bytes[5] }
            if bytes.count > 6 { b6 = bytes[6] }
            if bytes.count > 7 { b7 = bytes[7] }
            if bytes.count > 8 { b8 = bytes[8] }
            if bytes.count > 9 { b9 = bytes[9] }
            if bytes.count > 10 { b10 = bytes[10] }
            if bytes.count > 11 { b11 = bytes[11] }
            if bytes.count > 12 { b12 = bytes[12] }
            if bytes.count > 13 { b13 = bytes[13] }
            if bytes.count > 14 { b14 = bytes[14] }
            if bytes.count > 15 { b15 = bytes[15] }
            if bytes.count > 16 { b16 = bytes[16] }
            if bytes.count > 17 { b17 = bytes[17] }
            if bytes.count > 18 { b18 = bytes[18] }
            if bytes.count > 19 { b19 = bytes[19] }
            if bytes.count > 20 { b20 = bytes[20] }
            if bytes.count > 21 { b21 = bytes[21] }
            if bytes.count > 22 { b22 = bytes[22] }
        }

        /// Span-taking sibling of the Array initializer.
        ///
        /// Avoids the intermediate `Swift.Array` allocation when the
        /// source bytes are already contiguous in a `Swift.Span<UInt8>`
        /// (e.g., the `Array.Small<24>.span` produced by the JSON lexer).
        /// The 23-field copy is the same shape as the Array variant.
        @usableFromInline
        internal init(_ bytes: borrowing Swift.Span<UInt8>) {
            precondition(bytes.count <= 23, "Inline can hold at most 23 bytes")
            count = UInt8(bytes.count)
            if bytes.count > 0 { b0 = bytes[0] }
            if bytes.count > 1 { b1 = bytes[1] }
            if bytes.count > 2 { b2 = bytes[2] }
            if bytes.count > 3 { b3 = bytes[3] }
            if bytes.count > 4 { b4 = bytes[4] }
            if bytes.count > 5 { b5 = bytes[5] }
            if bytes.count > 6 { b6 = bytes[6] }
            if bytes.count > 7 { b7 = bytes[7] }
            if bytes.count > 8 { b8 = bytes[8] }
            if bytes.count > 9 { b9 = bytes[9] }
            if bytes.count > 10 { b10 = bytes[10] }
            if bytes.count > 11 { b11 = bytes[11] }
            if bytes.count > 12 { b12 = bytes[12] }
            if bytes.count > 13 { b13 = bytes[13] }
            if bytes.count > 14 { b14 = bytes[14] }
            if bytes.count > 15 { b15 = bytes[15] }
            if bytes.count > 16 { b16 = bytes[16] }
            if bytes.count > 17 { b17 = bytes[17] }
            if bytes.count > 18 { b18 = bytes[18] }
            if bytes.count > 19 { b19 = bytes[19] }
            if bytes.count > 20 { b20 = bytes[20] }
            if bytes.count > 21 { b21 = bytes[21] }
            if bytes.count > 22 { b22 = bytes[22] }
        }

        @usableFromInline
        internal var bytes: [UInt8] {
            var result: [UInt8] = []
            result.reserveCapacity(Int(count))
            if count > 0 { result.append(b0) }
            if count > 1 { result.append(b1) }
            if count > 2 { result.append(b2) }
            if count > 3 { result.append(b3) }
            if count > 4 { result.append(b4) }
            if count > 5 { result.append(b5) }
            if count > 6 { result.append(b6) }
            if count > 7 { result.append(b7) }
            if count > 8 { result.append(b8) }
            if count > 9 { result.append(b9) }
            if count > 10 { result.append(b10) }
            if count > 11 { result.append(b11) }
            if count > 12 { result.append(b12) }
            if count > 13 { result.append(b13) }
            if count > 14 { result.append(b14) }
            if count > 15 { result.append(b15) }
            if count > 16 { result.append(b16) }
            if count > 17 { result.append(b17) }
            if count > 18 { result.append(b18) }
            if count > 19 { result.append(b19) }
            if count > 20 { result.append(b20) }
            if count > 21 { result.append(b21) }
            if count > 22 { result.append(b22) }
            return result
        }
    }
}
