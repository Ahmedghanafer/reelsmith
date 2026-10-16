import AVFoundation
import Flutter
import Foundation
import ReelsmithCore
import ReelsmithEngine

/// The player of the preview, which draws into the texture of `PreviewTexture`. The player is made once,
/// so a step of the playhead builds nothing again. It holds the state Dart last showed it, which its own
/// reports of the time move as they moved the store's state in the SwiftUI app.
///
/// The player follows the state: its item is built again
/// when the footage of the project changes and refreshed when only the texts change, it seeks when the
/// playhead changes while not playing, and it starts from the playhead when `isPlaying` turns true.
/// A new item is given the playhead as its starting time before it goes in, and a state that rests
/// or starts there sends no seek.
/// While playing it reports its time with the event `playhead`, which never makes it seek, and at the end
/// it sends `playedToEnd`. Never mirrored.
///
/// The event `buildCount` carries the count of the items the player began to build. A refresh does not
/// change it. Dart shows it as the value of `editor.picture` on a seeded start.
///
/// A new item has no frame to show at first. So the texture keeps the last frame it holds, the old
/// picture, from before the new item goes into the player until the first frame of the new item comes
/// out of the item's video output, or until `oldPictureLimit` has passed. Each time one line goes
/// to the log, starting with "old picture": laid, not laid and why, taken away after how long and why.
///
/// https://developer.apple.com/documentation/foundation/nslog(_:_:)
/// https://developer.apple.com/documentation/swift/task/sleep(nanoseconds:)
/// https://developer.apple.com/documentation/avfoundation/avplayer
/// https://developer.apple.com/documentation/avfoundation/avplayer/replacecurrentitem(with:)
/// https://developer.apple.com/documentation/avfoundation/avplayer/currentitem
/// https://developer.apple.com/documentation/avfoundation/avplayeritem/status-swift.property
/// https://developer.apple.com/documentation/objectivec/nsobject-swift.class/observe(_:options:changehandler:)
/// https://developer.apple.com/documentation/avfoundation/avplayer/play()
/// https://developer.apple.com/documentation/avfoundation/avplayer/pause()
/// https://developer.apple.com/documentation/avfoundation/avplayer/removetimeobserver(_:)
/// https://developer.apple.com/documentation/avfoundation/avplayeritem/didplaytoendtimenotification
/// https://developer.apple.com/documentation/foundation/notificationcenter/addobserver(_:selector:name:object:)
/// https://developer.apple.com/documentation/avfoundation/avplayeritem/videocomposition
@MainActor
final class PreviewPlayer: NSObject {
    private let events: EngineEvents
    private let texture: PreviewTexture
    private let player: AVPlayer
    /// The state Dart last showed, with the playhead the player last reported while playing.
    private var state: EditorState
    /// The folder of the project's media, as Dart last showed it.
    private var mediaFolder: URL
    /// The project the player last followed, or the one a build that landed was refreshed to.
    private var project: Project?
    /// Counts the builds, so the result of a build that a newer one superseded is dropped.
    private var build = 0
    /// True from the start of a build of an item until it lands.
    private var isBuilding = false
    /// Counts the items the player began to build, sent as the event `buildCount`.
    private var built = 0
    /// The item of the newest build, the one whose status is observed.
    private var item: AVPlayerItem?
    /// True while `item` is ready to play.
    private var isReady = false
    private var statusObservation: NSKeyValueObservation?
    /// True from the moment the state turns to playing until the player is stopped.
    private var isPlaying = false
    /// The playhead of the last seek with a completion handler. While one seek is in flight it can
    /// be a newer playhead, whose seek is sent when the one in flight has ended. Nil when the player
    /// is not known to stand on a playhead of the state: a new item, a seek that did not finish,
    /// from a start on.
    private var target: Time?
    /// The time the newest item was given before it went into the player, its starting time. Nil
    /// from the first seek with a handler and from a start on. A state whose playhead is sought as
    /// this time sends no seek: the player answers a seek to the time it already has at once, with
    /// no frame of its own.
    private var sent: Time?
    /// True while one seek is in flight. A newer playhead waits in `target` until it lands.
    private var isSeeking = false
    private var timeObserver: Any?
    /// True when the next seek goes one tick back first and then to its time: after a picture refresh
    /// on a paused item, a seek to the time it stands on gave the video output a new frame in one
    /// simulator run and none in another, and one tick back then the time gave it in both.
    private var redraws = false
    /// Counts the items put into the player. What was registered for an older item does nothing.
    /// What is registered for the newest item reads the texture's flag of the moment.
    private var shown = 0
    /// When the old picture was laid. Nil while none lies.
    private var laid: Date?
    /// The seconds after which the old picture goes also when the item never gave a frame: an
    /// item that fails. A build and its first frame take under half a second in the simulator.
    private static let oldPictureLimit: UInt64 = 15

