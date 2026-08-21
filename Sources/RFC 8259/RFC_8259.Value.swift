extension RFC_8259 {

    public enum Value: Sendable, Hashable {

        case null

        case bool(Bool)

        case number(Number)

        case string(String)

        case array(Array)

        case object(Object)
    }
}

extension RFC_8259.Value {

    public var isNull: Bool {
        guard case .null = self else { return false }
        return true
    }

    public var bool: Bool? {
        guard case .bool(let b) = self else { return nil }
        return b
    }

    public var number: RFC_8259.Number? {
        guard case .number(let n) = self else { return nil }
        return n
    }

    public var string: String? {
        guard case .string(let s) = self else { return nil }
        return s
    }

    public var array: RFC_8259.Array? {
        guard case .array(let a) = self else { return nil }
        return a
    }

    public var object: RFC_8259.Object? {
        guard case .object(let o) = self else { return nil }
        return o
    }
}

extension RFC_8259.Value {

    public subscript(_ key: String) -> RFC_8259.Value? {
        object?[key]
    }

    public subscript(_ index: Int) -> RFC_8259.Value? {
        guard let array = self.array,
            array.indices.contains(index)
        else {
            return nil
        }
        return array[index]
    }
}

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

extension RFC_8259.Value {

    public static func from<T>(_ optional: T?, transform: (T) -> RFC_8259.Value) -> RFC_8259.Value {
        guard let value = optional else { return .null }
        return transform(value)
    }
}
