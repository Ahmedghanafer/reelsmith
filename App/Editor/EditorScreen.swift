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
                // end slot: preview
            }
            .frame(maxHeight: .infinity)
            .region("editor.previewRegion")
            ZStack {
                // slot: timeline
                // end slot: timeline
            }
            .region("editor.timelineRegion")
            ZStack {
                // slot: tools
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

    /// Shown on a seed start only: the clips of the project and the files the seed start left in the media folder.
    private var seedInfo: Words {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: store.mediaFolder.path)) ?? []
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
