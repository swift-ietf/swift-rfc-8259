import RFC_8259
import Testing

enum `RFC_8259.Decode Tests` {}

extension `RFC_8259.Decode Tests` {
    @Suite struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension `RFC_8259.Decode Tests` {

    static func parse(_ text: String) throws(RFC_8259.Error) -> RFC_8259.Value {
        try RFC_8259.Decode.parse([Byte](utf8: text))
    }
}

extension `RFC_8259.Decode Tests`.Test.Unit {

    @Test
    func `a value reads with its members in order and its numbers' text`() throws {
        let value = try `RFC_8259.Decode Tests`.parse(#" {"b": [1.50, true, null], "a": "x\n", "b": 2} "#)
        let object = try #require(value.object)
        #expect(object.keys == ["b", "a", "b"])
        #expect(object["a"] == .string("x\n"))
        #expect(object["b"]?.array?.first?.number?.description == "1.50")
    }
}

extension `RFC_8259.Decode Tests`.Test.`Edge Case` {

    @Test
    func `anything after the value is refused`() {
        #expect {
            try `RFC_8259.Decode Tests`.parse("1 2")
        } throws: { error in
            guard case .trailingContent = error as? RFC_8259.Error else { return false }
            return true
        }
    }

    @Test
    func `empty input is an unexpected end`() {
        #expect {
            try `RFC_8259.Decode Tests`.parse("  ")
        } throws: { error in
            guard case .unexpectedEndOfInput = error as? RFC_8259.Error else { return false }
            return true
        }
    }
}

extension `RFC_8259.Decode Tests`.Test.`Edge Case` {

    @Test
    func `nesting deeper than 512 is refused`() throws {
        _ = try `RFC_8259.Decode Tests`.parse(String(repeating: "[", count: 512) + String(repeating: "]", count: 512))
        #expect {
            try `RFC_8259.Decode Tests`.parse(String(repeating: "[", count: 513) + String(repeating: "]", count: 513))
        } throws: { error in
            guard case .depthExceeded = error as? RFC_8259.Error else { return false }
            return true
        }
    }
}