    init(textures: FlutterTextureRegistry, events: EngineEvents) {
        self.events = events
        texture = PreviewTexture(registry: textures)
        player = AVPlayer()
        state = EditorState(project: Project())
        mediaFolder = URL(fileURLWithPath: NSTemporaryDirectory())
        super.init()
        NotificationCenter.default.addObserver(
            self, selector: #selector(itemEnded(_:)), name: AVPlayerItem.didPlayToEndTimeNotification, object: nil)
    }

    /// The id of the texture the player draws into.
    var textureId: Int64 {
        texture.id
    }

    /// Takes what Dart shows: the project, its media folder, a playhead only when Dart moved it, and
    /// playing. A show with no playhead seeks nothing: when the player stands on no playhead of the state
    /// and is not to play on, as after playing or after a seek that did not finish, it counts as standing
    /// on the playhead it has, so a playhead the player reported never comes back as a seek. Only a
    /// refreshed picture still waiting to be drawn again is sought, at the playhead it has.
    func show(project shownProject: Project, mediaFolder folder: URL, playhead: Time?, playing: Bool) {
        mediaFolder = folder
        state.project = shownProject
        if let playhead {
            state.playhead = playhead
        }
        state.isPlaying = playing
        if playhead == nil, target == nil, !redraws, !(playing && isPlaying) {
            target = state.playhead
        }
        follow(state)
    }

    /// Stops the player, lets its item go and unregisters the texture. What a build or a limit of the
    /// player registered before does nothing after it.
    func dispose() {
        build += 1
        shown += 1
        stop()
        statusObservation = nil
        item = nil
        player.replaceCurrentItem(with: nil)
        texture.dispose()
    }

    /// Called with every state Dart shows. Another footage builds a new item. Other texts on the
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
        // Only levels differ: the standing item is given the mix of the new plan and the player plays on, then the
        // texts are refreshed as below when they differ too. While a build runs, or when the Engine refuses, a new
        // item is built.
        let sameTracks: Bool = project?.sameTracks(as: state.project) ?? false
        let sameTexts: Bool = project?.texts == state.project.texts
        // A level and a framing changed at once: the picture is refreshed too, as for other texts.
        let sameFramings: Bool = project?.clips.map(\.framing) == state.project.clips.map(\.framing)
        project = state.project
        if !sameFootage, sameTracks, !isBuilding, let standing = item,
            (try? refreshSound(of: standing, plan: renderPlan(for: state.project))) != nil {
            if (sameTexts && sameFramings) || refresh(standing, to: state.project) {
                if isReady {
                    bring(to: state)
                }
            } else {
                rebuild(for: state)
            }
        } else if !sameFootage {
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
    /// It only sets the video composition of the item. False when the Engine refused: the item is then
    /// as it was. For the item in the paused player the next seek goes one tick back first, so the
    /// texture gets the frame drawn again. With no seek in flight the player then stands on no playhead,
    /// and with one in flight it is sought again when that one lands.
    private func refresh(_ item: AVPlayerItem, to project: Project) -> Bool {
        do {
            try refreshPicture(of: item, plan: renderPlan(for: project), media: project.media)
            if item === player.currentItem, !isPlaying {
                redraws = true
                if !isSeeking || !isReady {
                    target = nil
                    sent = nil
                }
            }
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
        redraws = false
        isReady = false
        statusObservation = nil
        stop()
        isBuilding = state.canPlay
        guard state.canPlay else {
            item = nil
            texture.follow(nil)
            keepTheOldPicture(until: nil, without: "an empty project")
            player.replaceCurrentItem(with: nil)
            return
        }
        built += 1
        events.send(BuildCountEvent(count: Int64(built)))
        let project: Project = state.project
        Task {
            var item: AVPlayerItem?
            do {
                let plan: RenderPlan = try renderPlan(for: project)
                item = try await makePlayerItem(plan: plan, media: project.media, mediaFolder: self.mediaFolder)
            } catch {
                item = nil
            }
            guard number == self.build else {
                return
            }
            self.isBuilding = false
            // A text edit made while the build ran: the item is refreshed once, before it goes into
            // the player and is brought to the state.
            let now: Project = self.state.project
            if let made = item, now != project, now.sameFootage(as: project) {
                self.project = now
                if !self.refresh(made, to: now) {
                    self.rebuild(for: self.state)
                    return
                }
            }
            self.install(item, build: number)
        }
    }

    private func install(_ item: AVPlayerItem?, build number: Int) {
        self.item = item
        redraws = false
        // The item is given the first playhead before it goes into the player, so that time is its
        // starting time: the player makes the item ready on that frame and never begins on the
        // first one. A seek sent after the item went in could reach a player that had already
        // begun to decode the first frame of the project, and that frame was once seen to stay.
        let first: Time = state.playhead
        target = nil
        sent = frameTime(of: first)
        item?.seekExactly(to: frameTime(of: first))
        texture.follow(item)
        keepTheOldPicture(until: item, without: "a failed build")
        player.replaceCurrentItem(with: item)
        // A seek with a completion handler needs an item that is ready, so the player waits for it.
        // The change can come on any thread.
        statusObservation = item?.observe(\.status, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.itemStatusChanged(number)
            }
        }
    }

    /// Called before an item goes into the player, once the texture follows it. With no item nothing is
    /// kept, so the area is black, and `why` says for the log why there is none.
    /// The texture keeps the last frame it holds until the first frame of the new item. When it holds
    /// none (nothing was drawn yet, as at the opening of the editor), nothing is laid and the area is
    /// black until the first frame.
    private func keepTheOldPicture(until item: AVPlayerItem?, without why: String) {
        shown += 1
        let number = shown
        texture.onFirstFrame = nil
        guard item != nil else {
            takeTheOldPictureAway(because: why)
            return
        }
        let missing = "the layer gave no buffer"
        if texture.holdsPicture {
            if laid == nil {
                laid = Date()
            }
            NSLog("%@", "old picture laid, item \(number)")
        } else {
            let before = laid == nil ? "nothing lies" : "the one before still lies"
            NSLog("%@", "old picture not laid, item \(number): \(missing), \(before)")
        }
        // Set before the item goes in, so no first frame is missed. It is called on the main thread.
        texture.onFirstFrame = { [weak self] in
            self?.showThePlayer(number, onlyWhenReady: true)
        }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: PreviewPlayer.oldPictureLimit * 1_000_000_000)
            self?.showThePlayer(number, onlyWhenReady: false)
        }
    }

