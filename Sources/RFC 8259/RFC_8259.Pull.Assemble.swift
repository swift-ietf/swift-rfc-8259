/// RFC_8259.Pull.Assemble.swift
/// swift-rfc-8259
///
/// JSON assemble strategy for the L1 ``Lexer/Pull/Assemble`` cohort.
///
/// Implements ``Lexer/Pull/Assemble/Strategy`` for RFC 8259 JSON.
/// Supplies:
///
/// - `Tokens` = ``RFC_8259/Pull/Tokens`` (the JSON token witness).
/// - `Value` = ``RFC_8259/Value`` (the JSON value tree).
/// - `consume(bytes:limit:)` — the wholesale fast-path. Delegates to
///   ``RFC_8259/Span/Parser/parse(_:maxDepth:)`` over the same bytes.
///   Per A0 §9.3, this short-circuit is the BINDING constraint that
///   makes the §4.3 default-fallback non-regressing.
/// - `build(events:)` — the slow-path. Walks the event stream and
///   builds ``RFC_8259/Value`` event-by-event. Used only when the
///   stream has been partially consumed before assembly fires (no
///   existing consumer hits this; preserved for completeness).

extension RFC_8259.Pull {
    public enum Assemble: Lexer_Primitives.Lexer.Pull.Assemble.Strategy {
        public typealias Tokens = RFC_8259.Pull.Tokens
        public typealias Value = RFC_8259.Value

        /// Wholesale fast-path — delegates to the Span parser.
        @inlinable
        public static func consume(
            bytes: Swift.Span<UInt8>,
            limit: Int
        ) throws(RFC_8259.Error) -> RFC_8259.Value {
            try RFC_8259.Span.Parser.parse(bytes, maxDepth: limit)
        }

        /// Slow-path — drives the event stream to rebuild the tree.
        @inlinable
        public static func build(
            events: inout Lexer_Primitives.Lexer.Pull.Stream<RFC_8259.Pull.Tokens>
        ) throws(RFC_8259.Error) -> RFC_8259.Value {
            guard let token = try events.next() else {
                throw .unexpectedEndOfInput(
                    at: events.position(at: events.position),
                    expected: .value
                )
            }
            return try buildValue(forToken: token, events: &events)
        }

        @inlinable
        internal static func buildValue(
            forToken token: RFC_8259.Token.Kind,
            events: inout Lexer_Primitives.Lexer.Pull.Stream<RFC_8259.Pull.Tokens>
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
                    at: events.position(at: events.position),
                    found: token,
                    expected: .value
                )
            }
        }

        @inlinable
        internal static func buildObject(
            events: inout Lexer_Primitives.Lexer.Pull.Stream<RFC_8259.Pull.Tokens>
        ) throws(RFC_8259.Error) -> RFC_8259.Value {
            var members: [(key: String, value: RFC_8259.Value)] = []
            guard let first = try events.next() else {
                throw .unexpectedEndOfInput(at: events.position(at: events.position), expected: .objectEnd)
            }
            if first == .objectEnd {
                return .object(RFC_8259.Object(members))
            }
            guard first == .string else {
                throw .unexpectedToken(
                    at: events.position(at: events.position),
                    found: first,
                    expected: .objectKey
                )
            }
            let firstKey = try events.currentString()
            try expectColon(&events)
            guard let firstValueToken = try events.next() else {
                throw .unexpectedEndOfInput(at: events.position(at: events.position), expected: .value)
            }
            let firstValue = try buildValue(forToken: firstValueToken, events: &events)
            members.append((key: firstKey, value: firstValue))

            while true {
                guard let next = try events.next() else {
                    throw .unexpectedEndOfInput(at: events.position(at: events.position), expected: .objectEnd)
                }
                switch next {
                case .objectEnd:
                    return .object(RFC_8259.Object(members))
                case .comma:
                    guard let keyToken = try events.next() else {
                        throw .unexpectedEndOfInput(at: events.position(at: events.position), expected: .objectKey)
                    }
                    guard keyToken == .string else {
                        throw .unexpectedToken(
                            at: events.position(at: events.position),
                            found: keyToken,
                            expected: .objectKey
                        )
                    }
                    let key = try events.currentString()
                    try expectColon(&events)
                    guard let valueToken = try events.next() else {
                        throw .unexpectedEndOfInput(at: events.position(at: events.position), expected: .value)
                    }
                    let value = try buildValue(forToken: valueToken, events: &events)
                    members.append((key: key, value: value))
                default:
                    throw .unexpectedToken(
                        at: events.position(at: events.position),
                        found: next,
                        expected: .commaOrEnd
                    )
                }
            }
        }

        @inlinable
        internal static func buildArray(
            events: inout Lexer_Primitives.Lexer.Pull.Stream<RFC_8259.Pull.Tokens>
        ) throws(RFC_8259.Error) -> RFC_8259.Value {
            var elements: [RFC_8259.Value] = []
            guard let first = try events.next() else {
                throw .unexpectedEndOfInput(at: events.position(at: events.position), expected: .arrayEnd)
            }
            if first == .arrayEnd {
                return .array(RFC_8259.Array(elements))
            }
            let firstValue = try buildValue(forToken: first, events: &events)
            elements.append(firstValue)

            while true {
                guard let next = try events.next() else {
                    throw .unexpectedEndOfInput(at: events.position(at: events.position), expected: .arrayEnd)
                }
                switch next {
                case .arrayEnd:
                    return .array(RFC_8259.Array(elements))
                case .comma:
                    guard let valueToken = try events.next() else {
                        throw .unexpectedEndOfInput(at: events.position(at: events.position), expected: .value)
                    }
                    let value = try buildValue(forToken: valueToken, events: &events)
                    elements.append(value)
                default:
                    throw .unexpectedToken(
                        at: events.position(at: events.position),
                        found: next,
                        expected: .commaOrEnd
                    )
                }
            }
        }

        @inlinable
        internal static func expectColon(
            _ events: inout Lexer_Primitives.Lexer.Pull.Stream<RFC_8259.Pull.Tokens>
        ) throws(RFC_8259.Error) {
            guard let token = try events.next() else {
                throw .unexpectedEndOfInput(at: events.position(at: events.position), expected: .colon)
            }
            guard token == .colon else {
                throw .unexpectedToken(
                    at: events.position(at: events.position),
                    found: token,
                    expected: .colon
                )
            }
        }
    }
}
