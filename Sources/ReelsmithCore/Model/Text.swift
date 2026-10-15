public struct TextID: Hashable, Codable, Sendable {
    public let raw: Int

    public init(_ raw: Int) {
        self.raw = raw
    }
}

public enum TextFont: String, CaseIterable, Equatable, Codable, Sendable {
    /// Amiri Regular. `allCases` is naskh, naskhBold, system, the order on screen.
    case naskh = "naskh"
    /// Amiri Bold.
    case naskhBold = "naskh-bold"
    /// The platform's own face.
    case system = "system"

    public var words: Words {
        switch self {
        case .naskh:
            return Words("text.font.naskh")
        case .naskhBold:
            return Words("text.font.naskhBold")
        case .system:
            return Words("text.font.system")
        }
    }

    public static let allWords: [String] = ["text.font.naskh", "text.font.naskhBold", "text.font.system"]
}

/// A side of the picture, the same in every language.
public enum TextAlign: String, CaseIterable, Equatable, Codable, Sendable {
    case left = "left"
    case centre = "centre"
    case right = "right"
}

public struct TextStyle: Equatable, Codable, Sendable {
    public var font: TextFont
    /// The font size in canvas pixels.
    public var size: Double
    public var colour: RGB
    public var align: TextAlign
    /// Extra space between two lines as a share of size, 0 for none.
    public var lineSpacing: Double
    /// A line around every letter: black, and white when colour is black.
    public var outline: Bool
    /// A soft black shadow under the letters.
    public var shadow: Bool
    /// A black box at 60 percent behind the block.
    public var box: Bool

    public init(font: TextFont, size: Double, colour: RGB, align: TextAlign, lineSpacing: Double, outline: Bool, shadow: Bool, box: Bool) {
        self.font = font
        self.size = size
        self.colour = colour
        self.align = align
        self.lineSpacing = lineSpacing
        self.outline = outline
        self.shadow = shadow
        self.box = box
    }

    public static let standard = TextStyle(
        font: .naskh, size: 64, colour: RGB(r: 255, g: 255, b: 255), align: .centre, lineSpacing: 0, outline: false,
        shadow: false, box: false)

    public static let palette: [RGB] = [
        RGB(r: 255, g: 255, b: 255), RGB(r: 0, g: 0, b: 0), RGB(r: 255, g: 214, b: 10), RGB(r: 255, g: 69, b: 58),
        RGB(r: 48, g: 209, b: 88), RGB(r: 10, g: 132, b: 255), RGB(r: 255, g: 105, b: 180),
        RGB(r: 142, g: 142, b: 147),
    ]
}

public struct TextRange: Equatable, Codable, Sendable {
    /// Timeline time, a whole frame.
    public var start: Time
    /// Whole frames.
    public var duration: Time

    public init(start: Time, duration: Time) {
        self.start = start
        self.duration = duration
    }
}

public enum TextSpan: Equatable, Codable, Sendable {
    /// From zero to the end of the project, whatever its length becomes.
    case whole
    case range(TextRange)
}

public struct TextItem: Equatable, Codable, Sendable {
    public var id: TextID
    /// As typed. A line break is "\n".
    public var string: String
    public var span: TextSpan
    /// Canvas pixels: the centre of the block.
    public var x: Double
    public var y: Double
    /// Degrees clockwise, above minus 180 and at most 180.
    public var rotation: Double
    public var style: TextStyle

    public init(id: TextID, string: String, span: TextSpan, x: Double, y: Double, rotation: Double, style: TextStyle) {
        self.id = id
        self.string = string
        self.span = span
        self.x = x
        self.y = y
        self.rotation = rotation
        self.style = style
    }

    /// The string is empty or holds only spaces and line breaks.
    public var isBlank: Bool {
        string.allSatisfy { $0 == " " || $0.isNewline }
    }
}
