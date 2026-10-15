// Moving a clip and cutting the selected clip at the playhead, and the values the clip panel reads.

extension EditorState {
    /// The playhead is inside the selected clip with at least minimumClip on both sides of it.
    public var canCutBefore: Bool {
        cutPlace(in: self) != nil
    }

    /// The playhead is inside the selected clip with at least minimumClip on both sides of it.
    public var canCutAfter: Bool {
        cutPlace(in: self) != nil
    }

    /// The selection names a clip of the project.
    public var showsClipPanel: Bool {
        guard let selection else {
            return false
        }
        return project.position(of: selection) != nil
    }

    /// showsClipPanel, and the media of the selected clip has sound.
    public var showsClipVolume: Bool {
        guard showsClipPanel, let selection, let clip = project.clips.first(where: { $0.id == selection }) else {
            return false
        }
        return project.media[clip.media]?.hasSound == true
    }
}

extension Project {
    /// The position from 1 the clip takes when let go at the time: 1 plus the count of the other clips, in their
    /// order with the clip taken out, whose middle is before the time. Nil for an unknown id.
    public func dropPosition(of clip: ClipID, at time: Time) -> Int? {
        guard position(of: clip) != nil else {
            return nil
        }
        var start = Time.zero
        var before = 0
        for other in clips where other.id != clip {
            if start + Time(ticks: other.duration.ticks / 2) < time {
                before += 1
            }
            start = start + other.duration
        }
        return before + 1
    }
}

func moveClip(_ state: EditorState, _ clip: ClipID, to position: Int) -> EditorState {
    guard let index = state.project.clips.firstIndex(where: { $0.id == clip }) else {
        return state
    }
    let target = min(max(position, 1), state.project.clips.count) - 1
    if target == index {
        return state
    }
    var next = state
    let moved = next.project.clips.remove(at: index)
    next.project.clips.insert(moved, at: target)
    next.selection = clip
    next.selectedText = nil
    next.isPlaying = false
    return next
}

func cutBefore(_ state: EditorState) -> EditorState {
    guard let place = cutPlace(in: state) else {
        return state
    }
    var next = state
    next.project.clips[place.index].sourceStart = next.project.clips[place.index].sourceStart + place.left
    next.project.clips[place.index].duration = next.project.clips[place.index].duration - place.left
    next.playhead = place.start
    next.isPlaying = false
    return next
}

func cutAfter(_ state: EditorState) -> EditorState {
    guard let place = cutPlace(in: state) else {
        return state
    }
    var next = state
    next.project.clips[place.index].duration = place.left
    next.isPlaying = false
    return next
}

/// The index and the start of the selected clip and the part of it before the playhead, when at least
/// minimumClip lies on both sides of the playhead inside that clip. Nil otherwise.
private func cutPlace(in state: EditorState) -> (index: Int, start: Time, left: Time)? {
    guard let selection = state.selection,
        let index = state.project.clips.firstIndex(where: { $0.id == selection }),
        let start = state.project.start(of: selection)
    else {
        return nil
    }
    let left = state.playhead - start
    let right = state.project.clips[index].duration - left
    guard left >= TimelineGeometry.minimumClip && right >= TimelineGeometry.minimumClip else {
        return nil
    }
    return (index: index, start: start, left: left)
}
