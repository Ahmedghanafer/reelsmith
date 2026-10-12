// The edit actions and the values that enable their buttons. Declared here, not built yet.

extension EditorState {
    public var canSplit: Bool {
        false
    }

    public var canDelete: Bool {
        false
    }
}

func addClips(_ state: EditorState, _ media: [MediaInfo]) -> EditorState {
    state
}

func split(_ state: EditorState) -> EditorState {
    state
}

func trimStart(_ state: EditorState, _ clip: ClipID, by amount: Time) -> EditorState {
    state
}

func trimEnd(_ state: EditorState, _ clip: ClipID, by amount: Time) -> EditorState {
    state
}

func deleteSelected(_ state: EditorState) -> EditorState {
    state
}
