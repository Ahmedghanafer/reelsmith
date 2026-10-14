import Foundation
import ReelsmithCore
import SwiftUI

/// The button `sound.addFromVideo` of the part `music`, with the words of `music.fromVideo`. It opens the photo
/// picker for one video and takes the sound of the video chosen as the music. It moves the `MusicImport` of the
/// part it stands in: `picked` when a video is chosen, then the event `addMusic` answers, and `refused` with no
/// protection when the copy fails. It is disabled while that state is `copying`. A picker closed with nothing
/// chosen sends no event. The picked video is copied into a new folder under the temporary folder, handed to
/// `addMusic(from:title:to:)`, which makes the copy the project keeps, and the folder is removed when `addMusic`
/// has returned, after an import and after a refusal alike.
///
/// https://developer.apple.com/documentation/swiftui/view/sheet(ispresented:ondismiss:content:)
/// https://developer.apple.com/documentation/swiftui/binding
/// https://developer.apple.com/documentation/foundation/filemanager/temporarydirectory
/// https://developer.apple.com/documentation/foundation/filemanager/createdirectory(at:withintermediatedirectories:attributes:)
/// https://developer.apple.com/documentation/foundation/filemanager/removeitem(at:)
/// https://developer.apple.com/documentation/foundation/nsitemprovider/suggestedname
struct MusicFromVideo: View {
    let store: EditorStore
    @Binding var importing: MusicImport

    @State private var picking = false

    var body: some View {
        Button("music.fromVideo") { picking = true }
            .disabled(importing == .copying)
            .accessibilityIdentifier("sound.addFromVideo")
            .sheet(isPresented: $picking) {
                VideoPicker(closed: picked, limit: 1)
                    .ignoresSafeArea()
            }
    }

    /// The picker closed with these videos, none when she cancelled.
    private func picked(_ videos: [NSItemProvider]) {
        picking = false
        guard let video = videos.first else {
            return
        }
        importing = importing.after(.picked)
        Task { @MainActor in
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            // A folder that cannot be made fails the copy below.
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var event = MusicImport.Event.refused(isProtected: false)
            if let fileName = await copyVideo(video, named: UUID().uuidString, into: folder) {
                event = await addMusic(
                    from: folder.appendingPathComponent(fileName), title: video.suggestedName ?? "", to: store)
            }
            try? FileManager.default.removeItem(at: folder)
            importing = importing.after(event)
        }
    }
}
