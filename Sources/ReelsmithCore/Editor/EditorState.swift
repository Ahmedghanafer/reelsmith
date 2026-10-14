public struct EditorState: Equatable, Sendable {
    public var project: Project
    public var selection: ClipID?
    /// A whole frame from zero to the project length.
    public var playhead: Time
    public var isPlaying: Bool
    /// At most one of selection, selectedText and showsSound is set.
    public var selectedText: TextID?
    /// The sound panel shows.
    public var showsSound: Bool

    /// No selection, no sound panel, playhead zero, not playing.
    public init(project: Project) {
        self.project = project
        selection = nil
        selectedText = nil
        showsSound = false
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

    public var canOpenSound: Bool {
        !project.clips.isEmpty
    }

    /// There is music and a step of the start slider fits into its range.
    public var canSetMusicStart: Bool {
        guard let music = project.music else {
            return false
        }
        return music.largestStart >= SoundGeometry.startStep
    }

    /// Three fields with one space between them when there is no music: the volume of the clips times 100,
    /// "m" for muted or "." for not, and "none". With music six: the same two, then "<start ticks>+<heard ticks>"
    /// or "hidden" when nothing of it is heard, the volume of the music times 100, and the fade in and the
    /// fade out in ticks, both as stored. Digits and fixed marks, the same in every language.
    public var soundInfo: String {
        var fields: [String] = [whole(project.clipVolume * 100), project.clipsMuted ? "m" : "."]
        guard let music = project.music else {
            fields.append("none")
            return fields.joined(separator: " ")
        }
        var heard = "hidden"
        if let length = project.heardMusic {
            heard = String(music.start.ticks) + "+" + String(length.ticks)
        }
        fields.append(heard)
        fields.append(whole(music.volume * 100))
        fields.append(String(music.fadeIn.ticks))
        fields.append(String(music.fadeOut.ticks))
        return fields.joined(separator: " ")
    }

    /// "<start>-<end> / <length>" as clock texts: the part of the file that is heard and the length of the file,
    /// for example "00:00-00:07 / 00:10". Nil when nothing of the music is heard.
    public var musicLabel: String? {
        guard let music = project.music, let heard = project.heardMusic else {
            return nil
        }
        return music.start.clockText + "-" + (music.start + heard).clockText + " / " + music.file.duration.clockText
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
