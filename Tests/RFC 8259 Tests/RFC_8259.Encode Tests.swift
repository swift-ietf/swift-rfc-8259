import RFC_8259
import Testing

enum `RFC_8259.Encode Tests` {}

extension `RFC_8259.Encode Tests` {
    @Suite struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension `RFC_8259.Encode Tests` {

    static func text(_ value: RFC_8259.Value, _ options: RFC_8259.Encode.Options = .init()) -> String {
        String(decoding: RFC_8259.Encode.encode(value, options: options), as: UTF8.self)
    }
}

extension `RFC_8259.Encode Tests`.Test.Unit {

    @Test
    func `output is compact and keeps member order`() {
        let value: RFC_8259.Value = ["b": [1, true, nil], "a": "x"]
        #expect(`RFC_8259.Encode Tests`.text(value) == #"{"b":[1,true,null],"a":"x"}"#)
    }

    @Test
    func `pretty printing puts members on their own lines`() {
        let value: RFC_8259.Value = ["a": [1], "e": [:]]
        #expect(
            `RFC_8259.Encode Tests`.text(value, .init(prettyPrint: true))
                == "{\n  \"a\": [\n    1\n  ],\n  \"e\": {}\n}"
        )
    }

    @Test
    func `sorting orders keys by their UTF-8 bytes`() {
        let value: RFC_8259.Value = ["é": 1, "Z": 2, "a": 3]
        #expect(`RFC_8259.Encode Tests`.text(value, .init(sortKeys: true)) == #"{"Z":2,"a":3,"é":1}"#)
    }
}

extension `RFC_8259.Encode Tests`.Test.`Edge Case` {

    @Test
    func `strings escape quotes, backslashes and controls but not slashes or non-ASCII`() {
        let value: RFC_8259.Value = .string("\"\\/\n\u{1}é</")
        #expect(`RFC_8259.Encode Tests`.text(value) == #""\"\\/\n\u0001é</""#)
        #expect(`RFC_8259.Encode Tests`.text(value, .init(escapeSlashes: true)) == #""\"\\\/\n\u0001é<\/""#)
    }
}
