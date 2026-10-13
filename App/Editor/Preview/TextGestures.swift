import ReelsmithCore
import SwiftUI
import UIKit

/// The gestures on the picture area: four recognizers and nothing that is drawn. A drag moves the
/// selected text, a pinch sizes it, a twist turns it, and a tap selects the text nearest to the finger.
/// They decide nothing. Each step of a gesture sends a whole value, worked out from the text as it was
/// when the gesture began, and Core holds it inside its limits. `pause` goes before the first value.
/// With no text selected a drag, a pinch and a twist send nothing. The preview shows every result.
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

/// One finger: with two on the picture it is a pinch or a twist and no move.
///
/// https://developer.apple.com/documentation/uikit/uipangesturerecognizer
/// https://developer.apple.com/documentation/uikit/uipangesturerecognizer/maximumnumberoftouches
private struct TextDrag: UIGestureRecognizerRepresentable {
    let store: EditorStore
    let picture: PictureWidth

    func makeCoordinator(converter: CoordinateSpaceConverter) -> GestureStart {
        GestureStart()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.maximumNumberOfTouches = 1
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        guard let start = context.coordinator.text(for: recognizer, in: store),
            let moved: CGPoint = context.converter.localTranslation
        else {
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
    }
}

/// https://developer.apple.com/documentation/uikit/uipinchgesturerecognizer
/// https://developer.apple.com/documentation/uikit/uipinchgesturerecognizer/scale
private struct TextPinch: UIGestureRecognizerRepresentable {
    let store: EditorStore

    func makeCoordinator(converter: CoordinateSpaceConverter) -> GestureStart {
        GestureStart()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPinchGestureRecognizer {
        UIPinchGestureRecognizer()
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPinchGestureRecognizer, context: Context) {
        guard let start = context.coordinator.text(for: recognizer, in: store) else {
            return
        }
        var style: TextStyle = start.style
        style.size = start.style.size * Double(recognizer.scale)
        store.send(.text(.setStyle(start.id, style)))
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
