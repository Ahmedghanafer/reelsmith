public enum Seed: String, CaseIterable, Sendable {
    case empty = "empty"
    case twoClips = "two-clips"
    case threeClips = "three-clips"
    case twoClipsWide = "two-clips-wide"

    public var canvas: Canvas {
        switch self {
        case .empty, .twoClips, .threeClips:
            return .portrait
        case .twoClipsWide:
            return .landscape
        }
    }

    public var testClips: [TestClip] {
        switch self {
        case .empty:
            return []
        case .twoClips, .twoClipsWide:
            return [.blue, .red]
        case .threeClips:
            return [.blue, .red, .green]
        }
    }

    /// Each clip whole, from its first frame, on the seed's canvas.
    public var project: Project {
        var project = Project(canvas: canvas)
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
