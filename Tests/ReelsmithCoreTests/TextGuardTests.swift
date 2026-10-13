import ReelsmithCore
import XCTest

/// A random source of our own with a fixed start number (SplitMix64). It uses whole number arithmetic only,
/// so a start number gives the same run on Linux and on Apple platforms.
private struct Draw {
    private var state: UInt64

    init(startNumber: Int) {
        state = UInt64(startNumber)
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A whole number from zero up to the count, the count itself left out.
    mutating func below(_ count: Int) -> Int {
        Int(next() % UInt64(count))
    }
}

/// The clip actions as they are drawn. The runs must hold every one.
private enum ClipKind: String, CaseIterable {
    case addClips = "addClips"
    case split = "split"
    case trimStart = "trimStart of a clip of the project"
    case trimEnd = "trimEnd of a clip of the project"
    case trimUnknown = "a trim of a clip id that is not in the project"
    case deleteNoText = "deleteSelected with no text selected"
    case deleteText = "deleteSelected with a text selected"
    case select = "select of a clip of the project"
    case selectUnknown = "select of a clip id that is not in the project"
    case clearSelection = "clearSelection"
    case movePlayhead = "movePlayhead"
    case play = "play"
    case pause = "pause"
}

/// The kinds of text actions: each case of TextAction in each of its outcomes (done, held at a limit,
/// unknown id, nothing to do), and the values past a limit or on it. The runs must hold every one.
private enum TextKind: String, CaseIterable {
    case add = "add on a project with a clip"
    case addOnEmpty = "add on an empty project"
    case select = "select of a text of the project"
    case selectUnknown = "select of a text id that is not in the project"
    case setString = "setString of a text of the project"
    case setStringUnknown = "setString of a text id that is not in the project"
    case stringEmpty = "setString with an empty string"
    case stringSpaces = "setString with a string of spaces only"
    case stringLineBreak = "setString with a line break"
    case stringArabic = "setString with the Arabic line"
    case setStyle = "setStyle inside its limits"
    case sizeBelow = "setStyle with a size below minimumSize"
    case sizeAbove = "setStyle with a size above maximumSize"
    case spacingBelow = "setStyle with a line spacing below 0"
    case spacingAbove = "setStyle with a line spacing above 2"
    case setStyleUnknown = "setStyle of a text id that is not in the project"
    case move = "move to a centre inside the canvas"
    case movePastLeft = "move to left of the canvas"
    case movePastRight = "move to right of the canvas"
    case movePastTop = "move to above the canvas"
    case movePastBottom = "move to below the canvas"
    case moveOnLeft = "move onto the left edge"
    case moveOnRight = "move onto the right edge"
    case moveOnTop = "move onto the top edge"
    case moveOnBottom = "move onto the bottom edge"
    case moveUnknown = "move of a text id that is not in the project"
    case turn = "turn to an angle inside its limits and more than 3 from 0"
    case turnBelow = "turn to below minus 180"
    case turnAbove = "turn to above 180"
    case turnNearZero = "turn to at most 3 from 0"
    case turnUnknown = "turn of a text id that is not in the project"
    case trimStart = "trimStart of a text inside its limits"
    case trimStartNegative = "trimStart of a text by a negative amount"
    case trimStartPastProject = "trimStart of a text to before the start of the project"
    case trimStartPastShortest = "trimStart of a text by more than leaves minimumText"
    case trimStartShort = "trimStart of a text whose seen range is shorter than minimumText"
    case trimStartNoRange = "trimStart of a text with no range"
    case trimStartUnknown = "trimStart of a text id that is not in the project"
    case trimEnd = "trimEnd of a text inside its limits"
    case trimEndNegative = "trimEnd of a text by a negative amount"
    case trimEndPastProject = "trimEnd of a text to after the end of the project"
    case trimEndPastShortest = "trimEnd of a text by more than leaves minimumText"
    case trimEndShort = "trimEnd of a text whose seen range is shorter than minimumText"
    case trimEndNoRange = "trimEnd of a text with no range"
    case trimEndUnknown = "trimEnd of a text id that is not in the project"

