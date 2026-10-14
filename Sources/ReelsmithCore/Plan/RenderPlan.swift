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

public struct TextLayer: Equatable, Sendable {
    public var text: TextID
    public var string: String
    /// The start of the text's range in the project.
    public var timelineStart: Time
    /// Its length. The layer is drawn in a frame at time t when timelineStart <= t < timelineStart + duration.
    public var duration: Time
    /// Canvas pixels: the centre of the block.
    public var x: Double
    public var y: Double
    public var rotation: Double
    public var style: TextStyle
    /// Canvas pixels: a line longer than this wraps. The canvas width times TextGeometry.wrapShare.
    public var lineWidth: Double

    public init(text: TextID, string: String, timelineStart: Time, duration: Time, x: Double, y: Double, rotation: Double, style: TextStyle, lineWidth: Double) {
        self.text = text
        self.string = string
        self.timelineStart = timelineStart
        self.duration = duration
        self.x = x
        self.y = y
        self.rotation = rotation
        self.style = style
        self.lineWidth = lineWidth
    }
}

public struct MusicLayer: Equatable, Sendable {
    /// The id of the music file.
    public var media: MediaID
    /// Inside the media folder.
    public var fileName: String
    /// The start in the file.
    public var sourceStart: Time
    /// The music sounds on the timeline from zero for this long.
    public var duration: Time
    public var volume: Double
    /// As stored, cut to half of duration, rounded down to a tick. The fade in runs over the first of the layer.
    public var fadeIn: Time
    /// As stored, cut to half of duration, rounded down to a tick. The fade out runs over the last of the layer.
    public var fadeOut: Time

    public init(media: MediaID, fileName: String, sourceStart: Time, duration: Time, volume: Double, fadeIn: Time, fadeOut: Time) {
        self.media = media
        self.fileName = fileName
        self.sourceStart = sourceStart
        self.duration = duration
        self.volume = volume
        self.fadeIn = fadeIn
        self.fadeOut = fadeOut
    }
}

public struct SoundPlan: Equatable, Sendable {
    /// The volume of the clips as heard: 0 when they are muted.
    public var clipVolume: Double
    /// Nil with no music and when nothing of it is heard.
    public var music: MusicLayer?

    public init(clipVolume: Double, music: MusicLayer?) {
        self.clipVolume = clipVolume
        self.music = music
    }

    /// 1, and no music.
    public static let plain: SoundPlan = SoundPlan(clipVolume: 1, music: nil)
}

public struct RenderPlan: Equatable, Sendable {
    public var segments: [Segment]
    public var duration: Time
    /// Copied from the project.
    public var canvas: Canvas
    /// In drawing order. Blank texts and texts with no range are left out.
    public var texts: [TextLayer]
    /// The volume of the clips and the music, as they are heard.
    public var sound: SoundPlan

    public init(segments: [Segment], duration: Time, canvas: Canvas = .portrait, texts: [TextLayer] = [], sound: SoundPlan = .plain) {
        self.segments = segments
        self.duration = duration
        self.canvas = canvas
        self.texts = texts
        self.sound = sound
    }
}

public enum PlanError: Error, Equatable, Sendable {
    case unknownMedia(MediaID)
}

/// An empty project gives an empty plan and no error.
public func renderPlan(for project: Project) throws -> RenderPlan {
    let canvasWidth = Double(project.canvas.width)
    let canvasHeight = Double(project.canvas.height)
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
        // The side that limits the fit takes the canvas value itself, so it is exact.
        var width = canvasWidth
        var height = canvasHeight
        if uprightWidth * canvasHeight > uprightHeight * canvasWidth {
            height = uprightHeight * canvasWidth / uprightWidth
        } else {
            width = uprightWidth * canvasHeight / uprightHeight
        }
        let placement = Placement(
            quarterTurns: info.quarterTurns, x: (canvasWidth - width) / 2, y: (canvasHeight - height) / 2,
            width: width, height: height)
        segments.append(Segment(
            clip: clip.id, media: clip.media, sourceStart: clip.sourceStart, timelineStart: start,
            duration: clip.duration, placement: placement, hasSound: info.hasSound))
        start = start + clip.duration
    }
    var texts: [TextLayer] = []
    for text in project.texts {
        guard !text.isBlank, let range = project.range(of: text.id) else {
            continue
        }
        texts.append(TextLayer(
            text: text.id, string: text.string, timelineStart: range.start, duration: range.duration, x: text.x,
            y: text.y, rotation: text.rotation, style: text.style, lineWidth: canvasWidth * TextGeometry.wrapShare))
    }
    var music: MusicLayer?
    if let stored = project.music, let heard = project.heardMusic {
        let half = Time(ticks: heard.ticks / 2)
        music = MusicLayer(
            media: stored.file.id, fileName: stored.file.fileName, sourceStart: stored.start, duration: heard,
            volume: stored.volume, fadeIn: stored.fadeIn, fadeOut: min(stored.fadeOut, half))
    }
    let sound = SoundPlan(clipVolume: project.clipsMuted ? 0 : project.clipVolume, music: music)
    return RenderPlan(segments: segments, duration: start, canvas: project.canvas, texts: texts, sound: sound)
}
