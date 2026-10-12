/// The one value the start screen draws.
public enum StartState: Equatable, Sendable {
    case idle
    case copying
    case failed
    /// Carries the project to open.
    case ready(Project)

    /// What happened on the start screen.
    public enum Event: Equatable, Sendable {
        /// The picker closed with this many videos chosen.
        case pickerClosed(chosen: Int)
        /// Copying ended. These are the facts that could be read, in the order chosen.
        case copyingEnded([MediaInfo])
        /// She confirmed that none of the videos could be read.
        case failureConfirmed
    }

    /// Every key `words` can give.
    public static let allWords: [String] = ["start.copying", "start.noneReadable"]

    public var words: Words? {
        switch self {
        case .idle, .ready:
            return nil
        case .copying:
            return Words("start.copying")
        case .failed:
            return Words("start.noneReadable")
        }
    }

    /// The moves between the cases. An event that has no meaning in a case leaves it unchanged.
    public func after(_ event: Event) -> StartState {
        switch (self, event) {
        case (.idle, .pickerClosed(let chosen)):
            return chosen > 0 ? .copying : .idle
        case (.copying, .copyingEnded(let facts)):
            let project = reduce(EditorState(project: Project()), .addClips(facts)).project
            return project.clips.isEmpty ? .failed : .ready(project)
        case (.failed, .failureConfirmed):
            return .idle
        default:
            return self
        }
    }
}
