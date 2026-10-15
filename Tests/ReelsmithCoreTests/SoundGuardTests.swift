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

/// The cases of EditorAction and of TextAction. The runs must send every one. The case sound is counted by
/// the kinds of sound actions.
private enum ActionCase: String, CaseIterable {
    case addClips = "addClips"
    case split = "split"
    case trimStart = "trimStart"
    case trimEnd = "trimEnd"
    case deleteSelected = "deleteSelected"
    case select = "select"
    case clearSelection = "clearSelection"
    case movePlayhead = "movePlayhead"
    case play = "play"
    case pause = "pause"
    case textAdd = "text add"
    case textSelect = "text select"
    case textSetString = "text setString"
    case textSetStyle = "text setStyle"
    case textMove = "text move"
    case textTurn = "text turn"
    case textTrimStart = "text trimStart"
    case textTrimEnd = "text trimEnd"
}

/// The kinds of sound actions: each case of SoundAction in each of its outcomes (done, held at a limit,
/// nothing to do), and the values past a limit. The runs must draw every one.
private enum SoundKind: String, CaseIterable {
    case open = "open on a project with a clip"
    case openEmpty = "open on an empty project"
    case clipVolume = "setClipVolume from 0 to 1 to another value"
    case clipVolumeBelow = "setClipVolume below 0"
    case clipVolumeAbove = "setClipVolume above 1"
    case clipVolumeNotFinite = "setClipVolume with a number that is not finite"
    case clipVolumeSame = "setClipVolume with the value the project has"
    case mute = "muteClips to the other value"
    case muteSame = "muteClips with the value the project has"
    case setMusicLong = "setMusic with long-tone"
    case setMusicShort = "setMusic with short-tone"
    case setMusic500 = "setMusic with a file of 500 ticks"
    case setMusic900 = "setMusic with a file of 900 ticks"
    case setMusicNoLength = "setMusic with a file of no length"
    case setMusicSame = "setMusic with the music the project has"
    case removeMusic = "removeMusic with music"
    case removeNoMusic = "removeMusic with no music"
    case musicVolume = "setMusicVolume from 0 to 1 to another value"
    case musicVolumeBelow = "setMusicVolume below 0"
    case musicVolumeAbove = "setMusicVolume above 1"
    case musicVolumeNotFinite = "setMusicVolume with a number that is not finite"
    case musicVolumeSame = "setMusicVolume with the value the project has"
    case musicVolumeNoMusic = "setMusicVolume with no music"
    case start = "setMusicStart to another whole frame inside its limits"
    case startBelow = "setMusicStart below zero"
    case startAbove = "setMusicStart above the largest start"
    case startOffFrame = "setMusicStart inside its limits and not on a whole frame"
    case startSame = "setMusicStart with the value the project has"
    case startNoMusic = "setMusicStart with no music"
    case fadeIn = "setFadeIn to another whole frame inside its limits"
    case fadeInBelow = "setFadeIn below zero"
    case fadeInAbove = "setFadeIn above 3000"
    case fadeInOffFrame = "setFadeIn inside its limits and not on a whole frame"
    case fadeInSame = "setFadeIn with the value the project has"
    case fadeInNoMusic = "setFadeIn with no music"
    case fadeOut = "setFadeOut to another whole frame inside its limits"
    case fadeOutBelow = "setFadeOut below zero"
    case fadeOutAbove = "setFadeOut above 3000"
    case fadeOutOffFrame = "setFadeOut inside its limits and not on a whole frame"
    case fadeOutSame = "setFadeOut with the value the project has"
    case fadeOutNoMusic = "setFadeOut with no music"

    /// An action of this kind returns a state equal to the one before it.
    var leavesTheStateEqual: Bool {
        switch self {
        case .openEmpty, .clipVolumeNotFinite, .clipVolumeSame, .muteSame, .setMusicNoLength, .setMusicSame,
            .removeNoMusic, .musicVolumeNotFinite, .musicVolumeSame, .musicVolumeNoMusic, .startSame, .startNoMusic,
            .fadeInSame, .fadeInNoMusic, .fadeOutSame, .fadeOutNoMusic:
            return true
        default:
            return false
        }
    }
}

