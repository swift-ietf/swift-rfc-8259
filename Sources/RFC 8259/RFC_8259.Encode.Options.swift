extension RFC_8259.Encode {

    public struct Options: Sendable {

        public var prettyPrint: Bool

        public var sortKeys: Bool

        public var escapeSlashes: Bool

        public var indent: String

        public var maxDepth: Int = 512

        public init(
            prettyPrint: Bool = false,
            sortKeys: Bool = false,
            escapeSlashes: Bool = false,
            indent: String = "  "
        ) {
            self.prettyPrint = prettyPrint
            self.sortKeys = sortKeys
            self.escapeSlashes = escapeSlashes
            self.indent = indent
        }
    }
}
