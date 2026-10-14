/// The size of an exported video, by its short side.
public enum ExportSize: CaseIterable, Equatable, Sendable {
    /// `allCases` is hd720, hd1080, uhd4K, the order on screen.
    case hd720
    case hd1080
    case uhd4K

    /// Pixels: 720, 1080, 2160.
    public var shortSide: Int {
        switch self {
        case .hd720:
            return 720
        case .hd1080:
            return 1080
        case .uhd4K:
            return 2160
        }
    }

    public var words: Words {
        switch self {
        case .hd720:
            return Words("export.size.720")
        case .hd1080:
            return Words("export.size.1080")
        case .uhd4K:
            return Words("export.size.4K")
        }
    }

    /// The keys of `words`, in the order of the cases.
    public static let allWords: [String] = ["export.size.720", "export.size.1080", "export.size.4K"]

    /// The rates offered at this size.
    public var rates: [ExportRate] {
        switch self {
        case .hd720, .hd1080:
            return [.thirty, .sixty]
        case .uhd4K:
            return [.thirty, .sixty]
        }
    }
}

/// The frames a second of an exported video.
public enum ExportRate: CaseIterable, Equatable, Sendable {
    /// `allCases` is thirty, sixty.
    case thirty
    case sixty

    /// 30, 60.
    public var framesPerSecond: Int {
        switch self {
        case .thirty:
            return 30
        case .sixty:
            return 60
        }
    }

    public var words: Words {
        switch self {
        case .thirty:
            return Words("export.rate.30")
        case .sixty:
            return Words("export.rate.60")
        }
    }

    /// The keys of `words`, in the order of the cases.
    public static let allWords: [String] = ["export.rate.30", "export.rate.60"]
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
    public static let standard: ExportSettings = ExportSettings(size: .hd1080, rate: .thirty)

    /// What the export button holds when the editor opens: standard.
    public static let startChoice: ExportSettings = .standard

    /// Pixels: the canvas width times the short side of the size, divided by 1080.
    public func width(on canvas: Canvas) -> Int {
        canvas.width * size.shortSide / 1080
    }

    /// Pixels: the canvas height times the short side of the size, divided by 1080.
    public func height(on canvas: Canvas) -> Int {
        canvas.height * size.shortSide / 1080
    }

    /// That size, with the rate kept when the size offers it, else thirty.
    public func choosing(_ size: ExportSize) -> ExportSettings {
        ExportSettings(size: size, rate: size.rates.contains(rate) ? rate : .thirty)
    }

    /// That rate when the size offers it, else these settings unchanged.
    public func choosing(_ rate: ExportRate) -> ExportSettings {
        size.rates.contains(rate) ? ExportSettings(size: size, rate: rate) : self
    }
}
