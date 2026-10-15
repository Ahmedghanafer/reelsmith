import AVFoundation
import Flutter
import ReelsmithCore
import ReelsmithEngine
import UIKit

/// The bridge of the trial: the Engine's player item drawn into a Flutter texture, the time sent as
/// events, and the Engine's export. Frames are pulled from an AVPlayerItemVideoOutput on each display tick.
final class E25Plugin: NSObject, FlutterPlugin, FlutterTexture, FlutterStreamHandler {
    private let textures: FlutterTextureRegistry
    private var textureId: Int64 = -1
    private let player = AVPlayer()
    private var output: AVPlayerItemVideoOutput?
    private var link: CADisplayLink?
    private var latest: CVPixelBuffer?
    private var sink: FlutterEventSink?
    private var timeObserver: Any?
    private var frames = 0
    private var project = Project(canvas: .portrait)
    private var mediaFolder = URL(fileURLWithPath: NSTemporaryDirectory())
    /// While a swap is watched: every buffer that comes is measured.
    private var watchSwap = false
    private var swapMeans: [Double] = []

    init(textures: FlutterTextureRegistry) {
        self.textures = textures
    }

    static func register(with registrar: FlutterPluginRegistrar) {
        let plugin = E25Plugin(textures: registrar.textures())
        let methods = FlutterMethodChannel(name: "e25/engine", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(plugin, channel: methods)
        let events = FlutterEventChannel(name: "e25/events", binaryMessenger: registrar.messenger())
        events.setStreamHandler(plugin)
    }

    // MARK: events

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        return nil
    }

    private func send(_ event: [String: Any]) {
        sink?(event)
    }

