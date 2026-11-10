public import Byte

extension RFC_8259 {

    public enum Decode {}
}

extension RFC_8259.Decode {

    @inlinable
    public static func parse(
        _ bytes: borrowing Swift.Span<Byte>
    ) throws(RFC_8259.Error) -> RFC_8259.Value {
        var events = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(bytes, limit: 512)
        let value = try self.value(events: &events)
        if try events.next() != nil {
            throw .trailingContent(at: events.position(at: events.position))
        }
        return value
    }

    @inlinable
    public static func parse(_ bytes: [Byte]) throws(RFC_8259.Error) -> RFC_8259.Value {
        try parse(bytes.span)
    }

    @inlinable
    public static func value(
        events: inout Lexer.Pull.Stream<RFC_8259.Pull.Tokens>
    ) throws(RFC_8259.Error) -> RFC_8259.Value {
        var stack: [Frame] = []
        var token = try next(&events, expected: .value)
        while true {
            var value: RFC_8259.Value
            switch token {
            case .null:
                value = .null

            case .`true`:
                value = .bool(true)

            case .`false`:
                value = .bool(false)

            case .string:
                value = .string(try events.currentString())

            case .number:
                value = .number(try events.currentNumber())

            case .arrayStart:
                let first = try next(&events, expected: .arrayEnd)
                guard first != .arrayEnd else {
                    value = .array(RFC_8259.Array([]))
                    break
                }
                stack.append(.array([]))
                token = first
                continue

            case .objectStart:
                let first = try next(&events, expected: .objectEnd)
                guard first != .objectEnd else {
                    value = .object(RFC_8259.Object([]))
                    break
                }
                let key = try key(after: first, events: &events)
                stack.append(.object([], key: key))
                token = try next(&events, expected: .value)
                continue

            case .objectEnd, .arrayEnd, .colon, .comma, .unknown:
                throw unexpected(token, events: &events, expected: .value)
            }
            while let frame = stack.popLast() {
                switch frame {
                case .array(var elements):
                    elements.append(value)
                    let next = try next(&events, expected: .arrayEnd)
                    if next == .arrayEnd {
                        value = .array(RFC_8259.Array(elements))
                        continue
                    }
                    guard next == .comma else {
                        throw unexpected(next, events: &events, expected: .commaOrEnd)
                    }
                    stack.append(.array(elements))

                case .object(var members, let key):
                    members.append((key: key, value: value))
                    let next = try next(&events, expected: .objectEnd)
                    if next == .objectEnd {
                        value = .object(RFC_8259.Object(members))
                        continue
                    }
                    guard next == .comma else {
                        throw unexpected(next, events: &events, expected: .commaOrEnd)
                    }
                    let following = try self.next(&events, expected: .objectKey)
                    stack.append(.object(members, key: try self.key(after: following, events: &events)))
                }
                break
            }
            if stack.isEmpty {
                return value
            }
            token = try next(&events, expected: .value)
        }
    }
}

extension RFC_8259.Decode {

    @inlinable
    static func next(
        _ events: inout Lexer.Pull.Stream<RFC_8259.Pull.Tokens>,
        expected: RFC_8259.Error.Expected
    ) throws(RFC_8259.Error) -> RFC_8259.Token.Kind {
        guard let token = try events.next() else {
            throw .unexpectedEndOfInput(at: events.position(at: events.position), expected: expected)
        }
        return token
    }

    @inlinable
    static func unexpected(
        _ token: RFC_8259.Token.Kind,
        events: inout Lexer.Pull.Stream<RFC_8259.Pull.Tokens>,
        expected: RFC_8259.Error.Expected
    ) -> RFC_8259.Error {
        .unexpectedToken(at: events.position(at: events.position), found: token, expected: expected)
    }

    @inlinable
    static func key(
        after token: RFC_8259.Token.Kind,
        events: inout Lexer.Pull.Stream<RFC_8259.Pull.Tokens>
    ) throws(RFC_8259.Error) -> String {
        guard token == .string else {
            throw unexpected(token, events: &events, expected: .objectKey)
        }
        let key = try events.currentString()
        let colon = try next(&events, expected: .colon)
        guard colon == .colon else {
            throw unexpected(colon, events: &events, expected: .colon)
        }
        return key
    }
}
