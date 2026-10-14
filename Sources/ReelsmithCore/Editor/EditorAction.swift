public enum EditorAction: Equatable, Sendable {
    /// To the end, in order, each whole and rounded down to a frame.
    case addClips([MediaInfo])
    /// At the playhead.
    case split
    /// A positive amount makes the clip shorter. Rounded toward zero to whole frames. Sent once, on release.
    case trimStart(ClipID, by: Time)
    /// A positive amount makes the clip shorter. Rounded toward zero to whole frames. Sent once, on release.
    case trimEnd(ClipID, by: Time)
    /// Deleting the last clip leaves an empty project.
    case deleteSelected
    case select(ClipID)
    case clearSelection
    /// Clamped to the project, rounded down to a frame, leaves isPlaying alone.
    case movePlayhead(Time)
    /// From zero when the playhead is at the end. Nothing on an empty project.
    case play
    case pause
    case text(TextAction)
    case sound(SoundAction)
}
