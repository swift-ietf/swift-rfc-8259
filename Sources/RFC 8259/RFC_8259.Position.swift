/// RFC_8259.Position.swift
/// swift-rfc-8259
///
/// Position within JSON input for error reporting

extension RFC_8259 {
    /// Position within the JSON input for error reporting.
    ///
    /// Composes ecosystem types: `Text.Position` for the byte offset
    /// and `Text.Location` for the human-readable line:column pair.
    public struct Position: Sendable, Hashable {
        /// Byte offset from start of input (0-indexed).
        public let offset: Text.Position

        /// Line and column (both 1-indexed, column in UTF-8 bytes).
        public let location: Text.Location

        public init(offset: Text.Position, location: Text.Location) {
            self.offset = offset
            self.location = location
        }
    }
}

extension RFC_8259.Position: CustomStringConvertible {
    public var description: String {
        "line \(location.line), column \(location.column) (byte \(Int(bitPattern: offset)))"
    }
}
