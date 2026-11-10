extension RFC_8259 {

    public enum Encode {}
}

extension RFC_8259.Encode.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .depthExceeded(let maxDepth):
            return "JSON encoding exceeded maximum depth of \(maxDepth)"
        }
    }
}

extension RFC_8259.Encode {

    @inlinable
    public static func encode(
        _ value: RFC_8259.Value,
        options: RFC_8259.Encode.Options = RFC_8259.Encode.Options()
    ) -> [UInt8] {
        var buffer: [UInt8] = []
        var encoder = Encoder(options: options)
        do throws(RFC_8259.Encode.Error) {
            try encoder.encode(value, into: &buffer)
        } catch {
            preconditionFailure(
                "JSON encoding exceeded maximum depth despite non-throwing contract: \(error)"
            )
        }
        return buffer
    }

    @inlinable
    public static func encode<Buffer: Swift.RangeReplaceableCollection>(
        _ value: RFC_8259.Value,
        into buffer: inout Buffer,
        options: RFC_8259.Encode.Options = RFC_8259.Encode.Options()
    ) where Buffer.Element == UInt8 {
        var encoder = Encoder(options: options)
        do throws(RFC_8259.Encode.Error) {
            try encoder.encode(value, into: &buffer)
        } catch {
            preconditionFailure(
                "JSON encoding exceeded maximum depth despite non-throwing contract: \(error)"
            )
        }
    }
}
