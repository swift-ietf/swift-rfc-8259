/// RFC_8259.Lexer.Span.swift
/// swift-rfc-8259
///
/// Span-specialized cursor for the contiguous-bytes case.
///
/// Phase A1 of the Tier-4 parse-performance work
/// (`swift-foundations/swift-json/Research/parse-performance-architecture.md`).
/// Mirrors `Binary.Bytes.Input.View` one layer up.
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

extension RFC_8259 {
    /// Internal namespace for Span-specialized variants.
    ///
    /// `RFC_8259.Span.Lexer` and `RFC_8259.Span.Parser` are the
    /// Span-backed implementations of the public `RFC_8259.Lexer` /
    /// `RFC_8259.Parser` generic types. The public generic types
    /// remain the slow path for non-contiguous inputs; the Span
    /// variants are the fast path engaged by the `RFC_8259.Decode`
    /// dispatch fork on contiguous storage.
    @usableFromInline
    internal enum Span {}
}

extension RFC_8259.Span {
    /// Span-specialised cursor for the contiguous-bytes case.
    ///
    /// `~Copyable & ~Escapable` per the `Binary.Bytes.Input.View`
    /// precedent. The cursor cannot escape the scope of the span it
    /// borrows; the compiler enforces this via
    /// `@_lifetime(borrow bytes)`.
    ///
    /// Not a public type — exposed only to the `RFC_8259.Decode`
    /// dispatch fork. If a second hot consumer surfaces, promote
    /// per [RES-018].
    ///
    /// ## Strict memory safety
    ///
    /// Backed by `Swift.Span<UInt8>`, a safe stdlib type. The cursor
    /// performs only safe operations; `@safe` documents that.
    ///
    /// ## Lazy position
    ///
    /// The `RFC_8259.Position`-valued position is computed lazily.
    /// `cachedPosition` is `nil` until first read, populated on
    /// access, and reset to `nil` on every `advance` / `advance(by:)`.
    /// Repeated reads at the same byte offset don't re-scan.
    // SAFETY: Safe by construction — backing storage uses only stdlib
    // SAFETY: safe types; `@safe` documents that this type performs no
    // SAFETY: unsafe operations.
    @safe
    @usableFromInline
    internal struct Lexer: ~Copyable, ~Escapable {
        @usableFromInline
        internal let bytes: Swift.Span<UInt8>

        @usableFromInline
        internal var position: Int

        /// Lazy cache for the `RFC_8259.Position` materialisation.
        ///
        /// Stores the offset at which the cached position was computed
        /// in `cachedPositionOffset` (set to `-1` when invalid). Cache
        /// validation happens at materialisation time by comparing the
        /// cached offset against the current `position` — `advance`
        /// does NOT need to write the cache, keeping the hot path
        /// store-free.
        ///
        /// The default sentinel `-1` is impossible to reach via the
        /// non-negative `position` increment, so a valid cache always
        /// has `cachedPositionOffset >= 0`.
        @usableFromInline
        internal var cachedPosition: RFC_8259.Position?
        @usableFromInline
        internal var cachedPositionOffset: Int

        @inlinable
        @_lifetime(borrow bytes)
        internal init(_ bytes: borrowing Swift.Span<UInt8>) {
            self.bytes = copy bytes
            self.position = 0
            self.cachedPosition = nil
            self.cachedPositionOffset = -1
        }
    }
}

// MARK: - Properties

extension RFC_8259.Span.Lexer {
    /// Total length of the underlying span.
    @inlinable
    internal var totalCount: Int { bytes.count }

    /// Whether the cursor has no more bytes to read.
    @inlinable
    internal var isEmpty: Bool { position >= bytes.count }

    /// Number of bytes remaining (>= 0).
    @inlinable
    internal var count: Int { bytes.count - position }
}

// MARK: - Peek

extension RFC_8259.Span.Lexer {
    /// Peeks at the next byte without consuming it.
    ///
    /// Returns `nil` at end of input. No position mutation; no cache
    /// invalidation.
    @inlinable
    internal var peek: UInt8? {
        guard position < bytes.count else { return nil }
        return bytes[position]
    }

    /// Peek at the byte `offset` bytes ahead of the current position.
    ///
    /// Used for limited single-byte lookahead during number / string
    /// lexing. Returns `nil` if the offset would read past the input.
    @inlinable
    internal func peek(offset: Int) -> UInt8? {
        let idx = position &+ offset
        guard idx < bytes.count else { return nil }
        return bytes[idx]
    }
}

// MARK: - Advance

extension RFC_8259.Span.Lexer {
    /// Advances by one byte and returns it.
    ///
    /// Caller must ensure the cursor is not at end of input — the
    /// Span lexer's caller pattern always `peek`s first.
    ///
    /// Cache invalidation is performed by the position-computation
    /// helper at materialisation time (`materializedPosition()`
    /// compares the cached offset against the current `position` and
    /// recomputes on mismatch). Doing the invalidation here would add
    /// an unnecessary `Optional<RFC_8259.Position>` store per byte on
    /// the hot path; the position-helper-side check is free outside
    /// the error path.
    @inlinable
    @discardableResult
    @_lifetime(self: copy self)
    internal mutating func advance() -> UInt8 {
        let byte = bytes[position]
        position &+= 1
        return byte
    }

    /// Advances by `n` bytes (no return value).
    ///
    /// Caller must ensure `n <= count`.
    @inlinable
    @_lifetime(self: copy self)
    internal mutating func advance(by n: Int) {
        position &+= n
    }
}

// MARK: - StartsWith

extension RFC_8259.Span.Lexer {
    /// Checks whether the bytes starting at `position` match `prefix`.
    ///
    /// Used for literal expectations (`null`, `true`, `false`). Does
    /// not mutate position.
    @inlinable
    internal func startsWith(_ prefix: Swift.Span<UInt8>) -> Bool {
        let n = prefix.count
        guard count >= n else { return false }
        for i in 0..<n {
            if bytes[position &+ i] != prefix[i] { return false }
        }
        return true
    }
}
