// The text actions. Both bodies are still empty: no text action changes the state yet.

/// What reduce calls for the case text.
func reduceText(_ state: EditorState, _ action: TextAction) -> EditorState {
    state
}

/// The blank rule: a blank text exists only while it is selected. Called by reduce on every path.
func settleTexts(from before: EditorState, to after: EditorState) -> EditorState {
    after
}

extension Project {
    /// Among the texts that are not blank and whose range holds the time, the one whose centre is nearest
    /// in canvas pixels, the later of the list on a tie. Nil when there is none.
    public func text(nearestToX x: Double, y: Double, at time: Time) -> TextID? {
        nil
    }
}
