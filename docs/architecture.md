# Architecture

Each story writes only inside its own slot.

### m1-1-core-contracts
<!-- slot: m1-1-core-contracts -->
`Sources/ReelsmithCore` imports nothing but the standard library and Foundation, and is tested on Linux. The types in the files below are public values, Equatable and Sendable.

- `Model/Time.swift`: `Time`, a whole number of ticks, 600 a second.
- `Model/Media.swift`: `MediaID` and `MediaInfo`, the facts of one media file.
- `Model/Project.swift`: `ClipID`, `Clip` and `Project`. Clips always touch, so every place is computed from the clip lengths.
- `Model/Words.swift`: `Words`, a word key with its arguments. Core never holds a word a person reads.
- `Editor/EditorState.swift`: `EditorState`, the project with selection, playhead and playing.
- `Editor/EditorAction.swift`: `EditorAction`, everything a screen can ask for.
- `Editor/Reduce.swift`: `reduce`, state plus action gives the new state. An action that cannot be done returns the state unchanged.
- `Editor/Edits.swift`: the edit actions and `canSplit`, `canDelete`, bodies by `m1-3-edit-actions`.
- `Plan/RenderPlan.swift`: `renderPlan(for:)` turns a project into segments, each with its source range and the rectangle its upright picture fills on the 1080 by 1920 canvas.
- `Seeds/TestClip.swift`: `RGB` and `TestClip`, the values of the five test clips. No file is written here.
- `Seeds/Seed.swift`: `Seed`, the three demo projects by name.
<!-- end slot: m1-1-core-contracts -->

### m1-3-edit-actions
<!-- slot: m1-3-edit-actions -->
- `Editor/Edits.swift`: the bodies of `addClips`, `split`, `trimStart`, `trimEnd` and `deleteSelected`, which `reduce` calls, and of `canSplit` and `canDelete`. An edit that cannot be done returns the state unchanged. A trim past a limit stops at the limit. An edit that is done pauses, a media id that a clip still uses keeps its stored facts when it is added again, and a delete keeps the facts of the deleted clip's media. Every edit keeps a valid state valid: each clip inside its source, each length whole frames and at least `TimelineGeometry.minimumClip`, the playhead a whole frame inside the project, the selection a clip of the project or none.
- `Editor/TimelineGeometry.swift`: `TimelineGeometry`, the fixed scale of the timeline strip (60 points a second), the shortest clip (60 ticks), and the pure functions between a time and a point and from a drag in points to a trim amount.
<!-- end slot: m1-3-edit-actions -->

### m1-2a-engine-target
<!-- slot: m1-2a-engine-target -->
`Sources/ReelsmithEngine` is the second package target and the only one that touches AVFoundation. It is the library product `ReelsmithEngine`, which the app links, and it depends on `ReelsmithCore`. It uses frameworks that exist on iOS and macOS alike, never UIKit or SwiftUI. Every file that imports an Apple framework sits whole inside `#if canImport(AVFoundation)`, so Linux compiles nothing of it. The Engine and its tests are in Swift 5 language mode.

- `EngineError.swift`: `EngineError`, what an entry point can throw.
- `MediaProbe.swift`: `readMediaInfo`, throws `notBuilt` until `m1-6a-media-facts`.
- `Composition.swift`: `makePlayerItem`, throws `notBuilt` until `m1-5-engine`.
- `Export.swift`: `export`, throws `notBuilt` until `m1-5-engine`.
- `TestClipMaker.swift`: `writeTestClip` writes one test clip from its Core values as `<folder>/<name>.mov`: H.264 with the 709 colour properties, and for a clip with sound one mono track of uncompressed 16 bit samples. It makes the folder when missing, writes under a temporary name in that folder, renames, and keeps a file that is already there. A clip with one quarter turn gets the stored transform a 0, b 1, c minus 1, d 0, tx the stored height, ty 0. Other turns are written with no transform.

`UITests/` is the UI test target `ReelsmithUITests` of `project.yml`. The scheme `Reelsmith` has a test action that runs it.
<!-- end slot: m1-2a-engine-target -->

