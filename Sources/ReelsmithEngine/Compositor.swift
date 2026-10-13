#if canImport(CoreText)
import AVFoundation
import CoreGraphics
import CoreImage
import CoreMedia
import CoreVideo
import Foundation

/// One for each segment of the plan: the track that holds its picture and where that picture goes.
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

    init(timeRange: CMTimeRange, track: CMPersistentTrackID, placing: CGAffineTransform) {
        self.timeRange = timeRange
        self.track = track
        self.placing = placing
        requiredSourceTrackIDs = [NSNumber(value: track)]
        super.init()
    }
}

/// Draws every frame of the picture, for the player item and for the export alike: black, then the frame of
/// the segment at its place. A time at which the track has no frame stays black. It changes no colour: Core
/// Image takes the numbers of a source frame as they are and writes them as they are, with no colour space
/// on the way in, in the middle or on the way out.
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
    ///
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
            picture = source.transformed(by: piece.placing).composited(over: picture)
        }
        context.render(picture.cropped(to: canvas), to: frame, bounds: canvas, colorSpace: nil)
        request.finish(withComposedVideoFrame: frame)
    }
}
#endif
