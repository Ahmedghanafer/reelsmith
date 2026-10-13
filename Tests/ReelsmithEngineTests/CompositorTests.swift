#if canImport(AVFoundation)
import AVFoundation
import CoreGraphics
import CoreMedia
import CoreVideo
import Foundation
import ReelsmithCore
import ReelsmithEngine
import XCTest

/// The Engine's own compositor, through the player item and through the export. The clips and the exported
/// files go into the folder of `ExportTests`.
final class CompositorTests: XCTestCase {
    /// https://developer.apple.com/documentation/avfoundation/avvideocomposition/customvideocompositorclass
    /// https://developer.apple.com/documentation/avfoundation/avvideocompositioninstructionprotocol/containstweening
    @MainActor
    func testTheVideoCompositionOfTheWideItemNamesTheCompositorWithOneInstructionForEachSegment() async throws {
        let videoComposition = try await composition(of: .twoClipsWide)

        let named = try XCTUnwrap(videoComposition.customVideoCompositorClass)
        XCTAssertEqual(String(describing: named), "Compositor")

        let instructions = videoComposition.instructions
        XCTAssertEqual(instructions.count, 2)
        XCTAssertEqual(instructions.map { String(describing: type(of: $0)) }, ["PieceInstruction", "PieceInstruction"])
        XCTAssertEqual(instructions.map { $0.containsTweening }, [true, true])
        XCTAssertEqual(instructions.map { $0.timeRange.start }, [ticks(0), ticks(1800)])
        XCTAssertEqual(instructions.map { $0.timeRange.duration }, [ticks(1800), ticks(2400)])
    }

    @MainActor
    func testTheVideoCompositionKeepsTheCanvasSizeTheFrameLengthAndThe709ColourProperties() async throws {
        let wide = try await composition(of: .twoClipsWide)
        let upright = try await composition(of: .threeClips)
        XCTAssertEqual(wide.renderSize, CGSize(width: 1920, height: 1080))
        XCTAssertEqual(upright.renderSize, CGSize(width: 1080, height: 1920))
        for videoComposition in [wide, upright] {
            XCTAssertEqual(videoComposition.frameDuration, CMTime(value: 1, timescale: 30))
            XCTAssertEqual(videoComposition.colorPrimaries, AVVideoColorPrimaries_ITU_R_709_2)
            XCTAssertEqual(videoComposition.colorTransferFunction, AVVideoTransferFunction_ITU_R_709_2)
            XCTAssertEqual(videoComposition.colorYCbCrMatrix, AVVideoYCbCrMatrix_ITU_R_709_2)
        }
    }

    /// https://developer.apple.com/documentation/avfoundation/avvideocompositing/sourcepixelbufferattributes
    /// https://developer.apple.com/documentation/avfoundation/avvideocompositing/requiredpixelbufferattributesforrendercontext
    /// https://developer.apple.com/documentation/avfoundation/avvideocompositing/supportshdrsourceframes
    @MainActor
    func testTheCompositorAsksForItsFramesAndItsBuffersAs32BitBGRAWithTheIOSurfaceKey() async throws {
        let videoComposition = try await composition(of: .twoClipsWide)
        let named = try XCTUnwrap(videoComposition.customVideoCompositorClass)
        let object = try XCTUnwrap((named as? NSObject.Type)?.init())
        let compositor = try XCTUnwrap(object as? AVVideoCompositing)

        let requests = [
            try XCTUnwrap(compositor.sourcePixelBufferAttributes), compositor.requiredPixelBufferAttributesForRenderContext,
        ]
        for request in requests {
            XCTAssertEqual(request.count, 2)
            XCTAssertEqual(
                request[kCVPixelBufferPixelFormatTypeKey as String] as? OSType, kCVPixelFormatType_32BGRA)
            XCTAssertNotNil(request[kCVPixelBufferIOSurfacePropertiesKey as String])
        }
        XCTAssertFalse(object.responds(to: NSSelectorFromString("supportsHDRSourceFrames")))
        XCTAssertFalse(object.responds(to: NSSelectorFromString("supportsWideColorSourceFrames")))
    }

    /// The join of two-clips-wide is at 1800 ticks. Blue fills the canvas, red stands in the middle with bars.
    func testTheFrameBeforeAJoinIsTheFirstClipAndTheFrameAtTheJoinIsTheSecond() async throws {
        let file = try await CanvasEngineTests.twoClipsWide.value.file
        let blue = RGB(r: 0, g: 0, b: 255)
        let red = RGB(r: 255, g: 0, b: 0)
        let black = RGB(r: 0, g: 0, b: 0)
        let checks: [(Int64, Int, Int, RGB)] = [
            (1780, 960, 540, blue), (1780, 100, 540, blue),
            (1800, 960, 540, red), (1800, 100, 540, black), (1800, 1820, 540, black),
        ]
        for (ticks, x, y, wanted) in checks {
            let colour = try await pixel(of: file, at: Time(ticks: ticks), x: x, y: y)
            XCTAssertLessThanOrEqual(worst(colour, wanted), 24, "(\(x), \(y)) at \(ticks) ticks reads \(colour)")
        }
    }

