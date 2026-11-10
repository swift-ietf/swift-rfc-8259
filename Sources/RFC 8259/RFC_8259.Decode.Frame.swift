extension RFC_8259.Decode {

    @usableFromInline
    enum Frame {

        case array([RFC_8259.Value])

        case object([(key: String, value: RFC_8259.Value)], key: String)
    }
}
