import ReelsmithCore
import SwiftUI
import UIKit

/// The timeline strip for SwiftUI: hands the state and the way to send an action to the UIKit view below.
///
/// https://developer.apple.com/documentation/swiftui/uiviewrepresentable
struct TimelineStrip: UIViewRepresentable {
    let state: EditorState
    let send: @MainActor (EditorAction) -> Void

    func makeUIView(context: Context) -> TimelineStripView {
        TimelineStripView()
    }

    func updateUIView(_ view: TimelineStripView, context: Context) {
        view.send = send
        view.state = state
    }
}

/// The clips as plain blocks in one row at the fixed scale of `TimelineGeometry`, under a playhead line
/// that stays in the middle. A drag scrubs, a tap on a block selects it. Never mirrored: every frame is
/// set by hand from the left, and the view forces left to right.
///
/// https://developer.apple.com/documentation/uikit/uiview/layoutsubviews()
/// https://developer.apple.com/documentation/uikit/uiview/semanticcontentattribute
/// https://developer.apple.com/documentation/uikit/uipangesturerecognizer
/// https://developer.apple.com/documentation/uikit/uitapgesturerecognizer
/// https://developer.apple.com/documentation/uikit/uilabel
/// https://developer.apple.com/documentation/objectivec/nsobject/accessibilitytraits
/// https://developer.apple.com/documentation/uikit/uiaccessibilityidentification/accessibilityidentifier
final class TimelineStripView: UIView {
    var send: @MainActor (EditorAction) -> Void = { _ in }

    /// The state that is drawn. Setting it draws it.
    var state = EditorState(project: Project()) {
        didSet { setNeedsLayout() }
    }

    /// Holds the blocks and moves under the playhead. Its left edge is time zero.
    let strip = UIView()
    private var blocks: [UILabel] = []
    private let playhead = UIView()
    private var scrubStart: Double = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        semanticContentAttribute = .forceLeftToRight
        strip.semanticContentAttribute = .forceLeftToRight
        addSubview(strip)
        playhead.backgroundColor = UIColor.label
        playhead.isUserInteractionEnabled = false
        playhead.isAccessibilityElement = true
        playhead.accessibilityIdentifier = "editor.playhead"
        addSubview(playhead)
        // One finger only, so a pinch is no scrub.
        let pan = UIPanGestureRecognizer(target: self, action: #selector(scrubbed(_:)))
        pan.maximumNumberOfTouches = 1
        addGestureRecognizer(pan)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let clips: [Clip] = state.project.clips
        while blocks.count > clips.count {
            blocks.removeLast().removeFromSuperview()
        }
        while blocks.count < clips.count {
            let block = UILabel()
            block.semanticContentAttribute = .forceLeftToRight
            block.numberOfLines = 2
            block.textAlignment = .center
            block.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
            block.textColor = UIColor.label
            block.backgroundColor = UIColor.systemGray5
            strip.addSubview(block)
            blocks.append(block)
        }

        let middle = bounds.width / 2
        strip.frame = CGRect(
            x: middle - CGFloat(TimelineGeometry.x(of: state.playhead)),
            y: 8,
            width: CGFloat(TimelineGeometry.width(of: state.project.duration)),
            height: max(bounds.height - 16, 0)
        )
        for (clip, block) in zip(clips, blocks) {
            let start: Time = state.project.start(of: clip.id) ?? Time.zero
            let position: Int = state.project.position(of: clip.id) ?? 0
            let selected = clip.id == state.selection
            block.frame = CGRect(
                x: CGFloat(TimelineGeometry.x(of: start)),
                y: 0,
                width: CGFloat(TimelineGeometry.width(of: clip.duration)),
                height: strip.bounds.height
            )
            block.text = String(position) + "\n" + clip.duration.clockText
            block.accessibilityIdentifier = "editor.clip." + String(position)
            block.accessibilityTraits = selected ? [.staticText, .selected] : .staticText
            block.layer.borderWidth = selected ? 3 : 1
            block.layer.borderColor = (selected ? UIColor.systemYellow : UIColor.systemBackground).cgColor
        }
        playhead.frame = CGRect(x: middle - 1, y: 0, width: 2, height: bounds.height)
        playhead.accessibilityValue = state.playhead.clockText

        // Views above the clips are added and laid out here. A view that stays inside `strip` is added
        // to `strip`. A view that can lie outside it, as a handle at the edge of the first or the last clip,
        // is added to this view below `playhead`, at `strip.frame.minX` plus its x: a view gets no touch
        // outside the bounds of the view that holds it. A tap on such a view also reaches the tap of this
        // view unless it has a tap of its own. A `state` set here as a preview is written over when the
        // state of the store changes, so a drag that previews starts by sending `pause`.
        // slot: handles
        // end slot: handles
    }

    /// A scrub sends `pause`, then `movePlayhead`. The strip follows the finger, so a drag to the left
    /// moves to a later time. Core keeps the time inside the project.
    @objc private func scrubbed(_ pan: UIPanGestureRecognizer) {
        if pan.state == .began {
            scrubStart = TimelineGeometry.x(of: state.playhead)
            send(.pause)
        }
        if pan.state == .began || pan.state == .changed || pan.state == .ended {
            let x = scrubStart - Double(pan.translation(in: self).x)
            send(.movePlayhead(TimelineGeometry.time(atX: x)))
        }
    }

    @objc private func tapped(_ tap: UITapGestureRecognizer) {
        let point = tap.location(in: strip)
        guard strip.bounds.contains(point) else {
            return
        }
        if let clip: Clip = state.project.clip(at: TimelineGeometry.time(atX: Double(point.x))) {
            send(.select(clip.id))
        }
    }
}