    func testAMiddleToneInTheExportedFileIsWithin6OfTheSourceFile() async throws {
        let clip = midToneClip()
        let file = try await ExportTests.exported(midTonePlan(), clips: [clip], name: "mid-tone.out").file
        let source = ExportTests.folder.appendingPathComponent(clip.info.fileName)

        for (side, x) in [("left", 480), ("right", 1440)] {
            let wanted = try await pixel(of: source, at: Time(ticks: 600), x: x, y: 540)
            let colour = try await pixel(of: file, at: Time(ticks: 600), x: x, y: 540)
            print("compositor: mid tone, exported file against source file, \(side) half: "
                + "source \(wanted.r), \(wanted.g), \(wanted.b), export \(colour.r), \(colour.g), \(colour.b), "
                + "difference \(differences(colour, wanted))")
            XCTAssertLessThanOrEqual(worst(colour, wanted), 6, "\(side) half reads \(colour), source \(wanted)")
        }
    }

    /// The frame the compositor hands out, with no encoding between.
    /// https://developer.apple.com/documentation/avfoundation/avassetimagegenerator/videocomposition
    @MainActor
    func testAMiddleToneInTheFrameOfThePlayerItemIsWithin2OfTheSourceFile() async throws {
        let clip = midToneClip()
        let source = try await writeTestClip(clip, to: ExportTests.folder)
        let item = try await makePlayerItem(
            plan: midTonePlan(), media: [clip.info.id: clip.info], mediaFolder: ExportTests.folder)

        let generator = AVAssetImageGenerator(asset: item.asset)
        generator.videoComposition = item.videoComposition
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let image = try await generator.image(at: ticks(600)).image
        XCTAssertEqual(image.width, 1920)
        XCTAssertEqual(image.height, 1080)

        for (side, x) in [("left", 480), ("right", 1440)] {
            let wanted = try await pixel(of: source, at: Time(ticks: 600), x: x, y: 540)
            let colour = try self.colour(in: image, x: x, y: 540)
            print("compositor: mid tone, frame of the player item against source file, \(side) half: "
                + "source \(wanted.r), \(wanted.g), \(wanted.b), frame \(colour.r), \(colour.g), \(colour.b), "
                + "difference \(differences(colour, wanted))")
            XCTAssertLessThanOrEqual(worst(colour, wanted), 2, "\(side) half reads \(colour), source \(wanted)")
        }
    }

    /// A source in high dynamic range is not supported and not refused: the export stays 709 and grey stays grey.
    func testAHighDynamicRangeClipExportsAs709WithAMiddleGrey() async throws {
        let folder = ExportTests.folder
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let info = MediaInfo(
            id: MediaID("high-range"), fileName: "high-range.mov", width: 1920, height: 1080,
            duration: Time(ticks: 600), quarterTurns: 0, hasSound: false)
        let source = folder.appendingPathComponent(info.fileName)
        try await writeHighDynamicRangeClip(to: source)
        let written = try await colourProperties(of: source)
        XCTAssertEqual(written.primaries, kCMFormatDescriptionColorPrimaries_ITU_R_2020 as String)
        XCTAssertEqual(written.transfer, kCMFormatDescriptionTransferFunction_ITU_R_2100_HLG as String)
        XCTAssertEqual(written.matrix, kCMFormatDescriptionYCbCrMatrix_ITU_R_2020 as String)

        let project = landscapeProject(of: info)
        let file = folder.appendingPathComponent("high-range.out.mp4")
        try await export(
            plan: renderPlan(for: project), media: project.media, mediaFolder: folder, to: file) { _ in }

        let colour = try await colourProperties(of: file)
        XCTAssertEqual(colour.primaries, kCMFormatDescriptionColorPrimaries_ITU_R_709_2 as String)
        XCTAssertEqual(colour.transfer, kCMFormatDescriptionTransferFunction_ITU_R_709_2 as String)
        XCTAssertEqual(colour.matrix, kCMFormatDescriptionYCbCrMatrix_ITU_R_709_2 as String)
        let middle = try await pixel(of: file, at: Time(ticks: 300), x: 960, y: 540)
        print("compositor: high dynamic range source at half signal exports as \(middle.r), \(middle.g), \(middle.b)")
        // 109 is what the platform's own compositor gave for this clip, which converts such a source.
        XCTAssertLessThanOrEqual(worst(middle, RGB(r: 109, g: 109, b: 109)), 12, "reads \(middle)")
    }

