public struct RGB: Equatable, Sendable {
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8

    public init(r: UInt8, g: UInt8, b: UInt8) {
        self.r = r
        self.g = g
        self.b = b
    }
}

public struct TestClip: Equatable, Sendable {
    public var name: String
    public var storedWidth: Int
    public var storedHeight: Int
    public var duration: Time
    public var framesPerSecond: Int
    public var quarterTurns: Int
    public var hasSound: Bool
    /// The colour of the left half of the stored picture.
    public var left: RGB
    /// The colour of the right half.
    public var right: RGB

    public init(name: String, storedWidth: Int, storedHeight: Int, duration: Time, framesPerSecond: Int, quarterTurns: Int, hasSound: Bool, left: RGB, right: RGB) {
        self.name = name
        self.storedWidth = storedWidth
        self.storedHeight = storedHeight
        self.duration = duration
        self.framesPerSecond = framesPerSecond
        self.quarterTurns = quarterTurns
        self.hasSound = hasSound
        self.left = left
        self.right = right
    }

    /// The id is MediaID(name), the file name is name + ".mov".
    public var info: MediaInfo {
        MediaInfo(
            id: MediaID(name), fileName: name + ".mov", width: storedWidth, height: storedHeight, duration: duration,
            quarterTurns: quarterTurns, hasSound: hasSound)
    }

    public static let blue = TestClip(
        name: "blue", storedWidth: 1920, storedHeight: 1080, duration: Time(ticks: 1800), framesPerSecond: 30,
        quarterTurns: 0, hasSound: true, left: RGB(r: 0, g: 0, b: 255), right: RGB(r: 0, g: 0, b: 255))

    public static let red = TestClip(
        name: "red", storedWidth: 1080, storedHeight: 1920, duration: Time(ticks: 2400), framesPerSecond: 30,
        quarterTurns: 0, hasSound: true, left: RGB(r: 255, g: 0, b: 0), right: RGB(r: 255, g: 0, b: 0))

    public static let green = TestClip(
        name: "green", storedWidth: 1080, storedHeight: 1920, duration: Time(ticks: 1200), framesPerSecond: 30,
        quarterTurns: 0, hasSound: false, left: RGB(r: 0, g: 255, b: 0), right: RGB(r: 0, g: 255, b: 0))

    public static let turned = TestClip(
        name: "turned", storedWidth: 1920, storedHeight: 1080, duration: Time(ticks: 1200), framesPerSecond: 30,
        quarterTurns: 1, hasSound: false, left: RGB(r: 255, g: 255, b: 255), right: RGB(r: 0, g: 0, b: 255))

    public static let fast = TestClip(
        name: "fast", storedWidth: 1080, storedHeight: 1920, duration: Time(ticks: 1200), framesPerSecond: 60,
        quarterTurns: 0, hasSound: false, left: RGB(r: 255, g: 255, b: 0), right: RGB(r: 255, g: 255, b: 0))

    public static let all: [TestClip] = [blue, red, green, turned, fast]
}
