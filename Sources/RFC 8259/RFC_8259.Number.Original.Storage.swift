/// RFC_8259.Number.Original.Storage.swift
/// swift-rfc-8259
///
/// Storage discriminant for Number.Original

extension RFC_8259.Number.Original {
    @usableFromInline
    internal enum Storage: Sendable, Hashable {
        case inline(Inline)
        case heap([UInt8])
    }
}
