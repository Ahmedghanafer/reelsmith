public struct Words: Equatable, Sendable {
    /// A word key written screen.thing, for example "export.saved".
    public var key: String
    /// Put into the text at %1$@, %2$@ and so on. Numbers are handed over as text with the digits 0 to 9.
    public var arguments: [String]

    public init(_ key: String, _ arguments: [String] = []) {
        self.key = key
        self.arguments = arguments
    }
}