### m1-2b-ui-harness
<!-- slot: m1-2b-ui-harness -->
The app side. Screens live in `App/`, hold no logic and no word, and draw a Core state.

- `Sources/ReelsmithCore/Launch/LaunchOptions.swift`: `LaunchOptions`, the three launch values `-seed <name>`, `-playhead <ticks>` and `-export-fails`. It always parses what it is given. An unknown seed name, a missing value or a playhead that is no number gives nil.
- `App/ReelsmithApp.swift`: the debug guard and the root. A debug build hands the process arguments to `LaunchOptions`, a release build an empty list. The root holds an optional `EditorStore`: with a store it shows `EditorScreen`, without one the content of the slot `start` (the M0 screen until `m1-6b-new-project`). The editor is opened by setting that store.
- `App/SeedStart.swift`: `seedStart`, the start on a seed. It writes the seed's test clips with `writeTestClip` into `<caches>/Seeds/`, where a file that is already there is kept, and returns a store on the seed's project with that folder as the media folder. A playhead from `-playhead` goes through `reduce` with `movePlayhead`, so it is clamped to the project and rounded down to a frame. A clip that cannot be written does not stop the start: its file is missing from the folder.
- `App/Editor/EditorStore.swift`: `EditorStore`, the one observable object of the editor. It holds the `EditorState`, the media folder and the launch options. `send` is `state = reduce(state, action)`.
- `App/Editor/EditorScreen.swift`: `EditorScreen`, the shell. Its root has the identifier `editor.root` and holds four regions from top to bottom, `editor.previewRegion`, `editor.timelineRegion`, `editor.toolsRegion` and `editor.exportRegion`, with the slots `preview`, `timeline`, `tools` and `export`. Root and regions are accessibility containers, so a region is found while it is empty and a control inside keeps its own identifier. On a seed start the shell also shows the text `editor.seedInfo`, the clips of the project and how many of its media files are in the media folder, as in "2 clips, 2 files". A file left under a temporary name by a failed write does not count.
- `App/WordsText.swift`: `text(_:)` looks the key of a `Words` value up in `Localizable.strings` and puts its arguments in at `%1$@`, `%2$@` and so on. A fixed label is written with its key, as in `Text("tools.split")`.
- `App/Resources/<en, ar, sv>.lproj/Localizable.strings`: the words of the app in English, Arabic and Swedish, one line `"screen.thing" = "Text";` per key. Each file has one slot per story, the two lines `/* slot: <key> */` and `/* end slot: <key> */`, and a story writes the same keys into its slot in all three files. English is the development language.
- `App/Resources/<en, ar, sv>.lproj/InfoPlist.strings`: the one photo text, for adding only, under the key `NSPhotoLibraryAddUsageDescription`. `project.yml` puts the English text into the Info.plist.
<!-- end slot: m1-2b-ui-harness -->

### m1-2c-wave-run
<!-- slot: m1-2c-wave-run -->
<!-- end slot: m1-2c-wave-run -->

### m1-5-engine
<!-- slot: m1-5-engine -->
<!-- end slot: m1-5-engine -->

### m1-6a-media-facts
<!-- slot: m1-6a-media-facts -->
<!-- end slot: m1-6a-media-facts -->

### m1-8-timeline
<!-- slot: m1-8-timeline -->
<!-- end slot: m1-8-timeline -->

### m1-6b-new-project
<!-- slot: m1-6b-new-project -->
<!-- end slot: m1-6b-new-project -->

### m1-7-preview
<!-- slot: m1-7-preview -->
<!-- end slot: m1-7-preview -->

### m1-9b-trim-handles
<!-- slot: m1-9b-trim-handles -->
<!-- end slot: m1-9b-trim-handles -->

### m1-9a-split-delete
<!-- slot: m1-9a-split-delete -->
<!-- end slot: m1-9a-split-delete -->

### m1-10-export
<!-- slot: m1-10-export -->
<!-- end slot: m1-10-export -->

### m1-11-guard
<!-- slot: m1-11-guard -->
<!-- end slot: m1-11-guard -->

### m1-12-whole-path
<!-- slot: m1-12-whole-path -->
<!-- end slot: m1-12-whole-path -->
