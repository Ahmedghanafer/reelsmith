// The text actions. Both bodies are still empty: no text action changes the state yet.

/// What reduce calls for the case text.
func reduceText(_ state: EditorState, _ action: TextAction) -> EditorState {
    state
}

/// The blank rule: a blank text exists only while it is selected. Called by reduce on every path.
func settleTexts(from before: EditorState, to after: EditorState) -> EditorState {
    after
}
