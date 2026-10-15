import ReelsmithCore
import UIKit

/// The music row of the strip, under the text row: one bar from time zero to the end of the heard music, with
/// the title of the music. It is shown while no text is selected, so the picture keeps its room above the
/// keyboard of the text panel. It decides nothing: the place and the width come from the scale of the strip,
/// the length from `Project.heardMusic`.
///
/// https://developer.apple.com/documentation/swift/mainactor
@MainActor
enum MusicBar {
    /// The row of music: 24 points high from y 100.
    static let row: (y: CGFloat, height: CGFloat) = (y: 100, height: 24)

    /// The height the slot `timeline` gives the strip: 128 without a selected text, 104 with one.
    static func stripHeight(for state: EditorState) -> CGFloat {
        state.selectedText == nil ? 128 : 104
    }

    /// Called on every layout of the strip view, in the slot `music-row`. The bar is made once, below the
    /// playhead line, and hidden with no heard music or a selected text.
    static func layout(in view: TimelineStripView, below playhead: UIView) {
        let bar: MusicBarView
        if let made = view.subviews.compactMap({ $0 as? MusicBarView }).first {
            bar = made
        } else {
            bar = MusicBarView(frame: .zero)
            view.insertSubview(bar, belowSubview: playhead)
        }

        let state: EditorState = view.state
        guard state.selectedText == nil, let music = state.project.music, let heard = state.project.heardMusic else {
            bar.isHidden = true
            return
        }
        bar.isHidden = false
        bar.frame = CGRect(
            x: view.strip.frame.minX + CGFloat(view.scale.x(of: Time.zero)),
            y: row.y,
            width: CGFloat(view.scale.width(of: heard)),
            height: row.height
        )
        bar.writing.frame = CGRect(x: 6, y: 0, width: max(bar.frame.width - 12, 0), height: row.height)
        bar.writing.text = music.file.title
        bar.accessibilityLabel = text(Words("musicRow.bar", [music.file.title]))
    }
}

/// The bar of the music row. It shows the title of the music, which is content and no word of the app, set
/// verbatim in the label `writing` against its left. A tap sends `.sound(.open)`. Never mirrored: its frame is
/// set by hand from the left.
///
/// https://developer.apple.com/documentation/uikit/uilabel
/// https://developer.apple.com/documentation/uikit/uilabel/linebreakmode
/// https://developer.apple.com/documentation/uikit/uiview/ishidden
/// https://developer.apple.com/documentation/uikit/uiview/insertsubview(_:belowsubview:)
/// https://developer.apple.com/documentation/uikit/uitapgesturerecognizer
/// https://developer.apple.com/documentation/uikit/uigesturerecognizerdelegate/gesturerecognizer(_:shouldberequiredtofailby:)
/// https://developer.apple.com/documentation/objectivec/nsobject/accessibilitylabel
/// https://developer.apple.com/documentation/objectivec/nsobject/accessibilitytraits
/// https://developer.apple.com/documentation/uikit/uiaccessibilityidentification/accessibilityidentifier
final class MusicBarView: UIView, UIGestureRecognizerDelegate {
    /// The title of the music. Its frame inside the bar is set on every layout.
    fileprivate let writing = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        semanticContentAttribute = .forceLeftToRight
        writing.semanticContentAttribute = .forceLeftToRight
        writing.numberOfLines = 1
        writing.lineBreakMode = .byTruncatingTail
        writing.textAlignment = .left
        writing.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        writing.textColor = UIColor.label
        addSubview(writing)
        backgroundColor = UIColor.systemTeal.withAlphaComponent(0.35)
        layer.borderWidth = 1
        layer.borderColor = UIColor.systemBackground.cgColor
        isUserInteractionEnabled = true
        isAccessibilityElement = true
        accessibilityIdentifier = "editor.music"
        accessibilityTraits = .button
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
        tap.delegate = self
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    /// The tap, the scrub and the pinch of the strip view wait for the tap of the bar to fail, so a tap on the bar
    /// clears nothing, and a drag that begins on the bar is still a scrub.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return otherGestureRecognizer.view === superview
    }

    @objc private func tapped(_ tap: UITapGestureRecognizer) {
        guard let view = superview as? TimelineStripView else {
            return
        }
        view.send(.sound(.open))
    }
}
