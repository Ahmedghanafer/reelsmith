import ReelsmithCore
import SwiftUI
import UIKit

/// The gestures on the picture area: four recognizers and nothing that is drawn. A drag moves the
/// selected text, a pinch sizes it, a twist turns it, and a tap selects the text nearest to the finger.
/// They decide nothing. Each step of a gesture sends a whole value, worked out from the text as it was
/// when the gesture began, and Core holds it inside its limits. `pause` goes before the first value.
/// With no text selected a drag and a pinch act on the clip framed by hand (`framedByHand`): the drag moves
/// its picture and the pinch zooms it, as the steps of one drag run, so a gesture is one step of undo.
/// A twist acts on a text only. With neither a text nor such a clip the gestures send nothing. The preview
/// shows every result.
///
/// The recognizers may sit on another view than the picture, so the width of the picture is read
/// from its geometry and a place or a distance comes from the converter, in the space of the picture.
///
/// https://developer.apple.com/documentation/swiftui/viewmodifier
/// https://developer.apple.com/documentation/swiftui/view/ongeometrychange(for:of:action:)
/// https://developer.apple.com/documentation/swiftui/view/gesture(_:)
/// https://developer.apple.com/documentation/swiftui/uigesturerecognizerrepresentable
/// https://developer.apple.com/documentation/swiftui/uigesturerecognizerrepresentablecontext
/// https://developer.apple.com/documentation/swiftui/uigesturerecognizerrepresentablecoordinatespaceconverter
/// https://developer.apple.com/documentation/uikit/uigesturerecognizer/state-swift.property
struct TextGestures: ViewModifier {
    let store: EditorStore
    @State private var picture = PictureWidth()

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { width in
                picture.points = Double(width)
            }
            .gesture(TextTap(store: store, picture: picture))
            .gesture(TextDrag(store: store, picture: picture))
            .gesture(TextPinch(store: store))
            .gesture(TextTwist(store: store))
    }
}

/// The width of the picture area in points, as its geometry last gave it.
final class PictureWidth {
    var points: Double = 0
}

/// The selected text as it was when a gesture began, kept by the coordinator of that gesture.
@MainActor
final class GestureStart {
    private var text: TextItem?

    /// Called for every report of a recognizer. At the first one it reads the selected text and sends
    /// `pause` when there is one. Nil while the gesture began with no text selected.
    func text(for recognizer: UIGestureRecognizer, in store: EditorStore) -> TextItem? {
        if recognizer.state == .began {
            let state: EditorState = store.state
            text = state.selectedText.flatMap { state.project.text($0) }
            if text != nil {
                store.send(.pause)
            }
        }
        return text
    }
}

/// The clip framed by hand as it was when a gesture began with no text selected, kept beside the text's
/// `GestureStart` by the coordinator of a drag or a pinch.
@MainActor
final class ClipStart {
    let text = GestureStart()
    private var clip: Clip?

    /// Called for every report of a recognizer that began with no text. At the first one it reads
    /// `framedByHand` and that clip and sends `pause` when there is one. Nil while the gesture began with none.
    func clip(for recognizer: UIGestureRecognizer, in store: EditorStore) -> Clip? {
        if recognizer.state == .began {
            let state: EditorState = store.state
            clip = state.framedByHand.flatMap { id in state.project.clips.first(where: { $0.id == id }) }
            if clip != nil {
                store.send(.pause)
            }
        }
        return clip
    }
}

/// True for the last report of a gesture.
@MainActor
private func ends(_ recognizer: UIGestureRecognizer) -> Bool {
    recognizer.state == .ended || recognizer.state == .cancelled || recognizer.state == .failed
}

/// https://developer.apple.com/documentation/uikit/uitapgesturerecognizer
private struct TextTap: UIGestureRecognizerRepresentable {
    let store: EditorStore
    let picture: PictureWidth

    func makeUIGestureRecognizer(context: Context) -> UITapGestureRecognizer {
        UITapGestureRecognizer()
    }

    /// The picture is as wide and as high as the canvas in one scale, so the width gives both lengths.
    /// With the playhead at the end of the project the last frame is asked, which is the one shown.
    func handleUIGestureRecognizerAction(_ recognizer: UITapGestureRecognizer, context: Context) {
        let state: EditorState = store.state
        let canvas: ReelsmithCore.Canvas = state.project.canvas
        let place: CGPoint = context.converter.localLocation
        let time: Time = min(state.playhead, state.project.duration - Time.frame)
        let nearest: TextID? = state.project.text(
            nearestToX: TextGeometry.canvasLength(
                ofPoints: Double(place.x), pictureWidth: picture.points, canvas: canvas),
            y: TextGeometry.canvasLength(ofPoints: Double(place.y), pictureWidth: picture.points, canvas: canvas),
            at: time)
        if let nearest {
            store.send(.text(.select(nearest)))
        }
    }
}

