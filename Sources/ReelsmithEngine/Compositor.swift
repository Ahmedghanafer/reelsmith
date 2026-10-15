#if canImport(CoreText)
import AVFoundation
import CoreGraphics
import CoreImage
import CoreMedia
import CoreVideo
import Foundation
import ReelsmithCore

/// One text of an instruction: its picture, the three values the picture was drawn from, and where and when
/// it is put.
struct PieceText {
    let string: String
    let style: TextStyle
    let lineWidth: Double
    /// The picture as it was drawn, with no colour space, as a source frame is read.
    let image: CIImage
    /// The picture turned around its centre and put at its place, counted from the bottom left of the canvas.
    let placed: CIImage
    /// The text is drawn in a frame at time t when start <= t < end.
    let start: CMTime
    let end: CMTime
}

/// The texts of one instruction: every layer of the plan whose time overlaps the range, in the order of the
/// plan. The one place that asks for a text picture. A picture is taken from `kept` when one there was drawn
/// from the same string, style and wrap width, so a text that only moved or turned draws nothing. `drawn` counts
/// the calls of `textPicture(for:)`. A layer with no picture, as a blank one, is left out.
///
/// The place of a layer is counted from the top left of the canvas and Core Image counts from the bottom left,
/// where a turn clockwise as she sees it is a negative angle. A picture that is not turned is put on whole
/// pixels, so its letters stay sharp.
///
/// https://developer.apple.com/documentation/coreimage/ciimage/init(cgimage:options:)
/// https://developer.apple.com/documentation/coreimage/ciimageoption/colorspace
/// https://developer.apple.com/documentation/coregraphics/cgaffinetransform/init(rotationangle:)
func pieceTexts(
    of plan: RenderPlan, in range: CMTimeRange, kept: [PieceText]
) -> (texts: [PieceText], drawn: Int) {
    var texts: [PieceText] = []
    var drawn = 0
    for layer in plan.texts {
        let start = CMTime(value: layer.timelineStart.ticks, timescale: 600)
        let end = CMTime(value: (layer.timelineStart + layer.duration).ticks, timescale: 600)
        guard start < range.end, range.start < end else { continue }

        let image: CIImage
        let same = (kept + texts).first {
            $0.string == layer.string && $0.style == layer.style && $0.lineWidth == layer.lineWidth
        }
        if let same {
            image = same.image
        } else {
            drawn += 1
            guard let picture = textPicture(for: layer) else { continue }
            image = CIImage(cgImage: picture.image, options: [.colorSpace: NSNull()])
        }

        let width = Double(image.extent.width)
        let height = Double(image.extent.height)
        let canvasHeight = Double(plan.height)
        let placing: CGAffineTransform
        if layer.rotation == 0 {
            let left = (layer.x - width / 2).rounded()
            let top = (layer.y - height / 2).rounded()
            placing = CGAffineTransform(translationX: CGFloat(left), y: CGFloat(canvasHeight - top - height))
        } else {
            placing = CGAffineTransform(translationX: CGFloat(-width / 2), y: CGFloat(-height / 2))
                .concatenating(CGAffineTransform(rotationAngle: CGFloat(-layer.rotation * Double.pi / 180)))
                .concatenating(CGAffineTransform(translationX: CGFloat(layer.x), y: CGFloat(canvasHeight - layer.y)))
        }
        texts.append(PieceText(
            string: layer.string, style: layer.style, lineWidth: layer.lineWidth, image: image,
            placed: image.transformed(by: placing), start: start, end: end))
    }
    return (texts, drawn)
}

/// One for each segment of the plan: the track that holds its picture, where that picture goes, and the texts
/// of the plan whose time overlaps its range, each with its picture.
/// It answers true for `containsTweening`, so every frame of its range is asked for by its own time.
///
/// https://developer.apple.com/documentation/avfoundation/avvideocompositioninstructionprotocol
/// https://developer.apple.com/documentation/avfoundation/avvideocompositioninstructionprotocol/containstweening
/// https://developer.apple.com/documentation/avfoundation/avvideocompositioninstructionprotocol/requiredsourcetrackids
final class PieceInstruction: NSObject, AVVideoCompositionInstructionProtocol {
    let timeRange: CMTimeRange
    let enablePostProcessing: Bool = false
    let containsTweening: Bool = true
    let requiredSourceTrackIDs: [NSValue]?
    let passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid

    let track: CMPersistentTrackID
    /// From the source frame to the canvas, both counted from the bottom left as Core Image counts.
    let placing: CGAffineTransform
    /// From the source frame to the place of its blurred copy under the picture, counted as `placing` is. Nil when
    /// the segment has no backdrop.
    let backdrop: CGAffineTransform?
    /// In drawing order, the later one on top.
    let texts: [PieceText]
    /// How many times a text picture was asked for when this instruction was built.
    let drawn: Int

    init(
        timeRange: CMTimeRange, track: CMPersistentTrackID, placing: CGAffineTransform,
        backdrop: CGAffineTransform?, texts: [PieceText], drawn: Int
    ) {
        self.timeRange = timeRange
        self.track = track
        self.placing = placing
        self.backdrop = backdrop
        self.texts = texts
        self.drawn = drawn
        requiredSourceTrackIDs = [NSNumber(value: track)]
        super.init()
    }
}

