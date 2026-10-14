/// The size of an exported video, by its short side.
public enum ExportSize: CaseIterable, Equatable, Sendable {
    /// `allCases` is hd720, hd1080, uhd4K, the order on screen.
    case hd720
    case hd1080
    case uhd4K

    /// Pixels: 720, 1080, 2160.
    public var shortSide: Int {
        0
    }

    public var words: Words {
        Words("")
    }

    /// The keys of `words`, in the order of the cases.
    public static let allWords: [String] = []

    /// The rates offered at this size.
    public var rates: [ExportRate] {
        []
    }
}

/// The frames a second of an exported video.
public enum ExportRate: CaseIterable, Equatable, Sendable {
    /// `allCases` is thirty, sixty.
    case thirty
    case sixty

    /// 30, 60.
    public var framesPerSecond: Int {
        0
    }

    public var words: Words {
        Words("")
    }

    /// The keys of `words`, in the order of the cases.
    public static let allWords: [String] = []
}

/// The size and the rate of one export.
public struct ExportSettings: Equatable, Sendable {
    public var size: ExportSize
    public var rate: ExportRate

    public init(size: ExportSize, rate: ExportRate) {
        self.size = size
        self.rate = rate
    }

    /// hd1080 at thirty: every export before the choice existed, and every preview.
    public static let standard = ExportSettings(size: .hd720, rate: .sixty)

    /// What the export button holds when the editor opens.
    public static let startChoice = ExportSettings(size: .hd720, rate: .sixty)

    /// Pixels: the canvas width times the short side of the size, divided by 1080.
    public func width(on canvas: Canvas) -> Int {
        0
    }

    /// Pixels: the canvas height times the short side of the size, divided by 1080.
    public func height(on canvas: Canvas) -> Int {
        0
    }

    /// That size, with the rate kept when the size offers it, else thirty.
    public func choosing(_ size: ExportSize) -> ExportSettings {
        self
    }

    /// That rate when the size offers it, else these settings unchanged.
    public func choosing(_ rate: ExportRate) -> ExportSettings {
        self
    }
}
