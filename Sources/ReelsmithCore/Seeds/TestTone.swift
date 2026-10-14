public struct TestTone: Equatable, Sendable {
    public var name: String
    public var duration: Time
    /// The pitch of the first half of the file.
    public var firstHertz: Int
    /// The pitch of the second half.
    public var secondHertz: Int
    /// Of full scale.
    public var peak: Double
    public var sampleRate: Int
    /// 1 or 2. With 2 both carry the same samples.
    public var channels: Int

    public init(name: String, duration: Time, firstHertz: Int, secondHertz: Int, peak: Double, sampleRate: Int, channels: Int) {
        self.name = name
        self.duration = duration
        self.firstHertz = firstHertz
        self.secondHertz = secondHertz
        self.peak = peak
        self.sampleRate = sampleRate
        self.channels = channels
    }

    /// The id is MediaID(name), the file name is name + ".mov", the title is the name.
    public var file: MusicFile {
        MusicFile(id: MediaID(name), fileName: name + ".mov", title: name, duration: duration)
    }

    public static let long = TestTone(
        name: "long-tone", duration: Time(ticks: 6000), firstHertz: 880, secondHertz: 1320, peak: 0.25,
        sampleRate: 44100, channels: 1)

    public static let short = TestTone(
        name: "short-tone", duration: Time(ticks: 1200), firstHertz: 660, secondHertz: 660, peak: 0.25,
        sampleRate: 44100, channels: 1)

    public static let all: [TestTone] = [long, short]
}
