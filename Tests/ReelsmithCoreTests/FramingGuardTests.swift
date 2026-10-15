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

/// The outcomes of the frame actions. The runs must hold every one.
private enum Kind: String, CaseIterable {
    case fit = "setFit that changes the state"
    case backdrop = "setBackdrop that changes the state"
    case zoom = "setZoom that changes the state"
    case offset = "setOffset that changes the state"
    case all = "applyToAll that changes the state"
    case held = "a frame action whose value was held"
    case unknown = "a frame action of a clip id that is not in the project"
    case notFinite = "a frame action with a value that is not finite"
}

private func kinds(of action: EditorAction, before: EditorState, after: EditorState) -> [Kind] {
    guard case .frame(let frameAction) = action else {
        return []
    }
    let clips = before.project.clips
    let changed = after != before
    var kinds: [Kind] = []
    switch frameAction {
    case .setFit(let id, _), .setBackdrop(let id, _), .applyToAll(let id):
        if !clips.contains(where: { $0.id == id }) {
            kinds.append(.unknown)
        }
    case .setZoom(let id, let zoom):
        if !zoom.isFinite {
            kinds.append(.notFinite)
        } else if !clips.contains(where: { $0.id == id }) {
            kinds.append(.unknown)
        } else if let clip = after.project.clips.first(where: { $0.id == id }), clip.framing.zoom != zoom {
            kinds.append(.held)
        }
    case .setOffset(let id, let x, let y):
        if !x.isFinite || !y.isFinite {
            kinds.append(.notFinite)
        } else if !clips.contains(where: { $0.id == id }) {
            kinds.append(.unknown)
        } else if let clip = after.project.clips.first(where: { $0.id == id }),
            clip.framing.x != x || clip.framing.y != y
        {
            kinds.append(.held)
        }
    }
    if changed {
        switch frameAction {
        case .setFit:
            kinds.append(.fit)
        case .setBackdrop:
            kinds.append(.backdrop)
        case .setZoom:
            kinds.append(.zoom)
        case .setOffset:
            kinds.append(.offset)
        case .applyToAll:
            kinds.append(.all)
        }
    }
    return kinds
}

/// One time in four an id that no clip has, else the id of a clip of the project, as the merged guards draw.
private func drawClip(_ draw: inout Draw, in state: EditorState) -> ClipID {
    let clips = state.project.clips
    if clips.isEmpty || draw.below(4) == 0 {
        return ClipID(state.project.nextClipID + draw.below(3))
    }
    return clips[draw.below(clips.count)].id
}

/// Not finite, below 1, above 4, or from 1 to 4 in hundredths.
private func drawZoom(_ draw: inout Draw) -> Double {
    switch draw.below(10) {
    case 0:
        return .nan
    case 1:
        return .infinity
    case 2:
        return Double(draw.below(100)) / 100
    case 3:
        return 4 + Double(1 + draw.below(500)) / 100
    default:
        return 1 + Double(draw.below(301)) / 100
    }
}

/// Not finite, far past every edge, or from minus 1 to 1 in hundredths.
private func drawShare(_ draw: inout Draw) -> Double {
    switch draw.below(12) {
    case 0:
        return .nan
    case 1:
        return -.infinity
    case 2:
        return (draw.below(2) == 0 ? -1 : 1) * (1 + Double(draw.below(300)) / 100)
    default:
        return Double(draw.below(201) - 100) / 100
    }
}

/// Ten thousand ticks either way are past every limit of a trim, as the merged guards draw.
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

private let added: [MediaInfo] = [
    TestClip.blue.info, TestClip.red.info, TestClip.green.info, TestClip.turned.info, TestPhoto.magenta.info,
]

/// 26 actions in 40 are frame actions, the rest split, move, the cuts, the trims, addClips, select and the playhead.
private func drawAction(_ draw: inout Draw, in state: EditorState) -> EditorAction {
    switch draw.below(40) {
    case 0...4:
        return .frame(.setFit(drawClip(&draw, in: state), draw.below(2) == 0 ? .fit : .fill))
    case 5...8:
        return .frame(.setBackdrop(drawClip(&draw, in: state), draw.below(2) == 0 ? .black : .blurred))
    case 9...14:
        let clip = drawClip(&draw, in: state)
        return .frame(.setZoom(clip, drawZoom(&draw)))
    case 15...22:
        let clip = drawClip(&draw, in: state)
        let x = drawShare(&draw)
        return .frame(.setOffset(clip, x: x, y: drawShare(&draw)))
    case 23...25:
        return .frame(.applyToAll(drawClip(&draw, in: state)))
    case 26:
        return .split
    case 27:
        let clip = drawClip(&draw, in: state)
        return .moveClip(clip, to: draw.below(state.project.clips.count + 4) - 1)
    case 28:
        return .cutBefore
    case 29:
        return .cutAfter
    case 30:
        let clip = drawClip(&draw, in: state)
        return .trimStart(clip, by: drawAmount(&draw))
    case 31:
        let clip = drawClip(&draw, in: state)
        return .trimEnd(clip, by: drawAmount(&draw))
    case 32:
        return .addClips([added[draw.below(added.count)]])
    case 33...36:
        return .select(drawClip(&draw, in: state))
    default:
        return .movePlayhead(Time(ticks: Int64(draw.below(Int(state.project.duration.ticks) + 1))))
    }
}

private func upright(_ info: MediaInfo) -> (width: Double, height: Double) {
    let turned = info.quarterTurns % 2 != 0
    return (Double(turned ? info.height : info.width), Double(turned ? info.width : info.height))
}

