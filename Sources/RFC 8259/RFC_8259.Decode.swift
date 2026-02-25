/// RFC_8259.Decode.swift
/// swift-rfc-8259
///
/// JSON decoding convenience API

import Parser_Primitives

extension RFC_8259 {
    /// Decodes UTF-8 bytes to a JSON value.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Decode from bytes
    /// let value = try RFC_8259.decode(bytes)
    ///
    /// // Decode from string
    /// let value = try RFC_8259.decode("{\"name\": \"John\"}")
    ///
    /// // With custom depth limit
    /// let value = try RFC_8259.decode(bytes, maxDepth: 100)
    /// ```
    public struct Decode: Sendable {
        @usableFromInline
        internal init() {}

        /// Decodes a byte collection to a JSON value.
        ///
        /// - Parameters:
        ///   - bytes: UTF-8 encoded JSON bytes.
        ///   - maxDepth: Maximum nesting depth (default: 512).
        /// - Throws: `RFC_8259.Error` if parsing fails.
        /// - Returns: The parsed JSON value.
        @inlinable
        public func callAsFunction<C: Swift.Collection & Sendable>(
            _ bytes: C,
            maxDepth: Int = 512
        ) throws(RFC_8259.Error) -> Value
        where C.Element == UInt8, C.Index: Sendable {
            let array = Swift.Array(bytes)
            let input = Input.Buffer(array)
            var parser = Parser(consume input, maxDepth: maxDepth)
            return try parser.parse()
        }

        /// Decodes a string to a JSON value.
        ///
        /// - Parameters:
        ///   - string: JSON string (will be converted to UTF-8).
        ///   - maxDepth: Maximum nesting depth (default: 512).
        /// - Throws: `RFC_8259.Error` if parsing fails.
        /// - Returns: The parsed JSON value.
        @inlinable
        public func callAsFunction(
            _ string: String,
            maxDepth: Int = 512
        ) throws(RFC_8259.Error) -> Value {
            try callAsFunction(Swift.Array(string.utf8), maxDepth: maxDepth)
        }

        /// Decodes a substring to a JSON value.
        ///
        /// - Parameters:
        ///   - string: JSON substring.
        ///   - maxDepth: Maximum nesting depth (default: 512).
        /// - Throws: `RFC_8259.Error` if parsing fails.
        /// - Returns: The parsed JSON value.
        @inlinable
        public func callAsFunction(
            _ string: Substring,
            maxDepth: Int = 512
        ) throws(RFC_8259.Error) -> Value {
            try callAsFunction(Swift.Array(string.utf8), maxDepth: maxDepth)
        }
    }
}

// MARK: - Static Accessor

extension RFC_8259 {
    /// The JSON decoder.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let value = try RFC_8259.decode("{\"key\": \"value\"}")
    /// ```
    public static var decode: Decode { Decode() }
}

// MARK: - Convenience Methods

extension RFC_8259 {
    /// Parses a JSON string and returns the value.
    ///
    /// Convenience method equivalent to `RFC_8259.decode(string)`.
    ///
    /// - Parameters:
    ///   - json: The JSON string to parse.
    ///   - maxDepth: Maximum nesting depth (default: 512).
    /// - Throws: `RFC_8259.Error` if parsing fails.
    /// - Returns: The parsed JSON value.
    @inlinable
    public static func parse(
        _ json: String,
        maxDepth: Int = 512
    ) throws(Error) -> Value {
        try decode(json, maxDepth: maxDepth)
    }

    /// Parses JSON bytes and returns the value.
    ///
    /// Convenience method equivalent to `RFC_8259.decode(bytes)`.
    ///
    /// - Parameters:
    ///   - json: UTF-8 encoded JSON bytes.
    ///   - maxDepth: Maximum nesting depth (default: 512).
    /// - Throws: `RFC_8259.Error` if parsing fails.
    /// - Returns: The parsed JSON value.
    @inlinable
    public static func parse<C: Swift.Collection & Sendable>(
        _ json: C,
        maxDepth: Int = 512
    ) throws(Error) -> Value
    where C.Element == UInt8, C.Index: Sendable {
        try decode(json, maxDepth: maxDepth)
    }
}

// MARK: - String Extension

extension String {
    /// Parses this string as JSON.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let value = try "{\"name\": \"John\"}".parseJSON()
    /// ```
    ///
    /// - Parameter maxDepth: Maximum nesting depth (default: 512).
    /// - Throws: `RFC_8259.Error` if parsing fails.
    /// - Returns: The parsed JSON value.
    @inlinable
    public func parseJSON(maxDepth: Int = 512) throws(RFC_8259.Error) -> RFC_8259.Value {
        try RFC_8259.decode(self, maxDepth: maxDepth)
    }
}
