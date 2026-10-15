// The frame actions and the values the framing row and the gestures on the picture read.

extension EditorState {
    /// The selected clip while no text is selected and the playhead is inside that clip. Nil otherwise (rule 90).
    public var framedByHand: ClipID? {
        guard selectedText == nil, let selection, project.clip(at: playhead)?.id == selection else {
            return nil
        }
        return selection
    }

    /// "none" with no clip selected. Else "<fit|fill> <black|blur> <zoom times 100> <x times 1000>,<y times 1000>"
    /// of the selected clip, whole numbers with the digits 0 to 9, the same in every language: "fit black 100 0,0".
    public var frameInfo: String {
        guard let selection, let clip = project.clips.first(where: { $0.id == selection }) else {
            return "none"
        }
        let framing = clip.framing
        let backdrop = framing.backdrop == .black ? "black" : "blur"
        return framing.fit.rawValue + " " + backdrop + " " + whole(framing.zoom * 100) + " "
            + whole(framing.x * 1000) + "," + whole(framing.y * 1000)
    }
}

/// What reduce calls for the case frame. Nothing for an unknown id or a value that is not finite. Every framing
/// the action changes is stored held (rule 84). An action that changes the state pauses, one that would change
/// nothing returns the state unchanged.
func reduceFrame(_ state: EditorState, _ action: FrameAction) -> EditorState {
    var next = state
    switch action {
    case .setFit(let id, let fit):
        guard let index = state.project.clips.firstIndex(where: { $0.id == id }) else {
            return state
        }
        next.project.clips[index].framing.fit = fit
    case .setBackdrop(let id, let backdrop):
        guard let index = state.project.clips.firstIndex(where: { $0.id == id }) else {
            return state
        }
        next.project.clips[index].framing.backdrop = backdrop
    case .setZoom(let id, let zoom):
        guard zoom.isFinite, let index = state.project.clips.firstIndex(where: { $0.id == id }) else {
            return state
        }
        next.project.clips[index].framing.zoom = zoom
    case .setOffset(let id, let x, let y):
        guard x.isFinite, y.isFinite, let index = state.project.clips.firstIndex(where: { $0.id == id }) else {
            return state
        }
        next.project.clips[index].framing.x = x
        next.project.clips[index].framing.y = y
    case .applyToAll(let id):
        guard let source = state.project.clips.first(where: { $0.id == id }) else {
            return state
        }
        for index in next.project.clips.indices {
            next.project.clips[index].framing.fit = source.framing.fit
            next.project.clips[index].framing.backdrop = source.framing.backdrop
        }
    }
    for index in next.project.clips.indices where next.project.clips[index] != state.project.clips[index] {
        let clip = next.project.clips[index]
        guard let info = next.project.media[clip.media] else {
            continue
        }
        let turned = info.quarterTurns % 2 != 0
        next.project.clips[index].framing = clip.framing.held(
            uprightWidth: Double(turned ? info.height : info.width),
            uprightHeight: Double(turned ? info.width : info.height), canvas: next.project.canvas)
    }
    if next.project == state.project {
        return state
    }
    next.isPlaying = false
    return next
}

/// A number rounded to a whole one, written with the digits 0 to 9.
private func whole(_ value: Double) -> String {
    String(Int(value.rounded()))
}
