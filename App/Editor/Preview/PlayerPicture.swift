import AVFoundation
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
/// when the project changes, it seeks when the playhead changes while not playing, and it starts from
/// the playhead when `isPlaying` turns true. While playing it reports its time with `movePlayhead`,
/// which never makes it seek, and at the end it sends `pause`. Never mirrored.
///
/// https://developer.apple.com/documentation/avfoundation/avplayer
/// https://developer.apple.com/documentation/avfoundation/avplayerlayer
/// https://developer.apple.com/documentation/avfoundation/avplayerlayer/pixelbufferattributes
/// https://developer.apple.com/documentation/corevideo/kcvpixelbufferiosurfacepropertieskey
/// https://developer.apple.com/documentation/uikit/uiview/layerclass
/// https://developer.apple.com/documentation/avfoundation/avplayer/replacecurrentitem(with:)
/// https://developer.apple.com/documentation/avfoundation/avplayeritem/status-swift.property
/// https://developer.apple.com/documentation/objectivec/nsobject-swift.class/observe(_:options:changehandler:)
/// https://developer.apple.com/documentation/avfoundation/avplayer/seek(to:tolerancebefore:toleranceafter:)
/// https://developer.apple.com/documentation/avfoundation/avplayer/seek(to:tolerancebefore:toleranceafter:completionhandler:)
/// https://developer.apple.com/documentation/avfoundation/avplayer/play()
/// https://developer.apple.com/documentation/avfoundation/avplayer/pause()
/// https://developer.apple.com/documentation/avfoundation/avplayer/addperiodictimeobserver(forinterval:queue:using:)
/// https://developer.apple.com/documentation/avfoundation/avplayer/removetimeobserver(_:)
/// https://developer.apple.com/documentation/avfoundation/avplayeritem/didplaytoendtimenotification
/// https://developer.apple.com/documentation/foundation/notificationcenter/addobserver(_:selector:name:object:)
/// https://developer.apple.com/documentation/coremedia/cmtime/convertscale(_:method:)
/// https://developer.apple.com/documentation/swift/mainactor/assumeisolated(_:file:line:)
/// https://developer.apple.com/documentation/uikit/uiview/semanticcontentattribute
/// https://developer.apple.com/documentation/uikit/uiaccessibilityidentification/accessibilityidentifier
final class PlayerPictureView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    private let store: EditorStore
    private let player: AVPlayer
    /// The project of the newest build of the item.
    private var project: Project?
    /// Counts the builds, so the result of a build that a newer one superseded is dropped.
    private var build = 0
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

    init(store: EditorStore) {
        self.store = store
        player = AVPlayer()
        super.init(frame: .zero)
        semanticContentAttribute = .forceLeftToRight
        backgroundColor = UIColor.black
        isAccessibilityElement = true
        accessibilityIdentifier = "editor.picture"
        (layer as? AVPlayerLayer)?.player = player
        // Without this request the simulator's layer refuses every frame of a clip that fills the canvas
        // unscaled and shows black. It names a kind of buffer. What it costs on a device is not measured.
        (layer as? AVPlayerLayer)?.pixelBufferAttributes = [
            kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()
        ]
        NotificationCenter.default.addObserver(
            self, selector: #selector(itemEnded(_:)), name: AVPlayerItem.didPlayToEndTimeNotification, object: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    /// Called with every state of the store.
    func follow(_ state: EditorState) {
        if project != state.project {
            project = state.project
            rebuild(for: state)
        } else if isReady {
            bring(to: state)
        }
    }

    /// Builds the item of the state's project and sends it to the playhead of that moment. Until it is
    /// ready the player follows nothing. Then it is brought to the state of that moment.
    /// An empty project gets no item and the one of the last build is let go. A build that throws
    /// gets no item either: the area is black.
    private func rebuild(for state: EditorState) {
        build += 1
        let number = build
        isReady = false
        statusObservation = nil
        stop()
        guard state.canPlay else {
            item = nil
            player.replaceCurrentItem(with: nil)
            return
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
            self.install(item, build: number)
        }
    }

    private func install(_ item: AVPlayerItem?, build number: Int) {
        self.item = item
        player.replaceCurrentItem(with: item)
        // The first playhead goes with the item, so the player gets ready on that frame and not on
        // the first one. A seek with no completion handler may be sent before the item is ready.
        // Nothing says when it lands, so the player does not count as standing there: at ready it is
        // sought to the playhead of that moment with a handler, and rests or starts when that landed.
        let first: Time = store.state.playhead
        target = nil
        player.seek(to: CMTime(value: first.ticks, timescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        // A seek with a completion handler needs an item that is ready, so the player waits for it.
        // The change can come on any thread.
        statusObservation = item?.observe(\.status, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.itemStatusChanged(number)
            }
        }
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
        // The handler can come on any thread.
        player.seek(
            to: CMTime(value: wanted.ticks, timescale: 600), toleranceBefore: .zero, toleranceAfter: .zero
        ) { [weak self] finished in
            Task { @MainActor [weak self] in
                self?.seekEnded(wanted, finished: finished, build: number)
            }
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
        // The queue is the main queue, so the block runs on the main actor.
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(value: Time.frame.ticks, timescale: 600), queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated {
                if let self {
                    self.report(time)
                }
            }
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
    private func report(_ time: CMTime) {
        guard store.state.isPlaying, timeObserver != nil else {
            return
        }
        store.send(.movePlayhead(Time(ticks: time.convertScale(600, method: .roundTowardZero).value)))
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
