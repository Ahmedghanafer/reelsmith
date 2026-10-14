// Undo and redo beside reduce: a history of whole projects, never of inverse actions.

extension Project {
    /// Every text that isBlank taken out, all else kept.
    public var withoutBlankTexts: Project {
        var project = self
        project.texts.removeAll(where: { $0.isBlank })
        return project
    }
}

/// A row of actions on one text of one kind, which together are one step.
public enum EditRun: Equatable, Codable, Sendable {
    case typing(TextID)
    case shaping(TextID)

    /// typing for text(.setString(id, _)). shaping for text(.move(id, ...)), text(.turn(id, _)), and a
    /// text(.setStyle(id, style)) whose style equals the stored style of id in every member but size and
    /// lineSpacing. Each only when the text id is in the project. Nil for every other action.
    public static func of(_ action: EditorAction, on state: EditorState) -> EditRun? {
        guard case .text(let textAction) = action else {
            return nil
        }
        switch textAction {
        case .setString(let id, _):
            return state.project.text(id) != nil ? .typing(id) : nil
        case .move(let id, _, _), .turn(let id, _):
            return state.project.text(id) != nil ? .shaping(id) : nil
        case .setStyle(let id, let style):
            guard let stored = state.project.text(id)?.style else {
                return nil
            }
            var shaped = style
            shaped.size = stored.size
            shaped.lineSpacing = stored.lineSpacing
            return shaped == stored ? .shaping(id) : nil
        case .add, .select, .trimStart, .trimEnd:
            return nil
        }
    }
}

public struct UndoHistory: Equatable, Codable, Sendable {
    public static let depth: Int = 50
    /// Without blank texts, the oldest first.
    public private(set) var past: [Project]
    /// Without blank texts, the next to come back last.
    public private(set) var future: [Project]
    public private(set) var run: EditRun?

    /// Empty, no run.
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

    /// A new step: the project before it goes to the end of past, the oldest dropped past depth, no future.
    mutating func add(_ before: Project, run: EditRun?) {
        past.append(before)
        while past.count > UndoHistory.depth {
            past.removeFirst()
        }
        future.removeAll()
        self.run = run
    }

    mutating func endRun() {
        run = nil
    }

    /// The last of past, with the current project put at the end of future. Nil when past is empty.
    mutating func undo(from current: Project) -> Project? {
        guard let project = past.popLast() else {
            return nil
        }
        future.append(current)
        run = nil
        return project
    }

    /// The last of future, with the current project put at the end of past. Nil when future is empty.
    mutating func redo(from current: Project) -> Project? {
        guard let project = future.popLast() else {
            return nil
        }
        past.append(current)
        run = nil
        return project
    }
}

public struct Editing: Equatable, Sendable {
    public private(set) var state: EditorState
    public private(set) var history: UndoHistory
    public private(set) var unsaved: Bool

    /// The state as given, an empty history, unsaved false.
    public init(state: EditorState) {
        self.state = state
        history = UndoHistory()
        unsaved = false
    }

    /// The state as given, that history with its run ended, unsaved false.
    public init(state: EditorState, history: UndoHistory) {
        self.state = state
        self.history = history
        self.history.endRun()
        unsaved = false
    }

    public func after(_ action: EditorAction) -> Editing {
        var next = self
        next.state = reduce(state, action)
        let b = state.project.withoutBlankTexts
        let a = next.state.project.withoutBlankTexts
        let k = EditRun.of(action, on: state)
        if !oneStepApart(a, b) {
            if case .movePlayhead = action {
                // A moving playhead keeps the run as it is: the player's clock sends it while the video plays.
            } else if k != history.run {
                next.history.endRun()
            }
        } else if k != nil && k == history.run {
            next.unsaved = true
        } else {
            next.history.add(b, run: k)
            next.unsaved = true
        }
        return next
    }

    /// self when canUndo is false.
    public func undone() -> Editing {
        var next = self
        guard let project = next.history.undo(from: state.project.withoutBlankTexts) else {
            return self
        }
        next.restore(project)
        return next
    }

    /// self when canRedo is false.
    public func redone() -> Editing {
        var next = self
        guard let project = next.history.redo(from: state.project.withoutBlankTexts) else {
            return self
        }
        next.restore(project)
        return next
    }

    public var canUndo: Bool {
        history.canUndo
    }

    public var canRedo: Bool {
        history.canRedo
    }

    /// unsaved, and history.run is nil.
    public var writesNow: Bool {
        unsaved && history.run == nil
    }

    /// unsaved false, all else as it was.
    public func written() -> Editing {
        var next = self
        next.unsaved = false
        return next
    }

    /// The project back from the history, with what the state holds outside it kept only where it still fits.
    private mutating func restore(_ project: Project) {
        state.project = project
        if let selection = state.selection, project.position(of: selection) == nil {
            state.selection = nil
        }
        if let selectedText = state.selectedText, project.text(selectedText) == nil {
            state.selectedText = nil
        }
        state.playhead = min(state.playhead, project.duration).roundedDownToFrame
        state.isPlaying = false
        if project.clips.isEmpty {
            state.showsSound = false
        }
        unsaved = true
    }
}

/// Two projects without their blank texts are one step apart when they differ in a member other than nextTextID.
private func oneStepApart(_ a: Project, _ b: Project) -> Bool {
    var a = a
    a.nextTextID = b.nextTextID
    return a != b
}