    // MARK: texture

    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        guard let buffer = latest else { return nil }
        return Unmanaged.passRetained(buffer)
    }

    @MainActor @objc private func tick(_ link: CADisplayLink) {
        guard let output else { return }
        let time = output.itemTime(forHostTime: CACurrentMediaTime())
        guard output.hasNewPixelBuffer(forItemTime: time),
              let buffer = output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil)
        else { return }
        latest = buffer
        textures.textureFrameAvailable(textureId)
        frames += 1
        if watchSwap {
            swapMeans.append(Self.mean(of: buffer, centre: false).luma)
        }
        if frames == 1 || frames % 30 == 0 {
            let m = Self.mean(of: buffer, centre: false)
            send(["type": "frame", "count": frames, "r": m.r, "g": m.g, "b": m.b])
        }
    }

    /// The mean colour of a BGRA buffer, over the whole picture or its middle third, read on a grid.
    static func mean(of buffer: CVPixelBuffer, centre: Bool) -> (r: Double, g: Double, b: Double, luma: Double) {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return (0, 0, 0, 0) }
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let row = CVPixelBufferGetBytesPerRow(buffer)
        let pixels = base.assumingMemoryBound(to: UInt8.self)
        let x0 = centre ? width / 3 : 0, x1 = centre ? 2 * width / 3 : width
        let y0 = centre ? height / 3 : 0, y1 = centre ? 2 * height / 3 : height
        var r = 0.0, g = 0.0, b = 0.0, n = 0.0
        for y in stride(from: y0, to: y1, by: 16) {
            for x in stride(from: x0, to: x1, by: 16) {
                let p = pixels + y * row + x * 4
                b += Double(p[0])
                g += Double(p[1])
                r += Double(p[2])
                n += 1
            }
        }
        guard n > 0 else { return (0, 0, 0, 0) }
        r /= n
        g /= n
        b /= n
        return (r, g, b, 0.299 * r + 0.587 * g + 0.114 * b)
    }

    // MARK: calls

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Flutter calls the handler on the main thread.
        MainActor.assumeIsolated { self.handleOnMain(call, result: result) }
    }

    @MainActor private func handleOnMain(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "launchArguments":
            result(ProcessInfo.processInfo.arguments)
        case "prepare":
            Task { @MainActor in await self.prepare(result) }
        case "play":
            player.play()
            result(nil)
        case "pause":
            player.pause()
            result(nil)
        case "seek":
            let seconds = args["seconds"] as? Double ?? 0
            let start = CACurrentMediaTime()
            player.seekExactly(to: Time(ticks: Int64(seconds * 600))) { finished in
                result(["ms": (CACurrentMediaTime() - start) * 1000, "finished": finished])
            }
        case "refresh":
            refresh(result)
        case "swap":
            Task { @MainActor in await self.swap(result) }
        case "export":
            Task { await self.runExport(result) }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func clipProject(_ clip: TestClip) -> Project {
        var project = Project(canvas: .portrait)
        project.media[clip.info.id] = clip.info
        project.clips = [Clip(id: ClipID(1), media: clip.info.id, sourceStart: .zero, duration: clip.duration)]
        project.nextClipID = 2
        return project
    }

    @MainActor private func prepare(_ result: @escaping FlutterResult) async {
        let start = CACurrentMediaTime()
        do {
            mediaFolder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("e25media")
            _ = try await writeTestClip(.red, to: mediaFolder)
            _ = try await writeTestClip(.green, to: mediaFolder)
            project = clipProject(.red)
            let item = try await makePlayerItem(plan: renderPlan(for: project), media: project.media, mediaFolder: mediaFolder)
            attach(item)
            textureId = textures.register(self)
            let display = CADisplayLink(target: self, selector: #selector(tick(_:)))
            display.add(to: .main, forMode: .common)
            link = display
            timeObserver = player.reportTime(every: Time(ticks: 60)) { [weak self] time in
                self?.send(["type": "time", "seconds": Double(time.ticks) / 600])
            }
            result([
                "textureId": textureId, "seconds": Double(project.duration.ticks) / 600,
                "ms": (CACurrentMediaTime() - start) * 1000,
            ])
        } catch {
            result(FlutterError(code: "prepare", message: "\(error)", details: nil))
        }
    }

    @MainActor private func attach(_ item: AVPlayerItem) {
        let video = AVPlayerItemVideoOutput(pixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey as String: true,
        ])
        item.add(video)
        output = video
        player.replaceCurrentItem(with: item)
    }

    /// Adds a large boxed text to the plan, refreshes the picture of the paused item and draws the frame
    /// again with an exact seek to where it stands. Reports the mean of the middle before and after.
    @MainActor private func refresh(_ result: @escaping FlutterResult) {
        guard let item = player.currentItem, let video = output else {
            result(FlutterError(code: "refresh", message: "no item", details: nil))
            return
        }
        player.pause()
        let before = latest.map { Self.mean(of: $0, centre: true) }
        let framesBefore = frames
        var style = TextStyle.standard
        style.size = 400
        style.box = true
        style.colour = RGB(r: 255, g: 255, b: 255)
        style.font = .system
        project.texts = [
            TextItem(id: TextID(1), string: "E27", span: .whole, x: 540, y: 960, rotation: 0, style: style)
        ]
        project.nextTextID = 2
        do {
            try refreshPicture(of: item, plan: renderPlan(for: project), media: project.media)
        } catch {
            result(FlutterError(code: "refresh", message: "\(error)", details: nil))
            return
        }
        let now = item.currentTime()
        let start = CACurrentMediaTime()
        player.seek(to: now, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Reads the output straight, in case no display tick took the new frame.
                let time = video.itemTime(forHostTime: CACurrentMediaTime())
                if let fresh = video.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil) {
                    self.latest = fresh
                    self.textures.textureFrameAvailable(self.textureId)
                }
                let after = self.latest.map { Self.mean(of: $0, centre: true) }
                result([
                    "beforeLuma": before?.luma ?? -1, "afterLuma": after?.luma ?? -1,
                    "framesBetween": self.frames - framesBefore, "ms": (CACurrentMediaTime() - start) * 1000,
                ])
            }
        }
    }

    /// Builds the item of another clip and puts it in the player, then watches every buffer for a second.
    @MainActor private func swap(_ result: @escaping FlutterResult) async {
        do {
            let start = CACurrentMediaTime()
            project = clipProject(.green)
            let item = try await makePlayerItem(plan: renderPlan(for: project), media: project.media, mediaFolder: mediaFolder)
            swapMeans = []
            watchSwap = true
            attach(item)
            player.play()
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            watchSwap = false
            let black = swapMeans.filter { $0 < 8 }.count
            let last = latest.map { Self.mean(of: $0, centre: false) }
            result([
                "buffers": swapMeans.count, "black": black, "minLuma": swapMeans.min() ?? -1,
                "lastG": last?.g ?? -1, "ms": (CACurrentMediaTime() - start) * 1000,
            ])
        } catch {
            result(FlutterError(code: "swap", message: "\(error)", details: nil))
        }
    }

    private func runExport(_ result: @escaping FlutterResult) async {
        let start = CACurrentMediaTime()
        let target = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("e25.mp4")
        do {
            let plan = try renderPlan(for: project)
            try await export(plan: plan, media: project.media, mediaFolder: mediaFolder, to: target) { _ in }
            let size = (try FileManager.default.attributesOfItem(atPath: target.path)[.size] as? NSNumber)?.int64Value ?? -1
            let duration = try await AVURLAsset(url: target).load(.duration)
            result([
                "path": target.path, "bytes": size, "seconds": duration.seconds,
                "ms": (CACurrentMediaTime() - start) * 1000,
            ])
        } catch {
            result(FlutterError(code: "export", message: "\(error)", details: nil))
        }
    }
}
