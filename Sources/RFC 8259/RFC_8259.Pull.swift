/// RFC_8259.Pull.swift
/// swift-rfc-8259
///
/// Namespace for the JSON token witness of the L1
/// ``Lexer/Pull`` structural-event cohort.
///
/// Reified under the 2026-05-14 [RES-018] amendment (case (c)) which
/// pulled the substrate-shared event-stream + assembler machinery
/// down to L1 (`Lexer.Pull` in swift-lexer-primitives). Per the
/// Arc 1.5 spec-only refactor, RFC 8259 retains only the JSON
/// token witness here:
///
/// - ``RFC_8259/Pull/Tokens`` — implements ``Lexer/Pull/Tokens``.
///   Provides token-kind dispatch, whitespace classification,
///   depth-delta semantics, and per-kind value-skip logic.
///
/// The assemble strategy and payload-decode methods (which were
/// implementation, not spec) live at L3 in swift-json:
///
/// - `JSON.Assemble: Lexer.Pull.Assemble.Strategy` (internal).
/// - `currentString` / `currentNumber` extensions on
///   `Lexer.Pull.Stream where Tokens == RFC_8259.Pull.Tokens`.
///
/// Direct use: consumers driving JSON parsing should depend on
/// swift-json and route through ``RFC_8259/Value`` (which conforms
/// to `Coder.Codable` at L3 via `JSON.Coder`).

extension RFC_8259 {
    /// Namespace for the JSON token witness of the L1 ``Lexer/Pull``
    /// cohort. See the file header for the cohort shape and the
    /// case-(c) pull-down provenance.
    public enum Pull {}
}
