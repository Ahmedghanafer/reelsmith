import ReelsmithCore
import SwiftUI
import UIKit

/// The timeline strip for SwiftUI: hands the state and the way to send an action to the UIKit view below.
///
/// https://developer.apple.com/documentation/swiftui/uiviewrepresentable
struct TimelineStrip: UIViewRepresentable {
    let state: EditorState
    /// Where the files of the media are, for the frames on the blocks.
    let mediaFolder: URL
    /// The blocks are thin and show no frames.
    let folded: Bool
    let send: @MainActor (EditorAction) -> Void

    func makeUIView(context: Context) -> TimelineStripView {
        let view = TimelineStripView()
        view.frames.changed = { [weak view] in view?.setNeedsLayout() }
        return view
    }

    func updateUIView(_ view: TimelineStripView, context: Context) {
        view.send = send
        view.mediaFolder = mediaFolder
        view.folded = folded
        view.state = state
    }
}

/// The clips as blocks in one row at the scale of the strip, each showing frames of its clip unless the
/// blocks are folded, under a playhead line that stays in the middle. A drag scrubs, a tap on a block
/// selects it, a pinch sets the scale. Never mirrored: every frame is set by hand from the left, and the
/// view forces left to right.
///
/// https://developer.apple.com/documentation/uikit/uiview/layoutsubviews()
/// https://developer.apple.com/documentation/uikit/uiview/semanticcontentattribute
/// https://developer.apple.com/documentation/uikit/uipangesturerecognizer
/// https://developer.apple.com/documentation/uikit/uitapgesturerecognizer
/// https://developer.apple.com/documentation/uikit/uipinchgesturerecognizer
/// https://developer.apple.com/documentation/uikit/uipinchgesturerecognizer/scale
/// https://developer.apple.com/documentation/uikit/uilabel
/// https://developer.apple.com/documentation/objectivec/nsobject/accessibilityvalue
/// https://developer.apple.com/documentation/objectivec/nsobject/accessibilitytraits
/// https://developer.apple.com/documentation/uikit/uiaccessibilityidentification/accessibilityidentifier
final class TimelineStripView: UIView {
    var send: @MainActor (EditorAction) -> Void = { _ in }

    /// The state that is drawn. Setting it draws it.
    var state = EditorState(project: Project()) {
        didSet { setNeedsLayout() }
    }

    /// The points a second of every x and width on the strip, its handles and its bars. Each editor makes
    /// a strip view of its own, so it starts at the standard. Only a pinch changes it.
    var scale: TimelineScale = .standard

