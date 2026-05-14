/// Span.Assemble Tests.swift
/// swift-rfc-8259
///
/// Tests for `RFC_8259.Span.Assemble` — the event-stream-to-Value
/// assembler re-homed from `swift-json/JSON.Assemble` per the
/// streaming-deserialize placement audit's Ticket T-2.
///
/// Coverage:
/// - FAST PATH: `from(_:)` short-circuits through
///   `events.consumeAsParseValue()` when the stream is unforked at
///   position 0.
/// - SLOW PATH: `buildFromEvents(_:)` rebuilds the tree by driving
///   the event stream forward after a partial advance.
/// - Round-trip: `Assemble.from` produces the same `RFC_8259.Value`
///   as the direct `RFC_8259.Span.Parser.parse(_:)` path.

import Testing
@testable import RFC_8259

@Suite("Span.Assemble Tests")
struct SpanAssembleTests {

    @Test
    func `Assemble.from short-circuits at position 0 and returns parsed value`() throws {
        let bytes: [UInt8] = Swift.Array(#"{"name":"alice","age":30,"tags":["x","y"]}"#.utf8)
        try bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) throws(RFC_8259.Error) in
            let span = buf.span
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            let unforkedBefore: Bool = stream.isPristine
            #expect(unforkedBefore)
            let value = try Lexer.Pull.Assemble.from(&stream, strategy: RFC_8259.Pull.Assemble.self)
            // The short-circuit fully consumed the stream.
            let unforkedAfter: Bool = stream.isPristine
            #expect(!unforkedAfter)
            // Verify object structure.
            #expect(value.object != nil)
            #expect(value["name"]?.string == "alice")
            #expect(value["age"]?.number?.int64 == 30)
            #expect(value["tags"]?.array?.count == 2)
        }
    }

    @Test
    func `Assemble.from slow path after partial advance rebuilds via events`() throws {
        // Pull one event manually before calling Assemble.from so that
        // isPristine becomes false; the helper then routes
        // through the slow event-pull-and-rebuild path.
        let bytes: [UInt8] = Swift.Array(#"[1,2,3]"#.utf8)
        try bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) throws(RFC_8259.Error) in
            let span = buf.span
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            // Pull and discard the leading `.arrayStart` so the slow
            // path picks up from inside the array. Note: this leaves
            // the assembler to build a partial value — we don't expect
            // a full `[1,2,3]` array, but a value that buildFromEvents
            // reconstructs starting at the next token (the number 1).
            let firstToken = try stream.next()
            #expect(firstToken == .arrayStart)
            let unforkedAfterAdvance: Bool = stream.isPristine
            #expect(!unforkedAfterAdvance)
            // buildFromEvents pulls the next token (.number) and
            // returns just that value — confirms the slow path is
            // exercised and produces a coherent partial result.
            let value = try Lexer.Pull.Assemble.from(&stream, strategy: RFC_8259.Pull.Assemble.self)
            #expect(value.number?.int64 == 1)
        }
    }

    @Test
    func `Assemble.from on null produces .null value`() throws {
        let bytes: [UInt8] = Swift.Array("null".utf8)
        try bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) throws(RFC_8259.Error) in
            let span = buf.span
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            let value = try Lexer.Pull.Assemble.from(&stream, strategy: RFC_8259.Pull.Assemble.self)
            #expect(value.isNull)
        }
    }

    @Test
    func `Assemble.from output matches direct Span.Parser output`() throws {
        // Round-trip: the assembler's output via Assemble.from MUST
        // equal the direct Span.Parser.parse(_:) output on the same
        // bytes. This pins the FAST PATH's semantics against the
        // existing Span.Parser surface.
        let bytes: [UInt8] = Swift.Array(#"{"a":1,"b":[true,null,"s"]}"#.utf8)
        try bytes.withUnsafeBufferPointer { (buf: UnsafeBufferPointer<UInt8>) throws(RFC_8259.Error) in
            let span = buf.span
            // Direct parse.
            let direct = try RFC_8259.Span.Parser.parse(span, maxDepth: 512)
            // Via Assemble (FAST PATH).
            var stream = Lexer.Pull.Stream<RFC_8259.Pull.Tokens>(span)
            let assembled = try Lexer.Pull.Assemble.from(&stream, strategy: RFC_8259.Pull.Assemble.self)
            #expect(direct == assembled)
        }
    }
}
