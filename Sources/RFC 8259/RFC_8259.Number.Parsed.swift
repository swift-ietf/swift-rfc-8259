extension RFC_8259.Number {

    public enum Parsed: Sendable, Hashable {

        case integer(Int64)

        case unsigned(UInt64)

        case float(Double)
    }
}