private func actionCase(of action: EditorAction) -> ActionCase? {
    switch action {
    case .addClips:
        return .addClips
    case .split:
        return .split
    case .trimStart:
        return .trimStart
    case .trimEnd:
        return .trimEnd
    case .deleteSelected:
        return .deleteSelected
    case .select:
        return .select
    case .clearSelection:
        return .clearSelection
    case .movePlayhead:
        return .movePlayhead
    case .play:
        return .play
    case .pause:
        return .pause
    case .text(let textAction):
        switch textAction {
        case .add:
            return .textAdd
        case .select:
            return .textSelect
        case .setString:
            return .textSetString
        case .setStyle:
            return .textSetStyle
        case .move:
            return .textMove
        case .turn:
            return .textTurn
        case .trimStart:
            return .textTrimStart
        case .trimEnd:
            return .textTrimEnd
        }
    case .sound:
        return nil
    case .moveClip: return nil
    case .cutBefore: return nil
    case .cutAfter: return nil
    }
}

/// The kind of a volume sent: not finite, the value stored, below 0, above 1, or another value inside.
private func volumeKind(
    _ volume: Double, stored: Double,
    _ kinds: (notFinite: SoundKind, same: SoundKind, below: SoundKind, above: SoundKind, done: SoundKind)
) -> SoundKind {
    if !volume.isFinite {
        return kinds.notFinite
    }
    if volume == stored {
        return kinds.same
    }
    if volume < 0 {
        return kinds.below
    }
    return volume > 1 ? kinds.above : kinds.done
}

/// The kind of a time sent: the value stored, below zero, above the upper limit, inside and not on a whole
/// frame, or another whole frame inside.
private func timeKind(
    _ time: Time, stored: Time, upper: Time,
    _ kinds: (same: SoundKind, below: SoundKind, above: SoundKind, offFrame: SoundKind, done: SoundKind)
) -> SoundKind {
    if time == stored {
        return kinds.same
    }
    if time < Time.zero {
        return kinds.below
    }
    if time > upper {
        return kinds.above
    }
    return time.ticks % Time.frame.ticks != 0 ? kinds.offFrame : kinds.done
}

private func soundKind(of action: SoundAction, in state: EditorState) -> SoundKind {
    let project = state.project
    switch action {
    case .open:
        return project.clips.isEmpty ? .openEmpty : .open
    case .setClipVolume(let volume):
        return volumeKind(
            volume, stored: project.clipVolume,
            (.clipVolumeNotFinite, .clipVolumeSame, .clipVolumeBelow, .clipVolumeAbove, .clipVolume))
    case .muteClips(let muted):
        return muted == project.clipsMuted ? .muteSame : .mute
    case .setMusic(let file):
        if file.duration <= Time.zero {
            return .setMusicNoLength
        }
        if project.music == Music(file: file) {
            return .setMusicSame
        }
        if file == TestTone.long.file {
            return .setMusicLong
        }
        if file == TestTone.short.file {
            return .setMusicShort
        }
        return file.duration.ticks == 500 ? .setMusic500 : .setMusic900
    case .removeMusic:
        return project.music == nil ? .removeNoMusic : .removeMusic
    case .setMusicVolume(let volume):
        guard let music = project.music else {
            return .musicVolumeNoMusic
        }
        return volumeKind(
            volume, stored: music.volume,
            (.musicVolumeNotFinite, .musicVolumeSame, .musicVolumeBelow, .musicVolumeAbove, .musicVolume))
    case .setMusicStart(let start):
        guard let music = project.music else {
            return .startNoMusic
        }
        return timeKind(
            start, stored: music.start, upper: music.largestStart,
            (.startSame, .startBelow, .startAbove, .startOffFrame, .start))
    case .setFadeIn(let fade):
        guard let music = project.music else {
            return .fadeInNoMusic
        }
        return timeKind(
            fade, stored: music.fadeIn, upper: SoundGeometry.maximumFade,
            (.fadeInSame, .fadeInBelow, .fadeInAbove, .fadeInOffFrame, .fadeIn))
    case .setFadeOut(let fade):
        guard let music = project.music else {
            return .fadeOutNoMusic
        }
        return timeKind(
            fade, stored: music.fadeOut, upper: SoundGeometry.maximumFade,
            (.fadeOutSame, .fadeOutBelow, .fadeOutAbove, .fadeOutOffFrame, .fadeOut))
    case .setVolumeOfClip: preconditionFailure("the runs draw no volume of a clip")
    }
}

