/// Where a time sits on the timeline strip, in points. Declared here, not built yet.
public enum TimelineGeometry {
    public static let pointsPerSecond: Double = 60

    /// 60 ticks, a tenth of a second.
    public static let minimumClip: Time = Time(ticks: 60)

    public static func x(of time: Time) -> Double {
        0
    }

    /// Rounded down to a frame, never below zero.
    public static func time(atX x: Double) -> Time {
        .zero
    }

    public static func width(of duration: Time) -> Double {
        0
    }

    /// Whole frames, signed, rounded toward zero: minus 61 points give minus 600 ticks.
    public static func trimAmount(forDragOf points: Double) -> Time {
        .zero
    }
}
