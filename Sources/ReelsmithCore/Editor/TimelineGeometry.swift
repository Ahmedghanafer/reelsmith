/// Where a time sits on the timeline strip, in points, at the scale of 60 points a second.
public enum TimelineGeometry {
    public static let pointsPerSecond: Double = 60

    /// 60 ticks, a tenth of a second.
    public static let minimumClip: Time = Time(ticks: 60)

    public static func x(of time: Time) -> Double {
        TimelineScale.standard.x(of: time)
    }

    /// Rounded down to a frame, never below zero.
    public static func time(atX x: Double) -> Time {
        TimelineScale.standard.time(atX: x)
    }

    public static func width(of duration: Time) -> Double {
        TimelineScale.standard.width(of: duration)
    }

    /// Whole frames, signed, rounded toward zero: minus 61 points give minus 600 ticks.
    public static func trimAmount(forDragOf points: Double) -> Time {
        TimelineScale.standard.trimAmount(forDragOf: points)
    }

    /// Where the writing of a text bar begins and how wide it may be: from 6 points right of the left end
    /// of the part of the bar that is on the screen to 6 points left of the right end of that part.
    /// `shownX` and `shownWidth` are the part of the strip row that is on the screen, in the points of
    /// `barX`, and so is the x that comes back. The width is 0 for a bar with no part on the screen
    /// and for a part narrower than 12 points.
    public static func writing(
        barX: Double, barWidth: Double, shownX: Double, shownWidth: Double
    ) -> (x: Double, width: Double) {
        let inset: Double = 6
        let left = max(barX, shownX)
        let right = min(barX + barWidth, shownX + shownWidth)
        return (x: left + inset, width: max(right - left - 2 * inset, 0))
    }
}

/// The scale of the timeline strip, held between `least` and `most` points a second.
public struct TimelineScale: Equatable, Sendable {
    public var pointsPerSecond: Double

    public init(pointsPerSecond: Double) {
        self.pointsPerSecond = min(max(pointsPerSecond, Self.least), Self.most)
    }

    public static let standard = TimelineScale(pointsPerSecond: 60)
    public static let least: Double = 10
    public static let most: Double = 240

    /// Times the factor, held. A factor that is not finite or not above 0 gives the scale unchanged.
    public func zoomed(by factor: Double) -> TimelineScale {
        guard factor.isFinite && factor > 0 else {
            return self
        }
        return TimelineScale(pointsPerSecond: pointsPerSecond * factor)
    }

    public func x(of time: Time) -> Double {
        Double(time.ticks) * pointsPerSecond / 600
    }

    /// Rounded down to a frame, never below zero.
    public func time(atX x: Double) -> Time {
        Time(ticks: Int64(max(x, 0) * 600 / pointsPerSecond)).roundedDownToFrame
    }

    public func width(of duration: Time) -> Double {
        x(of: duration)
    }

    /// Whole frames, signed, rounded toward zero.
    public func trimAmount(forDragOf points: Double) -> Time {
        let ticks = Int64(points * 600 / pointsPerSecond)
        return Time(ticks: ticks / Time.frame.ticks * Time.frame.ticks)
    }
}
