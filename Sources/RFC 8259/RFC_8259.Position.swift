/// RFC_8259.Position.swift
/// swift-rfc-8259
///
/// Position within JSON input for error reporting.

public import Lexer_Primitives

extension RFC_8259 {
    /// Position within JSON input for error reporting.
    ///
    /// Aliases ``Lexer/Position`` — the canonical L1 position type
    /// (byte offset paired with line:column location). The alias
    /// keeps the JSON-domain name for surface-API stability while
    /// using the shared L1 substrate directly.
    public typealias Position = Lexer_Primitives.Lexer.Position
}
