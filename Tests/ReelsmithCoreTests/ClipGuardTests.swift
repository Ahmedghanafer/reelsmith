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

/// The outcomes of the three clip edits. The runs must hold every one.
private enum Kind: String, CaseIterable {
    case moveDone = "moveClip that changes the order"
    case moveNothing = "moveClip to the place the clip has or of an unknown id"
    case cutBeforeDone = "cutBefore while canCutBefore is true"
    case cutBeforeRefused = "cutBefore while canCutBefore is false"
    case cutAfterDone = "cutAfter while canCutAfter is true"
    case cutAfterRefused = "cutAfter while canCutAfter is false"
}

private func kind(of action: EditorAction, before: EditorState, after: EditorState) -> Kind? {
    switch action {
    case .moveClip:
        return after.project.clips == before.project.clips ? .moveNothing : .moveDone
    case .cutBefore:
        return before.canCutBefore ? .cutBeforeDone : .cutBeforeRefused
    case .cutAfter:
        return before.canCutAfter ? .cutAfterDone : .cutAfterRefused
    default:
        return nil
    }
}

/// One time in four an id that no clip has, else the id of a clip of the project, as the merged guards draw.
private func drawClip(_ draw: inout Draw, in state: EditorState) -> ClipID {
    let clips = state.project.clips
    if clips.isEmpty || draw.below(4) == 0 {
        return ClipID(state.project.nextClipID + draw.below(3))
    }
    return clips[draw.below(clips.count)].id
}

/// A place from minus 1 to two past the count, so below the first and past the last too.
private func drawPosition(_ draw: inout Draw, in state: EditorState) -> Int {
    draw.below(state.project.clips.count + 4) - 1
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
    switch draw.below(20) {
    case 0...2:
        let clip = drawClip(&draw, in: state)
        return .moveClip(clip, to: drawPosition(&draw, in: state))
    case 3...4:
        return .cutBefore
    case 5...6:
        return .cutAfter
    case 7...9:
        return .select(drawClip(&draw, in: state))
    case 10:
        return .clearSelection
    case 11...13:
        return .movePlayhead(drawPlayhead(&draw, in: state))
    case 14:
        return .split
    case 15:
        return .deleteSelected
    case 16...17:
        let clip = drawClip(&draw, in: state)
        return .trimStart(clip, by: drawAmount(&draw))
    default:
        let clip = drawClip(&draw, in: state)
        return .trimEnd(clip, by: drawAmount(&draw))
    }
}

/// What the state breaks, or nil: the clips touch, each is at least minimumClip long and inside its media, the
/// ids are unique, every media a clip uses has its facts, and the playhead is a whole frame inside the project.
private func breach(in state: EditorState) -> String? {
    let project = state.project
    var ids: Set<ClipID> = []
    for clip in project.clips {
        if !ids.insert(clip.id).inserted {
            return "the clip id \(clip.id.raw) is used twice"
        }
        guard let info = project.media[clip.media] else {
            return "clip \(clip.id.raw) uses the media \(clip.media.raw), which has no facts"
        }
        if clip.duration < TimelineGeometry.minimumClip {
            return "clip \(clip.id.raw) is \(clip.duration.ticks) ticks long, less than minimumClip"
        }
        if clip.sourceStart < Time.zero || clip.sourceStart + clip.duration > info.duration {
            return "clip \(clip.id.raw) starts at \(clip.sourceStart.ticks) and is \(clip.duration.ticks) ticks long "
                + "in a media of \(info.duration.ticks)"
        }
    }
    let plan: RenderPlan
    do {
        plan = try renderPlan(for: project)
    } catch {
        return "renderPlan threw \(error)"
    }
    var before = Time.zero
    for segment in plan.segments {
        if segment.timelineStart != before {
            return "the segment of clip \(segment.clip.raw) starts at \(segment.timelineStart.ticks), and the clips "
                + "before it are \(before.ticks) ticks long, so the clips do not touch"
        }
        before = before + segment.duration
    }
    if before != project.duration {
        return "the segments are \(before.ticks) ticks long together and the project \(project.duration.ticks)"
    }
    if state.playhead.ticks % Time.frame.ticks != 0 || state.playhead < Time.zero
        || state.playhead > project.duration
    {
        return "the playhead is at \(state.playhead.ticks) ticks in a project of \(project.duration.ticks)"
    }
    return nil
}

/// A move keeps the same clips, in another order or the same.
private func moveBreach(before: EditorState, action: EditorAction, after: EditorState) -> String? {
    guard case .moveClip = action else {
        return nil
    }
    let kept = before.project.clips.sorted { $0.id.raw < $1.id.raw }
    let moved = after.project.clips.sorted { $0.id.raw < $1.id.raw }
    return kept == moved ? nil : "the move did not keep the same clips"
}

/// Plays 1000 runs of 50 actions from the seed, with the start numbers 1 to 1000, and checks the state after
/// every action. A run starts as a start of the app on the seed does. Answers false after a failure.
private func playRuns(from seed: Seed, counts: inout [Kind: Int]) -> Bool {
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
        for _ in 1...50 {
            let action = drawAction(&draw, in: state)
            sent.append(action)
            let next = reduce(state, action)
            if let kind = kind(of: action, before: state, after: next) {
                counts[kind, default: 0] += 1
            }
            if let fault = breach(in: next) ?? moveBreach(before: state, action: action, after: next) {
                XCTFail(
                    "seed \(seed.rawValue), start number \(startNumber), action \(sent.count) of 50: \(fault). "
                        + "The actions of this run, the last one being the one that failed: \(sent)")
                return false
            }
            state = next
        }
    }
    return true
}

final class ClipGuardTests: XCTestCase {
    func testTwoThousandRunsOfFiftyActionsWithTheClipEditsKeepTheClipsValid() {
        var counts: [Kind: Int] = [:]
        for seed in [Seed.threeClips, Seed.textWide] {
            guard playRuns(from: seed, counts: &counts) else {
                return
            }
        }
        for kind in Kind.allCases {
            XCTAssertGreaterThan(counts[kind, default: 0], 0, "the runs never sent: \(kind.rawValue)")
        }
    }
}
