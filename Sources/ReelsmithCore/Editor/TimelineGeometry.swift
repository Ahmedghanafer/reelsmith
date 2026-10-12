/// Where a time sits on the timeline strip, in points.
public enum TimelineGeometry {
    public static let pointsPerSecond: Double = 60

    /// 60 ticks, a tenth of a second.
    public static let minimumClip: Time = Time(ticks: 60)

    public static func x(of time: Time) -> Double {
        Double(time.ticks) * pointsPerSecond / 600
    }

    /// Rounded down to a frame, never below zero.
    public static func time(atX x: Double) -> Time {
        Time(ticks: Int64(max(x, 0) * 600 / pointsPerSecond)).roundedDownToFrame
    }

    public static func width(of duration: Time) -> Double {
        x(of: duration)
    }

    /// Whole frames, signed, rounded toward zero: minus 61 points give minus 600 ticks.
    public static func trimAmount(forDragOf points: Double) -> Time {
        let ticks = Int64(points * 600 / pointsPerSecond)
        return Time(ticks: ticks / Time.frame.ticks * Time.frame.ticks)
    }
}
