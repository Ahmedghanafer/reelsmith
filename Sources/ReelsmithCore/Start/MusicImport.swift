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
    public static let allWords: [String] = ["music.copying", "music.notReadable", "music.protected"]

    /// Nil when idle.
    public var words: Words? {
        switch self {
        case .idle:
            return nil
        case .copying:
            return Words("music.copying")
        case .failed(let isProtected):
            return Words(isProtected ? "music.protected" : "music.notReadable")
        }
    }

    /// The five moves. Every other pair leaves the case unchanged, so a pick while copying changes nothing
    /// and a new pick is the way out of a refusal too.
    public func after(_ event: Event) -> MusicImport {
        switch (self, event) {
        case (.idle, .picked), (.failed, .picked):
            return .copying
        case (.copying, .imported):
            return .idle
        case (.copying, .refused(let isProtected)):
            return .failed(isProtected: isProtected)
        case (.failed, .failureConfirmed):
            return .idle
        default:
            return self
        }
    }
}
