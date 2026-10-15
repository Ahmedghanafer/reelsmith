public struct ClipID: Hashable, Codable, Sendable {
    public let raw: Int

    public init(_ raw: Int) {
        self.raw = raw
    }
}

public struct Clip: Equatable, Codable, Sendable {
    public var id: ClipID
    public var media: MediaID
    public var sourceStart: Time
    public var duration: Time
    /// 0 to 1, a factor on the volume of the clips. 1 when a stored file lacks it.
    public var volume: Double

    public init(id: ClipID, media: MediaID, sourceStart: Time, duration: Time, volume: Double = 1) {
        self.id = id
        self.media = media
        self.sourceStart = sourceStart
        self.duration = duration
        self.volume = volume
    }

    /// The coding keys and the encoding stay synthesized. A file written before volume existed reads as 1.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(ClipID.self, forKey: .id)
        media = try container.decode(MediaID.self, forKey: .media)
        sourceStart = try container.decode(Time.self, forKey: .sourceStart)
        duration = try container.decode(Time.self, forKey: .duration)
        volume = try container.decodeIfPresent(Double.self, forKey: .volume) ?? 1
    }
}

public struct Project: Equatable, Codable, Sendable {
    public static let framesPerSecond = 30

    /// The shape every picture is fitted into.
    public var canvas: Canvas
    /// The main track, in order, always touching.
    public var clips: [Clip]
    /// The facts of every media file a clip uses.
    public var media: [MediaID: MediaInfo]
    /// Starts at 1, each new clip takes it and adds 1.
    public var nextClipID: Int
    /// In drawing order, the later one on top.
    public var texts: [TextItem]
    /// Starts at 1, each new text takes it and adds 1.
    public var nextTextID: Int
    /// The sound of every clip, 0 to 1.
    public var clipVolume: Double
    public var clipsMuted: Bool
    /// At most one music, which begins at the start of the video.
    public var music: Music?

    public init(canvas: Canvas = .portrait) {
        self.canvas = canvas
        clips = []
        media = [:]
        nextClipID = 1
        texts = []
        nextTextID = 1
        clipVolume = 1
        clipsMuted = false
        music = nil
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

    public func text(_ id: TextID) -> TextItem? {
        texts.first(where: { $0.id == id })
    }

    /// 1 for the first text of the list.
    public func position(of text: TextID) -> Int? {
        guard let index = texts.firstIndex(where: { $0.id == text }) else {
            return nil
        }
        return index + 1
    }

    /// Whole: zero to the project length. A range is cut at the project end. Nil for an unknown id,
    /// for an empty project, and for a range that starts at or after the end.
    public func range(of text: TextID) -> TextRange? {
        guard let item = self.text(text) else {
            return nil
        }
        let end = duration
        switch item.span {
        case .whole:
            return end > .zero ? TextRange(start: .zero, duration: end) : nil
        case .range(let range):
            guard range.start < end else {
                return nil
            }
            return TextRange(start: range.start, duration: min(range.duration, end - range.start))
        }
    }

    /// The smaller of what is left of the file after the start of the music and the project length.
    /// Nil with no music and for an empty project.
    public var heardMusic: Time? {
        guard let music, !clips.isEmpty else {
            return nil
        }
        return min(music.file.duration - music.start, duration)
    }

    /// Canvas, clips, media, clipVolume, clipsMuted and music are equal. The texts may differ.
    public func sameFootage(as other: Project) -> Bool {
        canvas == other.canvas && clips == other.clips && media == other.media
            && clipVolume == other.clipVolume && clipsMuted == other.clipsMuted && music == other.music
    }
}

extension Project {
    /// "<media raw> <sourceStart ticks>+<duration ticks> <volume times 100, rounded> <v or p>", nil for an unknown
    /// id. "v" for a video, "p" for a photo. Digits 0 to 9 in every language. Example: "blue 0+1800 100 v".
    public func clipInfo(_ id: ClipID) -> String? {
        guard let clip = clips.first(where: { $0.id == id }) else {
            return nil
        }
        let kind = media[clip.media]?.kind == .photo ? "p" : "v"
        return clip.media.raw + " " + String(clip.sourceStart.ticks) + "+" + String(clip.duration.ticks) + " "
            + String(Int((clip.volume * 100).rounded())) + " " + kind
    }
}
