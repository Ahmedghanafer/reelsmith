// The edit actions and the values that enable their buttons.

extension EditorState {
    public var canSplit: Bool {
        guard let clip = project.clip(at: playhead), let start = project.start(of: clip.id) else {
            return false
        }
        let left = playhead - start
        return left >= TimelineGeometry.minimumClip && clip.duration - left >= TimelineGeometry.minimumClip
    }

    public var canDelete: Bool {
        guard let selection else {
            return false
        }
        return project.position(of: selection) != nil
    }
}

func addClips(_ state: EditorState, _ media: [MediaInfo]) -> EditorState {
    var next = state
    for info in media {
        let duration = info.duration.roundedDownToFrame
        if duration < TimelineGeometry.minimumClip {
            continue
        }
        next.project.media[info.id] = info
        next.project.clips.append(
            Clip(id: ClipID(next.project.nextClipID), media: info.id, sourceStart: .zero, duration: duration))
        next.project.nextClipID += 1
    }
    next.isPlaying = false
    return next
}

func split(_ state: EditorState) -> EditorState {
    guard state.canSplit,
        let clip = state.project.clip(at: state.playhead),
        let start = state.project.start(of: clip.id),
        let index = state.project.clips.firstIndex(where: { $0.id == clip.id })
    else {
        return state
    }
    let left = state.playhead - start
    var next = state
    next.project.clips[index].duration = left
    next.project.clips.insert(
        Clip(
            id: ClipID(next.project.nextClipID), media: clip.media, sourceStart: clip.sourceStart + left,
            duration: clip.duration - left),
        at: index + 1)
    next.project.nextClipID += 1
    next.isPlaying = false
    return next
}

func trimStart(_ state: EditorState, _ clip: ClipID, by amount: Time) -> EditorState {
    guard let index = state.project.clips.firstIndex(where: { $0.id == clip }),
        state.project.media[state.project.clips[index].media] != nil
    else {
        return state
    }
    let old = state.project.clips[index]
    let change = wholeFrames(amount, from: Time.zero - old.sourceStart, to: old.duration - TimelineGeometry.minimumClip)
    var next = state
    next.project.clips[index].sourceStart = old.sourceStart + change
    next.project.clips[index].duration = old.duration - change
    return afterTrim(next)
}

func trimEnd(_ state: EditorState, _ clip: ClipID, by amount: Time) -> EditorState {
    guard let index = state.project.clips.firstIndex(where: { $0.id == clip }),
        let info = state.project.media[state.project.clips[index].media]
    else {
        return state
    }
    let old = state.project.clips[index]
    let change = wholeFrames(
        amount, from: old.sourceStart + old.duration - info.duration, to: old.duration - TimelineGeometry.minimumClip)
    var next = state
    next.project.clips[index].duration = old.duration - change
    return afterTrim(next)
}

func deleteSelected(_ state: EditorState) -> EditorState {
    guard let selection = state.selection,
        let index = state.project.clips.firstIndex(where: { $0.id == selection })
    else {
        return state
    }
    var next = state
    next.project.clips.remove(at: index)
    next.selection = nil
    next.playhead = min(next.playhead, next.project.duration)
    next.isPlaying = false
    return next
}

/// The amount held between the two limits, then rounded toward zero to whole frames.
private func wholeFrames(_ amount: Time, from low: Time, to high: Time) -> Time {
    let held = min(max(amount, low), high)
    return Time(ticks: held.ticks / Time.frame.ticks * Time.frame.ticks)
}

private func afterTrim(_ state: EditorState) -> EditorState {
    var next = state
    next.playhead = min(next.playhead, next.project.duration)
    next.isPlaying = false
    return next
}
