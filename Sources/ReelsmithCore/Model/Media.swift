public struct MediaID: Hashable, Codable, Sendable {
    /// A seed clip uses its name, a picked video a new UUID string.
    public let raw: String

    public init(_ raw: String) {
        self.raw = raw
    }
}

public enum MediaKind: String, Equatable, Codable, Sendable {
    case video
    case photo
}

public struct MediaInfo: Equatable, Codable, Sendable {
    public var id: MediaID
    /// The file's name inside the media folder, with its extension.
    public var fileName: String
    /// Pixels as stored, before any turn.
    public var width: Int
    public var height: Int
    /// The length of the picture track, rounded down to a tick. photoLongest for a photo.
    public var duration: Time
    /// 0 to 3: clockwise quarter turns to apply to the stored picture to show it upright.
    public var quarterTurns: Int
    public var hasSound: Bool
    /// .video when a stored file lacks it.
    public var kind: MediaKind

    public init(
        id: MediaID, fileName: String, width: Int, height: Int, duration: Time, quarterTurns: Int, hasSound: Bool,
        kind: MediaKind = .video
    ) {
        self.id = id
        self.fileName = fileName
        self.width = width
        self.height = height
        self.duration = duration
        self.quarterTurns = quarterTurns
        self.hasSound = hasSound
        self.kind = kind
    }

    /// The coding keys and the encoding stay synthesized. A file written before kind existed reads as a video.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(MediaID.self, forKey: .id)
        fileName = try container.decode(String.self, forKey: .fileName)
        width = try container.decode(Int.self, forKey: .width)
        height = try container.decode(Int.self, forKey: .height)
        duration = try container.decode(Time.self, forKey: .duration)
        quarterTurns = try container.decode(Int.self, forKey: .quarterTurns)
        hasSound = try container.decode(Bool.self, forKey: .hasSound)
        kind = try container.decodeIfPresent(MediaKind.self, forKey: .kind) ?? .video
    }
}

extension MediaInfo {
    /// 1800 ticks: a photo clip when it is added.
    public static let photoLength: Time = Time(ticks: 1800)
    /// 108000 ticks: the media duration of every photo.
    public static let photoLongest: Time = Time(ticks: 108000)
}
