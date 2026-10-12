/// An action that cannot be done returns the state unchanged.
public func reduce(_ state: EditorState, _ action: EditorAction) -> EditorState {
    state
}