/// What addClips is given: the five test clips.
private let pool: [MediaInfo] = TestClip.all.map { $0.info }

/// What setString is given: an empty string, spaces only, and plain words.
private let strings: [String] = ["", "  ", "Peace", "a b"]

/// What setMusic is given: the two test tones, a file shorter than minimumMusic, a file whose largest start
/// is shorter than one step, and a file with no length.
private let musicFiles: [MusicFile] = [
    TestTone.long.file, TestTone.short.file, musicFile(ticks: 500), musicFile(ticks: 900), musicFile(ticks: 0),
]

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

/// The amount of a trim, of a clip or of a text: ten thousand ticks either way, at most 60 ticks either way,
/// or at most 800 ticks either way.
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

/// Below 0 down to minus 2, above 1 up to 3, a number that is not finite, the value stored, or a step of
/// 0.05 from 0 to 1.
private func drawVolume(_ draw: inout Draw, stored: Double) -> Double {
    switch draw.below(8) {
    case 0:
        return -Double(1 + draw.below(200)) / 100
    case 1:
        return 1 + Double(1 + draw.below(200)) / 100
    case 2:
        return [Double.nan, Double.infinity, -Double.infinity][draw.below(3)]
    case 3:
        return stored
    default:
        return Double(draw.below(21)) / 20
    }
}

/// Below zero, above the upper limit, inside and not on a whole frame, the value stored, or a whole frame
/// from zero to the upper limit. With an upper limit of zero, the time not on a whole frame is above it.
private func drawTime(_ draw: inout Draw, stored: Time, upper: Time) -> Time {
    let frames = Int(upper.ticks / Time.frame.ticks)
    switch draw.below(8) {
    case 0:
        return Time(ticks: -1 - Int64(draw.below(1000)))
    case 1:
        return Time(ticks: upper.ticks + 1 + Int64(draw.below(2000)))
    case 2:
        return Time(ticks: Int64(draw.below(max(frames, 1))) * Time.frame.ticks + 1 + Int64(draw.below(19)))
    case 3:
        return stored
    default:
        return Time(ticks: Int64(draw.below(frames + 1)) * Time.frame.ticks)
    }
}

private func drawTextAction(_ draw: inout Draw, in state: EditorState) -> TextAction {
    let canvas = state.project.canvas
    switch draw.below(8) {
    case 0:
        return .add
    case 1:
        return .select(drawText(&draw, in: state))
    case 2:
        let text = drawText(&draw, in: state)
        return .setString(text, strings[draw.below(strings.count)])
    case 3:
        let text = drawText(&draw, in: state)
        var style = TextStyle.standard
        style.size = Double(draw.below(500))
        return .setStyle(text, style)
    case 4:
        let text = drawText(&draw, in: state)
        let x = Double(draw.below(canvas.width + 201) - 100)
        let y = Double(draw.below(canvas.height + 201) - 100)
        return .move(text, x: x, y: y)
    case 5:
        let text = drawText(&draw, in: state)
        return .turn(text, to: Double(draw.below(721) - 360))
    case 6:
        let text = drawText(&draw, in: state)
        let amount = drawAmount(&draw)
        return .trimStart(text, by: amount)
    default:
        let text = drawText(&draw, in: state)
        let amount = drawAmount(&draw)
        return .trimEnd(text, by: amount)
    }
}

