import ReelsmithCore
import SwiftUI

@main
struct ReelsmithApp: App {
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
                    FirstScreen()
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

struct FirstScreen: View {
    private let opened = firstOpened(
        in: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0], now: Date())

    var body: some View {
        VStack(spacing: 12) {
            Text("Reelsmith").font(.largeTitle)
            Text("Version \(info("CFBundleShortVersionString")) (\(info("CFBundleVersion")))")
            Text("Commit \(info("GitCommit"))")
            switch opened {
            case .date(let date):
                Text("First opened \(date.formatted(date: .abbreviated, time: .shortened))")
            case .unavailable:
                Text("First opened: the date could not be saved or read on this phone.")
            }
        }
        .multilineTextAlignment(.center)
        .padding()
    }

    private func info(_ key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
    }
}
