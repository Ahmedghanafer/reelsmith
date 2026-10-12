public struct Time: Hashable, Comparable, Sendable {
    /// 600 ticks are one second.
    public var ticks: Int64

    public init(ticks: Int64) {
        self.ticks = ticks
    }

    /// Exact for 24, 25, 30 and 60 frames a second.
    public init(frames: Int64, perSecond: Int64) {
        ticks = 0
    }

    public static let zero = Time(ticks: 0)

    /// 20 ticks, one frame at 30 a second.
    public static let frame = Time(ticks: 20)

    public var roundedDownToFrame: Time {
        self
    }

    /// "mm:ss", rounded down.
    public var clockText: String {
        ""
    }

    public static func + (a: Time, b: Time) -> Time {
        a
    }

    public static func - (a: Time, b: Time) -> Time {
        a
    }

    public static func < (a: Time, b: Time) -> Bool {
        false
    }
}
