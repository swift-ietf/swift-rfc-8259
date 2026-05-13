/// RFC_8259.Lexer.Span.Position.swift
/// swift-rfc-8259
///
/// Lazy position computation for the Span cursor.
///
/// The `RFC_8259.Position` is built on demand by scanning the
/// consumed prefix for newlines. The scan is O(consumed bytes), but
/// fires only at error sites or when the parser surfaces a position
/// externally — never on the per-byte hot path. The result is cached
/// on the cursor's `cachedPosition` field; repeated reads at the same
/// byte offset don't re-scan. The cache is invalidated on every
/// `advance` / `advance(by:)`.
///
/// File name preserves the architecture doc's wording — the type
/// itself lives at `RFC_8259.Span.Lexer`, see the namespace note in
/// `RFC_8259.Lexer.Span.swift`.

import Index_Primitives

extension RFC_8259.Span.Lexer {
    /// The current position materialised as `RFC_8259.Position`.
    ///
    /// Lazy: scans the consumed prefix on first read after the last
    /// `advance` and caches the result. The next `advance` invalidates
    /// the cache.
    ///
    /// Cost: O(consumed bytes) per cache miss. Amortised cost per byte
    /// is zero — error sites and external position reads are rare
    /// relative to per-byte advances on non-pathological inputs.
    ///
    /// Returns an owned, Escapable, Copyable `RFC_8259.Position`; no
    /// lifetime annotation is required on the result. The mutation
    /// (cache write) takes `@_lifetime(self: copy self)`.
    @inlinable
    @_lifetime(self: copy self)
    internal mutating func materializedPosition() -> RFC_8259.Position {
        // Cache hit: cached offset matches the current cursor offset.
        if cachedPositionOffset == self.position, let cached = cachedPosition {
            return cached
        }
        let computed = self.computePosition()
        cachedPosition = computed
        cachedPositionOffset = self.position
        return computed
    }

    /// Pure compute path — no cache read/write. Used at the first cache
    /// miss; callers should prefer `materializedPosition()` which caches.
    @inlinable
    internal func computePosition() -> RFC_8259.Position {
        positionAt(byteOffset: self.position)
    }

    /// Compute an `RFC_8259.Position` for an arbitrary previously-recorded
    /// byte offset. Used by the parser to attach a position to errors
    /// whose start was captured before the failing scan. Avoids storing
    /// a full position on the hot path.
    ///
    /// Cost: O(byteOffset) per call. Only fires on error paths.
    @inlinable
    internal func positionAt(byteOffset: Int) -> RFC_8259.Position {
        var line: UInt = 1
        var lastNewline: Int = -1
        let endIndex = Swift.min(byteOffset, bytes.count)
        for i in 0..<endIndex {
            if bytes[i] == 0x0A { // \n
                line &+= 1
                lastNewline = i
            }
        }
        let column = byteOffset - lastNewline
        let offset = Text.Position(Ordinal(UInt(byteOffset)))
        let location = Text.Location(
            line: Text.Line.Number(line),
            column: Text.Line.Column(Cardinal(UInt(column)))
        )
        return RFC_8259.Position(offset: offset, location: location)
    }
}
