import ReelsmithCore
import SwiftUI

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
