/// RFC_8259.Number.Original.Storage.swift
/// swift-rfc-8259
///
/// Storage discriminant for Number.Original

public import Byte_Primitives

extension RFC_8259.Number.Original {
    @usableFromInline
    internal enum Storage: Sendable, Hashable {
        case inline(Inline)
        case heap([Byte])
    }
}
