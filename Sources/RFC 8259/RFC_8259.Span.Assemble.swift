/// RFC_8259.Span.Assemble.swift
/// swift-rfc-8259
///
/// Helper that assembles an `RFC_8259.Value` from a
/// `RFC_8259.Span.EventStream`. Used by the default fallback path on
/// `JSON.Serializable.deserialize(events:)` via the swift-json wrapper.
///
/// Re-homed from `swift-foundations/swift-json/Sources/JSON/JSON.Assemble.swift`
/// per the streaming-deserialize placement audit's Ticket T-2
/// (`swift-institute/Audits/streaming-deserialize-placement-audit.md`).
/// Both input (events) and output (`RFC_8259.Value`) are RFC-8259-
/// domain; the assemble step composed over an RFC-8259 substrate
/// belongs in the RFC-8259 package. swift-json retains a ~15-LoC thin
/// wrapper to preserve the `JSON.Assemble.from(_:)` call site at
/// `JSON.Serializable.swift:99`.
///
/// Phase A1 of the streaming-deserialize arc per
/// `swift-institute/Research/streaming-json-deserialize-comparative-analysis.md`
/// v1.0.1 §4.3.
///
/// ## Short-circuit (§4.3 mitigation 1 — REQUIRED per A0 §9.3)
///
/// When the input event stream is unforked at position 0 — i.e., the
/// consumer has not yet pulled any events — the helper delegates
/// directly to `RFC_8259.Span.Parser.parse(_:)` over the same byte
/// span via `events.consumeAsParseValue()`. This collapses the
/// default-fallback chain to the status-quo tree path, eliminating
/// the 4.48× silent-regression risk measured in the A0 spike's
/// `check-lifetime-inout-protocol` target.
///
/// The slow path (event-pull-and-rebuild) exists for completeness —
/// it handles the case where a future caller wraps a partial-decode
/// pattern in which events have already been consumed before
/// `RFC_8259.Span.Assemble.from(_:)` fires. The §4.3 default-fallback
/// path never exercises the slow path on existing conformers.

extension RFC_8259.Span {
    /// Helper namespace for assembling `RFC_8259.Value` from event
    /// streams. Called by swift-json's `JSON.Assemble.from(_:)` thin
    /// wrapper on the default-fallback path.
    public enum Assemble {}
}

extension RFC_8259.Span.Assemble {
    /// Assembles an `RFC_8259.Value` by consuming the event stream.
    ///
    /// FAST PATH: if `events.isUnforkedAtPositionZero` is `true`,
    /// delegate to `events.consumeAsParseValue()` which routes through
    /// `RFC_8259.Span.Parser.parse(_:)` over the same span — equivalent
    /// to status-quo `init(jsonBytes:)`. No event-pull, no tree-rebuild
    /// from events.
    ///
    /// SLOW PATH: events have been partially consumed; rebuild the
    /// `RFC_8259.Value` tree by driving the event stream forward.
    /// Used only by future callers wrapping partial-decode patterns —
    /// the §4.3 default-fallback shape exhibited by every existing
    /// conformer hits the FAST PATH.
    ///
    /// Per A0 §9.3, this short-circuit is the BINDING constraint
    /// that makes the §4.3 default-fallback non-regressing.
    @inlinable
    public static func from(_ events: inout RFC_8259.Span.EventStream) throws(RFC_8259.Error) -> RFC_8259.Value {
        // FAST PATH: unforked at position 0 — delegate to Span.Parser.
        if events.isUnforkedAtPositionZero {
            return try events.consumeAsParseValue()
        }
        // SLOW PATH: events partially consumed. Build the tree by
        // driving the stream forward.
        return try buildFromEvents(&events)
    }

    /// Builds an `RFC_8259.Value` by pulling events from the stream.
    /// Used by the slow path when the stream has been partially
    /// consumed.
    ///
    /// Drives `next()` and recurses on `.objectStart` / `.arrayStart`;
    /// reads payloads via `currentString()` / `currentNumber()`. The
    /// chain is equivalent to walking the event stream that a
    /// `RFC_8259.Span.Parser` parse would produce on the same input.
    @inlinable
    public static func buildFromEvents(_ events: inout RFC_8259.Span.EventStream) throws(RFC_8259.Error) -> RFC_8259.Value {
        guard let token = try events.next() else {
            throw .unexpectedEndOfInput(at: events.position(), expected: .value)
        }
        return try buildValue(forToken: token, events: &events)
    }

