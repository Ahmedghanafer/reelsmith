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
    let canvasWidth = Double(Project.canvasWidth)
    let canvasHeight = Double(Project.canvasHeight)
    var segments: [Segment] = []
    var start = Time.zero
    for clip in project.clips {
        guard let info = project.media[clip.media] else {
            throw PlanError.unknownMedia(clip.media)
        }
        // The turn is counted before the fit.
        let turned = info.quarterTurns % 2 != 0
        let uprightWidth = Double(turned ? info.height : info.width)
        let uprightHeight = Double(turned ? info.width : info.height)
        let scale = min(canvasWidth / uprightWidth, canvasHeight / uprightHeight)
        let width = uprightWidth * scale
        let height = uprightHeight * scale
        let placement = Placement(
            quarterTurns: info.quarterTurns, x: (canvasWidth - width) / 2, y: (canvasHeight - height) / 2,
            width: width, height: height)
        segments.append(Segment(
            clip: clip.id, media: clip.media, sourceStart: clip.sourceStart, timelineStart: start,
            duration: clip.duration, placement: placement, hasSound: info.hasSound))
        start = start + clip.duration
    }
    return RenderPlan(segments: segments, duration: start)
}