    /// Holds the blocks and moves under the playhead. Its left edge is time zero.
    let strip = UIView()
    private var blocks: [UILabel] = []
    private let playhead = UIView()
    private var scrubStart: Double = 0
    private var pinchStart: TimelineScale = .standard

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
        addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(pinched(_:))))
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
        // slot: recognizers
        ClipPress.add(to: self, beside: pan)
        // end slot: recognizers
    }

    required init?(coder: NSCoder) {
        return nil
    }

    /// Where the files of the media are. Set by `TimelineStrip`, and no frame is made before.
    var mediaFolder: URL?
    /// The frames of each media, made once while this view lives.
    let frames = FramesCache()
    /// The tiles of each block, beside its label in its container, in the order of `blocks`.
    private var tiles: [FrameTiles] = []
    /// The container of each block, in the order of `blocks`. Held here, since a view does not hold its superview.
    private var containers: [UIView] = []
    /// The blocks are thin and show no frames. Set by `TimelineStrip` before `state`, whose setting draws it.
    var folded = false
    /// Every row of the strip, read by the blocks, the trim handles, the text row and the music row.
    var rows: StripRows {
        StripRows.of(folded: folded, textSelected: state.selectedText != nil)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let clips: [Clip] = state.project.clips
        // Each block is a container in `strip` that holds its tiles and, on top, its label. The container lets its
        // touches through to `strip`. A new container goes into `strip` only once it and its label have their frames
        // and identifiers, below, so it never joins the strip empty and of no size.
        while blocks.count > clips.count {
            blocks.removeLast()
            tiles.removeLast()
            containers.removeLast().removeFromSuperview()
        }
        while blocks.count < clips.count {
            let container = UIView()
            container.semanticContentAttribute = .forceLeftToRight
            container.isUserInteractionEnabled = false
            container.clipsToBounds = true
            container.backgroundColor = UIColor.systemGray
            let tile = FrameTiles()
            container.addSubview(tile)
            let block = UILabel()
            block.semanticContentAttribute = .forceLeftToRight
            block.textAlignment = .center
            block.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
            // White with a dark shadow, readable on any frame.
            block.textColor = UIColor.white
            block.shadowColor = UIColor.black
            block.shadowOffset = CGSize(width: 0, height: 1)
            container.addSubview(block)
            blocks.append(block)
            tiles.append(tile)
            containers.append(container)
        }

        let middle = bounds.width / 2
        let rows: StripRows = self.rows
        strip.frame = CGRect(
            x: middle - CGFloat(scale.x(of: state.playhead)),
            y: CGFloat(rows.clipY),
            width: CGFloat(scale.width(of: state.project.duration)),
            height: CGFloat(rows.clipHeight)
        )
        let side = CGFloat(rows.clipHeight)
        for (place, clip) in clips.enumerated() {
            let block = blocks[place]
            let tile = tiles[place]
            let container = containers[place]
            let start: Time = state.project.start(of: clip.id) ?? Time.zero
            let position: Int = state.project.position(of: clip.id) ?? 0
            let selected = clip.id == state.selection
            let width = CGFloat(scale.width(of: clip.duration))
            container.frame = CGRect(x: CGFloat(scale.x(of: start)), y: 0, width: width, height: side)
            block.frame = CGRect(x: 0, y: 0, width: width, height: side)
            tile.frame = block.frame
            // A folded block shows no frames and asks for none, and its tiles are no element.
            tile.isHidden = folded
            if !folded {
                var images: [CGImage?] = []
                if let media: MediaInfo = state.project.media[clip.media], let folder: URL = mediaFolder {
                    let made = frames.frames(of: media, in: folder)
                    for index in 0..<BlockFrames.tileCount(width: Double(width), tile: Double(side)) {
                        let time = BlockFrames.frameTime(
                            of: clip, media: media, tile: index, tile: Double(side), scale: scale)
                        images.append(made?[time])
                    }
                }
                tile.show(images, side: side, made: frames.madeCount)
            }
            tile.accessibilityIdentifier = "editor.frames." + String(position)
            // One line of words on a folded block, two on a block with frames.
            block.numberOfLines = folded ? 1 : 2
            block.text = String(position) + (folded ? " " : "\n") + clip.duration.clockText
            block.accessibilityIdentifier = "editor.clip." + String(position)
            block.accessibilityValue = state.project.clipInfo(clip.id)
            block.accessibilityTraits = selected ? [.staticText, .selected] : .staticText
            block.layer.borderWidth = selected ? 3 : 1
            block.layer.borderColor = (selected ? UIColor.systemYellow : UIColor.systemBackground).cgColor
            if container.superview == nil {
                strip.addSubview(container)
            }
        }
        playhead.frame = CGRect(x: middle - 1, y: 0, width: 2, height: bounds.height)
        playhead.accessibilityValue = state.playhead.clockText

        // Views above the clips are added and laid out here. A view that stays inside `strip` is added
        // to `strip`. A view that can lie outside it, as a handle at the edge of the first or the last clip,
        // is added to this view below `playhead`, at `strip.frame.minX` plus its x and `strip.frame.minY`
        // plus its y: a view gets no touch outside the bounds of the view that holds it. The tap and the
        // scrub of this view see the touches on such a view too, unless it has a recognizer of its own
        // for them. A `state` set as a preview is written over when the state of the store changes,
        // so a drag that previews first sends `pause` and then sets `state` on each step.
        // slot: handles
        TrimHandle.layout(in: self, below: playhead)
        // end slot: handles
        // slot: reorder
        // The block of a running press is drawn with its left end where the press puts it, above the others,
        // larger and with a shadow, its tiles with it, and the others as above. Every container is set here
        // with no transform first, since a frame set on a view with a transform is not its frame.
        // https://developer.apple.com/documentation/uikit/uiview/transform
        // https://developer.apple.com/documentation/quartzcore/calayer/zposition
        // https://developer.apple.com/documentation/quartzcore/calayer/shadowopacity
        let lifted: (clip: ClipID, left: Double)? = gestureRecognizers?.compactMap { ($0 as? ClipPress)?.lifted }.first
        for (place, clip) in clips.enumerated() {
            let container = containers[place]
            let start: Time = state.project.start(of: clip.id) ?? Time.zero
            let left: Double = lifted?.clip == clip.id ? lifted?.left ?? 0 : scale.x(of: start)
            container.transform = .identity
            container.frame = CGRect(x: CGFloat(left), y: 0, width: CGFloat(scale.width(of: clip.duration)), height: side)
            if lifted?.clip == clip.id {
                container.layer.zPosition = 1
                container.clipsToBounds = false
                container.layer.shadowOpacity = 0.5
                container.layer.shadowRadius = 6
                container.layer.shadowOffset = CGSize(width: 0, height: 3)
                container.transform = CGAffineTransform(scaleX: 1.08, y: 1.08)
            } else {
                container.layer.zPosition = 0
                container.clipsToBounds = true
                container.layer.shadowOpacity = 0
            }
        }
        // end slot: reorder
        // slot: music-row
        MusicBar.layout(in: self, below: playhead)
        // end slot: music-row
        TextBars.layout(in: self, below: playhead)
    }

    /// A scrub sends `pause`, then `movePlayhead`. The strip follows the finger, so a drag to the left
    /// moves to a later time. Core keeps the time inside the project.
    @objc private func scrubbed(_ pan: UIPanGestureRecognizer) {
        if pan.state == .began {
            scrubStart = scale.x(of: state.playhead)
            send(.pause)
        }
        if pan.state == .began || pan.state == .changed || pan.state == .ended {
            let x = scrubStart - Double(pan.translation(in: self).x)
            send(.movePlayhead(scale.time(atX: x)))
        }
    }

    /// A pinch sets the scale to the scale at its start times its factor, held by Core. It sends nothing:
    /// the playhead stays in the middle on its time, and the strip is laid out again around it.
    @objc private func pinched(_ pinch: UIPinchGestureRecognizer) {
        if pinch.state == .began {
            pinchStart = scale
        }
        if pinch.state == .began || pinch.state == .changed || pinch.state == .ended {
            scale = pinchStart.zoomed(by: Double(pinch.scale))
            setNeedsLayout()
        }
    }

    /// A tap on a block selects it. A tap anywhere else on this view, beside the row of blocks, in the
    /// band above or below it or in the empty part of the text row, sends `clearSelection`. A tap on
    /// a trim handle, on a text bar or on a handle of a text bar never comes here.
    @objc private func tapped(_ tap: UITapGestureRecognizer) {
        let point = tap.location(in: strip)
        if strip.bounds.contains(point),
            let clip: Clip = state.project.clip(at: scale.time(atX: Double(point.x)))
        {
            send(.select(clip.id))
        } else {
            send(.clearSelection)
        }
    }
}
