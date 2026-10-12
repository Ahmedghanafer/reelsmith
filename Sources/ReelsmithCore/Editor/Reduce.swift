/// An action that cannot be done returns the state unchanged.
public func reduce(_ state: EditorState, _ action: EditorAction) -> EditorState {
    var next = state
    switch action {
    case .addClips(let media):
        return addClips(state, media)
    case .split:
        return split(state)
    case .trimStart(let clip, let amount):
        return trimStart(state, clip, by: amount)
    case .trimEnd(let clip, let amount):
        return trimEnd(state, clip, by: amount)
    case .deleteSelected:
        return deleteSelected(state)
    case .select(let clip):
        if state.project.position(of: clip) != nil {
            next.selection = clip
        }
    case .clearSelection:
        next.selection = nil
    case .movePlayhead(let time):
        next.playhead = min(max(time, .zero), state.project.duration).roundedDownToFrame
    case .play:
        if state.canPlay {
            if state.playhead >= state.project.duration {
                next.playhead = .zero
            }
            next.isPlaying = true
        }
    case .pause:
        next.isPlaying = false
    }
    return next
}
