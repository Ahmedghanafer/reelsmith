public enum Seed: String, CaseIterable, Sendable {
    case empty = "empty"
    case twoClips = "two-clips"
    case threeClips = "three-clips"

    public var testClips: [TestClip] {
        []
    }

    /// Each clip whole, from its first frame.
    public var project: Project {
        Project()
    }
}
