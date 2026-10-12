public struct Placement: Equatable, Sendable {
    /// Copied from the MediaInfo.
    public var quarterTurns: Int
    /// Canvas pixels, origin top left: the rectangle the upright picture fills.
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(quarterTurns: Int, x: Double, y: Double, width: Double, height: Double) {
        self.quarterTurns = quarterTurns
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct Segment: Equatable, Sendable {
    public var clip: ClipID
    public var media: MediaID
    public var sourceStart: Time
    public var timelineStart: Time
    public var duration: Time
    public var placement: Placement
    public var hasSound: Bool

    public init(clip: ClipID, media: MediaID, sourceStart: Time, timelineStart: Time, duration: Time, placement: Placement, hasSound: Bool) {
        self.clip = clip
        self.media = media
        self.sourceStart = sourceStart
        self.timelineStart = timelineStart
        self.duration = duration
        self.placement = placement
        self.hasSound = hasSound
    }
}

public struct RenderPlan: Equatable, Sendable {
    public var segments: [Segment]
    public var duration: Time

    public init(segments: [Segment], duration: Time) {
        self.segments = segments
        self.duration = duration
    }
}

public enum PlanError: Error, Equatable, Sendable {
    case unknownMedia(MediaID)
}

/// An empty project gives an empty plan and no error.
public func renderPlan(for project: Project) throws -> RenderPlan {
    RenderPlan(segments: [], duration: .zero)
}
