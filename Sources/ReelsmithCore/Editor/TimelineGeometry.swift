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

    /// Where the writing of a text bar begins and how wide it may be: from 6 points right of the left end
    /// of the part of the bar that is on the screen to 6 points left of the right end of that part.
    /// `shownX` and `shownWidth` are the part of the strip row that is on the screen, in the points of
    /// `barX`, and so is the x that comes back. The width is 0 for a bar with no part on the screen
    /// and for a part narrower than 12 points.
    public static func writing(
        barX: Double, barWidth: Double, shownX: Double, shownWidth: Double
    ) -> (x: Double, width: Double) {
        return (x: 0, width: 0)
    }
}