private func drawSoundAction(_ draw: inout Draw, in state: EditorState) -> SoundAction {
    let project = state.project
    let music = project.music
    switch draw.below(12) {
    case 0...1:
        return .open
    case 2:
        return .setClipVolume(drawVolume(&draw, stored: project.clipVolume))
    case 3:
        return .muteClips(draw.below(2) == 0)
    case 4...5:
        return .setMusic(musicFiles[draw.below(musicFiles.count)])
    case 6:
        return .removeMusic
    case 7:
        return .setMusicVolume(drawVolume(&draw, stored: music?.volume ?? 1))
    case 8...9:
        let upper = music?.largestStart ?? SoundGeometry.maximumFade
        return .setMusicStart(drawTime(&draw, stored: music?.start ?? Time.zero, upper: upper))
    case 10:
        let fade = drawTime(&draw, stored: music?.fadeIn ?? Time.zero, upper: SoundGeometry.maximumFade)
        return .setFadeIn(fade)
    default:
        let fade = drawTime(&draw, stored: music?.fadeOut ?? Time.zero, upper: SoundGeometry.maximumFade)
        return .setFadeOut(fade)
    }
}

/// 21 times in 50 a clip action, 9 times a text action and 20 times a sound action.
private func drawAction(_ draw: inout Draw, in state: EditorState) -> EditorAction {
    switch draw.below(50) {
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
    case 17...18:
        return .movePlayhead(drawPlayhead(&draw, in: state))
    case 19:
        return .play
    case 20:
        return .pause
    case 21...29:
        return .text(drawTextAction(&draw, in: state))
    default:
        return .sound(drawSoundAction(&draw, in: state))
    }
}

/// A broken check: its sentence, the same for every failure of that check, and what was seen.
private struct Fault {
    var check: String
    var detail: String

    init(_ check: String, _ detail: String) {
        self.check = check
        self.detail = detail
    }
}

/// The valid state of M1 and of seam J: every clip inside its source and a whole number of frames, the
/// playhead a whole frame from zero to the project length, the selection a clip of the project or none, every
/// text inside its limits, the selected text a text of the project or none, and a blank text only while it
/// is selected.
private func stateFault(_ state: EditorState) -> Fault? {
    let project = state.project
    let frame = Time.frame.ticks
    for clip in project.clips {
        guard let info = project.media[clip.media] else {
            return Fault("every clip lies inside its source", "clip \(clip.id.raw) has no media facts")
        }
        if clip.sourceStart < Time.zero || clip.sourceStart + clip.duration > info.duration {
            return Fault(
                "every clip lies inside its source",
                "clip \(clip.id.raw) starts at \(clip.sourceStart.ticks) and is \(clip.duration.ticks) ticks long "
                    + "in a source of \(info.duration.ticks)")
        }
        if clip.duration.ticks % frame != 0 || clip.duration < TimelineGeometry.minimumClip {
            return Fault(
                "every clip is a whole number of frames of at least minimumClip",
                "clip \(clip.id.raw) is \(clip.duration.ticks) ticks long")
        }
    }
    if state.playhead.ticks % frame != 0 || state.playhead < Time.zero || state.playhead > project.duration {
        return Fault(
            "the playhead is a whole frame from zero to the project length",
            "it is at \(state.playhead.ticks) ticks in a project of \(project.duration.ticks)")
    }
    if let selection = state.selection, !project.clips.contains(where: { $0.id == selection }) {
        return Fault("the selection is a clip of the project", "it is clip \(selection.raw)")
    }
    let width = Double(project.canvas.width)
    let height = Double(project.canvas.height)
    var ids: Set<TextID> = []
    for text in project.texts {
        if !ids.insert(text.id).inserted {
            return Fault("every text id is used once", "\(text.id.raw) is used twice")
        }
        if case .range(let range) = text.span {
            if range.start < Time.zero || range.start.ticks % frame != 0 || range.duration.ticks % frame != 0
                || range.duration < TextGeometry.minimumText
            {
                return Fault(
                    "every range of a text is whole frames from zero and at least minimumText long",
                    "text \(text.id.raw) starts at \(range.start.ticks) and is \(range.duration.ticks) ticks long")
            }
        }
        if !(text.style.size >= TextGeometry.minimumSize && text.style.size <= TextGeometry.maximumSize) {
            return Fault("every size of a text lies inside its limits", "text \(text.id.raw) is \(text.style.size)")
        }
        if !(text.x >= 0 && text.x <= width && text.y >= 0 && text.y <= height) {
            return Fault("every centre of a text lies inside the canvas", "text \(text.id.raw) is at \(text.x), \(text.y)")
        }
        if !(text.rotation > -180 && text.rotation <= 180) {
            return Fault(
                "every rotation of a text is above minus 180 and at most 180",
                "text \(text.id.raw) is turned \(text.rotation)")
        }
        if text.isBlank && state.selectedText != text.id {
            return Fault("a blank text exists only while it is selected", "text \(text.id.raw) is blank")
        }
    }
    if let selected = state.selectedText, project.text(selected) == nil {
        return Fault("the selected text is a text of the project", "it is text \(selected.raw)")
    }
    return nil
}