    /// For the newest item only: takes the old picture away when the texture holds a frame of it, or
    /// whatever the texture holds when the limit has passed.
    private func showThePlayer(_ number: Int, onlyWhenReady: Bool) {
        guard number == shown else {
            return
        }
        if onlyWhenReady, !texture.hasFrame {
            return
        }
        takeTheOldPictureAway(
            because: onlyWhenReady
                ? "the layer reported ready" : "the limit of \(PreviewPlayer.oldPictureLimit) seconds")
    }

    /// Lets the old picture go, so the area shows what the player gives. Writes a line when one lay.
    private func takeTheOldPictureAway(because why: String) {
        if let since = laid {
            let lay = Int(Date().timeIntervalSince(since) * 1000)
            NSLog("%@", "old picture taken away after \(lay) ms, item \(shown): \(why)")
        }
        laid = nil
        texture.takeTheOldPictureAway()
    }

    private func itemStatusChanged(_ number: Int) {
        guard number == build, !isReady, item?.status == .readyToPlay else {
            return
        }
        isReady = true
        isSeeking = false
        bring(to: state)
    }

    private func bring(to state: EditorState) {
        if state.isPlaying {
            if !isPlaying {
                // The player starts when it stands on the playhead: at once when a seek to it has
                // landed before or it is the starting time of the item, otherwise when the seek to
                // it has landed.
                isPlaying = true
                if target != state.playhead, sent != frameTime(of: state.playhead) {
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
            if target != state.playhead, sent != frameTime(of: state.playhead) {
                seek(to: state.playhead)
            }
        }
    }

    /// One seek is in flight at a time. A playhead that comes meanwhile is held, and the player is sent
    /// to the newest one when the seek in flight has landed.
    private func seek(to playhead: Time) {
        target = playhead
        sent = nil
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
        if redraws {
            redraws = false
            let time: Time = frameTime(of: wanted)
            // One tick back, or one frame on at the start, where a seek back would stay at the start.
            let aside: Time = time > .zero ? time - Time(ticks: 1) : time + Time.frame
            player.seekExactly(to: aside) { [weak self] _ in
                guard let self, number == self.build else {
                    return
                }
                self.player.seekExactly(to: time) { [weak self] finished in
                    self?.seekEnded(wanted, finished: finished, build: number)
                }
            }
            return
        }
        player.seekExactly(to: frameTime(of: wanted)) { [weak self] finished in
            self?.seekEnded(wanted, finished: finished, build: number)
        }
    }

    /// The time the player is sent to for a playhead: at the very end of the project the last frame,
    /// the one that holds the last tick before the end. A text is drawn in a frame before its end.
    /// Sent to the time of the end itself the player shows that same last frame with no text in it.
    private func frameTime(of playhead: Time) -> Time {
        guard let length: Time = project?.duration, playhead >= length else {
            return playhead
        }
        return (length - Time(ticks: 1)).roundedDownToFrame
    }

    private func seekEnded(_ sought: Time, finished: Bool, build number: Int) {
        guard number == build else {
            return
        }
        isSeeking = false
        if target != sought {
            seekToTarget()
        } else if redraws {
            // A picture refreshed while this seek was in flight is drawn again, finished or not.
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
        sent = nil
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

    /// The state Dart last showed is read at this moment: once it has stopped playing nothing more is
    /// reported. The playhead moves as the store's did, and Dart gets the time.
    private func report(_ time: Time) {
        guard state.isPlaying, timeObserver != nil else {
            return
        }
        state = ReelsmithCore.reduce(state, .movePlayhead(time))
        events.send(PlayheadEvent(ticks: time.ticks))
    }

    /// The notification can come on any thread.
    @objc nonisolated private func itemEnded(_ notification: Notification) {
        Task { @MainActor in
            self.playedToEnd()
        }
    }

    private func playedToEnd() {
        guard isPlaying, timeObserver != nil, state.isPlaying else {
            return
        }
        stop()
        state = ReelsmithCore.reduce(state, .movePlayhead(state.project.duration))
        state = ReelsmithCore.reduce(state, .pause)
        events.send(PlayheadEvent(ticks: state.project.duration.ticks))
        events.send(PlayedToEndEvent())
        // The player stands on the time of the end, where a frame drawn again has no text. It counts
        // as standing on no playhead, so the paused state seeks to the last frame.
        follow(state)
    }
}
