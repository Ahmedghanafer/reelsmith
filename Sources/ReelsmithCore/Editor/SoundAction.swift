public enum SoundAction: Equatable, Sendable {
    /// Shows the sound panel and clears both selections. Leaves isPlaying alone. Nothing on an empty project.
    case open
    /// Held between 0 and 1.
    case setClipVolume(Double)
    case muteClips(Bool)
    /// Replaces any music by Music(file:). Nothing for a file with no length.
    case setMusic(MusicFile)
    case removeMusic
    /// Held between 0 and 1.
    case setMusicVolume(Double)
    /// Held between zero and the largest start, rounded toward zero to a whole frame.
    case setMusicStart(Time)
    /// Held between zero and maximumFade, rounded toward zero to a whole frame.
    case setFadeIn(Time)
    /// Held between zero and maximumFade, rounded toward zero to a whole frame.
    case setFadeOut(Time)
    /// Held between 0 and 1. Nothing for an unknown clip or a value that is not finite.
    case setVolumeOfClip(ClipID, Double)
}
