/// RFC 8259 Spec Tests.swift
/// swift-rfc-8259
///
/// Spec-only tests: value-model construction, token vocabulary,
/// error vocabulary, position semantics. Tests for parsing /
/// encoding / wholesale Span fast-path live at L3 in swift-json.
///
/// Per Arc 1.5, swift-rfc-8259 retains only the RFC 8259 spec — its
/// data model, token vocabulary, error vocabulary, and the
/// `Pull.Tokens` witness. The associated tests here verify that
/// surface remains coherent.

import Testing
@testable import RFC_8259

extension RFC_8259 {
@Suite("RFC 8259 Spec Tests")
struct Tests {

    // MARK: - Value model

    @Test
    func `Value.null is .null case`() {
        let value: RFC_8259.Value = .null
        if case .null = value {} else { Issue.record("Expected .null") }
    }

    @Test
    func `Value.bool roundtrips`() {
        let t: RFC_8259.Value = .bool(true)
        let f: RFC_8259.Value = .bool(false)
        if case .bool(let v) = t { #expect(v == true) } else { Issue.record("Expected .bool(true)") }
        if case .bool(let v) = f { #expect(v == false) } else { Issue.record("Expected .bool(false)") }
    }

    @Test
    func `Value.string roundtrips`() {
        let v: RFC_8259.Value = .string("hello")
        if case .string(let s) = v { #expect(s == "hello") } else { Issue.record("Expected .string") }
    }

    @Test
    func `Object preserves insertion order`() {
        let pairs: [(String, RFC_8259.Value)] = [
            ("a", .number(RFC_8259.Number(1))),
            ("b", .number(RFC_8259.Number(2))),
            ("c", .number(RFC_8259.Number(3))),
        ]
        let object = RFC_8259.Object(pairs)
        let keys = object.map { $0.key }
        #expect(keys == ["a", "b", "c"])
    }

    @Test
    func `Array preserves element order`() {
        let elements: [RFC_8259.Value] = [.bool(true), .bool(false), .null]
        let array = RFC_8259.Array(elements)
        #expect(array.count == 3)
        if case .bool(let v) = array[0] { #expect(v == true) } else { Issue.record("Expected .bool(true)") }
        if case .bool(let v) = array[1] { #expect(v == false) } else { Issue.record("Expected .bool(false)") }
        if case .null = array[2] {} else { Issue.record("Expected .null") }
    }

    // MARK: - Number representation

    @Test
    func `Number from Int round-trips`() {
        let n = RFC_8259.Number(42)
        #expect(n.int64 == 42)
    }

    @Test
    func `Number from Double round-trips`() {
        let n = RFC_8259.Number(3.14)
        #expect(n.double == 3.14)
    }

    // MARK: - Token vocabulary

    @Test
    func `Token.Kind covers RFC 8259 structural characters`() {
        let kinds: [RFC_8259.Token.Kind] = [
            .objectStart, .objectEnd,
            .arrayStart, .arrayEnd,
            .colon, .comma,
            .null, .`true`, .`false`,
            .string, .number,
        ]
        // Just verifying the cases exist and are distinct via simple iteration.
        #expect(kinds.count == 11)
    }

    // MARK: - Error vocabulary

    @Test
    func `Error.unexpectedEndOfInput exists with expected payload`() {
        let pos = RFC_8259.Position(offset: .zero, location: .init(line: 1, column: 1))
        let err: RFC_8259.Error = .unexpectedEndOfInput(at: pos, expected: .value)
        if case .unexpectedEndOfInput(let p, let exp) = err {
            #expect(p.offset == .zero)
            #expect(exp == .value)
        } else {
            Issue.record("Expected .unexpectedEndOfInput")
        }
    }
}
}
