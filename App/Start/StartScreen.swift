import Foundation
import ReelsmithCore
import SwiftUI

/// The start screen: the title, the choice of the shape, and "New project", which opens the system picker for videos.
/// It draws a `StartState`, which only `StartState.after(_:)` moves. Its own state is the chosen shape and the
/// summaries of the drafts on the shelf, read when it appears. `open` gets the store the editor opens with.
/// A new project is a new draft: made first, the videos copied into its media folder, then written.
/// Under New project, while there are drafts, the title `drafts.title` and the list of them, where a tap on a row
/// opens that draft again.
///
/// https://developer.apple.com/documentation/swiftui/view/sheet(ispresented:ondismiss:content:)
/// https://developer.apple.com/documentation/swiftui/view/accessibilityaddtraits(_:)
/// https://developer.apple.com/documentation/swiftui/accessibilitytraits/isselected
/// https://developer.apple.com/documentation/swiftui/view/accessibilityidentifier(_:)
/// https://developer.apple.com/documentation/swiftui/view/background(_:in:fillstyle:)
/// https://developer.apple.com/documentation/swiftui/view/contentshape(_:eofill:)
/// https://developer.apple.com/documentation/swiftui/view/onappear(perform:)
/// https://developer.apple.com/documentation/swiftui/text/init(verbatim:)
struct StartScreen: View {
    let options: LaunchOptions
    let shelf: DraftShelf
    let open: @MainActor (EditorStore) -> Void

    @State private var state = StartState.idle
    @State private var canvas = ReelsmithCore.Canvas.startChoice
    @State private var picking = false
    @State private var summaries: [DraftSummary] = []

    var body: some View {
        VStack(spacing: 24) {
            Text("start.title")
                .font(.largeTitle)
                .accessibilityIdentifier("start.title")
            // A row, so the leading shape is first and Arabic changes the sides by itself.
            HStack(spacing: 12) {
                ForEach(ReelsmithCore.Canvas.allCases, id: \.self) { shape in
                    Button {
                        canvas = shape
                    } label: {
                        Text(text(shape.words))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .foregroundStyle(shape == canvas ? Color.white : Color.primary)
                            .background(
                                shape == canvas ? Color.accentColor : Color.clear,
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary))
                            // The whole shape takes the tap, the padding of the one with no fill too.
                            .contentShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(shape.words.key)
                    .accessibilityAddTraits(shape == canvas ? .isSelected : [])
                }
            }
            Button("start.newProject") {
                picking = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(state != .idle)
            .accessibilityIdentifier("start.newProject")
            if let words = state.words {
                Text(text(words))
            }
            if state == .failed {
                Button("start.ok") {
                    state = state.after(.failureConfirmed)
                }
                .accessibilityIdentifier("start.ok")
            }
            if !summaries.isEmpty {
                Text("drafts.title")
                    .font(.headline)
                DraftList(summaries: summaries, shelf: shelf, open: { openDraft($0) })
            }
            if options.drafts != nil {
                Text(verbatim: draftsInfo(summaries))
                    .font(.footnote)
                    .accessibilityIdentifier("start.draftsInfo")
            }
        }
        .multilineTextAlignment(.center)
        .padding()
        .onAppear {
            summaries = shelf.list()
        }
        .sheet(isPresented: $picking) {
            VideoPicker(closed: pickerClosed)
                .ignoresSafeArea()
        }
    }

    /// Opens the draft of a row with the history it was written with. A draft that cannot be opened is logged,
    /// and the list is read again, where it shows as unreadable.
    private func openDraft(_ id: DraftID) {
        let draft: Draft
        do {
            draft = try shelf.open(id)
        } catch {
            NSLog("%@", "start: the draft was not opened: \(error)")
            summaries = shelf.list()
            return
        }
        let opened = OpenDraft(shelf: shelf, id: id)
        open(
            EditorStore(
                state: EditorState(project: draft.project), mediaFolder: opened.mediaFolder, options: options,
                draft: opened, exportSettings: draft.exportSettings, history: draft.history))
    }

    /// The picker closed with these videos, none when she cancelled.
    private func pickerClosed(_ videos: [NSItemProvider]) {
        picking = false
        state = state.after(.pickerClosed(chosen: videos.count))
        guard state == .copying else { return }
        let draft: OpenDraft
        do {
            draft = try shelf.create(
                Draft(project: Project(canvas: canvas), exportSettings: .startChoice, changed: Date()))
        } catch {
            // The shelf leaves no draft when it throws.
            state = state.after(.copyingEnded([]))
            return
        }
        Task {
            // The copy throws nothing and nothing cancels it, so `copyingEnded` is always sent.
            let facts = await copyPicked(videos, into: draft.mediaFolder)
            state = state.after(.copyingEnded(facts))
            if case .ready(var project) = state {
                project.canvas = canvas
                do {
                    try draft.write(Draft(project: project, exportSettings: .startChoice, changed: Date()))
                } catch {
                    NSLog("%@", "start: the new draft was not written: \(error)")
                }
                let editor = EditorState(project: project)
                open(EditorStore(state: editor, mediaFolder: draft.mediaFolder, options: options, draft: draft))
            } else if state == .failed {
                try? shelf.delete(draft.id)
            }
        }
    }
}
