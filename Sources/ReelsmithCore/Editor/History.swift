extension Project {
    public var withoutBlankTexts: Project {
        self
    }
}

public enum EditRun: Equatable, Sendable {
    case typing(TextID)
    case shaping(TextID)

    public static func of(_ action: EditorAction, on state: EditorState) -> EditRun? {
        nil
    }
}

public struct UndoHistory: Equatable, Sendable {
    public static let depth: Int = 50
    public private(set) var past: [Project]
    public private(set) var future: [Project]
    public private(set) var run: EditRun?

    public init() {
        past = []
        future = []
        run = nil
    }

    public var canUndo: Bool {
        !past.isEmpty
    }

    public var canRedo: Bool {
        !future.isEmpty
    }
}

public struct Editing: Equatable, Sendable {
    public private(set) var state: EditorState
    public private(set) var history: UndoHistory
    public private(set) var unsaved: Bool

    public init(state: EditorState) {
        self.state = state
        history = UndoHistory()
        unsaved = false
    }

    public func after(_ action: EditorAction) -> Editing {
        Editing(state: reduce(state, action))
    }

    public func undone() -> Editing {
        self
    }

    public func redone() -> Editing {
        self
    }

    public var canUndo: Bool {
        history.canUndo
    }

    public var canRedo: Bool {
        history.canRedo
    }

    public var writesNow: Bool {
        unsaved && history.run == nil
    }

    public func written() -> Editing {
        self
    }
}
