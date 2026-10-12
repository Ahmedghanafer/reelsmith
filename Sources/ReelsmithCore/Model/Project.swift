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
    public static let framesPerSecond = 30

    /// The shape every picture is fitted into.
    public var canvas: Canvas
    /// The main track, in order, always touching.
    public var clips: [Clip]
    /// The facts of every media file a clip uses.
    public var media: [MediaID: MediaInfo]
    /// Starts at 1, each new clip takes it and adds 1.
    public var nextClipID: Int

    public init(canvas: Canvas = .portrait) {
        self.canvas = canvas
        clips = []
        media = [:]
        nextClipID = 1
    }

    /// The sum of the clip lengths.
    public var duration: Time {
        var sum = Time.zero
        for clip in clips {
            sum = sum + clip.duration
        }
        return sum
    }

    public func start(of clip: ClipID) -> Time? {
        var start = Time.zero
        for candidate in clips {
            if candidate.id == clip {
                return start
            }
            start = start + candidate.duration
        }
        return nil
    }

    /// The clip whose range holds the time, the later one on a join, none at the end.
    public func clip(at time: Time) -> Clip? {
        var start = Time.zero
        for candidate in clips {
            let end = start + candidate.duration
            if time >= start && time < end {
                return candidate
            }
            start = end
        }
        return nil
    }

    /// 1 for the first clip.
    public func position(of clip: ClipID) -> Int? {
        guard let index = clips.firstIndex(where: { $0.id == clip }) else {
            return nil
        }
        return index + 1
    }
}