/// One finger: with two on the picture it is a pinch or a twist and no move. With no text it moves the
/// clip framed by hand: the offset at the start plus the distance moved in shares of the picture, which has
/// the shape of the canvas, so its height is its width times the canvas height over its width.
///
/// https://developer.apple.com/documentation/uikit/uipangesturerecognizer
/// https://developer.apple.com/documentation/uikit/uipangesturerecognizer/maximumnumberoftouches
private struct TextDrag: UIGestureRecognizerRepresentable {
    let store: EditorStore
    let picture: PictureWidth

    func makeCoordinator(converter: CoordinateSpaceConverter) -> ClipStart {
        ClipStart()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.maximumNumberOfTouches = 1
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        if let start = context.coordinator.text.text(for: recognizer, in: store) {
            guard let moved: CGPoint = context.converter.localTranslation else {
                return
            }
            let canvas: ReelsmithCore.Canvas = store.state.project.canvas
            store.send(
                .text(
                    .move(
                        start.id,
                        x: start.x
                            + TextGeometry.canvasLength(
                                ofPoints: Double(moved.x), pictureWidth: picture.points, canvas: canvas),
                        y: start.y
                            + TextGeometry.canvasLength(
                                ofPoints: Double(moved.y), pictureWidth: picture.points, canvas: canvas))))
            return
        }
        guard let clip = context.coordinator.clip(for: recognizer, in: store) else {
            return
        }
        // A cancel sends no value. A picture of no width gives values that are not finite, which Core ignores.
        if recognizer.state != .cancelled, recognizer.state != .failed,
            let moved: CGPoint = context.converter.localTranslation
        {
            let canvas: ReelsmithCore.Canvas = store.state.project.canvas
            let width: Double = picture.points
            let height: Double = width * Double(canvas.height) / Double(canvas.width)
            store.sendDragStep(
                .frame(
                    .setOffset(
                        clip.id, x: clip.framing.x + Double(moved.x) / width,
                        y: clip.framing.y + Double(moved.y) / height)))
        }
        if ends(recognizer) {
            store.endDrag()
        }
    }
}

/// With no text it zooms the clip framed by hand: the zoom at the start times the scale of the pinch.
///
/// https://developer.apple.com/documentation/uikit/uipinchgesturerecognizer
/// https://developer.apple.com/documentation/uikit/uipinchgesturerecognizer/scale
private struct TextPinch: UIGestureRecognizerRepresentable {
    let store: EditorStore

    func makeCoordinator(converter: CoordinateSpaceConverter) -> ClipStart {
        ClipStart()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPinchGestureRecognizer {
        UIPinchGestureRecognizer()
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPinchGestureRecognizer, context: Context) {
        if let start = context.coordinator.text.text(for: recognizer, in: store) {
            var style: TextStyle = start.style
            style.size = start.style.size * Double(recognizer.scale)
            store.send(.text(.setStyle(start.id, style)))
            return
        }
        guard let clip = context.coordinator.clip(for: recognizer, in: store) else {
            return
        }
        // A cancel sends no value.
        if recognizer.state != .cancelled, recognizer.state != .failed {
            store.sendDragStep(.frame(.setZoom(clip.id, clip.framing.zoom * Double(recognizer.scale))))
        }
        if ends(recognizer) {
            store.endDrag()
        }
    }
}

/// The recognizer gives radians from the start of the twist, positive clockwise as she sees it.
///
/// https://developer.apple.com/documentation/uikit/uirotationgesturerecognizer
/// https://developer.apple.com/documentation/uikit/uirotationgesturerecognizer/rotation
private struct TextTwist: UIGestureRecognizerRepresentable {
    let store: EditorStore

    func makeCoordinator(converter: CoordinateSpaceConverter) -> GestureStart {
        GestureStart()
    }

    func makeUIGestureRecognizer(context: Context) -> UIRotationGestureRecognizer {
        UIRotationGestureRecognizer()
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIRotationGestureRecognizer, context: Context) {
        guard let start = context.coordinator.text(for: recognizer, in: store) else {
            return
        }
        store.send(.text(.turn(start.id, to: start.rotation + Double(recognizer.rotation) * 180 / Double.pi)))
    }
}
