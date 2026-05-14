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
    }
}

// MARK: - Decode callAsFunction

extension RFC_8259.Decode {
    /// Decodes a byte collection to a JSON value.
    ///
    /// Dispatches to the wholesale fast path when the collection
    /// exposes contiguous storage (the case for `[UInt8]` /
    /// `ContiguousArray<UInt8>` / `ArraySlice<UInt8>` etc.). Falls back
    /// to the generic `RFC_8259.Parser<Input.Buffer>` slow path for
    /// non-contiguous inputs.
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
    ) throws(RFC_8259.Error) -> RFC_8259.Value
    where C.Element == UInt8, C.Index: Sendable {
        // Fast path: contiguous storage → Span cursor.
        //
        // `withContiguousStorageIfAvailable` takes a closure with
        // untyped throws; we capture errors into a Result-shaped
        // optional and rethrow with the parser's typed error.
        var parserError: RFC_8259.Error? = nil
        let fastResult: RFC_8259.Value? = bytes.withContiguousStorageIfAvailable {
            (buffer: UnsafeBufferPointer<UInt8>) -> RFC_8259.Value? in
            let span = buffer.span
            do {
                return try RFC_8259.Decode.Implementation.parse(span, maxDepth: maxDepth)
            } catch let error as RFC_8259.Error {
                parserError = error
                return nil
            } catch {
                // Unreachable — Decode.Implementation.parse uses typed throws.
                parserError = nil
                return nil
            }
        } ?? nil
        if let value = fastResult {
            return value
        }
        if let err = parserError {
            throw err
        }
        // Slow path: arbitrary Collection<UInt8>.
        let array = Swift.Array(bytes)
        let input = Input.Buffer(array)
        var parser = RFC_8259.Parser(consume input, maxDepth: maxDepth)
        return try parser.parse()
    }

    /// Decodes a string to a JSON value.
    ///
    /// Dispatches to the wholesale fast path when the string's
    /// UTF-8 view exposes contiguous storage (the case for native Swift
    /// `String` and — on Apple platforms with macOS 26 / iOS 26 — for
    /// bridged `NSString` per the A0 probe in
    /// `Experiments/parse-performance-tier-4-feasibility/`).
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
    ) throws(RFC_8259.Error) -> RFC_8259.Value {
        // Fast path: contiguous UTF-8 storage.
        var parserError: RFC_8259.Error? = nil
        let fastResult: RFC_8259.Value? = string.utf8.withContiguousStorageIfAvailable {
            (buffer: UnsafeBufferPointer<UInt8>) -> RFC_8259.Value? in
            let span = buffer.span
            do {
                return try RFC_8259.Decode.Implementation.parse(span, maxDepth: maxDepth)
            } catch let error as RFC_8259.Error {
                parserError = error
                return nil
            } catch {
                // Unreachable — Decode.Implementation.parse uses typed throws.
                parserError = nil
                return nil
            }
        } ?? nil
        if let value = fastResult {
            return value
        }
        if let err = parserError {
            throw err
        }
        // Slow path: non-contiguous String (rare on Apple platforms).
        return try callAsFunction(Swift.Array(string.utf8), maxDepth: maxDepth)
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
    ) throws(RFC_8259.Error) -> RFC_8259.Value {
        // Fast path: contiguous UTF-8 storage on Substring's utf8 view.
        var parserError: RFC_8259.Error? = nil
        let fastResult: RFC_8259.Value? = string.utf8.withContiguousStorageIfAvailable {
            (buffer: UnsafeBufferPointer<UInt8>) -> RFC_8259.Value? in
            let span = buffer.span
            do {
                return try RFC_8259.Decode.Implementation.parse(span, maxDepth: maxDepth)
            } catch let error as RFC_8259.Error {
                parserError = error
                return nil
            } catch {
                // Unreachable — Decode.Implementation.parse uses typed throws.
                parserError = nil
                return nil
            }
        } ?? nil
        if let value = fastResult {
            return value
        }
        if let err = parserError {
            throw err
        }
        return try callAsFunction(Swift.Array(string.utf8), maxDepth: maxDepth)
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
