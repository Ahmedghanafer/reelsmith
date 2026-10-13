public enum Seed: String, CaseIterable, Sendable {
    case empty = "empty"
    case twoClips = "two-clips"
    case threeClips = "three-clips"
    case twoClipsWide = "two-clips-wide"
    /// Three lines for the whole video.
    case textWide = "text-wide"
    /// One boxed word for a part of the first clip.
    case textBoxWide = "text-box-wide"

    public var canvas: Canvas {
        switch self {
        case .empty, .twoClips, .threeClips:
            return .portrait
        case .twoClipsWide, .textWide, .textBoxWide:
            return .landscape
        }
    }

    public var testClips: [TestClip] {
        switch self {
        case .empty:
            return []
        case .twoClips, .twoClipsWide, .textWide, .textBoxWide:
            return [.blue, .red]
        case .threeClips:
            return [.blue, .red, .green]
        }
    }

    /// The text a start on the seed has selected.
    public var selectedText: TextID? {
        switch self {
        case .empty, .twoClips, .threeClips, .twoClipsWide:
            return nil
        case .textWide, .textBoxWide:
            return TextID(1)
        }
    }

    /// Each clip whole, from its first frame, on the seed's canvas. A text seed has one text, id 1.
    public var project: Project {
        var project = Project(canvas: canvas)
        for testClip in testClips {
            let info = testClip.info
            project.media[info.id] = info
            project.clips.append(
                Clip(id: ClipID(project.nextClipID), media: info.id, sourceStart: .zero, duration: info.duration))
            project.nextClipID += 1
        }
        switch self {
        case .empty, .twoClips, .threeClips, .twoClipsWide:
            break
        case .textWide:
            // The middle line is Arabic with every vowel mark, written as scalars so no editor reorders it.
            let arabic =
                "\u{0627}\u{0644}\u{0633}\u{0651}\u{064E}\u{0644}\u{064E}\u{0627}\u{0645}\u{064F}\u{0020}"
                + "\u{0639}\u{064E}\u{0644}\u{064E}\u{064A}\u{0652}\u{0643}\u{064F}\u{0645}\u{0652}"
            project.texts = [
                TextItem(
                    id: TextID(1), string: "Peace\n" + arabic + "\nbe upon you", span: .whole, x: 960, y: 540,
                    rotation: 0, style: .standard),
            ]
            project.nextTextID = 2
        case .textBoxWide:
            var style = TextStyle.standard
            style.size = 96
            style.colour = RGB(r: 255, g: 214, b: 10)
            style.box = true
            project.texts = [
                TextItem(
                    id: TextID(1), string: "BOX",
                    span: .range(TextRange(start: Time(ticks: 600), duration: Time(ticks: 900))), x: 960, y: 540,
                    rotation: 0, style: style),
            ]
            project.nextTextID = 2
        }
        return project
    }
}
