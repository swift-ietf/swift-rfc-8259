/// RFC_8259.Error.Number.swift
/// swift-rfc-8259
///
/// Number parsing sub-errors per RFC 8259 Section 6

extension RFC_8259.Error {
    /// Number parsing errors per RFC 8259 Section 6.
    public enum Number: Sendable, Hashable {
        /// Leading zeros are not permitted (e.g., "007").
        case leadingZeros

        /// Missing digits where required (e.g., "-", "1.", "1e").
        case missingDigits(context: Swift.String)

        /// Invalid character in exponent.
        case invalidExponent

        /// Number exceeds representable range.
        case overflow

        /// Empty number.
        case empty
    }
}

extension RFC_8259.Error.Number: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .leadingZeros:
            return "leading zeros not permitted"

        case .missingDigits(let context):
            return "missing digits in \(context)"

        case .invalidExponent:
            return "invalid exponent format"

        case .overflow:
            return "number overflow"

        case .empty:
            return "empty number"
        }
    }
}
