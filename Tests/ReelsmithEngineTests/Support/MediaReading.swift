#if canImport(AVFoundation)
import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
import ReelsmithCore
import XCTest

/// One track of a file. `kind` is "vide" or "soun". `coding` is the four characters of its sample coding,
/// "avc1" for H.264 and "lpcm" for uncompressed sound. The last three are 0 for a picture track.
struct TrackFacts {
    var kind: String
    var coding: String
    var duration: CMTime
    var sampleRate: Double
    var channels: Int
    var bitsPerSample: Int
}

/// The tracks of a file with the coding of each.
/// https://developer.apple.com/documentation/avfoundation/avasynchronouskeyvalueloading
/// https://developer.apple.com/documentation/coremedia/cmformatdescriptiongetmediasubtype(_:)
/// https://developer.apple.com/documentation/coremedia/cmaudioformatdescriptiongetstreambasicdescription(_:)
func tracks(of file: URL) async throws -> [TrackFacts] {
    let asset = AVURLAsset(url: file)
    defer { withExtendedLifetime(asset) {} }
    var facts: [TrackFacts] = []
    for track in try await asset.load(.tracks) {
        let descriptions = try await track.load(.formatDescriptions)
        let description = try XCTUnwrap(descriptions.first)
        let range = try await track.load(.timeRange)
        var sampleRate = 0.0
        var channels = 0
        var bitsPerSample = 0
        if track.mediaType == .audio, let basic = CMAudioFormatDescriptionGetStreamBasicDescription(description) {
            sampleRate = basic.pointee.mSampleRate
            channels = Int(basic.pointee.mChannelsPerFrame)
            bitsPerSample = Int(basic.pointee.mBitsPerChannel)
        }
        facts.append(TrackFacts(
            kind: track.mediaType.rawValue, coding: fourCharacters(CMFormatDescriptionGetMediaSubType(description)),
            duration: range.duration, sampleRate: sampleRate, channels: channels, bitsPerSample: bitsPerSample))
    }
    return facts
}

/// The size of the picture as stored, before any turn.
/// https://developer.apple.com/documentation/avfoundation/avassettrack/naturalsize
func storedSize(of file: URL) async throws -> (width: Int, height: Int) {
    let asset = AVURLAsset(url: file)
    defer { withExtendedLifetime(asset) {} }
    let size = try await pictureTrack(of: asset).load(.naturalSize)
    return (Int(size.width), Int(size.height))
}

/// The six numbers of the stored transform of the picture track: a, b, c, d, tx, ty.
/// https://developer.apple.com/documentation/avfoundation/avassettrack/preferredtransform
func storedTransform(of file: URL) async throws -> [Double] {
    let asset = AVURLAsset(url: file)
    defer { withExtendedLifetime(asset) {} }
    let transform = try await pictureTrack(of: asset).load(.preferredTransform)
    return [
        Double(transform.a), Double(transform.b), Double(transform.c), Double(transform.d),
        Double(transform.tx), Double(transform.ty),
    ]
}

/// The colour properties the picture track reports, each as the platform's own name, nil when it reports none.
/// https://developer.apple.com/documentation/coremedia/cmformatdescriptiongetextension(_:extensionkey:)
func colourProperties(of file: URL) async throws -> (primaries: String?, transfer: String?, matrix: String?) {
    let asset = AVURLAsset(url: file)
    defer { withExtendedLifetime(asset) {} }
    let descriptions = try await pictureTrack(of: asset).load(.formatDescriptions)
    let description = try XCTUnwrap(descriptions.first)
    func value(_ key: CFString) -> String? {
        CMFormatDescriptionGetExtension(description, extensionKey: key) as? String
    }
    return (
        value(kCMFormatDescriptionExtension_ColorPrimaries), value(kCMFormatDescriptionExtension_TransferFunction),
        value(kCMFormatDescriptionExtension_YCbCrMatrix)
    )
}

