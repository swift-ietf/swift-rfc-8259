/// RFC_8259.Pull.swift
/// swift-rfc-8259
///
/// Namespace for the JSON specialisation of the L1
/// ``Lexer/Pull`` structural-event cohort.
///
/// Reified under the 2026-05-14 [RES-018] amendment (case (c)) which
/// pulled the substrate-shared event-stream + assembler machinery
/// down to L1 (`Lexer.Pull` in swift-lexer-primitives). RFC 8259
/// supplies the JSON-specific byte-rules and value-tree constructors
/// via two witnesses:
///
/// - ``RFC_8259/Pull/Tokens`` — implements ``Lexer/Pull/Tokens``.
///   Provides token-kind dispatch, whitespace classification,
///   depth-delta semantics, and per-kind value-skip logic.
/// - ``RFC_8259/Pull/Assemble`` — implements
///   ``Lexer/Pull/Assemble/Strategy``. Provides the wholesale
///   fast-path (via ``RFC_8259/Decode/Implementation/parse(_:maxDepth:)``) and
///   the slow-path event-walking that builds ``RFC_8259/Value``.
///
/// Direct use: consumers driving JSON parsing should construct
/// `Lexer.Pull.Stream<RFC_8259.Pull.Tokens>` directly and pass
/// `RFC_8259.Pull.Assemble.self` to
/// `Lexer.Pull.Assemble.from(_:strategy:)`. The format-specific
/// payload-decode methods (`currentString`, `currentNumber`) are
/// available as extensions on the L1 stream specialised to
/// `RFC_8259.Pull.Tokens`.

extension RFC_8259 {
    /// Namespace for the JSON specialisations of the L1 ``Lexer/Pull``
    /// cohort. See the file header for the cohort shape and the
    /// case-(c) pull-down provenance.
    public enum Pull {}
}