/// The valid state as seam P adds to it.
private func soundFault(_ state: EditorState) -> Fault? {
    let project = state.project
    let frame = Time.frame.ticks
    if !(project.clipVolume >= 0 && project.clipVolume <= 1) {
        return Fault("the volume of the clips lies from 0 to 1", "it is \(project.clipVolume)")
    }
    if let music = project.music {
        if !(music.volume >= 0 && music.volume <= 1) {
            return Fault("the volume of the music lies from 0 to 1", "it is \(music.volume)")
        }
        if music.start < Time.zero || music.start > music.largestStart || music.start.ticks % frame != 0 {
            return Fault(
                "the start of the music is a whole frame from zero to its largest start",
                "it is \(music.start.ticks) ticks and the largest start is \(music.largestStart.ticks)")
        }
        for fade in [music.fadeIn, music.fadeOut] {
            if fade < Time.zero || fade > SoundGeometry.maximumFade || fade.ticks % frame != 0 {
                return Fault(
                    "both fades are whole frames from zero to maximumFade",
                    "the fade in is \(music.fadeIn.ticks) ticks and the fade out \(music.fadeOut.ticks)")
            }
        }
        if music.file.duration <= Time.zero {
            return Fault("the file of the music has a length above zero", "it is \(music.file.duration.ticks) ticks")
        }
    }
    let set = [state.selection != nil, state.selectedText != nil, state.showsSound].filter({ $0 }).count
    if set > 1 {
        return Fault(
            "at most one of selection, selectedText and showsSound is set",
            "selection \(String(describing: state.selection)), selectedText "
                + "\(String(describing: state.selectedText)), showsSound \(state.showsSound)")
    }
    if state.showsSound && project.clips.isEmpty {
        return Fault("showsSound is false on an empty project", "it is true")
    }
    return nil
}

/// heardMusic, soundInfo and canSetMusicStart against the project.
private func readFault(_ state: EditorState) -> Fault? {
    let project = state.project
    if let music = project.music, !project.clips.isEmpty {
        let expected = min(music.file.duration - music.start, project.duration)
        if project.heardMusic != expected || expected <= Time.zero {
            return Fault(
                "heardMusic is the smaller of the file less the start and the project, above zero",
                "it is \(String(describing: project.heardMusic?.ticks)) and the smaller is \(expected.ticks)")
        }
    } else if project.heardMusic != nil {
        return Fault(
            "heardMusic is nil when there is no music or no clip",
            "it is \(String(describing: project.heardMusic?.ticks))")
    }
    let fields = state.soundInfo.split(separator: " ", omittingEmptySubsequences: false)
    if fields.count != (project.music == nil ? 3 : 6) {
        return Fault("soundInfo has three fields with no music and six with music", "it is \(state.soundInfo)")
    }
    if (fields[2] == "hidden") != (project.music != nil && project.clips.isEmpty) {
        return Fault(
            "the third field of soundInfo is hidden exactly when there is music and no clip",
            "it is \(state.soundInfo)")
    }
    var fits = false
    if let music = project.music {
        fits = music.largestStart >= SoundGeometry.startStep
    }
    if state.canSetMusicStart != fits {
        return Fault(
            "canSetMusicStart is true exactly when the largest start of the music is at least startStep",
            "it is \(state.canSetMusicStart)")
    }
    return nil
}

