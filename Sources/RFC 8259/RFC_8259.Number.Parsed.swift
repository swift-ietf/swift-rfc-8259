/// RFC_8259.Number.Parsed.swift
/// swift-rfc-8259
///
/// Parsed numeric value for computation

extension RFC_8259.Number {
    /// The parsed numeric value for computation.
    public enum Parsed: Sendable, Hashable {
        /// Signed integer value (fits in Int64).
        case integer(Int64)

        /// Unsigned integer value (fits in UInt64 but not Int64).
        case unsigned(UInt64)

        /// Floating-point value (has fraction or exponent, or too large for integers).
        case float(Double)
    }
}
