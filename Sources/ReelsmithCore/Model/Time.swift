public struct Time: Hashable, Comparable, Sendable {
    /// 600 ticks are one second.
    public var ticks: Int64

    public init(ticks: Int64) {
        self.ticks = ticks
    }

    /// Exact for 24, 25, 30 and 60 frames a second.
    public init(frames: Int64, perSecond: Int64) {
        ticks = frames * 600 / perSecond
    }

    public static let zero = Time(ticks: 0)

    /// 20 ticks, one frame at 30 a second.
    public static let frame = Time(ticks: 20)

    public var roundedDownToFrame: Time {
        let rest = ticks % Time.frame.ticks
        return Time(ticks: ticks - (rest < 0 ? rest + Time.frame.ticks : rest))
    }

    /// "mm:ss", rounded down.
    public var clockText: String {
        let seconds = ticks / 600
        let minutes = seconds / 60
        let rest = seconds % 60
        return (minutes < 10 ? "0" : "") + String(minutes) + ":" + (rest < 10 ? "0" : "") + String(rest)
    }

    public static func + (a: Time, b: Time) -> Time {
        Time(ticks: a.ticks + b.ticks)
    }

    public static func - (a: Time, b: Time) -> Time {
        Time(ticks: a.ticks - b.ticks)
    }

    public static func < (a: Time, b: Time) -> Bool {
        a.ticks < b.ticks
    }
}