    /// Builds a JSON value given the current token (already pulled
    /// from the stream).
    @inlinable
    internal static func buildValue(
        forToken token: RFC_8259.Token.Kind,
        events: inout RFC_8259.Span.EventStream
    ) throws(RFC_8259.Error) -> RFC_8259.Value {
        switch token {
        case .null:
            return .null

        case .`true`:
            return .bool(true)

        case .`false`:
            return .bool(false)

        case .string:
            let value = try events.currentString()
            return .string(value)

        case .number:
            let number = try events.currentNumber()
            return .number(number)

        case .objectStart:
            return try buildObject(events: &events)

        case .arrayStart:
            return try buildArray(events: &events)

        case .objectEnd, .arrayEnd, .colon, .comma, .unknown(_):
            throw .unexpectedToken(
                at: events.position(),
                found: token,
                expected: .value
            )
        }
    }

    /// Builds a JSON object (called after `.objectStart` consumed).
    @inlinable
    internal static func buildObject(events: inout RFC_8259.Span.EventStream) throws(RFC_8259.Error) -> RFC_8259.Value {
        var members: [(key: String, value: RFC_8259.Value)] = []
        // Empty object?
        guard let first = try events.next() else {
            throw .unexpectedEndOfInput(at: events.position(), expected: .objectEnd)
        }
        if first == .objectEnd {
            return .object(RFC_8259.Object(members))
        }
        // First member: first should be .string for key.
        guard first == .string else {
            throw .unexpectedToken(
                at: events.position(),
                found: first,
                expected: .objectKey
            )
        }
        let firstKey = try events.currentString()
        try expectColon(&events)
        guard let firstValueToken = try events.next() else {
            throw .unexpectedEndOfInput(at: events.position(), expected: .value)
        }
        let firstValue = try buildValue(forToken: firstValueToken, events: &events)
        members.append((key: firstKey, value: firstValue))

        // Subsequent members.
        while true {
            guard let next = try events.next() else {
                throw .unexpectedEndOfInput(at: events.position(), expected: .objectEnd)
            }
            switch next {
            case .objectEnd:
                return .object(RFC_8259.Object(members))
            case .comma:
                guard let keyToken = try events.next() else {
                    throw .unexpectedEndOfInput(at: events.position(), expected: .objectKey)
                }
                guard keyToken == .string else {
                    throw .unexpectedToken(
                        at: events.position(),
                        found: keyToken,
                        expected: .objectKey
                    )
                }
                let key = try events.currentString()
                try expectColon(&events)
                guard let valueToken = try events.next() else {
                    throw .unexpectedEndOfInput(at: events.position(), expected: .value)
                }
                let value = try buildValue(forToken: valueToken, events: &events)
                members.append((key: key, value: value))
            default:
                throw .unexpectedToken(
                    at: events.position(),
                    found: next,
                    expected: .commaOrEnd
                )
            }
        }
    }

    /// Builds a JSON array (called after `.arrayStart` consumed).
    @inlinable
    internal static func buildArray(events: inout RFC_8259.Span.EventStream) throws(RFC_8259.Error) -> RFC_8259.Value {
        var elements: [RFC_8259.Value] = []
        guard let first = try events.next() else {
            throw .unexpectedEndOfInput(at: events.position(), expected: .arrayEnd)
        }
        if first == .arrayEnd {
            return .array(RFC_8259.Array(elements))
        }
        let firstValue = try buildValue(forToken: first, events: &events)
        elements.append(firstValue)

        while true {
            guard let next = try events.next() else {
                throw .unexpectedEndOfInput(at: events.position(), expected: .arrayEnd)
            }
            switch next {
            case .arrayEnd:
                return .array(RFC_8259.Array(elements))
            case .comma:
                guard let valueToken = try events.next() else {
                    throw .unexpectedEndOfInput(at: events.position(), expected: .value)
                }
                let value = try buildValue(forToken: valueToken, events: &events)
                elements.append(value)
            default:
                throw .unexpectedToken(
                    at: events.position(),
                    found: next,
                    expected: .commaOrEnd
                )
            }
        }
    }

    /// Internal helper: assert the next token is `.colon`.
    @inlinable
    internal static func expectColon(_ events: inout RFC_8259.Span.EventStream) throws(RFC_8259.Error) {
        guard let token = try events.next() else {
            throw .unexpectedEndOfInput(at: events.position(), expected: .colon)
        }
        guard token == .colon else {
            throw .unexpectedToken(
                at: events.position(),
                found: token,
                expected: .colon
            )
        }
    }
}
