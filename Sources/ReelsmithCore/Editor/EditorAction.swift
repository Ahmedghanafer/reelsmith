public enum EditorAction: Equatable, Sendable {
    /// To the end, in order: a video whole and rounded down to a frame, a photo for photoLength.
    case addClips([MediaInfo])
    /// At the playhead.
    case split
    /// A positive amount makes the clip shorter. Rounded toward zero to whole frames. Sent once, on release.
    case trimStart(ClipID, by: Time)
    /// A positive amount makes the clip shorter. Rounded toward zero to whole frames. Sent once, on release.
    case trimEnd(ClipID, by: Time)
    /// Deleting the last clip leaves an empty project.
    case deleteSelected
    /// To a position from 1, held between 1 and the count. Nothing for an unknown id or the position it has.
    /// Keeps the playhead, selects the clip, pauses.
    case moveClip(ClipID, to: Int)
    /// The selected clip, at the playhead, when canCutBefore.
    case cutBefore
    /// The selected clip, at the playhead, when canCutAfter.
    case cutAfter
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
