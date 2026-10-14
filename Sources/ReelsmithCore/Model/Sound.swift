public struct MusicFile: Equatable, Sendable {
    /// A test tone uses its name, a picked file a new UUID string.
    public var id: MediaID
    /// The file's name inside the media folder, with its extension.
    public var fileName: String
    /// Content: the name of the picked file without its extension.
    public var title: String
    /// The length of its first sound track, rounded down to a tick.
    public var duration: Time

    public init(id: MediaID, fileName: String, title: String, duration: Time) {
        self.id = id
        self.fileName = fileName
        self.title = title
        self.duration = duration
    }
}

public struct Music: Equatable, Sendable {
    public var file: MusicFile
    /// The place in the file where the music begins. A whole frame.
    public var start: Time
    /// 0 to 1.
    public var volume: Double
    /// Whole frames, 0 to SoundGeometry.maximumFade.
    public var fadeIn: Time
    /// Whole frames, 0 to SoundGeometry.maximumFade.
    public var fadeOut: Time

    public init(file: MusicFile, start: Time, volume: Double, fadeIn: Time, fadeOut: Time) {
        self.file = file
        self.start = start
        self.volume = volume
        self.fadeIn = fadeIn
        self.fadeOut = fadeOut
    }

    /// Start zero, volume 1, both fades zero.
    public init(file: MusicFile) {
        self.init(file: file, start: .zero, volume: 1, fadeIn: .zero, fadeOut: .zero)
    }

    /// The length of the file less SoundGeometry.minimumMusic, rounded down to a whole frame.
    /// Zero for a file not longer than minimumMusic.
    public var largestStart: Time {
        max(Time.zero, (file.duration - SoundGeometry.minimumMusic).roundedDownToFrame)
    }
}

public enum SoundGeometry {
    /// Five seconds.
    public static let maximumFade: Time = Time(ticks: 3000)
    /// A start leaves at least this much of the file.
    public static let minimumMusic: Time = Time(ticks: 600)
    /// The step of the slider that sets the start.
    public static let startStep: Time = Time(ticks: 600)
}
