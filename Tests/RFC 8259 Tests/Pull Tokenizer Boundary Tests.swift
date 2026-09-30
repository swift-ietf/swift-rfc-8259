import Byte
import Lexer
import Testing

@testable import RFC_8259

private func drive(_ span: borrowing Swift.Span<Byte>, limit: Int) -> Result<[String], RFC_8259.Error> {
    var scanner = Lexer.Scanner(span)
    var depth = 0
    var kinds: [String] = []
    do throws(RFC_8259.Error) {
        var steps = 0
        while let kind = try RFC_8259.Pull.Tokens.next(scanner: &scanner, depth: &depth, limit: limit) {
            kinds.append("\(kind)")
            if kind == .string || kind == .number {
                try RFC_8259.Pull.Tokens.skip(value: &scanner, depth: &depth, limit: limit)
            }
            steps += 1
            if steps > 10_000 { break }
        }
        return .success(kinds)
    } catch {
        return .failure(error)
    }
}

private func tokens(_ text: String, limit: Int = 64) -> Result<[String], RFC_8259.Error> {
    let bytes = Array(text.utf8).map(Byte.init(bitPattern:))
    return drive(bytes.span, limit: limit)
}

private func accepts(_ text: String) -> Bool {
    if case .success = tokens(text) { true } else { false }
}

@Suite
struct `Pull tokenizer boundaries` {
    @Test(arguments: [#""a""#, #""\"\\\/\b\f\n\r\t""#, #""é😀""#, #""""#])
    func `valid strings are consumed`(_ text: String) {
        #expect(accepts(text), "\(text)")
    }

    @Test(arguments: [#""\x""#, #""\u12""#, #""abc"#, "\"a\u{01}b\"", #""\u12G4""#])
    func `invalid strings are rejected`(_ text: String) {
        #expect(!accepts(text), "\(text)")
    }

    @Test(arguments: ["0", "-0", "1.5", "1e10", "1E+2", "-3.25e-7", "123"])
    func `valid numbers are consumed`(_ text: String) {
        #expect(accepts(text), "\(text)")
    }

    @Test(arguments: ["01", "-", "1.", ".5", "1e", "1e+", "+1", "-01", "00"])
    func `invalid numbers are rejected`(_ text: String) {
        #expect(!accepts(text), "\(text)")
    }

    @Test(arguments: ["tru", "nul", "fals", "True", "NULL"])
    func `partial or mis-cased literals are rejected`(_ text: String) {
        #expect(!accepts(text), "\(text)")
    }

    @Test
    func `nesting beyond the limit is rejected and at the limit is accepted`() {
        if case .success = tokens("[[[]]]", limit: 2) { Issue.record("depth 3 accepted with limit 2") }
        if case .failure(let error) = tokens("[[]]", limit: 2) { Issue.record("depth 2 rejected: \(error)") }
    }

    @Test
    func `structural tokens come out in order`() throws {
        let kinds = try tokens(#"{"a": [1, true, null]}"#).get()
        #expect(kinds == ["'{'", "string", "':'", "'['", "number", "','", "'true'", "','", "'null'", "']'", "'}'"])
    }
}
