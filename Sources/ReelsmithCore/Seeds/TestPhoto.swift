public struct TestPhoto: Equatable, Sendable {
    /// The file is name + ".png".
    public var name: String
    /// Upright pixels.
    public var width: Int
    public var height: Int
    /// The colour of the whole picture.
    public var colour: RGB

    /// The id is MediaID(name), the file name is name + ".png", a photo of photoLongest with no turn and no sound.
    public var info: MediaInfo {
        MediaInfo(
            id: MediaID(name), fileName: name + ".png", width: width, height: height,
            duration: MediaInfo.photoLongest, quarterTurns: 0, hasSound: false, kind: .photo)
    }

    public static let magenta = TestPhoto(name: "magenta", width: 1080, height: 1440, colour: RGB(r: 255, g: 0, b: 255))
}
