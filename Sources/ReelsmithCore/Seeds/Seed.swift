public enum Seed: String, CaseIterable, Sendable {
    case empty = "empty"
    case twoClips = "two-clips"
    case threeClips = "three-clips"

    public var testClips: [TestClip] {
        switch self {
        case .empty:
            return []
        case .twoClips:
            return [.blue, .red]
        case .threeClips:
            return [.blue, .red, .green]
        }
    }

    /// Each clip whole, from its first frame.
    public var project: Project {
        var project = Project()
        for testClip in testClips {
            let info = testClip.info
            project.media[info.id] = info
            project.clips.append(
                Clip(id: ClipID(project.nextClipID), media: info.id, sourceStart: .zero, duration: info.duration))
            project.nextClipID += 1
        }
        return project
    }
}
