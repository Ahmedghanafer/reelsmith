// The sound actions and the rule that at most one of a clip, a text and the sound panel is open.

/// What reduce calls for the case sound. A value past a limit is held at the limit. An action that would change
/// nothing returns the state unchanged, the playing flag included, and so does a volume that is not a finite number
/// and, for the four that name the music, an action with no music. An action that changes the state pauses.
func reduceSound(_ state: EditorState, _ action: SoundAction) -> EditorState {
    var next = state
    switch action {
    case .open:
        next.showsSound = true
        next.selection = nil
        next.selectedText = nil
        return next
    case .setClipVolume(let volume):
        guard volume.isFinite else {
            return state
        }
        next.project.clipVolume = min(max(volume, 0), 1)
    case .muteClips(let muted):
        next.project.clipsMuted = muted
    case .setMusic(let file):
        guard file.duration > .zero else {
            return state
        }
        next.project.music = Music(file: file)
    case .removeMusic:
        next.project.music = nil
    case .setMusicVolume(let volume):
        guard volume.isFinite, state.project.music != nil else {
            return state
        }
        next.project.music?.volume = min(max(volume, 0), 1)
    case .setMusicStart(let start):
        guard let music = state.project.music else {
            return state
        }
        next.project.music?.start = held(start, upTo: music.largestStart)
    case .setFadeIn(let fade):
        guard state.project.music != nil else {
            return state
        }
        next.project.music?.fadeIn = held(fade, upTo: SoundGeometry.maximumFade)
    case .setFadeOut(let fade):
        guard state.project.music != nil else {
            return state
        }
        next.project.music?.fadeOut = held(fade, upTo: SoundGeometry.maximumFade)
    }
    if next.project == state.project {
        return state
    }
    next.isPlaying = false
    return next
}

/// Called by reduce on every path, last. Closes the sound panel when a clip or a text is selected
/// and on an empty project, and changes nothing else.
func settleSound(_ state: EditorState) -> EditorState {
    guard state.showsSound,
        state.selectedText != nil
    else {
        return state
    }
    var next = state
    next.showsSound = false
    return next
}

/// The time held between zero and the upper limit, a whole frame, then rounded toward zero to a whole frame.
private func held(_ time: Time, upTo upper: Time) -> Time {
    min(max(time, .zero), upper).roundedDownToFrame
}
