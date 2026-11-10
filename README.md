# swift-rfc-8259

Use this package when you need JSON values as Swift data, want to read or write JSON text, or need a low-level tokenizer that checks JSON text against the RFC 8259 grammar as it scans. Start from `RFC_8259.Value` to build and inspect values, `RFC_8259.Decode.parse(_:)` to read text into a value, `RFC_8259.Encode.encode(_:options:)` to write one, and `RFC_8259.Pull.Tokens` to scan bytes. For `Codable`, streaming and newline-delimited JSON, use swift-json, which reads and writes text through this package.

## Laws

- `RFC_8259.Object` keeps its members in order and may hold the same key twice. Reading a key returns its first member. Setting a key replaces that first member in place, or appends one. Setting a key to nil removes every member with that key.
- Two objects are equal only if they have the same members in the same order.
- `RFC_8259.Number` keeps the text it was written as, and `RFC_8259.Number.description` returns that text. Numbers compare by both their value and their text, so 1 and 1.0 are not equal.
- `RFC_8259.Number.int` and `RFC_8259.Number.isInteger` accept a floating-point number with no fractional part. `RFC_8259.Number.int64` and `RFC_8259.Number.uint64` return nil for any floating-point number.
- `RFC_8259.Value.description` escapes only `"` and `\` in string values and nothing in object keys, so it is not valid JSON for every value.
- `RFC_8259.Pull.Tokens.next(scanner:depth:limit:)` consumes punctuation and the literals `true`, `false` and `null`, but only reports a string or number. The caller must then consume it, for example with `RFC_8259.Pull.Tokens.skip(value:depth:limit:)`.
- The tokenizer checks each token, not the structure around it. It doesn't check that commas, colons and closing brackets are in valid places.
- Each `{` or `[` adds one to the depth. Going past the limit fails, and reaching it exactly is allowed.
- Whitespace is only space, tab, LF and CR. Literals are case-sensitive. Any byte outside a string that can't start a token, including any non-ASCII byte, fails.
- Numbers follow the RFC grammar: an optional `-`, no leading zeros, no `+` sign before the number, and digits required after `.` and after the exponent marker.
- Strings must close, may contain only the escapes the RFC allows, need four hex digits after `\u`, and may not contain a raw control character below 0x20. Bytes above 0x7F inside a string are passed over without UTF-8 checks.
- `RFC_8259.Decode.parse(_:)` reads exactly one value. Anything but whitespace after it fails with `RFC_8259.Error.trailingContent`, empty input fails as an unexpected end of input, and nesting deeper than 512 arrays and objects fails with `RFC_8259.Error.depthExceeded`.
- `RFC_8259.Decode.parse(_:)` keeps object members in order, repeated keys included, and keeps each number's text.
- `RFC_8259.Encode` writes compact JSON unless `prettyPrint` is on. Pretty printing puts each member and element on its own line, indents with two spaces by default, and writes a space after each colon. Empty arrays and objects stay on one line.
- With `sortKeys`, `RFC_8259.Encode` orders keys by their UTF-8 bytes, not by Unicode collation.
- `RFC_8259.Encode` writes strings as UTF-8 without escaping non-ASCII characters. Quote, backslash and control characters are escaped, with the short form where JSON has one and a lowercase hex escape otherwise. A slash is escaped only when `escapeSlashes` is true. A number is written as its text.
