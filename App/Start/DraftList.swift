import ReelsmithCore
import SwiftUI
import UIKit

/// The list of her drafts on the start screen, in the order given. It decides nothing. Row n,
/// counted from 1, is a button with the identifier `drafts.row.<n>`: a box of 64 by 64 points with the cover
/// fitted whole on black, empty when the draft has no cover, then for a readable draft the date of its last
/// write over its length, both fixed left to right, and for an unreadable one the words of `drafts.unreadable`,
/// disabled. So every row has one height whatever its cover. A tap on a readable row calls `open`.
/// A swipe from the trailing edge, on an unreadable row too, shows the destructive button `drafts.delete`, never
/// a delete by a full swipe alone. Its tap asks in a system alert, whose `drafts.deleteConfirm` calls `delete`
/// and whose `drafts.deleteCancel` keeps the draft. The one state is the draft asked about.
///
/// https://developer.apple.com/documentation/swiftui/list
/// https://developer.apple.com/documentation/swiftui/button
/// https://developer.apple.com/documentation/swiftui/view/buttonstyle(_:)-7qx1
/// https://developer.apple.com/documentation/swiftui/image/init(uiimage:)
/// https://developer.apple.com/documentation/uikit/uiimage/init(contentsoffile:)
/// https://developer.apple.com/documentation/swiftui/image/resizable(capinsets:resizingmode:)
/// https://developer.apple.com/documentation/swiftui/view/scaledtofit()
/// https://developer.apple.com/documentation/swiftui/text/init(verbatim:)
/// https://developer.apple.com/documentation/swiftui/environmentvalues/layoutdirection
/// https://developer.apple.com/documentation/swiftui/view/contentshape(_:eofill:)
/// https://developer.apple.com/documentation/swiftui/view/disabled(_:)
/// https://developer.apple.com/documentation/swiftui/view/accessibilitylabel(_:)-5f0zj
/// https://developer.apple.com/documentation/swiftui/view/accessibilityidentifier(_:)
/// https://developer.apple.com/documentation/swiftui/view/swipeactions(edge:allowsfullswipe:content:)
/// https://developer.apple.com/documentation/swiftui/buttonrole/destructive
/// https://developer.apple.com/documentation/swiftui/view/alert(_:ispresented:presenting:actions:)-3fabk
struct DraftList: View {
    let summaries: [DraftSummary]
    /// For the cover files.
    let shelf: DraftShelf
    let open: @MainActor (DraftID) -> Void
    let delete: @MainActor (DraftID) -> Void

    @State private var asking = false
    @State private var asked: DraftID?

    var body: some View {
        List {
            ForEach(Array(summaries.enumerated()), id: \.element.id) { place, summary in
                row(summary)
                    .accessibilityIdentifier("drafts.row." + String(place + 1))
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            asked = summary.id
                            asking = true
                        } label: {
                            Text("drafts.delete")
                        }
                        .accessibilityIdentifier("drafts.delete")
                    }
            }
        }
        .listStyle(.plain)
        .alert(Text("drafts.deleteQuestion"), isPresented: $asking, presenting: asked) { id in
            Button(role: .destructive) {
                delete(id)
            } label: {
                Text("drafts.delete")
            }
            .accessibilityIdentifier("drafts.deleteConfirm")
            Button(role: .cancel) {
            } label: {
                Text("drafts.deleteCancel")
            }
            .accessibilityIdentifier("drafts.deleteCancel")
        }
    }

    private func row(_ summary: DraftSummary) -> some View {
        let words: String
        if let changed = summary.changed {
            words = text(Words("drafts.row", [dateText(changed, in: .current), summary.duration.clockText]))
        } else {
            words = text(Words("drafts.unreadable"))
        }
        return Button {
            open(summary.id)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Color.black
                    if summary.hasCover, let cover = UIImage(contentsOfFile: shelf.coverFile(of: summary.id).path) {
                        Image(uiImage: cover)
                            .resizable()
                            .scaledToFit()
                    }
                }
                .frame(width: 64, height: 64)
                if let changed = summary.changed {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: dateText(changed, in: .current))
                        Text(verbatim: summary.duration.clockText)
                    }
                    .environment(\.layoutDirection, .leftToRight)
                } else {
                    Text("drafts.unreadable")
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!summary.isReadable)
        .accessibilityLabel(Text(verbatim: words))
    }
}
