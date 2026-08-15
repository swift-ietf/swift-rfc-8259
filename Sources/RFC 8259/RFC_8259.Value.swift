/// RFC_8259.Value.swift
/// swift-rfc-8259
///
/// JSON value type - the fundamental unit of JSON data

extension RFC_8259 {
    /// A JSON value as defined in RFC 8259 Section 3.
    ///
    /// JSON values can be one of six types: null, boolean, number,
    /// string, array, or object.
    ///
    /// ## RFC 8259 Section 3 Grammar
    ///
    /// ```
    /// value = false / null / true / object / array / number / string
    /// ```
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Type-safe access via computed properties
    /// if let str = value.string {
    ///     print("String: \(str)")
    /// }
    ///
    /// // Subscript access for nested values
    /// let name = value["user"]?["name"]?.string
    /// let first = value["items"]?[0]?.number?.intValue
    /// ```
    public enum Value: Sendable, Hashable {
        /// JSON null value.
        case null

        /// JSON boolean (true or false).
        case bool(Bool)

        /// JSON number (preserves original representation).
        case number(Number)

        /// JSON string.
        case string(String)

        /// JSON array (ordered collection of values).
        case array(Array)

        /// JSON object (collection of key-value pairs).
        case object(Object)
    }
}

// MARK: - Value Type Accessors

extension RFC_8259.Value {
    /// True if this value is null.
    public var isNull: Bool {
        guard case .null = self else { return false }
        return true
    }

    /// The boolean value if this is a bool, nil otherwise.
    public var bool: Bool? {
        guard case .bool(let b) = self else { return nil }
        return b
    }

    /// The number if this is a number, nil otherwise.
    public var number: RFC_8259.Number? {
        guard case .number(let n) = self else { return nil }
        return n
    }

    /// The string value if this is a string, nil otherwise.
    public var string: String? {
        guard case .string(let s) = self else { return nil }
        return s
    }

    /// The array if this is an array, nil otherwise.
    public var array: RFC_8259.Array? {
        guard case .array(let a) = self else { return nil }
        return a
    }

    /// The object if this is an object, nil otherwise.
    public var object: RFC_8259.Object? {
        guard case .object(let o) = self else { return nil }
        return o
    }
}

// MARK: - Value Subscripts

extension RFC_8259.Value {
    /// Subscript for object key access.
    ///
    /// Returns nil if this value is not an object or the key doesn't exist.
    ///
    /// ```swift
    /// let name = value["user"]?["name"]?.string
    /// ```
    public subscript(_ key: String) -> RFC_8259.Value? {
        object?[key]
    }

    /// Subscript for array index access.
    ///
    /// Returns nil if this value is not an array or the index is out of bounds.
    ///
    /// ```swift
    /// let first = value["items"]?[0]
    /// ```
    public subscript(_ index: Int) -> RFC_8259.Value? {
        guard let array = self.array,
            array.indices.contains(index)
        else {
            return nil
        }
        return array[index]
    }
}

// MARK: - Value ExpressibleBy Literals

extension RFC_8259.Value: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}

extension RFC_8259.Value: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension RFC_8259.Value: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .number(RFC_8259.Number(value))
    }
}

extension RFC_8259.Value: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .number(RFC_8259.Number(value))
    }
}

extension RFC_8259.Value: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension RFC_8259.Value: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: RFC_8259.Value...) {
        self = .array(RFC_8259.Array(elements))
    }
}

extension RFC_8259.Value: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, RFC_8259.Value)...) {
        self = .object(RFC_8259.Object(elements.map { (key: $0.0, value: $0.1) }))
    }
}

// MARK: - Value CustomStringConvertible

extension RFC_8259.Value: CustomStringConvertible {
    public var description: String {
        switch self {
        case .null:
            return "null"

        case .bool(let b):
            return b ? "true" : "false"

        case .number(let n):
            return n.description

        case .string(let s):
            // Simple escaping for description (not full JSON encoding)
            var escaped = ""
            for char in s {
                if char == "\\" {
                    escaped += "\\\\"
                } else if char == "\"" {
                    escaped += "\\\""
                } else {
                    escaped.append(char)
                }
            }
            return "\"\(escaped)\""

        case .array(let a):
            return a.description

        case .object(let o):
            return o.description
        }
    }
}

// MARK: - Value Convenience Constructors

extension RFC_8259.Value {
    /// Creates a Value from an optional, returning null if nil.
    public static func from<T>(_ optional: T?, transform: (T) -> RFC_8259.Value) -> RFC_8259.Value {
        guard let value = optional else { return .null }
        return transform(value)
    }
}
