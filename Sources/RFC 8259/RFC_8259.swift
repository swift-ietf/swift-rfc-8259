/// RFC 8259: The JavaScript Object Notation (JSON) Data Interchange Format
///
/// This module encodes the RFC 8259 specification as Swift types:
///
/// - The JSON value model (``RFC_8259/Value``, ``RFC_8259/Object``,
///   ``RFC_8259/Array``, ``RFC_8259/Number``).
/// - The token vocabulary (``RFC_8259/Token`` and ``RFC_8259/Token/Kind``).
/// - The error vocabulary (``RFC_8259/Error``).
/// - The token witness for the L1 ``Lexer/Pull`` cohort
///   (``RFC_8259/Pull/Tokens``).
///
/// The parsing and encoding implementation lives at L3 in swift-json,
/// which conforms ``RFC_8259/Value`` to ``Coder_Primitives/Codable``
/// via `JSON.Coder`. Consumers should depend on swift-json for the
/// full bidirectional surface.
///
/// ## RFC 8259 Compliance
///
/// This implementation follows RFC 8259 exactly:
/// - Numbers reject leading zeros (except "0")
/// - Strings require proper escape sequences
/// - UTF-8 encoding is enforced
/// - Depth limiting prevents stack overflow
public enum RFC_8259 {}

// MARK: - JSON Whitespace (RFC 8259 §2)

extension RFC_8259 {
    /// Whitespace bytes permitted between JSON tokens.
    ///
    /// Per RFC 8259 Section 2:
    /// ```
    /// ws = *( %x20 / %x09 / %x0A / %x0D )
    /// ```
    ///
    /// Whitespace is insignificant except within strings.
    @usableFromInline
    static let whitespace: Swift.Set<UInt8> = [
        .ascii.sp,  // Space (0x20)
        .ascii.htab,  // Horizontal tab (0x09)
        .ascii.lf,  // Line feed (0x0A)
        .ascii.cr,  // Carriage return (0x0D)
    ]

    /// Returns true if the byte is JSON whitespace.
    @inlinable
    public static func isWhitespace(_ byte: UInt8) -> Bool {
        whitespace.contains(byte)
    }
}
