import AVFoundation
import CoreVideo
import Flutter
import QuartzCore

/// The picture of the preview as a Flutter texture. A display link reads the video output of the item
/// in the player on every refresh of the screen and hands Flutter each new frame, so the frame of a
/// paused seek is taken whenever it comes, also after the seek has ended. The texture keeps the last
/// frame it was given until the next one: over an item change that frame is the old picture, held until
/// the first frame of the new item.
///
/// `copyPixelBuffer` is called by Flutter off the main thread. Everything else runs on the main thread.
///
/// https://api.flutter.dev/ios-embedder/protocol_flutter_texture-p.html
/// https://api.flutter.dev/ios-embedder/protocol_flutter_texture_registry-p.html
/// https://developer.apple.com/documentation/avfoundation/avplayeritemvideooutput
/// https://developer.apple.com/documentation/avfoundation/avplayeritemvideooutput/init(pixelbufferattributes:)
/// https://developer.apple.com/documentation/avfoundation/avplayeritemoutput/itemtime(forhosttime:)
/// https://developer.apple.com/documentation/avfoundation/avplayeritemvideooutput/hasnewpixelbuffer(foritemtime:)
/// https://developer.apple.com/documentation/avfoundation/avplayeritemvideooutput/copypixelbuffer(foritemtime:itemtimefordisplay:)
/// https://developer.apple.com/documentation/avfoundation/avplayeritem/add(_:)
/// https://developer.apple.com/documentation/quartzcore/cadisplaylink
/// https://developer.apple.com/documentation/quartzcore/cacurrentmediatime()
/// https://developer.apple.com/documentation/corevideo/cvpixelbuffercreate(_:_:_:_:_:_:)
/// https://developer.apple.com/documentation/corevideo/kcvpixelbufferiosurfacepropertieskey
/// https://developer.apple.com/documentation/corevideo/kcvpixelbuffermetalcompatibilitykey
/// https://developer.apple.com/documentation/foundation/nslock
final class PreviewTexture: NSObject, FlutterTexture {
    private let registry: FlutterTextureRegistry
    private(set) var id: Int64 = 0
    private var link: CADisplayLink?
    /// The video output of the item in the player. Nil while the player has no item.
    private var output: AVPlayerItemVideoOutput?
    /// The buffer Flutter is handed, read under `lock`.
    private var latest: CVPixelBuffer?
    private let lock = NSLock()
    /// True once a frame of the item the texture follows came out of its video output.
    private(set) var hasFrame = false
    /// True while the texture holds a frame of an item, false at the start and while it is black.
    private(set) var holdsPicture = false
    /// Called on the main thread when the first frame of the item the texture follows has come.
    var onFirstFrame: (@MainActor () -> Void)?

    @MainActor
    init(registry: FlutterTextureRegistry) {
        self.registry = registry
        super.init()
        id = registry.register(self)
        let display = CADisplayLink(target: self, selector: #selector(tick(_:)))
        display.add(to: .main, forMode: .common)
        link = display
    }

    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        lock.lock()
        defer { lock.unlock() }
        guard let buffer = latest else {
            return nil
        }
        return Unmanaged.passRetained(buffer)
    }

    /// Follows the item about to go into the player: its frames come from a video output of its own,
    /// in the format the compositor draws. The frame the texture holds stays until the item gives one.
    /// With no item no frame comes.
    @MainActor
    func follow(_ item: AVPlayerItem?) {
        hasFrame = false
        output = nil
        guard let item else {
            return
        }
        let video = AVPlayerItemVideoOutput(pixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
            kCVPixelBufferMetalCompatibilityKey as String: true,
        ])
        item.add(video)
        output = video
    }

    /// Black when no frame of the item the texture follows has come: the old picture goes, and the area
    /// shows what the player gives, which is nothing.
    @MainActor
    func takeTheOldPictureAway() {
        guard !hasFrame else {
            return
        }
        holdsPicture = false
        hand(PreviewTexture.black)
    }

    /// Stops reading frames and unregisters the texture.
    @MainActor
    func dispose() {
        link?.invalidate()
        link = nil
        output = nil
        onFirstFrame = nil
        registry.unregisterTexture(id)
    }

    @MainActor @objc private func tick(_ link: CADisplayLink) {
        guard let output else {
            return
        }
        let time = output.itemTime(forHostTime: CACurrentMediaTime())
        guard output.hasNewPixelBuffer(forItemTime: time),
            let buffer = output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil)
        else {
            return
        }
        holdsPicture = true
        hand(buffer)
        if !hasFrame {
            hasFrame = true
            onFirstFrame?()
        }
    }

    private func hand(_ buffer: CVPixelBuffer?) {
        lock.lock()
        latest = buffer
        lock.unlock()
        registry.textureFrameAvailable(id)
    }

    /// Two by two black pixels, which Flutter stretches over the area. Nil when it cannot be made.
    private static let black: CVPixelBuffer? = {
        var made: CVPixelBuffer?
        let attributes: [String: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
            kCVPixelBufferMetalCompatibilityKey as String: true,
        ]
        guard CVPixelBufferCreate(kCFAllocatorDefault, 2, 2, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &made)
            == kCVReturnSuccess, let buffer = made
        else {
            return nil
        }
        CVPixelBufferLockBaseAddress(buffer, [])
        if let base = CVPixelBufferGetBaseAddress(buffer) {
            let bytes = base.assumingMemoryBound(to: UInt8.self)
            let row = CVPixelBufferGetBytesPerRow(buffer)
            for y in 0..<2 {
                for x in 0..<2 {
                    // Blue, green, red, alpha.
                    let pixel = bytes + y * row + x * 4
                    pixel[0] = 0
                    pixel[1] = 0
                    pixel[2] = 0
                    pixel[3] = 255
                }
            }
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }()
}