/// The file type as the file itself says it: the four characters of its major brand, "qt  " for a QuickTime
/// movie. Empty when the file does not start with a file type box.
func fileType(of file: URL) throws -> String {
    let head = try Data(contentsOf: file, options: .mappedIfSafe).prefix(12)
    guard head.count == 12, String(decoding: head[4..<8], as: UTF8.self) == "ftyp" else { return "" }
    return String(decoding: head[8..<12], as: UTF8.self)
}

/// The number of picture frames in the file, counted without decoding.
/// https://developer.apple.com/documentation/avfoundation/avassetreadertrackoutput
/// https://developer.apple.com/documentation/coremedia/cmsamplebuffergetnumsamples(_:)
func frameCount(of file: URL) async throws -> Int {
    let asset = AVURLAsset(url: file)
    let reader = try AVAssetReader(asset: asset)
    let track = try await pictureTrack(of: asset)
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
    reader.add(output)
    guard reader.startReading() else { throw try XCTUnwrap(reader.error) }
    var count = 0
    while let buffer = output.copyNextSampleBuffer() {
        count += CMSampleBufferGetNumSamples(buffer)
    }
    guard reader.status == .completed else { throw try XCTUnwrap(reader.error) }
    return count
}

/// The peak of the first sound track, from 0 to 1 of full scale.
/// https://developer.apple.com/documentation/avfoundation/avassetreader
/// https://developer.apple.com/documentation/coremedia/cmblockbuffercopydatabytes(_:atoffset:datalength:destination:)
func soundPeak(of file: URL) async throws -> Double {
    let asset = AVURLAsset(url: file)
    let soundTracks = try await asset.loadTracks(withMediaType: .audio)
    let reader = try AVAssetReader(asset: asset)
    let settings: [String: Any] = [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsNonInterleaved: false,
    ]
    let track = try XCTUnwrap(soundTracks.first)
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
    reader.add(output)
    guard reader.startReading() else { throw try XCTUnwrap(reader.error) }
    var peak = 0
    while let buffer = output.copyNextSampleBuffer() {
        guard let block = CMSampleBufferGetDataBuffer(buffer) else { continue }
        let length = CMBlockBufferGetDataLength(block)
        guard length >= 2 else { continue }
        var samples = [Int16](repeating: 0, count: length / 2)
        let status = samples.withUnsafeMutableBytes { bytes in
            CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: bytes.count, destination: bytes.baseAddress!)
        }
        XCTAssertEqual(status, kCMBlockBufferNoErr)
        for sample in samples {
            peak = max(peak, abs(Int(sample)))
        }
    }
    guard reader.status == .completed else { throw try XCTUnwrap(reader.error) }
    return Double(peak) / 32768
}

/// The colour of one pixel of the stored picture, x and y counted from the top left, in the frame shown at a time.
/// https://developer.apple.com/documentation/avfoundation/avassetimagegenerator/image(at:)
/// https://developer.apple.com/documentation/coregraphics/cgcontext/draw(_:in:byTiling:)
func pixel(of file: URL, at time: Time, x: Int, y: Int) async throws -> RGB {
    let generator = AVAssetImageGenerator(asset: AVURLAsset(url: file))
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    let image = try await generator.image(at: CMTime(value: time.ticks, timescale: 600)).image
    let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
    let context = try XCTUnwrap(CGContext(
        data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    let bytes = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
    let offset = y * context.bytesPerRow + x * 4
    return RGB(r: bytes[offset], g: bytes[offset + 1], b: bytes[offset + 2])
}

private func pictureTrack(of asset: AVURLAsset) async throws -> AVAssetTrack {
    let pictureTracks = try await asset.loadTracks(withMediaType: .video)
    return try XCTUnwrap(pictureTracks.first)
}

private func fourCharacters(_ code: FourCharCode) -> String {
    let bytes = [UInt8((code >> 24) & 0xFF), UInt8((code >> 16) & 0xFF), UInt8((code >> 8) & 0xFF), UInt8(code & 0xFF)]
    return String(decoding: bytes, as: UTF8.self)
}
#endif
