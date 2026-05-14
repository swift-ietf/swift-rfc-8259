/// RFC_8259.Lexer.Span.swift
/// swift-rfc-8259
///
/// Span-specialized cursor for the contiguous-bytes case.
///
/// Phase A1 of the Tier-4 parse-performance work
/// (`swift-foundations/swift-json/Research/parse-performance-architecture.md`),
/// rebased onto `Lexer.Scanner` from swift-lexer-primitives per the
/// streaming-deserialize placement audit's Ticket T-1
/// (`swift-institute/Audits/streaming-deserialize-placement-audit.md`).
///
/// ## Naming note
///
/// The architecture doc names this type `RFC_8259.Lexer.Span`
/// (variant label on the generic `RFC_8259.Lexer<Input>`). Swift
/// requires the parent generic's arguments at every nested-type
/// reference, which makes `RFC_8259.Lexer.Span` non-trivial to spell
/// from sibling files. The implementation lives at
/// `RFC_8259.Span.Lexer` — the same variant-label intent expressed
/// through a non-generic `RFC_8259.Span` namespace holder. The
/// file name preserves the architecture doc's wording for
/// recognisability.

public import Lexer_Primitives

extension RFC_8259 {
    /// Namespace for Span-specialised variants.
    ///
    /// `RFC_8259.Span.Lexer` and `RFC_8259.Span.Parser` are the
    /// internal Span-backed implementations of the public
    /// `RFC_8259.Lexer` / `RFC_8259.Parser` generic types. The public
    /// generic types remain the slow path for non-contiguous inputs;
    /// the Span variants are the fast path engaged by the
    /// `RFC_8259.Decode` dispatch fork on contiguous storage.
    ///
    /// `RFC_8259.Span.EventStream` is the public Span-backed event
    /// cursor introduced by Phase A1 of the streaming-deserialize
    /// arc (per `streaming-json-deserialize-comparative-analysis.md`
    /// v1.0.1). Public so that consumers may construct it from
    /// `Swift.Span<UInt8>` at their own call site; the namespace
    /// itself is now `public` rather than `internal`.
    public enum Span {}
}

extension RFC_8259.Span {
    /// Span-specialised cursor for the contiguous-bytes case.
    ///
    /// Wraps `Lexer.Scanner` from swift-lexer-primitives. The Scanner
    /// owns the cursor state (`Text.Position`), the underlying byte
    /// span, and the incremental line:column tracker
    /// (`Text.Location.Tracker`). The JSON-internal wrapper adds the
    /// JSON-specific helpers — `consume()` (delegates to
    /// `scanner.consume()`) and an `Int`-taking `peek(offset:)` that
    /// handles the boundary conversion to `Text.Count` locally.
    ///
    /// `~Copyable & ~Escapable` per the `Binary.Bytes.Input.View`
    /// precedent, inherited from the wrapped Scanner. The cursor cannot
    /// escape the scope of the span it borrows; the compiler enforces
    /// this via `@_lifetime(borrow bytes)`.
    ///
    /// Not a public type — exposed only to the `RFC_8259.Decode`
    /// dispatch fork. If a second hot consumer surfaces, promote
    /// per [RES-018].
    ///
    /// ## Strict memory safety
    ///
    /// Backed by `Swift.Span<UInt8>` through `Lexer.Scanner`, a safe
    /// stdlib type. The cursor performs only safe operations; `@safe`
    /// documents that.
    ///
    /// ## Line/column tracking
    ///
    /// The Scanner ships with `Text.Location.Tracker` — O(1) line:column
    /// queries via incremental updates. The replaced
    /// `RFC_8259.Lexer.Span.Position` lazy-position file recomputed the
    /// line:column from scratch on every error site (O(consumed));
    /// Tracker is strictly faster on error paths. The trade is that
    /// newlines must be reported to the tracker at advance time — this
    /// is handled by the parser/event-stream's `skipWhitespace()` since
    /// JSON cannot contain raw newlines inside tokens (strings,
    /// numbers, literals all forbid unescaped 0x0A / 0x0D).
    // SAFETY: Safe by construction — backing storage uses only stdlib
    // SAFETY: safe types; `@safe` documents that this type performs no
    // SAFETY: unsafe operations.
    @safe
    @usableFromInline
    internal struct Lexer: ~Copyable, ~Escapable {
        @usableFromInline
        internal var scanner: Lexer_Primitives.Lexer.Scanner

        @inlinable
        @_lifetime(borrow bytes)
        internal init(_ bytes: borrowing Swift.Span<UInt8>) {
            self.scanner = Lexer_Primitives.Lexer.Scanner(bytes)
        }
    }
}

// MARK: - JSON-internal helpers

extension RFC_8259.Span.Lexer {
    /// Reads the byte at the current cursor and advances by one.
    ///
    /// Delegates to `Lexer.Scanner.consume()`. Caller MUST ensure the
    /// cursor is in bounds (typically via a preceding `peek()` check
    /// in a `while let` / `guard let` chain).
    @inlinable
    @_lifetime(self: copy self)
    internal mutating func consume() -> UInt8 {
        scanner.consume()
    }

    /// `Int`-taking `peek(offset:)` for the JSON-internal call sites.
    ///
    /// JSON's parser/event-stream do their lookahead with `Int`
    /// offsets; this wrapper centralises the `Int → Text.Count`
    /// conversion so call sites stay terse.
    @inlinable
    internal func peek(offset: Int) -> UInt8? {
        scanner.peek(at: Text.Count(Cardinal(UInt(offset))))
    }
}
