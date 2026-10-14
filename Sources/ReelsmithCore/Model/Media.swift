public struct MediaID: Hashable, Codable, Sendable {
    /// A seed clip uses its name, a picked video a new UUID string.
    public let raw: String

    public init(_ raw: String) {
        self.raw = raw
    }
}

public struct MediaInfo: Equatable, Codable, Sendable {
    public var id: MediaID
    /// The file's name inside the media folder, with its extension.
    public var fileName: String
    /// Pixels as stored, before any turn.
    public var width: Int
    public var height: Int
    /// The length of the picture track, rounded down to a tick.
    public var duration: Time
    /// 0 to 3: clockwise quarter turns to apply to the stored picture to show it upright.
    public var quarterTurns: Int
    public var hasSound: Bool

    public init(id: MediaID, fileName: String, width: Int, height: Int, duration: Time, quarterTurns: Int, hasSound: Bool) {
        self.id = id
        self.fileName = fileName
        self.width = width
        self.height = height
        self.duration = duration
        self.quarterTurns = quarterTurns
        self.hasSound = hasSound
    }
}
