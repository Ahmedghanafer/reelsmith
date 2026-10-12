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

private func media(_ name: String, ticks: Int64) -> MediaInfo {
    MediaInfo(
        id: MediaID(name), fileName: name + ".mov", width: 1080, height: 1920, duration: Time(ticks: ticks),
        quarterTurns: 0, hasSound: true)
}

private let oddA = media("odd-a", ticks: 1219)
private let oddB = media("odd-b", ticks: 2417)

/// What addClips is given: the five test clips, two lengths that are not whole frames, one shorter than
/// the shortest clip, and red once more with other facts.
private let pool: [MediaInfo] = TestClip.all.map { $0.info } + [oddA, oddB, media("short", ticks: 59), media("red", ticks: 1200)]

/// What an action is to the state it is sent to. The runs from the three clip seed must hold every one.
private enum Kind: String, CaseIterable {
    case add = "addClips"
    case addTooShort = "addClips with a media shorter than minimumClip"
    case splitAllowed = "split while canSplit is true"
    case splitRefused = "split while canSplit is false"
    case trimStartInside = "trimStart inside its limits"
    case trimStartPastShortest = "trimStart by more than leaves minimumClip"
    case trimStartPastSource = "trimStart to before the start of the source"
    case trimStartUnknown = "trimStart of a clip id that is not in the project"
    case trimEndInside = "trimEnd inside its limits"
    case trimEndPastShortest = "trimEnd by more than leaves minimumClip"
    case trimEndPastSource = "trimEnd to after the end of the source"
    case trimEndUnknown = "trimEnd of a clip id that is not in the project"
    case deleteAllowed = "deleteSelected while canDelete is true"
    case deleteRefused = "deleteSelected while canDelete is false"
    case selectKnown = "select of a clip of the project"
    case selectUnknown = "select of a clip id that is not in the project"
    case clearSelection = "clearSelection"
    case moveInside = "movePlayhead inside the project"
    case moveBelowZero = "movePlayhead to below zero"
    case movePastEnd = "movePlayhead to past the project length"
    case play = "play"
    case pause = "pause"
    case becameEmpty = "an action that left the project empty"
}

private func kind(of action: EditorAction, in state: EditorState) -> Kind {
    let project = state.project
    switch action {
    case .addClips(let given):
        let tooShort = given.contains(where: { $0.duration.roundedDownToFrame < TimelineGeometry.minimumClip })
        return tooShort ? .addTooShort : .add
    case .split:
        return state.canSplit ? .splitAllowed : .splitRefused
    case .trimStart(let id, let amount):
        guard let clip = project.clips.first(where: { $0.id == id }) else {
            return .trimStartUnknown
        }
        if amount > clip.duration - TimelineGeometry.minimumClip {
            return .trimStartPastShortest
        }
        return amount < Time.zero - clip.sourceStart ? .trimStartPastSource : .trimStartInside
    case .trimEnd(let id, let amount):
        guard let clip = project.clips.first(where: { $0.id == id }), let info = project.media[clip.media] else {
            return .trimEndUnknown
        }
        if amount > clip.duration - TimelineGeometry.minimumClip {
            return .trimEndPastShortest
        }
        return amount < clip.sourceStart + clip.duration - info.duration ? .trimEndPastSource : .trimEndInside
    case .deleteSelected:
        return state.canDelete ? .deleteAllowed : .deleteRefused
    case .select(let id):
        return project.clips.contains(where: { $0.id == id }) ? .selectKnown : .selectUnknown
    case .clearSelection:
        return .clearSelection
    case .movePlayhead(let time):
        if time < Time.zero {
            return .moveBelowZero
        }
        return time > project.duration ? .movePastEnd : .moveInside
    case .play:
        return .play
    case .pause:
        return .pause
    }
}

