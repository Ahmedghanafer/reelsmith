public struct EditorState: Equatable, Sendable {
    public var project: Project
    public var selection: ClipID?
    /// A whole frame from zero to the project length.
    public var playhead: Time
    public var isPlaying: Bool
    /// At most one of selection and selectedText is set.
    public var selectedText: TextID?

    /// No selection, playhead zero, not playing.
    public init(project: Project) {
        self.project = project
        selection = nil
        selectedText = nil
        playhead = .zero
        isPlaying = false
    }

    /// "<playhead clockText> / <duration clockText>", for example "00:01 / 00:07".
    public var timeLabel: String {
        playhead.clockText + " / " + project.duration.clockText
    }

    public var canPlay: Bool {
        !project.clips.isEmpty
    }

    public var canExport: Bool {
        !project.clips.isEmpty
    }

    public var canAddText: Bool {
        !project.clips.isEmpty
    }

    /// "none" with no selected text. Else ten fields with one space between them: the position, the font,
    /// the size, the colour as "r,g,b", the alignment, the centre as "x,y", the rotation, three marks for
    /// outline, shadow and box ("o", "s", "b", or "." for off), the range as "<start ticks>+<duration ticks>"
    /// or "hidden", and the line spacing times 100. Digits and fixed marks, the same in every language.
    public var textInfo: String {
        guard let selectedText, let text = project.text(selectedText),
            let position = project.position(of: selectedText)
        else {
            return "none"
        }
        let style = text.style
        var range = "hidden"
        if let seen = project.range(of: selectedText) {
            range = String(seen.start.ticks) + "+" + String(seen.duration.ticks)
        }
        let fields: [String] = [
            String(position),
            style.font.rawValue,
            whole(style.size),
            String(style.colour.r) + "," + String(style.colour.g) + "," + String(style.colour.b),
            style.align.rawValue,
            whole(text.x) + "," + whole(text.y),
            whole(text.rotation),
            (style.outline ? "o" : ".") + (style.shadow ? "s" : ".") + (style.box ? "b" : "."),
            range,
            whole(style.lineSpacing * 100),
        ]
        return fields.joined(separator: " ")
    }
}

/// A number rounded to a whole one, written with the digits 0 to 9.
private func whole(_ value: Double) -> String {
    String(Int(value.rounded()))
}
