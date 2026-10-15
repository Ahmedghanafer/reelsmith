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

/// The rows of the timeline strip, in points from its top: the clips, the texts under them and, while no text is
/// selected, the music. Folded, the blocks are 24 points high and every row under them moves up 32.
public struct StripRows: Sendable {
    public let clipY: Double
    public let clipHeight: Double
    public let textY: Double
    public let musicY: Double
    /// The height of the text row and of the music row.
    public let rowHeight: Double
    /// The whole strip: 8 points under the text row with a selected text, 4 under the music row without.
    public let height: Double

    public static func of(folded: Bool, textSelected: Bool) -> StripRows {
        let clipHeight: Double = folded ? 24 : 56
        let textY = 8 + clipHeight + 8
        let musicY = textY + 24 + 4
        return StripRows(
            clipY: 8, clipHeight: clipHeight, textY: textY, musicY: musicY, rowHeight: 24,
            height: textSelected ? textY + 24 + 8 : musicY + 24 + 4)
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
