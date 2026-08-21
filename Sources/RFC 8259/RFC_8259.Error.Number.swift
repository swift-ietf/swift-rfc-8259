extension RFC_8259.Error {

    public enum Number: Sendable, Hashable {

        case leadingZeros

        case missingDigits(context: Swift.String)

        case invalidExponent

        case overflow

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
