/// RoundTripTests.swift
/// swift-rfc-8259
///
/// Tests for round-trip encode/decode consistency

import Testing
@testable import RFC_8259

@Suite("Round-Trip Tests")
struct RoundTripTests {

    @Test("Round-trip simple values")
    func roundTripSimple() throws {
        for json in ["null", "true", "false"] {
            let value = try RFC_8259.parse(json)
            let encoded = value.encode()
            let reparsed = try RFC_8259.parse(encoded)
            #expect(value == reparsed)
        }
    }

    @Test("Round-trip integers")
    func roundTripIntegers() throws {
        for json in ["0", "1", "-1", "42", "-123", "999999999"] {
            let value = try RFC_8259.parse(json)
            let encoded = value.encode()
            let reparsed = try RFC_8259.parse(encoded)
            #expect(value == reparsed)
        }
    }

    @Test("Round-trip floats")
    func roundTripFloats() throws {
        for json in ["0.0", "3.14", "-2.5", "1.5e10", "1e-5"] {
            let value = try RFC_8259.parse(json)
            let encoded = value.encode()
            let reparsed = try RFC_8259.parse(encoded)
            #expect(value == reparsed)
        }
    }

    @Test("Round-trip strings")
    func roundTripStrings() throws {
        for json in ["\"\"", "\"hello\"", "\"hello\\nworld\"", "\"\\u0041\""] {
            let value = try RFC_8259.parse(json)
            let encoded = value.encode()
            let reparsed = try RFC_8259.parse(encoded)
            #expect(value == reparsed)
        }
    }

    @Test("Round-trip arrays")
    func roundTripArrays() throws {
        for json in ["[]", "[1]", "[1, 2, 3]", "[[1], [2]]"] {
            let value = try RFC_8259.parse(json)
            let encoded = value.encode()
            let reparsed = try RFC_8259.parse(encoded)
            #expect(value == reparsed)
        }
    }

    @Test("Round-trip objects")
    func roundTripObjects() throws {
        let json = "{\"name\":\"John\",\"age\":30}"
        let value = try RFC_8259.parse(json)
        let encoded = value.encode()
        let reparsed = try RFC_8259.parse(encoded)
        #expect(value == reparsed)
    }

    @Test("Round-trip nested structure")
    func roundTripNested() throws {
        let json = "{\"users\":[{\"name\":\"Alice\",\"active\":true}]}"
        let value = try RFC_8259.parse(json)
        let encoded = value.encode()
        let reparsed = try RFC_8259.parse(encoded)
        #expect(value == reparsed)
    }

    @Test("Round-trip preserves number representation")
    func roundTripNumberPreservation() throws {
        // Scientific notation should be preserved
        let json = "1.5e10"
        let value = try RFC_8259.parse(json)
        let encoded = value.encode()
        #expect(String(decoding: encoded, as: UTF8.self) == json)
    }

    @Test("Round-trip complex document")
    func roundTripComplex() throws {
        let json = """
        {"data":{"items":[{"id":1,"name":"first","tags":["a","b"]},{"id":2,"name":"second","tags":[]}],"count":2,"active":true}}
        """
        let value = try RFC_8259.parse(json)
        let encoded = value.encode()
        let reparsed = try RFC_8259.parse(encoded)
        #expect(value == reparsed)
    }
}
