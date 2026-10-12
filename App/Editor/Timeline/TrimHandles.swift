import ReelsmithCore
import UIKit

/// One of the two trim handles of the selected clip, drawn outside its edge. It decides nothing: a drag
/// draws `reduce` of the state from its start with the trim for the points moved so far, and one trim
/// action is sent on release. Never mirrored: the start handle is at the left edge in every language.
///
/// https://developer.apple.com/documentation/uikit/uipangesturerecognizer
/// https://developer.apple.com/documentation/uikit/uipangesturerecognizer/translation(in:)
/// https://developer.apple.com/documentation/uikit/uitapgesturerecognizer
/// https://developer.apple.com/documentation/uikit/uigesturerecognizerdelegate/gesturerecognizer(_:shouldberequiredtofailby:)
/// https://developer.apple.com/documentation/uikit/uigesturerecognizer/state-swift.property
/// https://developer.apple.com/documentation/uikit/uiview/insertsubview(_:belowsubview:)
/// https://developer.apple.com/documentation/uikit/uiview/ishidden
/// https://developer.apple.com/documentation/uikit/uiview/semanticcontentattribute
/// https://developer.apple.com/documentation/objectivec/nsobject/accessibilitylabel
/// https://developer.apple.com/documentation/uikit/uiaccessibilityidentification/accessibilityidentifier
final class TrimHandle: UIView, UIGestureRecognizerDelegate {
    /// Wide enough to be pressed in its middle.
    private static let width: CGFloat = 24

    private var isStart = true
    /// The state at the start of the drag, nil while no drag runs.
    private var dragStart: EditorState?

    private init(isStart: Bool) {
        super.init(frame: .zero)
        self.isStart = isStart
        semanticContentAttribute = .forceLeftToRight
        backgroundColor = UIColor.systemYellow
        isAccessibilityElement = true
        accessibilityIdentifier = isStart ? "editor.trim.start" : "editor.trim.end"
        accessibilityLabel = text(Words(isStart ? "trim.start" : "trim.end"))
        let pan = UIPanGestureRecognizer(target: self, action: #selector(dragged(_:)))
        pan.maximumNumberOfTouches = 1
        pan.delegate = self
        addGestureRecognizer(pan)
        // A tap on a handle does nothing. Without this recognizer it would select the block under the handle.
        let tap = UITapGestureRecognizer(target: nil, action: nil)
        tap.delegate = self
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    /// Called from the slot `handles` on every layout of the strip view. The two handles are made once,
    /// below the playhead line, and then only moved, shown or hidden.
    static func layout(in view: TimelineStripView, below playhead: UIView) {
        var handles: [TrimHandle] = view.subviews.compactMap { $0 as? TrimHandle }
        if handles.isEmpty {
            handles = [TrimHandle(isStart: true), TrimHandle(isStart: false)]
            for handle in handles {
                view.insertSubview(handle, belowSubview: playhead)
            }
        }

        let state: EditorState = view.state
        guard let selection = state.selection,
            let clip = state.project.clips.first(where: { $0.id == selection }),
            let start = state.project.start(of: selection)
        else {
            for handle in handles {
                handle.isHidden = true
            }
            return
        }
        let left = view.strip.frame.minX + CGFloat(TimelineGeometry.x(of: start))
        let right = left + CGFloat(TimelineGeometry.width(of: clip.duration))
        for handle in handles {
            handle.isHidden = false
            handle.frame = CGRect(
                x: handle.isStart ? left - width : right,
                y: view.strip.frame.minY,
                width: width,
                height: view.strip.frame.height
            )
        }
    }

    /// The scrub and the tap of the strip view wait for the two recognizers of the handle to fail,
    /// so a drag on a handle never scrubs and a tap on it never selects. The recognizers of the handles
    /// do not wait for each other.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return otherGestureRecognizer.view === superview
    }

    /// The drag starts by sending `pause`, so the state of the store stands still under the preview.
    /// A cancelled drag draws the state from its start again and sends nothing.
    @objc private func dragged(_ pan: UIPanGestureRecognizer) {
        guard let view = superview as? TimelineStripView else {
            return
        }
        if pan.state == .began {
            view.send(.pause)
            dragStart = reduce(view.state, .pause)
        }
        guard let start = dragStart, let clip = start.selection else {
            return
        }
        let moved = Double(pan.translation(in: view).x)
        let action: EditorAction =
            isStart
            ? .trimStart(clip, by: TimelineGeometry.trimAmount(forDragOf: moved))
            : .trimEnd(clip, by: TimelineGeometry.trimAmount(forDragOf: -moved))
        if pan.state == .began || pan.state == .changed {
            view.state = reduce(start, action)
        } else if pan.state == .ended {
            // Drawn here too: when the action changes nothing, the store hands no new state to the view.
            view.state = reduce(start, action)
            view.send(action)
            dragStart = nil
        } else {
            view.state = start
            dragStart = nil
        }
    }
}
