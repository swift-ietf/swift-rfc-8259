public import Byte_Primitives

extension RFC_8259.Number.Original {
    @usableFromInline
    internal enum Storage: Sendable, Hashable {
        case inline(Inline)
        case heap([Byte])
    }
}
