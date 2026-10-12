import ReelsmithCore
import SwiftUI

/// The start screen: the title, the choice of the shape, and "New project", which opens the system picker for videos.
/// It draws a `StartState`, which only `StartState.after(_:)` moves. Its one own state is the chosen shape.
/// `open` gets the store the editor opens with.
///
/// https://developer.apple.com/documentation/swiftui/view/sheet(ispresented:ondismiss:content:)
/// https://developer.apple.com/documentation/swiftui/view/accessibilityaddtraits(_:)
/// https://developer.apple.com/documentation/swiftui/accessibilitytraits/isselected
/// https://developer.apple.com/documentation/swiftui/view/accessibilityidentifier(_:)
/// https://developer.apple.com/documentation/swiftui/view/background(_:in:fillstyle:)
struct StartScreen: View {
    let options: LaunchOptions
    let open: @MainActor (EditorStore) -> Void

    @State private var state = StartState.idle
    @State private var canvas = ReelsmithCore.Canvas.startChoice
    @State private var picking = false

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
        }
        .multilineTextAlignment(.center)
        .padding()
        .onAppear {
            emptyPickedMediaFolder()
        }
        .sheet(isPresented: $picking) {
            VideoPicker(closed: pickerClosed)
                .ignoresSafeArea()
        }
    }

    /// The picker closed with these videos, none when she cancelled.
    private func pickerClosed(_ videos: [NSItemProvider]) {
        picking = false
        state = state.after(.pickerClosed(chosen: videos.count))
        guard state == .copying else { return }
        Task {
            // The copy throws nothing and nothing cancels it, so `copyingEnded` is always sent.
            let facts = await copyPicked(videos)
            state = state.after(.copyingEnded(facts))
            if case .ready(var project) = state {
                project.canvas = canvas
                let editor = EditorState(project: project)
                open(EditorStore(state: editor, mediaFolder: pickedMediaFolder, options: options))
            }
        }
    }
}
