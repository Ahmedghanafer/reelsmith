import ReelsmithCore
import UIKit

/// The press and drag that moves a clip on the strip. It decides nothing: the place a block is let go at is
/// `Project.dropPosition(of:at:)` of the time of the block's left end moved by the finger since the press
/// began, so a press held still keeps its place, and the move is `reduce`. It begins only on a
/// block, after half a second. While the finger moves the strip view draws `reduce` of the state from the
/// start with the move so far, and one `moveClip` is sent on release. A press on a trim handle, a text bar or
/// the empty strip moves nothing. It is the delegate of the scrub of the strip view too, which does not
/// begin while a press runs.
///
/// https://developer.apple.com/documentation/uikit/uilongpressgesturerecognizer
/// https://developer.apple.com/documentation/uikit/uilongpressgesturerecognizer/minimumpressduration
/// https://developer.apple.com/documentation/uikit/uigesturerecognizer/init(target:action:)
/// https://developer.apple.com/documentation/uikit/uigesturerecognizer/addtarget(_:action:)
/// https://developer.apple.com/documentation/uikit/uigesturerecognizer/location(in:)
/// https://developer.apple.com/documentation/uikit/uigesturerecognizer/state-swift.property
/// https://developer.apple.com/documentation/uikit/uigesturerecognizer/delegate
/// https://developer.apple.com/documentation/uikit/uigesturerecognizerdelegate/gesturerecognizershouldbegin(_:)
/// https://developer.apple.com/documentation/uikit/uigesturerecognizerdelegate/gesturerecognizer(_:shouldreceive:)-1sztq
/// https://developer.apple.com/documentation/uikit/uitouch/view
final class ClipPress: UILongPressGestureRecognizer, UIGestureRecognizerDelegate {
    /// The state at the start of the press, nil while no press runs.
    private var pressStart: EditorState?
    /// The clip the press began on, nil while no press runs.
    private var pressedClip: ClipID?
    /// The x in `strip` of the left end of the pressed block, and of the finger, when the press began.
    private var blockStartX: Double = 0
    private var fingerStartX: Double = 0
    /// The one finger scrub of the strip view.
    private weak var scrub: UIPanGestureRecognizer?
    /// The pressed clip and the x in `strip` of the left end its block is drawn at: its left end at the press
    /// moved by the finger. Set at each step of a press, nil at the end and at a cancel. The slot `reorder`
    /// of the strip view draws that block lifted there.
    private(set) var lifted: (clip: ClipID, left: Double)?

    /// Called from the slot `recognizers` of the strip view, with its scrub.
    static func add(to view: TimelineStripView, beside scrub: UIPanGestureRecognizer) {
        let press = ClipPress(target: nil, action: nil)
        press.addTarget(press, action: #selector(pressed))
        press.minimumPressDuration = 0.5
        press.scrub = scrub
        press.delegate = press
        scrub.delegate = press
        view.addGestureRecognizer(press)
    }

    /// The press takes only a touch on the strip view or on the row of blocks, so a touch on a trim handle,
    /// a text bar or a handle of a bar never starts it. A block lets its touches through to the row.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer === self, let view = view as? TimelineStripView else {
            return true
        }
        return touch.view === view || touch.view === view.strip
    }

    /// The scrub does not begin while a press runs. The press begins only on a block.
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === scrub {
            return state != .began && state != .changed
        }
        guard gestureRecognizer === self, let view = view as? TimelineStripView else {
            return true
        }
        return clip(under: view) != nil
    }

    /// The clip of the block under the finger, nil beside the row of blocks.
    private func clip(under view: TimelineStripView) -> ClipID? {
        let point = location(in: view.strip)
        guard view.strip.bounds.contains(point) else {
            return nil
        }
        return view.state.project.clip(at: view.scale.time(atX: Double(point.x)))?.id
    }

    /// The press starts by sending `pause`, so the state of the store stands still under the preview.
    /// A cancelled press draws the state from its start again and sends nothing.
    @objc private func pressed() {
        guard let view = view as? TimelineStripView else {
            return
        }
        if state == .began {
            pressedClip = clip(under: view)
            view.send(.pause)
            pressStart = reduce(view.state, .pause)
            if let clip = pressedClip, let left = view.state.project.start(of: clip) {
                blockStartX = view.scale.x(of: left)
            }
            fingerStartX = Double(location(in: view.strip).x)
        }
        guard let start = pressStart, let clip = pressedClip else {
            return
        }
        let moved = Double(location(in: view.strip).x) - fingerStartX
        lifted = state == .began || state == .changed ? (clip: clip, left: blockStartX + moved) : nil
        let time: Time = view.scale.time(atX: blockStartX + moved)
        guard let position = start.project.dropPosition(of: clip, at: time) else {
            return
        }
        let action: EditorAction = .moveClip(clip, to: position)
        if state == .began || state == .changed {
            view.state = reduce(start, action)
        } else if state == .ended {
            // Drawn here too: when the move changes nothing, the store hands no new state to the view.
            view.state = reduce(start, action)
            view.send(action)
            pressStart = nil
            pressedClip = nil
        } else {
            view.state = start
            pressStart = nil
            pressedClip = nil
        }
    }
}