    /// Four quarters of four colours: a picture drawn upside down or mirrored reads wrong. Whole on the canvas
    /// it fills, and with one quarter turn, where the stored left edge is the top of the upright picture.
    @MainActor
    func testAFrameIsDrawnTheRightWayUpAndNotMirroredWithAndWithoutAQuarterTurn() async throws {
        let whole = try await writeQuarterClip(named: "quarters", firstFrame: .zero, to: ExportTests.folder)
        var turned = whole
        turned.quarterTurns = 1
        // The turned picture is 607.5 wide and stands from 656.25 to 1263.75.
        let cases: [(MediaInfo, String, [(Int, Int, RGB)])] = [
            (whole, "quarters.out.mp4", [
                (480, 270, QuarterClip.topLeft), (1440, 270, QuarterClip.topRight),
                (480, 810, QuarterClip.bottomLeft), (1440, 810, QuarterClip.bottomRight),
            ]),
            (turned, "quarters-turned.out.mp4", [
                (808, 270, QuarterClip.bottomLeft), (1112, 270, QuarterClip.topLeft),
                (808, 810, QuarterClip.bottomRight), (1112, 810, QuarterClip.topRight),
            ]),
        ]
        for (info, name, checks) in cases {
            let project = landscapeProject(of: info)
            let plan = try renderPlan(for: project)
            let item = try await makePlayerItem(plan: plan, media: project.media, mediaFolder: ExportTests.folder)
            let generator = AVAssetImageGenerator(asset: item.asset)
            generator.videoComposition = item.videoComposition
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero
            let image = try await generator.image(at: ticks(300)).image
            let file = ExportTests.folder.appendingPathComponent(name)
            try await export(plan: plan, media: project.media, mediaFolder: ExportTests.folder, to: file) { _ in }

            for (x, y, wanted) in checks {
                let shown = try colour(in: image, x: x, y: y)
                let saved = try await pixel(of: file, at: Time(ticks: 300), x: x, y: y)
                XCTAssertLessThanOrEqual(worst(shown, wanted), 24, "\(name) item (\(x), \(y)) reads \(shown)")
                XCTAssertLessThanOrEqual(worst(saved, wanted), 24, "\(name) export (\(x), \(y)) reads \(saved)")
            }
        }
    }

    /// A picture track whose first frame comes one second after the start of its file, as a screen recording
    /// can have. The stretch before it has no source frame.
    func testAClipWhoseFirstFrameComesLateExportsWithBlackBeforeIt() async throws {
        let info = try await writeQuarterClip(named: "late-start", firstFrame: Time(ticks: 600), to: ExportTests.folder)
        let project = landscapeProject(of: info)
        let file = ExportTests.folder.appendingPathComponent("late-start.out.mp4")
        try await export(
            plan: renderPlan(for: project), media: project.media, mediaFolder: ExportTests.folder, to: file) { _ in }

        let before = try await pixel(of: file, at: Time(ticks: 300), x: 480, y: 270)
        let after = try await pixel(of: file, at: Time(ticks: 900), x: 480, y: 270)
        XCTAssertLessThanOrEqual(worst(before, RGB(r: 0, g: 0, b: 0)), 24, "at 300 ticks reads \(before)")
        XCTAssertLessThanOrEqual(worst(after, QuarterClip.topLeft), 24, "at 900 ticks reads \(after)")
    }

    private func ticks(_ value: Int64) -> CMTime {
        CMTime(value: value, timescale: 600)
    }

    @MainActor
    private func composition(of seed: Seed) async throws -> AVVideoComposition {
        for clip in seed.testClips {
            _ = try await writeTestClip(clip, to: ExportTests.folder)
        }
        let project = seed.project
        let item = try await makePlayerItem(
            plan: renderPlan(for: project), media: project.media, mediaFolder: ExportTests.folder)
        return try XCTUnwrap(item.videoComposition)
    }

    /// One clip, whole, alone on the landscape canvas.
    private func landscapeProject(of info: MediaInfo) -> Project {
        var project = Project(canvas: .landscape)
        project.media[info.id] = info
        project.clips = [Clip(id: ClipID(1), media: info.id, sourceStart: .zero, duration: info.duration)]
        return project
    }

    /// The mid tone clip alone and whole on the landscape canvas, which it fills with no scaling.
    private func midTonePlan() throws -> RenderPlan {
        try renderPlan(for: landscapeProject(of: midToneClip().info))
    }

