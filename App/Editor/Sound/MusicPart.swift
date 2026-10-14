import Foundation
import ReelsmithCore
import ReelsmithEngine
import SwiftUI
import UniformTypeIdentifiers

/// The part `music` of the sound panel. With no music it offers the button `sound.addMusic` alone. With music it
/// shows the title as given (content, never a key), `state.musicLabel`, the same button under the words of
/// `music.replace`, and the button `sound.removeMusic`. The button opens the system's file browser for one audio
/// file. Its one state is the `MusicImport` of a file that comes in: while it is not idle its words show as
/// `sound.importWords`, while it is copying the add buttons are disabled, and after a refusal `sound.importOk`
/// confirms it. Core gives every word and every move. The part copies and reads no file itself: a picked file
/// goes to `addMusic(from:title:to:)`, and `importMusic` holds the right to read it while it copies.
/// The rows lay out from leading to trailing, so Arabic mirrors them. The label of the times is fixed left to
/// right, as the time of the preview is.
///
/// https://developer.apple.com/documentation/swiftui/view/fileimporter(ispresented:allowedcontenttypes:oncompletion:)
/// https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct/audio
/// https://developer.apple.com/documentation/swiftui/state
/// https://developer.apple.com/documentation/swiftui/task
/// https://developer.apple.com/documentation/swiftui/text/init(verbatim:)
/// https://developer.apple.com/documentation/swiftui/view/disabled(_:)
/// https://developer.apple.com/documentation/swiftui/view/linelimit(_:)-513mb
/// https://developer.apple.com/documentation/swiftui/environmentvalues/layoutdirection
/// https://developer.apple.com/documentation/swiftui/view/accessibilityidentifier(_:)
/// https://developer.apple.com/documentation/swiftui/withtransaction(_:_:)
/// https://developer.apple.com/documentation/swiftui/transaction/disablesanimations
struct MusicPart: View {
    let store: EditorStore

    @State private var importing: MusicImport = .idle
    @State private var browsing = false

    var body: some View {
        let state: EditorState = store.state
        let music: Music? = state.project.music
        VStack(spacing: 8) {
            if let music {
                HStack(spacing: 16) {
                    Text(verbatim: music.file.title)
                        .lineLimit(1)
                        .accessibilityIdentifier("sound.musicTitle")
                    Spacer()
                    if let label = state.musicLabel {
                        Text(verbatim: label)
                            .monospacedDigit()
                            .environment(\.layoutDirection, .leftToRight)
                            .accessibilityIdentifier("sound.musicLabel")
                    }
                }
            }
            HStack(spacing: 24) {
                Button(LocalizedStringKey(music == nil ? "music.add" : "music.replace")) { browsing = true }
                    .disabled(importing == .copying)
                    .accessibilityIdentifier("sound.addMusic")
                if music != nil {
                    // Disabled while copying, as the add button is, so a removal is not undone by the file that comes in.
                    Button("music.remove") { still { store.send(.sound(.removeMusic)) } }
                        .disabled(importing == .copying)
                        .accessibilityIdentifier("sound.removeMusic")
                }
                // slot: from-video
                MusicFromVideo(store: store, importing: $importing)
                // end slot: from-video
                Spacer()
            }
            .frame(minHeight: 44)
            if let words = importing.words {
                Text(text(words))
                    .accessibilityIdentifier("sound.importWords")
            }
            if case .failed = importing {
                Button("music.ok") { still { importing = importing.after(.failureConfirmed) } }
                    .accessibilityIdentifier("sound.importOk")
            }
        }
        // One audio file. A cancel calls nothing, so it sends no event and changes nothing. A failure of the
        // browser itself is taken as no pick.
        .fileImporter(isPresented: $browsing, allowedContentTypes: [UTType.audio]) { result in
            guard case .success(let source) = result else {
                return
            }
            bringIn(source)
        }
    }

    /// Sends `picked`, then the event that `addMusic` returns for the picked file, which has no title.
    private func bringIn(_ source: URL) {
        importing = importing.after(.picked)
        Task { @MainActor in
            let event: MusicImport.Event = await addMusic(from: source, title: nil, to: store)
            importing = importing.after(event)
        }
    }

    /// Makes the change of a tap inside a transaction that disables animations, so a tap that changes the
    /// height of the layout does not slide.
    private func still(_ change: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { change() }
    }
}

/// The one way a file comes in, from the file browser and from a video alike. `importMusic` copies the file into
/// the media folder of the store and reads its facts, then the music is set and the answer is `imported`. When it
/// throws, nothing was set and the answer is `refused`, protected for `protectedFile` alone. It throws nothing.
@MainActor
func addMusic(from source: URL, title: String?, to store: EditorStore) async -> MusicImport.Event {
    do {
        let file: MusicFile = try await importMusic(from: source, title: title, to: store.mediaFolder)
        store.send(.sound(.setMusic(file)))
        return .imported
    } catch {
        return .refused(isProtected: (error as? EngineError) == EngineError.protectedFile)
    }
}
