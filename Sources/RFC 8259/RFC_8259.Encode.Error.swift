extension RFC_8259.Encode {
    public enum Error: Swift.Error, Sendable, Hashable {

        case depthExceeded(maxDepth: Int)
    }
}
