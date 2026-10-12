public struct EditorState: Equatable, Sendable {
    public var project: Project
    public var selection: ClipID?
    /// A whole frame from zero to the project length.
    public var playhead: Time
    public var isPlaying: Bool

    /// No selection, playhead zero, not playing.
    public init(project: Project) {
        self.project = project
        selection = nil
        playhead = .zero
        isPlaying = false
    }

    /// "<playhead clockText> / <duration clockText>", for example "00:01 / 00:07".
    public var timeLabel: String {
        playhead.clockText + " / " + project.duration.clockText
    }

    public var canPlay: Bool {
        !project.clips.isEmpty
    }

    public var canExport: Bool {
        !project.clips.isEmpty
    }
}
