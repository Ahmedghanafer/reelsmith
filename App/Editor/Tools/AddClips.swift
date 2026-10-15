import Foundation
import ReelsmithCore
import SwiftUI

/// The button `editor.addClips` at the trailing end of the tools row, a plus of 44 by 44 points with the label of
/// `tools.add`. It opens the photo picker for videos and photos in the order she chooses. What she picks is copied
/// into the media folder of the store by `copyPicked`, and the facts go to the project in one `addClips`, at its
/// end. A picker closed with nothing chosen, or a copy that gives nothing, sends no action. The button is disabled
/// while a copy runs, and on no other state.
///
/// https://developer.apple.com/documentation/swiftui/view/sheet(ispresented:ondismiss:content:)
/// https://developer.apple.com/documentation/swiftui/image/init(systemname:)
/// https://developer.apple.com/documentation/swiftui/view/frame(width:height:alignment:)
/// https://developer.apple.com/documentation/swiftui/view/contentshape(_:eofill:)
/// https://developer.apple.com/documentation/swiftui/view/accessibilitylabel(_:)-1d7jv
/// https://developer.apple.com/documentation/swiftui/view/disabled(_:)
/// https://developer.apple.com/documentation/swiftui/withtransaction(_:_:)
struct AddClips: View {
    let store: EditorStore

    @State private var picking = false
    @State private var copying = false

    var body: some View {
        Button {
            picking = true
        } label: {
            Image(systemName: "plus")
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .disabled(copying)
        .accessibilityLabel(Text("tools.add"))
        .accessibilityIdentifier("editor.addClips")
        .sheet(isPresented: $picking) {
            VideoPicker(closed: picked, photos: true)
                .ignoresSafeArea()
        }
    }

    /// The picker closed with these items, none when she cancelled.
    private func picked(_ items: [NSItemProvider]) {
        picking = false
        guard !items.isEmpty else {
            return
        }
        copying = true
        Task { @MainActor in
            // The copy throws nothing and nothing cancels it, so the button is always enabled again.
            let facts = await copyPicked(items, into: store.mediaFolder)
            if !facts.isEmpty {
                var still = Transaction()
                still.disablesAnimations = true
                withTransaction(still) { store.send(.addClips(facts)) }
            }
            copying = false
        }
    }
}
