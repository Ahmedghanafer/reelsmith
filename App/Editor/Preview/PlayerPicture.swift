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
/// https://developer.apple.com/documentation/uikit/uiview/layerclass
/// https://developer.apple.com/documentation/avfoundation/avplayer/replacecurrentitem(with:)
/// https://developer.apple.com/documentation/avfoundation/avplayer/seek(to:tolerancebefore:toleranceafter:)
/// https://developer.apple.com/documentation/avfoundation/avplayer/play()
/// https://developer.apple.com/documentation/avfoundation/avplayer/pause()
/// https://developer.apple.com/documentation/avfoundation/avplayer/addperiodictimeobserver(forinterval:queue:using:)
/// https://developer.apple.com/documentation/avfoundation/avplayer/removetimeobserver(_:)
/// https://developer.apple.com/documentation/avfoundation/avplayer/timecontrolstatus-swift.property
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
    /// True while the item of `project` is in the player.
    private var isReady = false
    /// True from the moment the player is told to play until it is stopped.
    private var isPlaying = false
    /// The playhead the player was last sent to while not playing.
    private var shown: Time?
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

    /// Builds the item of the state's project. Until it is there the player keeps the old picture and
    /// follows nothing. Then it is brought to the state of that moment, so the playhead is kept.
    /// An empty project gets no item, and neither does a build that throws: the area is black.
    private func rebuild(for state: EditorState) {
        build += 1
        let number = build
        isReady = false
        stop()
        guard state.canPlay else {
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
            self.player.replaceCurrentItem(with: item)
            self.shown = nil
            if item != nil {
                self.isReady = true
                self.bring(to: self.store.state)
            }
        }
    }

    private func bring(to state: EditorState) {
        if state.isPlaying {
            if !isPlaying {
                isPlaying = true
                shown = nil
                seek(to: state.playhead)
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
        } else {
            if isPlaying {
                stop()
            }
            if shown != state.playhead {
                shown = state.playhead
                seek(to: state.playhead)
            }
        }
    }

    private func seek(to playhead: Time) {
        player.seek(to: CMTime(value: playhead.ticks, timescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
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
    /// reported, also when this view has not been handed that state yet. A time from before the
    /// player really runs, as one from before the seek of a start has landed, is not reported either.
    private func report(_ time: CMTime) {
        guard store.state.isPlaying, timeObserver != nil, player.timeControlStatus == .playing else {
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
        guard isPlaying, store.state.isPlaying else {
            return
        }
        stop()
        store.send(.movePlayhead(store.state.project.duration))
        store.send(.pause)
    }
}
