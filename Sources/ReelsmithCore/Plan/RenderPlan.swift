public struct Placement: Equatable, Sendable {
    /// Copied from the MediaInfo.
    public var quarterTurns: Int
    /// Pixels of the plan's picture, origin top left: the rectangle the upright picture fills.
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
    /// True when the media's kind is photo.
    public var isStill: Bool
    /// The clip's own volume as stored. What is heard of the segment is sound.clipVolume times it.
    public var volume: Double

    public init(
        clip: ClipID, media: MediaID, sourceStart: Time, timelineStart: Time, duration: Time, placement: Placement,
        hasSound: Bool, isStill: Bool = false, volume: Double = 1
    ) {
        self.clip = clip
        self.media = media
        self.sourceStart = sourceStart
        self.timelineStart = timelineStart
        self.duration = duration
        self.placement = placement
        self.hasSound = hasSound
        self.isStill = isStill
        self.volume = volume
    }
}

public struct TextLayer: Equatable, Sendable {
    public var text: TextID
    public var string: String
    /// The start of the text's range in the project.
    public var timelineStart: Time
    /// Its length. The layer is drawn in a frame at time t when timelineStart <= t < timelineStart + duration.
    public var duration: Time
    /// Pixels of the plan's picture: the centre of the block.
    public var x: Double
    public var y: Double
    public var rotation: Double
    /// Its size is in pixels of the plan's picture.
    public var style: TextStyle
    /// Pixels of the plan's picture: a line longer than this wraps. The plan's width times TextGeometry.wrapShare.
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
    /// The size and the rate of the picture the plan describes.
    public var settings: ExportSettings

    /// Pixels: the width of the picture.
    public var width: Int {
        settings.width(on: canvas)
    }

    /// Pixels: the height of the picture.
    public var height: Int {
        settings.height(on: canvas)
    }

    public var framesPerSecond: Int {
        settings.rate.framesPerSecond
    }

    public init(
        segments: [Segment], duration: Time, canvas: Canvas = .portrait, texts: [TextLayer] = [],
        sound: SoundPlan = .plain, settings: ExportSettings = .standard
    ) {
        self.segments = segments
        self.duration = duration
        self.canvas = canvas
        self.texts = texts
        self.sound = sound
        self.settings = settings
    }
}

public enum PlanError: Error, Equatable, Sendable {
    case unknownMedia(MediaID)
}

/// The plan at `ExportSettings.standard`: the plan of the preview.
public func renderPlan(for project: Project) throws -> RenderPlan {
    try renderPlan(for: project, settings: .standard)
}

/// An empty project gives an empty plan with the settings and no error.
public func renderPlan(for project: Project, settings: ExportSettings) throws -> RenderPlan {
    let pictureWidth = Double(settings.width(on: project.canvas))
    let pictureHeight = Double(settings.height(on: project.canvas))
    let shortSide = settings.size.shortSide
    // Canvas pixels to pixels of the picture. At a short side of 1080 they are copied, so the standard plan is exact.
    func scaled(_ value: Double) -> Double {
        shortSide == 1080 ? value : value * Double(shortSide) / 1080
    }
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
        // The side that limits the fit takes the plan's width or height itself, so it is exact.
        var width = pictureWidth
        var height = pictureHeight
        if uprightWidth * pictureHeight > uprightHeight * pictureWidth {
            height = uprightHeight * pictureWidth / uprightWidth
        } else {
            width = uprightWidth * pictureHeight / uprightHeight
        }
        let placement = Placement(
            quarterTurns: info.quarterTurns, x: (pictureWidth - width) / 2, y: (pictureHeight - height) / 2,
            width: width, height: height)
        segments.append(Segment(
            clip: clip.id, media: clip.media, sourceStart: clip.sourceStart, timelineStart: start,
            duration: clip.duration, placement: placement, hasSound: info.hasSound, isStill: info.kind == .photo,
            volume: clip.volume))
        start = start + clip.duration
    }
    var texts: [TextLayer] = []
    for text in project.texts {
        guard !text.isBlank, let range = project.range(of: text.id) else {
            continue
        }
        var style = text.style
        style.size = scaled(style.size)
        texts.append(TextLayer(
            text: text.id, string: text.string, timelineStart: range.start, duration: range.duration,
            x: scaled(text.x), y: scaled(text.y), rotation: text.rotation, style: style,
            lineWidth: pictureWidth * TextGeometry.wrapShare))
    }
    var music: MusicLayer?
    if let stored = project.music, let heard = project.heardMusic {
        let half = Time(ticks: heard.ticks / 2)
        music = MusicLayer(
            media: stored.file.id, fileName: stored.file.fileName, sourceStart: stored.start, duration: heard,
            volume: stored.volume, fadeIn: min(stored.fadeIn, half), fadeOut: min(stored.fadeOut, half))
    }
    let sound = SoundPlan(clipVolume: project.clipsMuted ? 0 : project.clipVolume, music: music)
    return RenderPlan(
        segments: segments, duration: start, canvas: project.canvas, texts: texts, sound: sound, settings: settings)
}