/// The sound of the render plan of a project with a clip, and its music layer.
private func planFault(_ project: Project) -> Fault? {
    guard !project.clips.isEmpty else {
        return nil
    }
    let plan: RenderPlan
    do {
        plan = try renderPlan(for: project)
    } catch {
        return Fault("renderPlan does not throw", "it threw \(error)")
    }
    let clipVolume = project.clipsMuted ? 0 : project.clipVolume
    if plan.sound.clipVolume != clipVolume {
        return Fault(
            "the plan has the volume of the clips, 0 when they are muted",
            "it has \(plan.sound.clipVolume) for \(project.clipVolume), muted \(project.clipsMuted)")
    }
    guard let layer = plan.sound.music, let music = project.music, let heard = project.heardMusic else {
        if (plan.sound.music == nil) != (project.heardMusic == nil) {
            return Fault(
                "the plan has a music layer exactly when heardMusic is not nil",
                "the layer is \(String(describing: plan.sound.music)), heardMusic "
                    + "\(String(describing: project.heardMusic?.ticks))")
        }
        return nil
    }
    if layer.sourceStart != music.start {
        return Fault(
            "the layer starts in the file at the start of the music",
            "it starts at \(layer.sourceStart.ticks) and the music at \(music.start.ticks)")
    }
    if layer.duration != heard || layer.duration <= Time.zero || layer.duration > plan.duration {
        return Fault(
            "the layer is heardMusic long, above zero and at most the plan",
            "it is \(layer.duration.ticks) ticks, heardMusic \(heard.ticks), the plan \(plan.duration.ticks)")
    }
    if layer.sourceStart + layer.duration > music.file.duration {
        return Fault(
            "the layer lies inside its file",
            "it ends at \((layer.sourceStart + layer.duration).ticks) in a file of \(music.file.duration.ticks)")
    }
    let half = Time(ticks: layer.duration.ticks / 2)
    if layer.fadeIn != min(music.fadeIn, half) || layer.fadeOut != min(music.fadeOut, half)
        || layer.fadeIn + layer.fadeOut > layer.duration
    {
        return Fault(
            "each fade of the layer is the stored fade cut to half the layer",
            "the layer has \(layer.fadeIn.ticks) and \(layer.fadeOut.ticks) for \(music.fadeIn.ticks) and "
                + "\(music.fadeOut.ticks) stored and \(layer.duration.ticks) heard")
    }
    if layer.media != music.file.id || layer.fileName != music.file.fileName || layer.volume != music.volume {
        return Fault("the layer carries the id, the file name and the volume of the music", "\(layer)")
    }
    return nil
}