/// One time in four an id that no clip has, else the id of a clip of the project.
private func drawClip(_ draw: inout Draw, in state: EditorState) -> ClipID {
    let clips = state.project.clips
    if clips.isEmpty || draw.below(4) == 0 {
        return ClipID(state.project.nextClipID + draw.below(3))
    }
    return clips[draw.below(clips.count)].id
}

/// Ten thousand ticks either way are past every limit of a trim, since no media of the runs is that long.
private func drawAmount(_ draw: inout Draw) -> Time {
    switch draw.below(4) {
    case 0:
        return Time(ticks: 10_000 + Int64(draw.below(40)))
    case 1:
        return Time(ticks: -10_000 - Int64(draw.below(40)))
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

private func drawAction(_ draw: inout Draw, in state: EditorState) -> EditorAction {
    switch draw.below(19) {
    case 0:
        var given: [MediaInfo] = []
        let count = draw.below(3)
        for _ in 0..<count {
            given.append(pool[draw.below(pool.count)])
        }
        return .addClips(given)
    case 1...2:
        return .split
    case 3...4:
        let clip = drawClip(&draw, in: state)
        let amount = drawAmount(&draw)
        return .trimStart(clip, by: amount)
    case 5...6:
        let clip = drawClip(&draw, in: state)
        let amount = drawAmount(&draw)
        return .trimEnd(clip, by: amount)
    case 7...9:
        return .deleteSelected
    case 10...12:
        return .select(drawClip(&draw, in: state))
    case 13:
        return .clearSelection
    case 14...16:
        return .movePlayhead(drawPlayhead(&draw, in: state))
    case 17:
        return .play
    default:
        return .pause
    }
}

/// The valid state that `reduce` must keep: "A state is valid when every clip lies inside its source, every
/// clip length is a whole number of frames and at least `minimumClip`, the playhead is a whole frame from zero
/// to the project length, and the selection is a clip of the project or none."
/// docs/architecture.md says the same in short under m1-3-edit-actions.
/// Answers the first part of that sentence the state breaks, or nil for a valid state.
private func breach(in state: EditorState) -> String? {
    for clip in state.project.clips {
        guard let info = state.project.media[clip.media] else {
            return "clip \(clip.id.raw) has no media facts, so no source to lie inside"
        }
        if clip.sourceStart < Time.zero || clip.sourceStart + clip.duration > info.duration {
            return "clip \(clip.id.raw) lies outside its source: it starts at \(clip.sourceStart.ticks) and is "
                + "\(clip.duration.ticks) ticks long in a source of \(info.duration.ticks)"
        }
        if clip.duration.ticks % Time.frame.ticks != 0 {
            return "the length of clip \(clip.id.raw) is \(clip.duration.ticks) ticks, not a whole number of frames"
        }
        if clip.duration < TimelineGeometry.minimumClip {
            return "the length of clip \(clip.id.raw) is \(clip.duration.ticks) ticks, less than minimumClip"
        }
    }
    if state.playhead.ticks % Time.frame.ticks != 0 {
        return "the playhead is at \(state.playhead.ticks) ticks, not a whole frame"
    }
    if state.playhead < Time.zero || state.playhead > state.project.duration {
        return "the playhead is at \(state.playhead.ticks) ticks in a project of \(state.project.duration.ticks)"
    }
    if let selection = state.selection, !state.project.clips.contains(where: { $0.id == selection }) {
        return "the selection is clip \(selection.raw), which is not in the project"
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
        guard let info = project.media[segment.media] else {
            return "the segment of clip \(segment.clip.raw) has a media without facts"
        }
        if segment.sourceStart < Time.zero || segment.sourceStart + segment.duration > info.duration {
            return "the segment of clip \(segment.clip.raw) lies outside its media: it starts at "
                + "\(segment.sourceStart.ticks) and is \(segment.duration.ticks) ticks long in a media of "
                + "\(info.duration.ticks)"
        }
        before = before + segment.duration
    }
    if before != plan.duration {
        return "the segments of the plan are \(before.ticks) ticks long together and the plan says \(plan.duration.ticks)"
    }
    return nil
}

/// A split or a delete that could be done must change the state, and one that could not must leave it equal.
private func gateBreach(before: EditorState, action: EditorAction, after: EditorState) -> String? {
    let allowed: Bool
    let name: String
    switch action {
    case .split:
        allowed = before.canSplit
        name = "canSplit"
    case .deleteSelected:
        allowed = before.canDelete
        name = "canDelete"
    default:
        return nil
    }
    if allowed && after == before {
        return "\(name) was true and the action changed nothing"
    }
    if !allowed && after != before {
        return "\(name) was false and the action changed the state"
    }
    return nil
}

/// Plays 1000 runs of 50 actions from the start state, with the start numbers 1 to 1000, and checks the state
/// after every action. Answers how often each kind of action was sent, or nil after a failure.
private func playRuns(from start: EditorState) -> [Kind: Int]? {
    if let fault = breach(in: start) {
        XCTFail("the start state is not valid: \(fault)")
        return nil
    }
    var counts: [Kind: Int] = [:]
    for startNumber in 1...1000 {
        var draw = Draw(startNumber: startNumber)
        var state = start
        var sent: [EditorAction] = []
        for _ in 1...50 {
            let action = drawAction(&draw, in: state)
            sent.append(action)
            counts[kind(of: action, in: state), default: 0] += 1
            let next = reduce(state, action)
            let fault = breach(in: next) ?? planBreach(for: next.project)
                ?? gateBreach(before: state, action: action, after: next)
            if let fault {
                XCTFail(
                    "start number \(startNumber), action \(sent.count) of 50: \(fault). "
                        + "The actions of this run, the last one being the one that failed: \(sent)")
                return nil
            }
            if next.project.clips.isEmpty && !state.project.clips.isEmpty {
                counts[.becameEmpty, default: 0] += 1
            }
            state = next
        }
    }
    return counts
}

final class TrackGuardTests: XCTestCase {
    private let red = ClipID(2)
    private let threeClips = EditorState(project: Seed.threeClips.project)

    func testAThousandRunsOfFiftyActionsFromThreeClipsKeepTheStateValidAndThePlanAsLongAsTheProject() {
        guard let counts = playRuns(from: threeClips) else {
            return
        }
        for kind in Kind.allCases {
            XCTAssertGreaterThan(counts[kind, default: 0], 0, "the runs never sent: \(kind.rawValue)")
        }
    }

    func testTheSameRunsFromMediaWhoseLengthsAreNotWholeFramesKeepTheStateValid() {
        var project = Project()
        project.media = [oddA.id: oddA, oddB.id: oddB]
        project.clips = [
            Clip(id: ClipID(1), media: oddA.id, sourceStart: .zero, duration: Time(ticks: 1200)),
            Clip(id: ClipID(2), media: oddB.id, sourceStart: .zero, duration: Time(ticks: 2400)),
        ]
        project.nextClipID = 3

        XCTAssertNotNil(playRuns(from: EditorState(project: project)))
    }

    func testATrimOfAnEarlierClipLeavesThePlayheadAtItsTimelineTime() {
        var state = threeClips
        state.playhead = Time(ticks: 4200)

        let endTrimmed = reduce(state, .trimEnd(red, by: Time(ticks: 600)))
        let startTrimmed = reduce(state, .trimStart(red, by: Time(ticks: 600)))

        XCTAssertEqual(endTrimmed.project.duration, Time(ticks: 4800))
        XCTAssertEqual(endTrimmed.playhead, Time(ticks: 4200))
        XCTAssertEqual(startTrimmed.project.duration, Time(ticks: 4800))
        XCTAssertEqual(startTrimmed.playhead, Time(ticks: 4200))
    }

    func testATrimEndThatChangesNothingStillPausesAPlayingState() {
        var playing = threeClips
        playing.isPlaying = true

        XCTAssertEqual(reduce(playing, .trimEnd(red, by: Time(ticks: 19))), threeClips)
    }
}