/// Draws every frame of the picture, for the player item and for the export alike: black, then the blurred
/// backdrop when the segment has one, then the frame of the segment at its place, then each text of the
/// instruction whose time holds the frame, the later one on top. A time at which the track has no frame stays
/// black under the texts. It changes no colour: Core Image takes the numbers of a source frame and of a text
/// picture as they are and writes them as they are, with no colour space on the way in, in the middle or on the
/// way out.
///
/// https://developer.apple.com/documentation/avfoundation/avvideocompositing
/// https://developer.apple.com/documentation/coreimage/cicontext/init(options:)
/// https://developer.apple.com/documentation/coreimage/cicontextoption/workingcolorspace
/// https://developer.apple.com/documentation/coreimage/cicontextoption/outputcolorspace
final class Compositor: NSObject, AVVideoCompositing {
    /// The source frames, as 32 bit BGRA with the IOSurface key. They reach this class and never a layer.
    /// https://developer.apple.com/documentation/avfoundation/avvideocompositing/sourcepixelbufferattributes
    let sourcePixelBufferAttributes: [String: any Sendable]? = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferIOSurfacePropertiesKey as String: [String: String](),
    ]

    /// The buffers of the frames it hands out, the same kind. The player layer of a simulator takes them.
    /// https://developer.apple.com/documentation/avfoundation/avvideocompositing/requiredpixelbufferattributesforrendercontext
    let requiredPixelBufferAttributesForRenderContext: [String: any Sendable] = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferIOSurfacePropertiesKey as String: [String: String](),
    ]

    private let context = CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])

    /// Nothing is kept from a render context: each request brings its own.
    /// https://developer.apple.com/documentation/avfoundation/avvideocompositing/rendercontextchanged(_:)
    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
    }

    /// Answers every request before it returns: with a frame, or with `cannotRead` when the instruction is not
    /// ours or the render context gives no buffer. With no source frame the frame is the black canvas.
    /// A text is put on as its instruction holds it: nothing is laid out, measured or drawn for text here.
    ///
    /// https://developer.apple.com/documentation/avfoundation/avasynchronousvideocompositionrequest/compositiontime
    /// https://developer.apple.com/documentation/avfoundation/avvideocompositing/startrequest(_:)
    /// https://developer.apple.com/documentation/avfoundation/avasynchronousvideocompositionrequest
    /// https://developer.apple.com/documentation/avfoundation/avasynchronousvideocompositionrequest/sourceframe(bytrackid:)
    /// https://developer.apple.com/documentation/avfoundation/avvideocompositionrendercontext/newpixelbuffer()
    /// https://developer.apple.com/documentation/avfoundation/avasynchronousvideocompositionrequest/finish(withcomposedvideoframe:)
    /// https://developer.apple.com/documentation/avfoundation/avasynchronousvideocompositionrequest/finish(with:)
    /// https://developer.apple.com/documentation/coreimage/ciimage/init(cvpixelbuffer:options:)
    /// https://developer.apple.com/documentation/coreimage/ciimage/transformed(by:)
    /// https://developer.apple.com/documentation/coreimage/ciimage/composited(over:)
    /// https://developer.apple.com/documentation/coreimage/cicontext/render(_:to:bounds:colorspace:)
    /// https://developer.apple.com/documentation/coreimage/ciimage/clampedtoextent()
    /// https://developer.apple.com/documentation/coreimage/ciimage/applyingfilter(_:parameters:)
    /// https://developer.apple.com/documentation/coreimage/cigaussianblur
    /// https://developer.apple.com/documentation/coreimage/ciimage/cropped(to:)
    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        guard let piece = request.videoCompositionInstruction as? PieceInstruction,
              let frame = request.renderContext.newPixelBuffer()
        else {
            request.finish(with: EngineError.cannotRead)
            return
        }
        let canvas = CGRect(origin: .zero, size: request.renderContext.size)
        var picture = CIImage.black
        if let buffer = request.sourceFrame(byTrackID: piece.track) {
            let source = CIImage(cvPixelBuffer: buffer, options: [.colorSpace: NSNull()])
            if let backdrop = piece.backdrop {
                // Blurred at an eighth of the size, which is cheap, and clamped so its edges do not fade to clear.
                let eighth = CGAffineTransform(scaleX: 0.125, y: 0.125)
                let blurred = source.clampedToExtent()
                    .transformed(by: eighth)
                    .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 8])
                    .transformed(by: eighth.inverted())
                    .cropped(to: source.extent)
                    .transformed(by: backdrop)
                    .cropped(to: canvas)
                picture = blurred.composited(over: picture)
            }
            picture = source.transformed(by: piece.placing).composited(over: picture)
        }
        let time = request.compositionTime
        for text in piece.texts where text.start <= time && time < text.end {
            picture = text.placed.composited(over: picture)
        }
        context.render(picture.cropped(to: canvas), to: frame, bounds: canvas, colorSpace: nil)
        request.finish(withComposedVideoFrame: frame)
    }
}
#endif
