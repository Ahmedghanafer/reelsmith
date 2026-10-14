import AVFoundation
import ReelsmithCore
import SwiftUI

@main
struct ReelsmithApp: App {
    // The sound plays with the ring switch on silent and stops other sound of the phone. A failure is logged,
    // and the app goes on with the category it has.
    // https://developer.apple.com/documentation/avfaudio/avaudiosession/setcategory(_:)
    // https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/playback
    init() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
        } catch {
            NSLog("%@", "audio session: the category playback was not set: \(error)")
        }
    }

    // The debug guard of the launch values: only a debug build reads the process arguments.
    #if DEBUG
    private let options = LaunchOptions(arguments: ProcessInfo.processInfo.arguments)
    #else
    private let options = LaunchOptions(arguments: [])
    #endif

    // The editor is opened by setting this store, by the seed start and by the start screen alike.
    @State private var store: EditorStore?

    var body: some Scene {
        WindowGroup {
            // A stack and no Group: a Group would hand the task to each branch and so run the seed start twice.
            ZStack {
                if let store {
                    EditorScreen(store: store)
                } else {
                    // slot: start
                    StartScreen(options: options, open: { store = $0 })
                    // end slot: start
                }
            }
            .task {
                if let seeded = await seedStart(options), store == nil {
                    store = seeded
                }
            }
        }
    }
}
