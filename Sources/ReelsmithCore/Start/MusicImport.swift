/// The state the music part draws while a file comes in.
public enum MusicImport: Equatable, Sendable {
    case idle
    case copying
    case failed(isProtected: Bool)

    public enum Event: Equatable, Sendable {
        /// A file or a video was chosen.
        case picked
        /// The Engine gave its facts.
        case imported
        /// The Engine threw.
        case refused(isProtected: Bool)
        case failureConfirmed
    }

    /// Every key `words` can give.
    public static let allWords: [String] = []

    /// Nil when idle.
    public var words: Words? {
        nil
    }

    /// The five moves. Every other pair leaves the case unchanged.
    public func after(_ event: Event) -> MusicImport {
        self
    }
}
