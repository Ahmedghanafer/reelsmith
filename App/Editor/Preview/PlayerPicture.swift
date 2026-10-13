import AVFoundation
import CoreImage
import ReelsmithCore
import ReelsmithEngine
import SwiftUI
import UIKit

/// The picture area for SwiftUI: hands each state to the UIKit view below. The view and its player
/// are made once, so a step of the playhead builds nothing again.
///
/// https://developer.apple.com/documentation/swiftui/uiviewrepresentable
struct PlayerPicture: UIViewRepresentable {
    let state: EditorState
    let store: EditorStore

    func makeUIView(context: Context) -> PlayerPictureView {
        PlayerPictureView(store: store)
    }

    func updateUIView(_ view: PlayerPictureView, context: Context) {
        view.follow(state)
    }
}

/// A black area whose layer shows the player. The player follows the state: its item is built again
/// when the footage of the project changes and refreshed when only the texts change, it seeks when the
/// playhead changes while not playing, and it starts from the playhead when `isPlaying` turns true.
/// While playing it reports its time with `movePlayhead`, which never makes it seek, and at the end
/// it sends `pause`. Never mirrored.
///
/// On a seeded start, and only then, the accessibility value of the area is the count of the items
/// that were built, in the digits 0 to 9. A refresh does not change it.
///
/// A new item has no frame to show at first. So the picture the layer shows is copied before the new
/// item goes into the player and lies over the layer until the layer says that the first frame of
/// the new item is ready for display, or until `oldPictureLimit` has passed. Each time one line goes
/// to the log, starting with "old picture": laid, not laid and why, taken away after how long and why.
///
/// https://developer.apple.com/documentation/foundation/nslog(_:_:)
/// https://developer.apple.com/documentation/avfoundation/avplayerlayer/isreadyfordisplay
/// https://developer.apple.com/documentation/avfoundation/avplayerlayer/displayedreadonlypixelbuffer()
/// https://developer.apple.com/documentation/corevideo/cvreadonlypixelbuffer
/// https://developer.apple.com/documentation/coreimage/ciimage/init(cvpixelbuffer:)
/// https://developer.apple.com/documentation/coreimage/cicontext/createcgimage(_:from:)
/// https://developer.apple.com/documentation/uikit/uiimageview
/// https://developer.apple.com/documentation/uikit/uiview/contentmode-swift.property
/// https://developer.apple.com/documentation/swift/task/sleep(nanoseconds:)
/// https://developer.apple.com/documentation/avfoundation/avplayer
/// https://developer.apple.com/documentation/avfoundation/avplayerlayer
/// https://developer.apple.com/documentation/avfoundation/avplayerlayer/pixelbufferattributes
/// https://developer.apple.com/documentation/corevideo/kcvpixelbufferiosurfacepropertieskey
/// https://developer.apple.com/documentation/uikit/uiview/layerclass
/// https://developer.apple.com/documentation/avfoundation/avplayer/replacecurrentitem(with:)
/// https://developer.apple.com/documentation/avfoundation/avplayeritem/status-swift.property
/// https://developer.apple.com/documentation/objectivec/nsobject-swift.class/observe(_:options:changehandler:)
/// https://developer.apple.com/documentation/avfoundation/avplayer/play()
/// https://developer.apple.com/documentation/avfoundation/avplayer/pause()
/// https://developer.apple.com/documentation/avfoundation/avplayer/removetimeobserver(_:)
/// https://developer.apple.com/documentation/avfoundation/avplayeritem/didplaytoendtimenotification
/// https://developer.apple.com/documentation/foundation/notificationcenter/addobserver(_:selector:name:object:)
/// https://developer.apple.com/documentation/uikit/uiview/semanticcontentattribute
/// https://developer.apple.com/documentation/uikit/uiaccessibilityidentification/accessibilityidentifier
/// https://developer.apple.com/documentation/objectivec/nsobject-swift.class/accessibilityvalue
/// https://developer.apple.com/documentation/avfoundation/avplayeritem/videocomposition
final class PlayerPictureView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    private let store: EditorStore
    private let player: AVPlayer
    /// The project the view was last handed, or the one a build that landed was refreshed to.
    private var project: Project?
    /// Counts the builds, so the result of a build that a newer one superseded is dropped.
    private var build = 0
    /// True from the start of a build of an item until it lands.
    private var isBuilding = false
    /// Counts the items that were built, for the accessibility value of a seeded start.
    private var built = 0
    /// The item of the newest build, the one whose status is observed.
    private var item: AVPlayerItem?
    /// True while `item` is ready to play.
    private var isReady = false
    private var statusObservation: NSKeyValueObservation?
    /// True from the moment the state turns to playing until the player is stopped.
    private var isPlaying = false
    /// The playhead of the last seek with a completion handler, or the end when the item has played
    /// to it. While one seek is in flight it can be a newer playhead, whose seek is sent when the one
    /// in flight has ended. Nil when the player is not known to stand on a playhead of the state: a
    /// new item, a seek that did not finish, from a start on.
    private var target: Time?
    /// True while one seek is in flight. A newer playhead waits in `target` until it lands.
    private var isSeeking = false
    private var timeObserver: Any?
    /// The picture of the item before the newest one, over the layer while it is not hidden.
    private let oldPicture = UIImageView()
    private let imageContext = CIContext()
    /// Counts the items put into the player. What was registered for an older item does nothing.
    /// What is registered for the newest item reads the layer's flag of the moment, so a late report
    /// of ready for the item before, just after a newer one went in, can take the old picture away
    /// early. The area is then black until the frame, as with no old picture, never a wrong picture.
    private var shown = 0
    /// When the old picture was laid. Nil while none lies.
    private var laid: Date?
    private var displayObservation: NSKeyValueObservation?
    /// The seconds after which the old picture goes also when the layer never said it was ready: an
    /// item that fails. A build and its first frame take under half a second in the simulator.
    private static let oldPictureLimit: UInt64 = 15

    init(store: EditorStore) {
        self.store = store
        player = AVPlayer()
        super.init(frame: .zero)
        semanticContentAttribute = .forceLeftToRight
        backgroundColor = UIColor.black
        isAccessibilityElement = true
        accessibilityIdentifier = "editor.picture"
        if store.options.seed != nil {
            accessibilityValue = String(built)
        }
        (layer as? AVPlayerLayer)?.player = player
        // Without this request the simulator's layer refuses every frame of a clip that fills the canvas
        // unscaled and shows black. It names a kind of buffer. What it costs on a device is not measured.
        (layer as? AVPlayerLayer)?.pixelBufferAttributes = [
            kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()
        ]
        NotificationCenter.default.addObserver(
            self, selector: #selector(itemEnded(_:)), name: AVPlayerItem.didPlayToEndTimeNotification, object: nil)
        // The layer shows a frame whole and in its middle, and so does this view.
        oldPicture.contentMode = .scaleAspectFit
        oldPicture.isHidden = true
        oldPicture.frame = bounds
        oldPicture.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(oldPicture)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    /// Called with every state of the store. Another footage builds a new item. Other texts on the
    /// same footage refresh the standing item, and build a new one when the Engine refuses the refresh.
    /// While a build runs nothing is refreshed: the build does it when it lands. With no item and the
    /// same footage (an empty project, a failed build) nothing is done.
    func follow(_ state: EditorState) {
        if project == state.project {
            if isReady {
                bring(to: state)
            }
            return
        }
        let sameFootage: Bool = project?.sameFootage(as: state.project) ?? false
        project = state.project
        if !sameFootage {
            rebuild(for: state)
        } else if !isBuilding, let standing = item {
            if refresh(standing, to: state.project) {
                if isReady {
                    bring(to: state)
                }
            } else {
                rebuild(for: state)
            }
        }
    }

    /// Gives the item the picture of the project, whose footage is the one the item was built from.
    /// It only sets the video composition of the item, and a paused player is expected to draw its
    /// frame again from it. False when the Engine refused: the item is then as it was.
    private func refresh(_ item: AVPlayerItem, to project: Project) -> Bool {
        do {
            try refreshPicture(of: item, plan: renderPlan(for: project), media: project.media)
            return true
        } catch {
            return false
        }
    }

    /// Builds the item of the state's project and sends it to the playhead of that moment. Until it is
    /// ready the player follows nothing. Then it is brought to the state of that moment.
    /// An empty project gets no item and the one of the last build is let go. A build that throws
    /// gets no item either: the area is black. While a build runs the player keeps the item before it
    /// and stands still, so the area shows the picture from before the change.
    private func rebuild(for state: EditorState) {
        build += 1
        let number = build
        isReady = false
        statusObservation = nil
        stop()
        isBuilding = state.canPlay
        guard state.canPlay else {
            item = nil
            keepTheOldPicture(until: nil, without: "an empty project")
            player.replaceCurrentItem(with: nil)
            return
        }
        built += 1
        if store.options.seed != nil {
            accessibilityValue = String(built)
        }
        let project: Project = state.project
        Task {
            var item: AVPlayerItem?
            do {
                let plan: RenderPlan = try renderPlan(for: project)
                item = try await makePlayerItem(plan: plan, media: project.media, mediaFolder: self.store.mediaFolder)
            } catch {
                item = nil
            }
            guard number == self.build else {
                return
            }
            self.isBuilding = false
            // A text edit made while the build ran: the item is refreshed once, before it goes into
            // the player and is brought to the state.
            let now: Project = self.store.state.project
            if let made = item, now != project, now.sameFootage(as: project) {
                self.project = now
                if !self.refresh(made, to: now) {
                    self.rebuild(for: self.store.state)
                    return
                }
            }
            self.install(item, build: number)
        }
    }

    private func install(_ item: AVPlayerItem?, build number: Int) {
        self.item = item
        keepTheOldPicture(until: item, without: "a failed build")
        player.replaceCurrentItem(with: item)
        // The first playhead goes with the item, so the player gets ready on that frame and not on
        // the first one. A seek with no completion handler may be sent before the item is ready.
        // Nothing says when it lands, so the player does not count as standing there: at ready it is
        // sought to the playhead of that moment with a handler, and rests or starts when that landed.
        let first: Time = store.state.playhead
        target = nil
        player.seekExactly(to: first)
        // A seek with a completion handler needs an item that is ready, so the player waits for it.
        // The change can come on any thread.
        statusObservation = item?.observe(\.status, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.itemStatusChanged(number)
            }
        }
    }

    /// Called before an item goes into the player. With no item nothing is kept, so the area is black,
    /// and `why` says for the log why there is none.
    /// The layer gives its picture only while the player is paused, which it is here: every build
    /// starts with a stop. When the layer gives none, what lies over it stays as it is: the picture
    /// of a still older item whose follower never drew, or nothing.
    private func keepTheOldPicture(until item: AVPlayerItem?, without why: String) {
        shown += 1
        let number = shown
        displayObservation = nil
        guard item != nil, let playerLayer = layer as? AVPlayerLayer else {
            takeTheOldPictureAway(because: why)
            return
        }
        var image: CGImage?
        var missing = "the layer gave no buffer"
        if let buffer = playerLayer.displayedReadOnlyPixelBuffer() {
            missing = "no image came of the buffer"
            image = buffer.withUnsafeBuffer { pixels in
                let picture = CIImage(cvPixelBuffer: pixels)
                return imageContext.createCGImage(picture, from: picture.extent)
            }
        }
        if let image {
            oldPicture.image = UIImage(cgImage: image)
            oldPicture.isHidden = false
            if laid == nil {
                laid = Date()
            }
            NSLog("%@", "old picture laid, item \(number)")
        } else {
            let before = laid == nil ? "nothing lies" : "the one before still lies"
            NSLog("%@", "old picture not laid, item \(number): \(missing), \(before)")
        }
        // Observed before the item goes in, so no change of the value is missed. The change can come
        // on any thread.
        displayObservation = playerLayer.observe(\.isReadyForDisplay, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.showThePlayer(number, onlyWhenReady: true)
            }
        }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: PlayerPictureView.oldPictureLimit * 1_000_000_000)
            self?.showThePlayer(number, onlyWhenReady: false)
        }
    }

    /// For the newest item only: takes the old picture away when the layer says it is ready, or
    /// whatever the layer says when the limit has passed.
    private func showThePlayer(_ number: Int, onlyWhenReady: Bool) {
        guard number == shown else {
            return
        }
        if onlyWhenReady, (layer as? AVPlayerLayer)?.isReadyForDisplay != true {
            return
        }
        takeTheOldPictureAway(
            because: onlyWhenReady
                ? "the layer reported ready" : "the limit of \(PlayerPictureView.oldPictureLimit) seconds")
    }

    /// Hides the old picture, so the area shows what the player shows. Writes a line when one lay.
    private func takeTheOldPictureAway(because why: String) {
        if let since = laid {
            let lay = Int(Date().timeIntervalSince(since) * 1000)
            NSLog("%@", "old picture taken away after \(lay) ms, item \(shown): \(why)")
        }
        laid = nil
        oldPicture.isHidden = true
        oldPicture.image = nil
    }

    private func itemStatusChanged(_ number: Int) {
        guard number == build, !isReady, item?.status == .readyToPlay else {
            return
        }
        isReady = true
        isSeeking = false
        bring(to: store.state)
    }

    private func bring(to state: EditorState) {
        if state.isPlaying {
            if !isPlaying {
                // The player starts when it stands on the playhead: at once when a seek to it has
                // landed before, otherwise when the seek to it has landed.
                isPlaying = true
                if target != state.playhead {
                    seek(to: state.playhead)
                }
                if !isSeeking {
                    start()
                }
            }
        } else {
            if isPlaying {
                stop()
            }
            if target != state.playhead {
                seek(to: state.playhead)
            }
        }
    }

    /// One seek is in flight at a time. A playhead that comes meanwhile is held, and the player is sent
    /// to the newest one when the seek in flight has landed.
    private func seek(to playhead: Time) {
        target = playhead
        if !isSeeking {
            seekToTarget()
        }
    }

    private func seekToTarget() {
        guard let wanted: Time = target else {
            return
        }
        isSeeking = true
        let number = build
        player.seekExactly(to: wanted) { [weak self] finished in
            self?.seekEnded(wanted, finished: finished, build: number)
        }
    }

    private func seekEnded(_ sought: Time, finished: Bool, build number: Int) {
        guard number == build else {
            return
        }
        isSeeking = false
        if target != sought {
            seekToTarget()
        } else if !finished {
            // The player is not there, so the next state seeks again.
            target = nil
        }
        if !isSeeking, isPlaying, timeObserver == nil {
            start()
        }
    }

    private func start() {
        // From here the player moves by itself and stands on no playhead of the state.
        target = nil
        player.play()
        timeObserver = player.reportTime(every: Time.frame) { [weak self] time in
            self?.report(time)
        }
    }

    private func stop() {
        isPlaying = false
        player.pause()
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
    }

    /// The state of the store is read at this moment: once it has stopped playing nothing more is
    /// reported, also when this view has not been handed that state yet.
    private func report(_ time: Time) {
        guard store.state.isPlaying, timeObserver != nil else {
            return
        }
        store.send(.movePlayhead(time))
    }

    /// The notification can come on any thread.
    @objc nonisolated private func itemEnded(_ notification: Notification) {
        Task { @MainActor in
            self.playedToEnd()
        }
    }

    private func playedToEnd() {
        guard isPlaying, timeObserver != nil, store.state.isPlaying else {
            return
        }
        stop()
        store.send(.movePlayhead(store.state.project.duration))
        store.send(.pause)
        // The player stands on its last frame, which is the picture of the end. No seek goes there.
        target = store.state.playhead
    }
}
