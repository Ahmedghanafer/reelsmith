import ReelsmithCore
import UIKit

/// The text row of the strip: lays out the bars and the two handles of the selected one.
///
/// https://developer.apple.com/documentation/swift/mainactor
@MainActor
enum TextBars {
    /// Called on every layout of the strip view, after the slot `handles`. The two handles are made once,
    /// below the playhead line. There is one bar for every text with a range, below the handles, and the
    /// handles stand outside the edges of the bar of the selected text and are hidden without one.
    static func layout(in view: TimelineStripView, below playhead: UIView) {
        var handles: [TextTrimHandle] = view.subviews.compactMap { $0 as? TextTrimHandle }
        if handles.isEmpty {
            handles = [TextTrimHandle(isStart: true), TextTrimHandle(isStart: false)]
            for handle in handles {
                view.insertSubview(handle, belowSubview: playhead)
            }
        }

        let state: EditorState = view.state
        var texts: [(item: TextItem, range: TextRange)] = []
        for item in state.project.texts {
            if let range: TextRange = state.project.range(of: item.id) {
                texts.append((item: item, range: range))
            }
        }
        var bars: [TextBar] = view.subviews.compactMap { $0 as? TextBar }
        while bars.count > texts.count {
            bars.removeLast().removeFromSuperview()
        }
        while bars.count < texts.count {
            let bar = TextBar(frame: .zero)
            view.insertSubview(bar, belowSubview: handles[0])
            bars.append(bar)
        }

        let row = TimelineStripView.textRow
        var selectedFrame: CGRect?
        for (entry, bar) in zip(texts, bars) {
            let item: TextItem = entry.item
            let range: TextRange = entry.range
            let position: Int = state.project.position(of: item.id) ?? 0
            let selected = item.id == state.selectedText
            bar.shown = item.id
            bar.frame = CGRect(
                x: view.strip.frame.minX + CGFloat(TimelineGeometry.x(of: range.start)),
                y: row.y,
                width: CGFloat(TimelineGeometry.width(of: range.duration)),
                height: row.height
            )
            let lines = item.string.split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline })
            let line: String = item.isBlank ? "" : String(lines.first ?? "")
            bar.text = line
            bar.accessibilityIdentifier = "editor.text." + String(position)
            bar.accessibilityLabel = text(Words("textRow.bar", [String(position)]))
            bar.accessibilityValue = line
            bar.accessibilityTraits = selected ? [.staticText, .selected] : .staticText
            bar.layer.borderWidth = selected ? 3 : 1
            bar.layer.borderColor = (selected ? UIColor.systemYellow : UIColor.systemBackground).cgColor
            if selected {
                selectedFrame = bar.frame
            }
        }

        for handle in handles {
            guard let frame = selectedFrame else {
                handle.isHidden = true
                continue
            }
            handle.isHidden = false
            handle.frame = CGRect(
                x: handle.isStart ? frame.minX - TextTrimHandle.width : frame.maxX,
                y: row.y,
                width: TextTrimHandle.width,
                height: row.height
            )
        }
    }
}

/// One bar of the text row of the strip: a text that has a range, drawn from its start for its length.
/// It shows the first line of the string, which is content and no word of the app. A tap selects its text.
/// It decides nothing: the place and the width come from `TimelineGeometry`, the range and the position
/// from `Project`. Never mirrored: its frame is set by hand from the left.
///
/// https://developer.apple.com/documentation/uikit/uilabel
/// https://developer.apple.com/documentation/uikit/uilabel/linebreakmode
/// https://developer.apple.com/documentation/uikit/uitapgesturerecognizer
/// https://developer.apple.com/documentation/uikit/uigesturerecognizerdelegate/gesturerecognizer(_:shouldberequiredtofailby:)
/// https://developer.apple.com/documentation/uikit/uiview/insertsubview(_:belowsubview:)
/// https://developer.apple.com/documentation/uikit/uiview/isuserinteractionenabled
/// https://developer.apple.com/documentation/objectivec/nsobject/accessibilitylabel
/// https://developer.apple.com/documentation/objectivec/nsobject/accessibilityvalue
/// https://developer.apple.com/documentation/objectivec/nsobject/accessibilitytraits
/// https://developer.apple.com/documentation/uikit/uiaccessibilityidentification/accessibilityidentifier
final class TextBar: UILabel, UIGestureRecognizerDelegate {
    /// The text this bar stands for, set on every layout.
    fileprivate var shown: TextID?

    override init(frame: CGRect) {
        super.init(frame: frame)
        semanticContentAttribute = .forceLeftToRight
        numberOfLines = 1
        lineBreakMode = .byTruncatingTail
        textAlignment = .center
        font = UIFont.systemFont(ofSize: 12, weight: .medium)
        textColor = UIColor.label
        backgroundColor = UIColor.systemGray4
        isUserInteractionEnabled = true
        isAccessibilityElement = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
        tap.delegate = self
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    /// The tap and the scrub of the strip view wait for the tap of the bar to fail, so a tap on a bar
    /// selects no clip and clears nothing, and a drag that begins on a bar is still a scrub.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return otherGestureRecognizer.view === superview
    }

    @objc private func tapped(_ tap: UITapGestureRecognizer) {
        guard let view = superview as? TimelineStripView, let id = shown else {
            return
        }
        view.send(.text(.select(id)))
    }
}

/// One of the two handles of the selected text bar, drawn outside its edge. It decides nothing: a drag
/// draws `reduce` of the state from its start with the trim for the points moved so far, and one trim
/// action is sent on release. Never mirrored: the start handle is at the left edge in every language.
///
/// https://developer.apple.com/documentation/uikit/uipangesturerecognizer
/// https://developer.apple.com/documentation/uikit/uipangesturerecognizer/translation(in:)
/// https://developer.apple.com/documentation/uikit/uigesturerecognizer/state-swift.property
/// https://developer.apple.com/documentation/uikit/uiview/ishidden
final class TextTrimHandle: UIView, UIGestureRecognizerDelegate {
    /// As wide as a trim handle of a clip.
    static let width: CGFloat = 24

    let isStart: Bool
    /// The state at the start of the drag, nil while no drag runs.
    private var dragStart: EditorState?

    init(isStart: Bool) {
        self.isStart = isStart
        super.init(frame: .zero)
        semanticContentAttribute = .forceLeftToRight
        backgroundColor = UIColor.systemYellow
        isAccessibilityElement = true
        accessibilityIdentifier = isStart ? "editor.textTrim.start" : "editor.textTrim.end"
        accessibilityLabel = text(Words(isStart ? "textRow.trimStart" : "textRow.trimEnd"))
        let pan = UIPanGestureRecognizer(target: self, action: #selector(dragged(_:)))
        pan.maximumNumberOfTouches = 1
        pan.delegate = self
        addGestureRecognizer(pan)
        // A tap on a handle does nothing. Without this recognizer it would clear the selection.
        let tap = UITapGestureRecognizer(target: nil, action: nil)
        tap.delegate = self
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    /// The scrub and the tap of the strip view wait for the two recognizers of the handle to fail,
    /// so a drag on a handle never scrubs and a tap on it never clears.
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
        guard let start = dragStart, let id = start.selectedText else {
            return
        }
        let moved = Double(pan.translation(in: view).x)
        let action: EditorAction =
            isStart
            ? .text(.trimStart(id, by: TimelineGeometry.trimAmount(forDragOf: moved)))
            : .text(.trimEnd(id, by: TimelineGeometry.trimAmount(forDragOf: -moved)))
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