/// The size of rule 84, worked out here by scale factors: the fit size or the fill size, times the zoom.
private func size(of framing: Framing, upright: (width: Double, height: Double), canvas: (Double, Double))
    -> (width: Double, height: Double)
{
    let across = canvas.0 / upright.width
    let down = canvas.1 / upright.height
    let scale = (framing.fit == .fit ? min(across, down) : max(across, down)) * framing.zoom
    return (upright.width * scale, upright.height * scale)
}

/// The fit of today, as the plan placed every clip before framing.
private func placedAsToday(_ info: MediaInfo, canvas: (Double, Double)) -> Placement {
    let (uprightWidth, uprightHeight) = upright(info)
    var width = canvas.0
    var height = canvas.1
    if uprightWidth * canvas.1 > uprightHeight * canvas.0 {
        height = uprightHeight * canvas.0 / uprightWidth
    } else {
        width = uprightWidth * canvas.1 / uprightHeight
    }
    return Placement(
        quarterTurns: info.quarterTurns, x: (canvas.0 - width) / 2, y: (canvas.1 - height) / 2, width: width,
        height: height)
}

/// What breaks rule 84 on one axis, or nil: the size, the near edge between its limits, the centre at the offset.
private func axisBreach(
    _ name: String, near: Double, length: Double, wanted: Double, share: Double, canvas: Double
) -> String? {
    if abs(length - wanted) > 0.01 {
        return "the \(name) length is \(length), rule 84 gives \(wanted)"
    }
    if near < min(0, canvas - length) - 0.01 || near > max(0, canvas - length) + 0.01 {
        return "the \(name) near edge is \(near) for a length of \(length) on a canvas of \(canvas)"
    }
    if abs(near + length / 2 - (canvas / 2 + share * canvas)) > 0.01 {
        return "the \(name) centre is \(near + length / 2), the offset \(share) gives \(canvas / 2 + share * canvas)"
    }
    return nil
}

/// What the state breaks, or nil: every zoom from 1 to 4, every framing equal to itself held, every segment's
/// rectangle and backdrop by rule 84, and a clip of the standard framing placed as today.
private func breach(in state: EditorState) -> String? {
    let project = state.project
    let canvas = (Double(project.canvas.width), Double(project.canvas.height))
    let plan: RenderPlan
    do {
        plan = try renderPlan(for: project)
    } catch {
        return "renderPlan threw \(error)"
    }
    if plan.segments.count != project.clips.count {
        return "the plan has \(plan.segments.count) segments for \(project.clips.count) clips"
    }
    for (clip, segment) in zip(project.clips, plan.segments) {
        guard let info = project.media[clip.media] else {
            return "clip \(clip.id.raw) has no media facts"
        }
        let framing = clip.framing
        let name = "clip \(clip.id.raw) at \(framing)"
        if framing.zoom < 1 || framing.zoom > 4 {
            return "\(name): the zoom is outside 1 to 4"
        }
        let side = upright(info)
        if framing.held(uprightWidth: side.width, uprightHeight: side.height, canvas: project.canvas) != framing {
            return "\(name): the stored framing is not equal to itself held"
        }
        let p = segment.placement
        let wanted = size(of: framing, upright: side, canvas: canvas)
        let across = axisBreach(
            "x", near: p.x, length: p.width, wanted: wanted.width, share: framing.x, canvas: canvas.0)
        let down = axisBreach(
            "y", near: p.y, length: p.height, wanted: wanted.height, share: framing.y, canvas: canvas.1)
        if let fault = across ?? down {
            return "\(name): \(fault)"
        }
        let covers = p.width >= canvas.0 - 0.01 && p.height >= canvas.1 - 0.01
        if framing.backdrop == .blurred && !covers {
            guard let backdrop = segment.backdrop else {
                return "\(name): a blurred backdrop with bars has no backdrop rectangle"
            }
            let fill = size(of: Framing(fit: .fill), upright: side, canvas: canvas)
            let x = (canvas.0 - fill.width) / 2
            let y = (canvas.1 - fill.height) / 2
            if abs(backdrop.x - x) > 0.01 || abs(backdrop.y - y) > 0.01 || abs(backdrop.width - fill.width) > 0.01
                || abs(backdrop.height - fill.height) > 0.01
            {
                return "\(name): the backdrop is \(backdrop), the fill at zoom 1 is (\(x), \(y), \(fill))"
            }
        } else if segment.backdrop != nil {
            return "\(name): a backdrop rectangle where none is wanted"
        }
        if framing == .standard && p != placedAsToday(info, canvas: canvas) {
            return "\(name): placed at \(p), today it is \(placedAsToday(info, canvas: canvas))"
        }
    }
    return nil
}

final class FramingGuardTests: XCTestCase {
    func testAThousandRunsOfFiftyActionsKeepEveryFramingHeldAndEveryRectangleByRule84() {
        let start = EditorState(project: Seed.twoClips.project)
        if let fault = breach(in: start) {
            XCTFail("the start state of two-clips is not valid: \(fault)")
            return
        }
        var counts: [Kind: Int] = [:]
        runs: for startNumber in 1...1000 {
            var draw = Draw(startNumber: startNumber)
            var state = start
            var sent: [EditorAction] = []
            for _ in 1...50 {
                let action = drawAction(&draw, in: state)
                sent.append(action)
                let next = reduce(state, action)
                for kind in kinds(of: action, before: state, after: next) {
                    counts[kind, default: 0] += 1
                }
                if let fault = breach(in: next) {
                    XCTFail(
                        "start number \(startNumber), action \(sent.count) of 50: \(fault). "
                            + "The actions of this run, the last one being the one that failed: \(sent)")
                    break runs
                }
                state = next
            }
        }
        for kind in Kind.allCases {
            XCTAssertGreaterThan(counts[kind, default: 0], 0, "the runs never sent: \(kind.rawValue)")
        }
    }
}