/// What the action did that its kind must not do, or nil.
private func editFault(before: EditorState, action: EditorAction, after: EditorState, kind: SoundKind?) -> Fault? {
    let project = before.project
    if let kind {
        if kind.leavesTheStateEqual && after != before {
            return Fault("a sound action with nothing to do returns the state equal", "it was \(kind.rawValue)")
        }
        if kind == .open && !(after.showsSound && after.selection == nil && after.selectedText == nil) {
            return Fault(
                "open on a project with a clip shows the panel and clears both selections",
                "showsSound \(after.showsSound), selection \(String(describing: after.selection)), "
                    + "selectedText \(String(describing: after.selectedText))")
        }
        if action != .sound(.open) && after != before && after.isPlaying != (before.isPlaying && ![SoundKind.setMusicLong, .setMusicShort, .setMusic500, .setMusic900, .removeMusic, .start, .startBelow, .startAbove, .startOffFrame].contains(kind)) {
            return Fault("a sound action but open that changes the state pauses", "it was \(kind.rawValue)")
        }
        return nil
    }
    if after.project.clipVolume != project.clipVolume || after.project.clipsMuted != project.clipsMuted
        || after.project.music != project.music
    {
        return Fault(
            "no clip action and no text action changes sound",
            "the volume of the clips went from \(project.clipVolume) to \(after.project.clipVolume), the mute from "
                + "\(project.clipsMuted) to \(after.project.clipsMuted), the music from "
                + "\(String(describing: project.music)) to \(String(describing: after.project.music))")
    }
    var closes = false
    switch action {
    case .select(let id):
        closes = project.clips.contains(where: { $0.id == id })
    case .text(.select(let id)):
        closes = project.text(id) != nil
    case .text(.add):
        closes = !project.clips.isEmpty
    case .clearSelection:
        closes = true
    default:
        break
    }
    if closes && after.showsSound {
        return Fault(
            "a select of a clip or a text, an add of a text and clearSelection close the panel", "it stayed open")
    }
    return nil
}

/// Plays 1000 runs of 50 actions from the seed, with the start numbers 1 to 1000, and checks the state after
/// every action. The start state has the selected text and the open panel a start of the app on the seed has.
/// A run stops at its first failure and the next run is played. Each check fails the test once, with the
/// first run that broke it.
private func playRuns(
    from seed: Seed, counts: inout [SoundKind: Int], cases: inout [ActionCase: Int], reported: inout Set<String>
) {
    var start = EditorState(project: seed.project)
    start.selectedText = seed.selectedText
    start.showsSound = seed.showsSound
    if let fault = stateFault(start) ?? soundFault(start) {
        XCTFail("the start state of \(seed.rawValue) is not valid: \(fault.check): \(fault.detail)")
        return
    }
    for startNumber in 1...1000 {
        var draw = Draw(startNumber: startNumber)
        var state = start
        var sent: [EditorAction] = []
        for _ in 1...50 {
            let action = drawAction(&draw, in: state)
            sent.append(action)
            var kind: SoundKind?
            if case .sound(let soundAction) = action {
                let drawn = soundKind(of: soundAction, in: state)
                counts[drawn, default: 0] += 1
                kind = drawn
            } else if let drawn = actionCase(of: action) {
                cases[drawn, default: 0] += 1
            }
            let next = reduce(state, action)
            var fault = stateFault(next) ?? soundFault(next) ?? readFault(next)
            if fault == nil {
                fault = planFault(next.project) ?? editFault(before: state, action: action, after: next, kind: kind)
            }
            if let fault {
                if reported.insert(fault.check).inserted {
                    XCTFail(
                        "seed \(seed.rawValue), start number \(startNumber), action \(sent.count) of 50: "
                            + "\(fault.check): \(fault.detail). The actions of this run, the last one being the "
                            + "one that failed: \(sent)")
                }
                break
            }
            state = next
        }
    }
}

final class SoundGuardTests: XCTestCase {
    func testThreeThousandRunsOfFiftyClipTextAndSoundActionsKeepTheStateValidAndTheMusicInsideTheProject() {
        var counts: [SoundKind: Int] = [:]
        var cases: [ActionCase: Int] = [:]
        var reported: Set<String> = []
        for seed in [Seed.musicWide, Seed.textWide, Seed.threeClips] {
            playRuns(from: seed, counts: &counts, cases: &cases, reported: &reported)
        }
        for actionCase in ActionCase.allCases {
            XCTAssertGreaterThan(cases[actionCase, default: 0], 0, "the runs never sent: \(actionCase.rawValue)")
        }
        for kind in SoundKind.allCases {
            XCTAssertGreaterThan(counts[kind, default: 0], 0, "the runs never drew: \(kind.rawValue)")
        }
    }
}