    /// The colour of one pixel of a picture, read as `pixel(of:at:x:y:)` reads a frame of a file.
    /// https://developer.apple.com/documentation/coregraphics/cgcontext/draw(_:in:byTiling:)
    private func colour(in image: CGImage, x: Int, y: Int) throws -> RGB {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(
            data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        let offset = y * context.bytesPerRow + x * 4
        return RGB(r: bytes[offset], g: bytes[offset + 1], b: bytes[offset + 2])
    }

    /// One second of grey at half signal: 10 bit HEVC, tagged HLG and 2020.
    /// https://developer.apple.com/documentation/avfoundation/avassetwriter/canapply(outputsettings:formediatype:)
    /// https://developer.apple.com/documentation/avfoundation/avvideoprofilelevelkey
    /// https://developer.apple.com/documentation/videotoolbox/kvtprofilelevel_hevc_main10_autolevel
    private func writeHighDynamicRangeClip(to file: URL) async throws {
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: 1920,
            AVVideoHeightKey: 1080,
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_2020,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_2100_HLG,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_2020,
            ],
            // The value of kVTProfileLevel_HEVC_Main10_AutoLevel, written out so the tests import no further framework.
            AVVideoCompressionPropertiesKey: [AVVideoProfileLevelKey: "HEVC_Main10_AutoLevel"],
        ]
        let writer = try AVAssetWriter(outputURL: file, fileType: .mov)
        guard writer.canApply(outputSettings: settings, forMediaType: .video) else {
            XCTFail("this machine cannot write 10 bit HEVC")
            throw EngineError.cannotWrite
        }
        let picture = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: picture, sourcePixelBufferAttributes: nil)
        writer.add(picture)
        guard writer.startWriting() else { throw try XCTUnwrap(writer.error) }
        writer.startSession(atSourceTime: .zero)

        let frame = try greyTenBitBuffer()
        for index in 0..<30 {
            while !picture.isReadyForMoreMediaData {
                guard writer.status == .writing else { throw try XCTUnwrap(writer.error) }
                try await Task.sleep(nanoseconds: 2_000_000)
            }
            guard adaptor.append(frame, withPresentationTime: ticks(Int64(index) * 20)) else {
                throw try XCTUnwrap(writer.error)
            }
        }
        picture.markAsFinished()
        writer.endSession(atSourceTime: ticks(600))
        await writer.finishWriting()
        guard writer.status == .completed else { throw try XCTUnwrap(writer.error) }
    }

    /// 1920 by 1080, two planes of 16 bit samples with the 10 bits at the top. Video range: half signal is
    /// 502 of 1023 in the brightness plane, and 512 in the colour plane is no colour.
    /// https://developer.apple.com/documentation/corevideo/kcvpixelformattype_420ypcbcr10biplanarvideorange
    /// https://developer.apple.com/documentation/corevideo/cvbuffersetattachment(_:_:_:_:)
    private func greyTenBitBuffer() throws -> CVPixelBuffer {
        var made: CVPixelBuffer?
        let attributes = [kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()] as CFDictionary
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault, 1920, 1080, kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange, attributes, &made)
        guard status == kCVReturnSuccess, let buffer = made else { throw EngineError.cannotWrite }
        CVBufferSetAttachment(
            buffer, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_2020, .shouldPropagate)
        CVBufferSetAttachment(
            buffer, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_2100_HLG, .shouldPropagate)
        CVBufferSetAttachment(
            buffer, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_2020, .shouldPropagate)

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let samples: [(plane: Int, rows: Int, value: UInt16)] = [(0, 1080, 502 << 6), (1, 540, 512 << 6)]
        for (plane, rows, value) in samples {
            guard let base = CVPixelBufferGetBaseAddressOfPlane(buffer, plane) else { throw EngineError.cannotWrite }
            let rowBytes = CVPixelBufferGetBytesPerRowOfPlane(buffer, plane)
            for y in 0..<rows {
                let row = (base + y * rowBytes).assumingMemoryBound(to: UInt16.self)
                for x in 0..<1920 {
                    row[x] = value
                }
            }
        }
        return buffer
    }
}

private func differences(_ colour: RGB, _ wanted: RGB) -> [Int] {
    [abs(Int(colour.r) - Int(wanted.r)), abs(Int(colour.g) - Int(wanted.g)), abs(Int(colour.b) - Int(wanted.b))]
}

/// The largest difference of the three channels.
private func worst(_ colour: RGB, _ wanted: RGB) -> Int {
    differences(colour, wanted).max() ?? 0
}
#endif
