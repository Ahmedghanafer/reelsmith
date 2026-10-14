import ReelsmithCore
import ReelsmithEngine
import SwiftUI

/// The editor shell: four regions from top to bottom, each with the slot of the story that fills it,
/// and between the tools and the export the text region, only while a text is selected, or the sound
/// region, only while the sound panel shows. Core keeps the two from showing together.
/// The root and the regions are accessibility containers, so a region is found while it is empty
/// and a control inside it keeps its own identifier.
///
/// https://developer.apple.com/documentation/swiftui/view/accessibilityelement(children:)
/// https://developer.apple.com/documentation/swiftui/view/accessibilityidentifier(_:)
struct EditorScreen: View {
    let store: EditorStore
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            if store.options.showsInfo {
                Text(text(seedInfo))
                    .font(.footnote)
                    .accessibilityIdentifier("editor.seedInfo")
                Text(verbatim: store.state.textInfo)
                    .font(.footnote)
                    .accessibilityIdentifier("editor.textInfo")
                Text(verbatim: faceName(of: .naskh) + " " + faceName(of: .naskhBold))
                    .font(.footnote)
                    .accessibilityIdentifier("editor.faceInfo")
                Text(verbatim: store.state.soundInfo)
                    .font(.footnote)
                    .accessibilityIdentifier("editor.soundInfo")
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
                    .frame(height: 104)
                // end slot: timeline
            }
            .region("editor.timelineRegion")
            ZStack {
                // slot: tools
                ToolsRow(state: store.state, send: { action in store.send(action) })
                // end slot: tools
            }
            .region("editor.toolsRegion")
            if let selected: TextID = store.state.selectedText {
                // A panel is made anew for every text that gets selected, so it starts on the part of that text.
                TextPanel(store: store)
                    .id(selected)
                    .region("editor.textRegion")
            }
            if store.state.showsSound {
                // Made anew every time the panel shows, so it starts on the part music.
                SoundPanel(store: store)
                    .region("editor.soundRegion")
            }
            ZStack {
                // slot: export
                ExportButton(store: store)
                // end slot: export
            }
            .region("editor.exportRegion")
        }
        // Takes the animation out of every transaction that comes down to the editor, so the text region
        // does not slide in or out.
        // https://developer.apple.com/documentation/swiftui/view/transaction(_:)
        .transaction { $0.animation = nil }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("editor.root")
        // The draft is written when the app leaves the active phase, a run that is still open included.
        // https://developer.apple.com/documentation/swiftui/environmentvalues/scenephase
        // https://developer.apple.com/documentation/swiftui/view/onchange(of:initial:_:)-4psgg
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                store.writeNow()
            }
        }
    }

    /// Shown on a seed start and on a launch with -drafts only: the clips of the project, and how many of its media files are in the media folder,
    /// the file of its music among them. A half written file under another name does not count.
    private var seedInfo: Words {
        let project: Project = store.state.project
        var names: [String] = project.media.values.map { $0.fileName }
        if let music: Music = project.music {
            names.append(music.file.fileName)
        }
        let files = names.filter {
            FileManager.default.fileExists(atPath: store.mediaFolder.appendingPathComponent($0).path)
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
