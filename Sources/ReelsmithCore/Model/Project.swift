public struct ClipID: Hashable, Sendable {
    public let raw: Int

    public init(_ raw: Int) {
        self.raw = raw
    }
}

public struct Clip: Equatable, Sendable {
    public var id: ClipID
    public var media: MediaID
    public var sourceStart: Time
    public var duration: Time

    public init(id: ClipID, media: MediaID, sourceStart: Time, duration: Time) {
        self.id = id
        self.media = media
        self.sourceStart = sourceStart
        self.duration = duration
    }
}

public struct Project: Equatable, Sendable {
    public static let canvasWidth = 1080
    public static let canvasHeight = 1920
    public static let framesPerSecond = 30

    /// The main track, in order, always touching.
    public var clips: [Clip]
    /// The facts of every media file a clip uses.
    public var media: [MediaID: MediaInfo]
    /// Starts at 1, each new clip takes it and adds 1.
    public var nextClipID: Int

    public init() {
        clips = []
        media = [:]
        nextClipID = 1
    }

    /// The sum of the clip lengths.
    public var duration: Time {
        .zero
    }

    public func start(of clip: ClipID) -> Time? {
        nil
    }

    /// The clip whose range holds the time, the later one on a join, none at the end.
    public func clip(at time: Time) -> Clip? {
        nil
    }

    /// 1 for the first clip.
    public func position(of clip: ClipID) -> Int? {
        nil
    }
}
