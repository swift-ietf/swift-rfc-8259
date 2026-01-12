/// RFC 8259: The JavaScript Object Notation (JSON) Data Interchange Format
///
/// This module implements JSON parsing and encoding as specified in RFC 8259.
/// JSON provides a lightweight text format for data interchange that is
/// language-independent and human-readable.
///
/// ## Key Concepts
///
/// - **JSON Text**: A sequence of tokens representing structured data
/// - **Value Types**: null, boolean, number, string, array, object
/// - **Encoding**: Strictly UTF-8 as required by RFC 8259
///
/// ## Example Usage
///
/// ```swift
/// // Parse JSON
/// let value = try RFC_8259.decode("{\"name\": \"John\", \"age\": 30}")
///
/// // Access values
/// print(value["name"]?.string)  // Optional("John")
/// print(value["age"]?.number?.int64Value)  // Optional(30)
///
/// // Encode JSON
/// let bytes = value.encode()
/// ```
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
    static let whitespace: Set<UInt8> = [
        .ascii.sp,      // Space (0x20)
        .ascii.htab,    // Horizontal tab (0x09)
        .ascii.lf,      // Line feed (0x0A)
        .ascii.cr,      // Carriage return (0x0D)
    ]

    /// Returns true if the byte is JSON whitespace.
    @inlinable
    public static func isWhitespace(_ byte: UInt8) -> Bool {
        whitespace.contains(byte)
    }
}
