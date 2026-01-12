/// RFC_8259.Parser.swift
/// swift-rfc-8259
///
/// JSON parser (~Copyable)

import Parsing_Primitives

extension RFC_8259 {
    /// JSON value parser.
    ///
    /// The parser builds a `Value` tree from lexer tokens.
    /// It is `~Copyable` to prevent accidental state copies.
    ///
    /// ## Features
    ///
    /// - Depth limiting to prevent stack overflow
    /// - Structured error reporting with positions
    /// - Rejects trailing content after the JSON value
    ///
    /// ## Usage
    ///
    /// ```swift
    /// var input = Parsing.CollectionInput(bytes)
    /// var parser = RFC_8259.Parser(consume input)
    /// let value = try parser.parse()
    /// ```
    public struct Parser<Input: Parsing.Input>: ~Copyable
    where Input.Element == UInt8 {
        /// The underlying lexer.
        @usableFromInline
        internal var lexer: Lexer<Input>

        /// Current nesting depth.
        @usableFromInline
        internal var depth: Int

        /// Maximum allowed nesting depth.
        @usableFromInline
        internal let maxDepth: Int

        /// Lookahead token (consumed but not yet processed).
        @usableFromInline
        internal var lookahead: Token?

        /// Creates a parser for the given input.
        ///
        /// - Parameters:
        ///   - input: The UTF-8 byte input to parse.
        ///   - maxDepth: Maximum nesting depth (default: 512).
        @inlinable
        public init(_ input: consuming Input, maxDepth: Int = 512) {
            self.lexer = Lexer(input)
            self.depth = 0
            self.maxDepth = maxDepth
            self.lookahead = nil
        }

        /// The current position in the input.
        public var currentPosition: Position {
            lexer.currentPosition
        }
    }
}

// MARK: - Parser Public API

extension RFC_8259.Parser {
    /// Parses the input and returns a JSON value.
    ///
    /// - Throws: `RFC_8259.Error` if parsing fails.
    /// - Returns: The parsed JSON value.
    @inlinable
    public mutating func parse() throws(RFC_8259.Error) -> RFC_8259.Value {
        let value = try parseValue()

        // Ensure no trailing content (except whitespace)
        if try nextToken() != nil {
            throw .trailingContent(at: lexer.currentPosition)
        }

        return value
    }
}

// MARK: - Parser Token Handling

extension RFC_8259.Parser {
    /// Gets the next token, using lookahead if available.
    @inlinable
    internal mutating func nextToken() throws(RFC_8259.Error) -> RFC_8259.Token? {
        if let token = lookahead {
            lookahead = nil
            return token
        }
        return try lexer.next()
    }

    /// Puts a token back into the lookahead.
    @inlinable
    internal mutating func pushBack(_ token: RFC_8259.Token) {
        precondition(lookahead == nil, "Cannot push back when lookahead is set")
        lookahead = token
    }
}

// MARK: - Parser Value Parsing

extension RFC_8259.Parser {
    /// Parses a JSON value.
    @inlinable
    internal mutating func parseValue() throws(RFC_8259.Error) -> RFC_8259.Value {
        guard let token = try nextToken() else {
            throw .unexpectedEndOfInput(at: lexer.currentPosition, expected: .value)
        }

        switch token {
        case .null:
            return .null

        case .true:
            return .bool(true)

        case .false:
            return .bool(false)

        case .number(let n):
            return .number(n)

        case .string(let s):
            return .string(s)

        case .arrayStart:
            return try parseArray()

        case .objectStart:
            return try parseObject()

        case .objectEnd, .arrayEnd, .colon, .comma:
            throw .unexpectedToken(
                at: lexer.currentPosition,
                found: token.kind,
                expected: .value
            )
        }
    }
}

// MARK: - Parser Array Parsing

extension RFC_8259.Parser {
    /// Parses a JSON array (after `[` has been consumed).
    @inlinable
    internal mutating func parseArray() throws(RFC_8259.Error) -> RFC_8259.Value {
        // Check depth
        depth += 1
        if depth > maxDepth {
            throw .depthExceeded(at: lexer.currentPosition, limit: maxDepth)
        }

        defer { depth -= 1 }

        var elements: [RFC_8259.Value] = []

        // Check for empty array
        guard let firstToken = try nextToken() else {
            throw .unexpectedEndOfInput(at: lexer.currentPosition, expected: .value)
        }

        if case .arrayEnd = firstToken {
            return .array(RFC_8259.Array(elements))
        }

        // Parse first value
        pushBack(firstToken)
        elements.append(try parseValue())

        // Parse remaining values
        while let token = try nextToken() {
            switch token {
            case .arrayEnd:
                return .array(RFC_8259.Array(elements))

            case .comma:
                // Expect another value
                elements.append(try parseValue())

            default:
                throw .unexpectedToken(
                    at: lexer.currentPosition,
                    found: token.kind,
                    expected: .commaOrEnd
                )
            }
        }

        throw .unexpectedEndOfInput(at: lexer.currentPosition, expected: .arrayEnd)
    }
}

// MARK: - Parser Object Parsing

extension RFC_8259.Parser {
    /// Parses a JSON object (after `{` has been consumed).
    @inlinable
    internal mutating func parseObject() throws(RFC_8259.Error) -> RFC_8259.Value {
        // Check depth
        depth += 1
        if depth > maxDepth {
            throw .depthExceeded(at: lexer.currentPosition, limit: maxDepth)
        }

        defer { depth -= 1 }

        var members: [(key: String, value: RFC_8259.Value)] = []

        // Check for empty object
        guard let firstToken = try nextToken() else {
            throw .unexpectedEndOfInput(at: lexer.currentPosition, expected: .objectKey)
        }

        if case .objectEnd = firstToken {
            return .object(RFC_8259.Object(members))
        }

        // Parse first member
        pushBack(firstToken)
        members.append(try parseMember())

        // Parse remaining members
        while let token = try nextToken() {
            switch token {
            case .objectEnd:
                return .object(RFC_8259.Object(members))

            case .comma:
                // Expect another member
                members.append(try parseMember())

            default:
                throw .unexpectedToken(
                    at: lexer.currentPosition,
                    found: token.kind,
                    expected: .commaOrEnd
                )
            }
        }

        throw .unexpectedEndOfInput(at: lexer.currentPosition, expected: .objectEnd)
    }

    /// Parses a single object member (key: value).
    @inlinable
    internal mutating func parseMember() throws(RFC_8259.Error) -> (key: String, value: RFC_8259.Value) {
        // Expect string key
        guard let keyToken = try nextToken() else {
            throw .unexpectedEndOfInput(at: lexer.currentPosition, expected: .objectKey)
        }

        guard case .string(let key) = keyToken else {
            throw .unexpectedToken(
                at: lexer.currentPosition,
                found: keyToken.kind,
                expected: .objectKey
            )
        }

        // Expect colon
        guard let colonToken = try nextToken() else {
            throw .unexpectedEndOfInput(at: lexer.currentPosition, expected: .colon)
        }

        guard case .colon = colonToken else {
            throw .unexpectedToken(
                at: lexer.currentPosition,
                found: colonToken.kind,
                expected: .colon
            )
        }

        // Parse value
        let value = try parseValue()

        return (key: key, value: value)
    }
}