    /// An action of this kind returns a state equal to the one before it.
    var leavesTheStateEqual: Bool {
        switch self {
        case .addOnEmpty, .selectUnknown, .setStringUnknown, .setStyleUnknown, .moveUnknown, .turnUnknown,
            .trimStartUnknown, .trimEndUnknown, .trimStartNoRange, .trimEndNoRange, .trimEndShort:
            return true
        default:
            return false
        }
    }
}

private func clipKind(of action: EditorAction, in state: EditorState) -> ClipKind? {
    let clips = state.project.clips
    switch action {
    case .addClips:
        return .addClips
    case .split:
        return .split
    case .trimStart(let id, _):
        return clips.contains(where: { $0.id == id }) ? .trimStart : .trimUnknown
    case .trimEnd(let id, _):
        return clips.contains(where: { $0.id == id }) ? .trimEnd : .trimUnknown
    case .deleteSelected:
        return state.selectedText == nil ? .deleteNoText : .deleteText
    case .select(let id):
        return clips.contains(where: { $0.id == id }) ? .select : .selectUnknown
    case .clearSelection:
        return .clearSelection
    case .movePlayhead:
        return .movePlayhead
    case .play:
        return .play
    case .pause:
        return .pause
    case .text:
        return nil
    }
}

private func textKinds(of action: TextAction, in state: EditorState) -> [TextKind] {
    let project = state.project
    switch action {
    case .add:
        return [project.clips.isEmpty ? .addOnEmpty : .add]
    case .select(let id):
        return [project.text(id) == nil ? .selectUnknown : .select]
    case .setString(let id, let string):
        guard project.text(id) != nil else {
            return [.setStringUnknown]
        }
        var kinds: [TextKind] = [.setString]
        if string.isEmpty {
            kinds.append(.stringEmpty)
        } else if string.allSatisfy({ $0 == " " }) {
            kinds.append(.stringSpaces)
        }
        if string.contains(where: { $0.isNewline }) {
            kinds.append(.stringLineBreak)
        }
        if string == arabicLine() {
            kinds.append(.stringArabic)
        }
        return kinds
    case .setStyle(let id, let style):
        guard project.text(id) != nil else {
            return [.setStyleUnknown]
        }
        var kinds: [TextKind] = []
        if style.size < TextGeometry.minimumSize {
            kinds.append(.sizeBelow)
        }
        if style.size > TextGeometry.maximumSize {
            kinds.append(.sizeAbove)
        }
        if style.lineSpacing < 0 {
            kinds.append(.spacingBelow)
        }
        if style.lineSpacing > 2 {
            kinds.append(.spacingAbove)
        }
        return kinds.isEmpty ? [.setStyle] : kinds
    case .move(let id, let x, let y):
        guard project.text(id) != nil else {
            return [.moveUnknown]
        }
        let width = Double(project.canvas.width)
        let height = Double(project.canvas.height)
        var kinds: [TextKind] = []
        if x < 0 {
            kinds.append(.movePastLeft)
        }
        if x > width {
            kinds.append(.movePastRight)
        }
        if y < 0 {
            kinds.append(.movePastTop)
        }
        if y > height {
            kinds.append(.movePastBottom)
        }
        if kinds.isEmpty {
            kinds.append(.move)
        }
        if x == 0 {
            kinds.append(.moveOnLeft)
        }
        if x == width {
            kinds.append(.moveOnRight)
        }
        if y == 0 {
            kinds.append(.moveOnTop)
        }
        if y == height {
            kinds.append(.moveOnBottom)
        }
        return kinds
    case .turn(let id, let angle):
        guard project.text(id) != nil else {
            return [.turnUnknown]
        }
        if angle < -180 {
            return [.turnBelow]
        }
        if angle > 180 {
            return [.turnAbove]
        }
        return [angle >= -3 && angle <= 3 ? .turnNearZero : .turn]
    case .trimStart(let id, let amount):
        guard project.text(id) != nil else {
            return [.trimStartUnknown]
        }
        guard let seen = project.range(of: id) else {
            return [.trimStartNoRange]
        }
        if seen.duration < TextGeometry.minimumText {
            return [.trimStartShort]
        }
        var kinds: [TextKind] = []
        if amount < Time.zero - seen.start {
            kinds.append(.trimStartPastProject)
        } else if amount > seen.duration - TextGeometry.minimumText {
            kinds.append(.trimStartPastShortest)
        } else {
            kinds.append(.trimStart)
        }
        if amount < Time.zero {
            kinds.append(.trimStartNegative)
        }
        return kinds
    case .trimEnd(let id, let amount):
        guard project.text(id) != nil else {
            return [.trimEndUnknown]
        }
        guard let seen = project.range(of: id) else {
            return [.trimEndNoRange]
        }
        if seen.duration < TextGeometry.minimumText {
            return [.trimEndShort]
        }
        var kinds: [TextKind] = []
        if amount < seen.start + seen.duration - project.duration {
            kinds.append(.trimEndPastProject)
        } else if amount > seen.duration - TextGeometry.minimumText {
            kinds.append(.trimEndPastShortest)
        } else {
            kinds.append(.trimEnd)
        }
        if amount < Time.zero {
            kinds.append(.trimEndNegative)
        }
        return kinds
    }
}

/// What addClips is given: the five test clips.
private let pool: [MediaInfo] = TestClip.all.map { $0.info }

/// What setString is given: an empty string, spaces only, a line break, the Arabic line, and plain words.
private let strings: [String] = ["", "  ", "one\ntwo", arabicLine(), "Peace", "BOX", "be upon you", "a b"]

/// One time in four an id that no clip has, else the id of a clip of the project.
private func drawClip(_ draw: inout Draw, in state: EditorState) -> ClipID {
    let clips = state.project.clips
    if clips.isEmpty || draw.below(4) == 0 {
        return ClipID(state.project.nextClipID + draw.below(3))
    }
    return clips[draw.below(clips.count)].id
}

/// One time in eight an id that no text has, else the id of a text of the project.
private func drawText(_ draw: inout Draw, in state: EditorState) -> TextID {
    let texts = state.project.texts
    if texts.isEmpty || draw.below(8) == 0 {
        return TextID(state.project.nextTextID + draw.below(3))
    }
    return texts[draw.below(texts.count)].id
}

/// The amount of a trim, of a clip or of a text. Ten thousand ticks either way are past every limit, since
/// no project of the runs is that long. One time in three the amount is at most 60 ticks either way.
private func drawAmount(_ draw: inout Draw) -> Time {
    switch draw.below(6) {
    case 0:
        return Time(ticks: 10_000 + Int64(draw.below(40)))
    case 1:
        return Time(ticks: -10_000 - Int64(draw.below(40)))
    case 2...3:
        return Time(ticks: Int64(draw.below(121)) - 60)
    default:
        return Time(ticks: Int64(draw.below(1601)) - 800)
    }
}

private func drawPlayhead(_ draw: inout Draw, in state: EditorState) -> Time {
    let length = state.project.duration.ticks
    switch draw.below(6) {
    case 0:
        return Time(ticks: -1 - Int64(draw.below(1000)))
    case 1:
        return Time(ticks: length + 1 + Int64(draw.below(1000)))
    default:
        return Time(ticks: Int64(draw.below(Int(length) + 1)))
    }
}

/// A size from minus 24 to 1000 and a line spacing from minus 1 to 3, each past a limit one time in three.
private func drawStyle(_ draw: inout Draw) -> TextStyle {
    var style = TextStyle.standard
    style.font = TextFont.allCases[draw.below(TextFont.allCases.count)]
    switch draw.below(6) {
    case 0:
        style.size = Double(15 - draw.below(40))
    case 1:
        style.size = Double(401 + draw.below(600))
    default:
        style.size = Double(16 + draw.below(385))
    }
    style.colour = TextStyle.palette[draw.below(TextStyle.palette.count)]
    style.align = TextAlign.allCases[draw.below(TextAlign.allCases.count)]
    switch draw.below(6) {
    case 0:
        style.lineSpacing = Double(-1 - draw.below(10)) / 10
    case 1:
        style.lineSpacing = 2 + Double(1 + draw.below(10)) / 10
    default:
        style.lineSpacing = Double(draw.below(21)) / 10
    }
    style.outline = draw.below(2) == 0
    style.shadow = draw.below(2) == 0
    style.box = draw.below(2) == 0
    return style
}

/// One side of a centre on a canvas that many pixels long: before it, after it, on each of its two edges,
/// or inside.
private func drawPlace(_ draw: inout Draw, length: Int) -> Double {
    switch draw.below(8) {
    case 0:
        return Double(-1 - draw.below(500))
    case 1:
        return Double(length + 1 + draw.below(500))
    case 2:
        return 0
    case 3:
        return Double(length)
    default:
        return Double(draw.below(length + 1))
    }
}

/// Below minus 180, above 180, at most 3 from 0 in tenths, or a whole angle from minus 179 to 180.
private func drawAngle(_ draw: inout Draw) -> Double {
    switch draw.below(6) {
    case 0:
        return Double(-181 - draw.below(600))
    case 1:
        return Double(181 + draw.below(600))
    case 2:
        return Double(draw.below(61) - 30) / 10
    default:
        return Double(draw.below(360) - 179)
    }
}

private func drawTextAction(_ draw: inout Draw, in state: EditorState) -> TextAction {
    let canvas = state.project.canvas
    switch draw.below(21) {
    case 0...2:
        return .add
    case 3...4:
        return .select(drawText(&draw, in: state))
    case 5...6:
        let text = drawText(&draw, in: state)
        return .setString(text, strings[draw.below(strings.count)])
    case 7...8:
        let text = drawText(&draw, in: state)
        return .setStyle(text, drawStyle(&draw))
    case 9...10:
        let text = drawText(&draw, in: state)
        let x = drawPlace(&draw, length: canvas.width)
        let y = drawPlace(&draw, length: canvas.height)
        return .move(text, x: x, y: y)
    case 11...12:
        let text = drawText(&draw, in: state)
        return .turn(text, to: drawAngle(&draw))
    case 13...16:
        let text = drawText(&draw, in: state)
        let amount = drawAmount(&draw)
        return .trimStart(text, by: amount)
    default:
        let text = drawText(&draw, in: state)
        let amount = drawAmount(&draw)
        return .trimEnd(text, by: amount)
    }
}

/// 22 times in 47 a clip action, else a text action.
private func drawAction(_ draw: inout Draw, in state: EditorState) -> EditorAction {
    switch draw.below(47) {
    case 0:
        var given: [MediaInfo] = []
        let count = draw.below(3)
        for _ in 0..<count {
            given.append(pool[draw.below(pool.count)])
        }
        return .addClips(given)
    case 1...2:
        return .split
    case 3...5:
        let clip = drawClip(&draw, in: state)
        let amount = drawAmount(&draw)
        return .trimStart(clip, by: amount)
    case 6...8:
        let clip = drawClip(&draw, in: state)
        let amount = drawAmount(&draw)
        return .trimEnd(clip, by: amount)
    case 9...11:
        return .deleteSelected
    case 12...15:
        return .select(drawClip(&draw, in: state))
    case 16:
        return .clearSelection
    case 17...19:
        return .movePlayhead(drawPlayhead(&draw, in: state))
    case 20:
        return .play
    case 21:
        return .pause
    default:
        return .text(drawTextAction(&draw, in: state))
    }
}

/// The valid state that `reduce` must keep. For the clips: "A state is valid when every clip lies inside its
/// source, every clip length is a whole number of frames and at least `minimumClip`, the playhead is a whole
/// frame from zero to the project length, and the selection is a clip of the project or none." For the texts:
/// "every text id is used once, every `.range` starts at a whole frame not below zero and is a whole number of
/// frames of at least `minimumText`, every size lies between the two limits, every centre lies inside the
/// canvas, every rotation is above minus 180 and at most 180, `selectedText` is a text of the project or nil,
/// at most one selection is set, and a blank text exists only while it is selected."
/// Answers the first part of those sentences the state breaks, or nil for a valid state.
private func breach(in state: EditorState) -> String? {
    let project = state.project
    let frame = Time.frame.ticks
    for clip in project.clips {
        guard let info = project.media[clip.media] else {
            return "clip \(clip.id.raw) has no media facts, so no source to lie inside"
        }
        if clip.sourceStart < Time.zero || clip.sourceStart + clip.duration > info.duration {
            return "clip \(clip.id.raw) lies outside its source: it starts at \(clip.sourceStart.ticks) and is "
                + "\(clip.duration.ticks) ticks long in a source of \(info.duration.ticks)"
        }
        if clip.duration.ticks % frame != 0 || clip.duration < TimelineGeometry.minimumClip {
            return "the length of clip \(clip.id.raw) is \(clip.duration.ticks) ticks"
        }
    }
    if state.playhead.ticks % frame != 0 || state.playhead < Time.zero || state.playhead > project.duration {
        return "the playhead is at \(state.playhead.ticks) ticks in a project of \(project.duration.ticks)"
    }
    if let selection = state.selection, !project.clips.contains(where: { $0.id == selection }) {
        return "the selection is clip \(selection.raw), which is not in the project"
    }
    let width = Double(project.canvas.width)
    let height = Double(project.canvas.height)
    var ids: Set<TextID> = []
    for text in project.texts {
        if !ids.insert(text.id).inserted {
            return "the text id \(text.id.raw) is used twice"
        }
        if case .range(let range) = text.span {
            if range.start < Time.zero || range.start.ticks % frame != 0 {
                return "the range of text \(text.id.raw) starts at \(range.start.ticks) ticks"
            }
            if range.duration.ticks % frame != 0 || range.duration < TextGeometry.minimumText {
                return "the range of text \(text.id.raw) is \(range.duration.ticks) ticks long"
            }
        }
        if !(text.style.size >= TextGeometry.minimumSize && text.style.size <= TextGeometry.maximumSize) {
            return "the size of text \(text.id.raw) is \(text.style.size), outside its two limits"
        }
        if !(text.x >= 0 && text.x <= width && text.y >= 0 && text.y <= height) {
            return "the centre of text \(text.id.raw) is \(text.x), \(text.y), outside the canvas"
        }
        if !(text.rotation > -180 && text.rotation <= 180) {
            return "the rotation of text \(text.id.raw) is \(text.rotation)"
        }
        if text.isBlank && state.selectedText != text.id {
            return "text \(text.id.raw) is blank and not selected"
        }
    }
    if let selected = state.selectedText, project.text(selected) == nil {
        return "the selected text is \(selected.raw), which is not in the project"
    }
    if state.selection != nil && state.selectedText != nil {
        return "a clip and a text are both selected"
    }
    return nil
}

/// What is wrong with the render plan of the project, or nil.
private func planBreach(for project: Project) -> String? {
    let plan: RenderPlan
    do {
        plan = try renderPlan(for: project)
    } catch {
        return "renderPlan threw \(error)"
    }
    if plan.duration != project.duration {
        return "the plan is \(plan.duration.ticks) ticks long and the project \(project.duration.ticks)"
    }
    var before = Time.zero
    for segment in plan.segments {
        if segment.timelineStart != before {
            return "the segment of clip \(segment.clip.raw) starts at \(segment.timelineStart.ticks) on the "
                + "timeline, and the segments before it are \(before.ticks) ticks long"
        }
        before = before + segment.duration
    }
    let shown = project.texts.filter { !$0.isBlank && project.range(of: $0.id) != nil }
    if plan.texts.map({ $0.text }) != shown.map({ $0.id }) {
        return "the plan has the layers of the texts \(plan.texts.map({ $0.text.raw })), and the texts that are "
            + "not blank and have a range are \(shown.map({ $0.id.raw }))"
    }
    for (layer, text) in zip(plan.texts, shown) {
        let name = "the layer of text \(text.id.raw)"
        if layer.timelineStart < Time.zero || layer.timelineStart.ticks % Time.frame.ticks != 0 {
            return "\(name) starts at \(layer.timelineStart.ticks) ticks"
        }
        if layer.duration <= Time.zero {
            return "\(name) is \(layer.duration.ticks) ticks long"
        }
        if layer.timelineStart + layer.duration > plan.duration {
            return "\(name) ends at \((layer.timelineStart + layer.duration).ticks) ticks in a plan of "
                + "\(plan.duration.ticks)"
        }
        if project.range(of: text.id) != TextRange(start: layer.timelineStart, duration: layer.duration) {
            return "\(name) does not have the start and the length of the range of its text"
        }
        if layer.string != text.string || layer.x != text.x || layer.y != text.y
            || layer.rotation != text.rotation || layer.style != text.style
        {
            return "\(name) does not carry the string, the centre, the rotation and the style of its text"
        }
        if layer.lineWidth != Double(project.canvas.width) * TextGeometry.wrapShare {
            return "\(name) has the line width \(layer.lineWidth)"
        }
    }
    return nil
}

/// What is wrong with `textInfo` of the state, or nil.
private func infoBreach(in state: EditorState) -> String? {
    let info = state.textInfo
    guard let selected = state.selectedText else {
        return info == "none" ? nil : "no text is selected and textInfo is \(info)"
    }
    let fields = info.split(separator: " ", omittingEmptySubsequences: false)
    if fields.count != 10 || fields.contains(where: { $0.isEmpty }) {
        return "a text is selected and textInfo is not ten fields with one space between them: \(info)"
    }
    if (fields[8] == "hidden") != (state.project.range(of: selected) == nil) {
        return "the ninth field of textInfo is \(fields[8]), against the range of the selected text"
    }
    return nil
}

/// What the action did that its kind must not do, or nil. The highest is that of the text ids seen in the run
/// before the action.
private func editBreach(before: EditorState, action: EditorAction, after: EditorState, highest: Int) -> String? {
    if case .text(let textAction) = action {
        if case .add = textAction, before.canAddText {
            guard let given = after.selectedText, given.raw > highest else {
                return "add did not give an id higher than \(highest), the highest text id seen in the run"
            }
        }
        return nil
    }
    if case .deleteSelected = action, let selected = before.selectedText {
        if !before.canDelete {
            return "a text was selected and canDelete was false"
        }
        if after.project.texts != before.project.texts.filter({ $0.id != selected }) {
            return "deleteSelected with text \(selected.raw) selected did not remove exactly that text"
        }
        if after.project.clips != before.project.clips {
            return "deleteSelected with a text selected changed the clips"
        }
        return nil
    }
    // A clip action. A blank text that lost its selection is gone, and no other text differs.
    let kept = before.project.texts.filter {
        !($0.isBlank && $0.id == before.selectedText && $0.id != after.selectedText)
    }
    if after.project.texts != kept {
        return "a clip action changed the texts"
    }
    return nil
}

/// Plays 1000 runs of 50 actions from the seed, with the start numbers 1 to 1000, and checks the state after
/// every action. A text seed starts with its text selected, as a start of the app on it does. Counts how often
/// each kind of action was drawn. Answers false after a failure.
private func playRuns(from seed: Seed, counts: inout [String: Int]) -> Bool {
    var start = EditorState(project: seed.project)
    start.selectedText = seed.selectedText
    if let fault = breach(in: start) {
        XCTFail("the start state of \(seed.rawValue) is not valid: \(fault)")
        return false
    }
    for startNumber in 1...1000 {
        var draw = Draw(startNumber: startNumber)
        var state = start
        var sent: [EditorAction] = []
        var highest = state.project.texts.map({ $0.id.raw }).max() ?? 0
        for _ in 1...50 {
            let action = drawAction(&draw, in: state)
            sent.append(action)
            var mustStayEqual = false
            if case .text(let textAction) = action {
                for kind in textKinds(of: textAction, in: state) {
                    counts[kind.rawValue, default: 0] += 1
                    mustStayEqual = mustStayEqual || kind.leavesTheStateEqual
                }
            } else if let kind = clipKind(of: action, in: state) {
                counts[kind.rawValue, default: 0] += 1
            }
            let next = reduce(state, action)
            var fault = breach(in: next) ?? planBreach(for: next.project) ?? infoBreach(in: next)
            if fault == nil {
                fault = editBreach(before: state, action: action, after: next, highest: highest)
            }
            if fault == nil && mustStayEqual && next != state {
                fault = "the action had nothing to do and the state is not equal to the one before it"
            }
            if let fault {
                XCTFail(
                    "seed \(seed.rawValue), start number \(startNumber), action \(sent.count) of 50: \(fault). "
                        + "The actions of this run, the last one being the one that failed: \(sent)")
                return false
            }
            if !next.project.clips.isEmpty
                && next.project.texts.contains(where: { next.project.range(of: $0.id) == nil })
            {
                counts["count: states with a text past the end of a project with clips", default: 0] += 1
            }
            if let selected = next.selectedText, next.project.range(of: selected) == nil {
                counts["count: states with a hidden selected text", default: 0] += 1
            }
            if state.project.texts.contains(where: { $0.isBlank }) && !next.project.texts.contains(where: { $0.isBlank }) {
                counts["count: actions after which a blank text was gone", default: 0] += 1
            }
            highest = max(highest, next.project.texts.map({ $0.id.raw }).max() ?? 0)
            state = next
        }
    }
    return true
}

final class TextGuardTests: XCTestCase {
    func testThreeThousandRunsOfFiftyClipAndTextActionsKeepTheStateValidAndThePlanInsideTheProject() {
        var counts: [String: Int] = [:]
        for seed in [Seed.textWide, Seed.textBoxWide, Seed.threeClips] {
            guard playRuns(from: seed, counts: &counts) else {
                return
            }
        }
        for name in counts.keys.sorted() {
            print("text guard: \(counts[name, default: 0]) \(name)")
        }
        for kind in ClipKind.allCases.map(\.rawValue) + TextKind.allCases.map(\.rawValue) {
            XCTAssertGreaterThan(counts[kind, default: 0], 0, "the runs never drew: \(kind)")
        }
    }
}
