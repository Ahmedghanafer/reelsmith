import ReelsmithCore
import SwiftUI

/// The editor shell: four regions from top to bottom, each with the slot of the story that fills it.
/// The root and the regions are accessibility containers, so a region is found while it is empty
/// and a control inside it keeps its own identifier.
///
/// https://developer.apple.com/documentation/swiftui/view/accessibilityelement(children:)
/// https://developer.apple.com/documentation/swiftui/view/accessibilityidentifier(_:)
struct EditorScreen: View {
    let store: EditorStore

    var body: some View {
        VStack(spacing: 0) {
            if store.options.seed != nil {
                Text(text(seedInfo))
                    .font(.footnote)
                    .accessibilityIdentifier("editor.seedInfo")
            }
            ZStack {
                // slot: preview
                PreviewPane(store: store)
                // end slot: preview
            }
            .frame(maxHeight: .infinity)
            .region("editor.previewRegion")
            ZStack {
                // slot: timeline
                // A wrapped UIKit view takes all the height it is offered, so the strip fixes its own.
                TimelineStrip(state: store.state, send: { action in store.send(action) })
                    .frame(height: 72)
                // end slot: timeline
            }
            .region("editor.timelineRegion")
            ZStack {
                // slot: tools
                ToolsRow(state: store.state, send: { action in store.send(action) })
                // end slot: tools
            }
            .region("editor.toolsRegion")
            ZStack {
                // slot: export
                // end slot: export
            }
            .region("editor.exportRegion")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("editor.root")
    }

    /// Shown on a seed start only: the clips of the project, and how many of its media files are in the media folder.
    /// A half written file under another name does not count.
    private var seedInfo: Words {
        let files = store.state.project.media.values.filter {
            FileManager.default.fileExists(atPath: store.mediaFolder.appendingPathComponent($0.fileName).path)
        }
        return Words("editor.seedInfo", [String(store.state.project.clips.count), String(files.count)])
    }
}

private extension View {
    func region(_ identifier: String) -> some View {
        frame(maxWidth: .infinity, minHeight: 44)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(identifier)
    }
}
