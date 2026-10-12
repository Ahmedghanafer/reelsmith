/// The shape of a project. The picture of every clip is fitted whole inside it.
public enum Canvas: CaseIterable, Equatable, Sendable {
    /// 16:9. `allCases` is landscape then portrait, the order on the start screen.
    case landscape
    /// 9:16.
    case portrait

    /// Pixels.
    public var width: Int {
        switch self {
        case .landscape:
            return 1920
        case .portrait:
            return 1080
        }
    }

    /// Pixels.
    public var height: Int {
        switch self {
        case .landscape:
            return 1080
        case .portrait:
            return 1920
        }
    }

    public var words: Words {
        switch self {
        case .landscape:
            return Words("start.landscape")
        case .portrait:
            return Words("start.portrait")
        }
    }

    public static let allWords: [String] = ["start.landscape", "start.portrait"]

    /// The shape the start screen has chosen before she taps.
    public static let startChoice: Canvas = .landscape
}
