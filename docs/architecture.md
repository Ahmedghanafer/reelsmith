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
- `Plan/RenderPlan.swift`: `renderPlan(for:)` turns a project into segments, each with its source range and the rectangle its upright picture fills on the canvas of the project.
- `Seeds/TestClip.swift`: `RGB` and `TestClip`, the values of the five test clips. No file is written here.
- `Seeds/Seed.swift`: `Seed`, the four demo projects by name.
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
- `App/ReelsmithApp.swift`: the debug guard and the root. A debug build hands the process arguments to `LaunchOptions`, a release build an empty list. The root holds an optional `EditorStore`: with a store it shows `EditorScreen`, without one the content of the slot `start`, which is `StartScreen` of `m1-6b-new-project`. The editor is opened by setting that store.
- `App/SeedStart.swift`: `seedStart`, the start on a seed. It writes the seed's test clips with `writeTestClip` into `<caches>/Seeds/`, where a file that is already there is kept, and returns a store on the seed's project with that folder as the media folder. A playhead from `-playhead` goes through `reduce` with `movePlayhead`, so it is clamped to the project and rounded down to a frame. A clip that cannot be written does not stop the start: its file is missing from the folder and the error is logged with `NSLog`.
- `App/Editor/EditorStore.swift`: `EditorStore`, the one observable object of the editor. It holds the `EditorState`, the media folder and the launch options. `send` is `state = reduce(state, action)`.
- `App/Editor/EditorScreen.swift`: `EditorScreen`, the shell. Its root has the identifier `editor.root` and holds four regions from top to bottom, `editor.previewRegion`, `editor.timelineRegion`, `editor.toolsRegion` and `editor.exportRegion`, with the slots `preview`, `timeline`, `tools` and `export`. Root and regions are accessibility containers, so a region is found while it is empty and a control inside keeps its own identifier. On a seed start the shell also shows the text `editor.seedInfo`, the clips of the project and how many of its media files are in the media folder, as in "2 clips, 2 files". A file left under a temporary name by a failed write does not count.
- `App/WordsText.swift`: `text(_:)` looks the key of a `Words` value up in `Localizable.strings` and puts its arguments in at `%1$@`, `%2$@` and so on. A fixed label is written with its key, as in `Text("tools.split")`.
- `App/Resources/<en, ar, sv>.lproj/Localizable.strings`: the words of the app in English, Arabic and Swedish, one line `"screen.thing" = "Text";` per key. Each file has one slot per story, the two lines `/* slot: <key> */` and `/* end slot: <key> */`, and a story writes the same keys into its slot in all three files. English is the development language. `project.yml` sets Swift 5 language mode for the app and the UI tests.
- `App/Resources/<en, ar, sv>.lproj/InfoPlist.strings`: the one photo text, for adding only, under the key `NSPhotoLibraryAddUsageDescription`. `project.yml` puts the English text into the Info.plist.
<!-- end slot: m1-2b-ui-harness -->

### m1-2c-wave-run
<!-- slot: m1-2c-wave-run -->
<!-- end slot: m1-2c-wave-run -->

### m1-5-engine
<!-- slot: m1-5-engine -->
The Engine turns a render plan into video. Both entry points take the plan, the facts of its media and the media folder, and find the file of a media id at `<media folder>/<fileName>`.

- `Composition.swift`: `makePlayerItem` gives the player item of a plan, on the main actor. The internal `buildComposition` in the same file is the one builder for the player item and for the export. It makes a composition with one picture track and, when a segment has sound, one sound track that ends where the last segment with sound ends. Its video composition has the size of the plan's canvas at 30 frames a second with one instruction per segment, whose transform applies the quarter turns of the segment's placement to the stored picture, scales it to the placement's size and moves it to the placement's corner. The canvas stays black around it. The video composition carries the 709 colour properties, so a high dynamic range source is converted to standard range for the preview and the export alike. It throws `sourceMissing` with the media id when the plan names media with no facts or a file that is not in the media folder, and `cannotRead` when a file has no picture track or cannot be put into the composition.
- `Export.swift`: `export` writes the plan as an MPEG-4 file with H.264 and AAC through an export session with the highest quality preset. It writes under a temporary name in the folder of the output place and renames when the file is whole, which replaces a file that was there. `progress` gets 0 before the export starts, the session's own value about ten times a second while it only rises, and 1 after the rename. It may be called from any thread. An empty plan throws `nothingToExport`. A folder of the output place that is missing or cannot be written throws `cannotWrite` before any work, and so does an export session that fails or a rename that fails. A failed export leaves no file of its own behind.
<!-- end slot: m1-5-engine -->

### m1-6a-media-facts
<!-- slot: m1-6a-media-facts -->
Reading a picked video and the state of the start screen.

- `Sources/ReelsmithEngine/MediaProbe.swift`: `readMediaInfo` reads the facts of the file `<media folder>/<fileName>` and returns them under the id and the file name it was given: the width and height of the picture as stored, the length of the picture track rounded down to a tick, the quarter turns, and whether the file has a sound track. The internal `quarterTurns(of:)` in the same file maps the stored transform of the picture track to the turns: b 1 is one turn, a minus 1 two turns, b minus 1 three turns, anything else none. The internal `wholeTicks(of:)` beside it rounds the length of the track down to a tick. It throws `sourceMissing` with the id when the file is not in the folder, and `cannotRead` when the file cannot be opened as a video or has no picture track.
- `Sources/ReelsmithCore/Start/StartState.swift`: `StartState`, the one value the start screen draws, with the cases `idle`, `copying`, `failed` and `ready(Project)`. `words` gives the word key of a case: `start.copying` while copying, `start.noneReadable` when failed, none for the other two. `allWords` lists those two keys. `after(_:)` is the one function that moves between the cases, on a `StartState.Event`: `pickerClosed(chosen:)` with the count of chosen videos (none leaves `idle`, one or more give `copying`), `copyingEnded` with the facts that could be read (they are added to an empty project with `addClips`: a project with a clip gives `ready` with that project, an empty one gives `failed`), and `failureConfirmed` (from `failed` back to `idle`). An event that has no meaning in a case leaves it unchanged. A video that could not be copied or read is simply not among the facts. The text of the two keys is written into the word files by `m1-6b-new-project`.
<!-- end slot: m1-6a-media-facts -->

### m1-8-timeline
<!-- slot: m1-8-timeline -->
The timeline strip, in the new folder `App/Editor/Timeline/`. It decides nothing: places and times come from `TimelineGeometry`, starts and positions from `Project`, and every change goes out as an `EditorAction`.

`App/Editor/Timeline/TimelineView.swift` holds two types of one screen. Neither is named `TimelineView`, because SwiftUI has a type of that name.

- `TimelineStrip` is the SwiftUI side, a `UIViewRepresentable` with `state: EditorState` and `send: @MainActor (EditorAction) -> Void`. The slot `timeline` of `EditorScreen` builds it from `store.state` and `store.send` and gives it a fixed height of 72 points, because a wrapped UIKit view takes all the height it is offered.
- `TimelineStripView` is the UIKit view. `var state: EditorState` is the state it draws, and setting it draws it. `var send` is the way to send an action. `let strip: UIView` holds the blocks and moves under the playhead: its left edge is time zero, so a point of it at x is the time `TimelineGeometry.time(atX: x)`, it starts 8 points below the top of the view and ends 8 above the bottom. Everything is drawn in `layoutSubviews()`: the blocks are made or removed to match the clips, `strip` is put with its left edge at the middle minus `TimelineGeometry.x(of: state.playhead)`, each block at `x(of: project.start(of:))` with `width(of: clip.duration)`, and the playhead line in the middle of the view above `strip`.
- A block is one `UILabel` in `strip` with the text "<position>\n<length as clockText>", the identifier `editor.clip.<position>` and the trait selected when its clip is the selection, which also gives it a wider outline. The playhead line has the identifier `editor.playhead` and the playhead's `clockText` as its value. Neither holds a word.
- A drag with one finger anywhere on the view is a scrub: `pause` once when it starts, then `movePlayhead` with `TimelineGeometry.time(atX:)` of the playhead's x at the start minus the distance dragged to the right. Core clamps it. A tap inside `strip` sends `select` with the clip that `Project.clip(at:)` gives for the time under the finger.
- The view never mirrors: every frame is set by hand from the left, and the view, `strip` and the blocks force left to right.

The slot `handles` is the two lines `// slot: handles` and `// end slot: handles` at the end of `layoutSubviews()` of `TimelineStripView`, after the blocks and the playhead have their frames. Code there runs inside the view on every draw, so it can read `state`, `send`, `strip`, `playhead` and `bounds`, and it cannot add a stored property. A view above the clips is added there when it is not there yet, and gets its frame there.

- A view that stays inside the bounds of `strip` is added to `strip`, in its coordinates. A new block is added above what `strip` already holds, so such a view is brought to the front there too.
- A view that can lie outside `strip` is added to the strip view itself, below `playhead` (`insertSubview(_:belowSubview:)`), at `strip.frame.minX` plus its x and `strip.frame.minY` plus its y. A trim handle is such a view: the start handle of the first clip and the end handle of the last clip are drawn outside the edges of `strip`, and UIKit never hands a touch outside a view's bounds to its subviews, so a handle inside `strip` would be drawn there and could not be dragged.
- The two recognizers of the strip view see the touches on a view above the clips too. A tap there also reaches the tap recognizer, which selects the clip at the finger's x when the point is inside `strip`, unless that view has a tap recognizer of its own. A drag there can also start the scrub, so a view that is dragged has a pan recognizer of its own.
- To draw a state without sending it, as a trim drag does, set `state`. That preview is written over as soon as the store's state changes, because SwiftUI then hands the view the store's state again. So a drag that previews first sends `pause`, so that playback no longer moves the playhead under it, and then sets `state` on every step of the drag: a preview set in the same step as the `pause` can be written over once.
<!-- end slot: m1-8-timeline -->

### m1-6b-new-project
<!-- slot: m1-6b-new-project -->
The start screen, in the new folder `App/Start/`. It is the content of the slot `start` of `App/ReelsmithApp.swift`, shown while the root holds no store. The M0 screen (`App/FirstScreen.swift`) and `Sources/ReelsmithCore/FirstOpened.swift` are gone.

- `App/Start/StartScreen.swift`: `StartScreen`, built with the launch options and `open: @MainActor (EditorStore) -> Void`, which the root uses to set its store. It draws a `StartState` that only `StartState.after(_:)` moves: the title `start.title`, one button per case of `Canvas.allCases` in their order with the words of `Canvas.words` and the identifiers `start.landscape` and `start.portrait`, the button `start.newProject`, enabled in `idle` only, the words of `StartState.words` when there are any, and in `failed` the button `start.ok`, which sends `failureConfirmed`. Its one own state is the chosen shape, `Canvas.startChoice` at first. The chosen shape carries the accessibility trait selected. The file writes the type as `ReelsmithCore.Canvas`, because SwiftUI has a view named `Canvas`.
- When the picker reports its close the screen sends `pickerClosed(chosen:)` with the count. Only when that gives `copying` it starts the copy, and when the copy returns it sends `copyingEnded` with the facts. The copy throws nothing and nothing cancels it, so that event is always sent. On `ready` it sets `canvas` of that project to the chosen shape and calls `open` with an `EditorStore` on it, with `<documents>/Media/` as the media folder. It sends no `addClips`: the project of `ready` holds the clips. A picker that is swiped away reports nothing, and the screen stays in `idle`.
- `App/Start/VideoPicker.swift`: `VideoPicker`, the system photo picker (`PHPickerViewController`) wrapped for SwiftUI and shown as a sheet. Videos only, no limit to the number, the order of choosing kept. It is made with no photo library, so it runs outside the app, no permission is asked, and the app declares no text for reading the library. `closed` gets one `NSItemProvider` per chosen video, none after a cancel.
- `App/Start/PickedVideos.swift`: `pickedMediaFolder` is `<documents>/Media/`, a constant at file level whose initialiser removes the folder with everything in it. Swift runs that initialiser once for a process, at the first read, and the start screen reads it when it appears, which is at every start of the app, a seeded one too. A start screen that appears a second time in the same process removes nothing. `<caches>/Seeds/` is never touched. `copyPicked(_:)` copies each video to `<documents>/Media/<uuid>.<the picked file's extension>` inside the completion handler of the provider, because the picker's file is gone when the handler returns, then reads its facts with `readMediaInfo` under the uuid as the media id. A video that cannot be copied or read is left out, and its copy stays in the folder until the next start.
- The words: the keys `start.title`, `start.newProject`, `start.landscape`, `start.portrait`, `start.copying`, `start.noneReadable` and `start.ok` in the slot `m1-6b-new-project` of the three word files. The numbers 16:9 and 9:16 are written with the digits 0 to 9 in every language.
<!-- end slot: m1-6b-new-project -->

### m1-7-preview
<!-- slot: m1-7-preview -->
The preview, in the new folder `App/Editor/Preview/`. It decides nothing and the slot `preview` of `EditorScreen` builds it as `PreviewPane(store: store)`.

- `App/Editor/Preview/PreviewPane.swift`: `PreviewPane`, the SwiftUI side. On top the picture area in the shape of `store.state.project.canvas`, its `width` to its `height`, as large as fits whole in the space above the button and in its middle. Under it one row: the button `editor.play`, which shows the pause symbol while `isPlaying` and the play symbol otherwise, is enabled by `canPlay`, sends `pause` or `play` and reads the key `preview.pause` or `preview.play`, and the label `editor.time` with `timeLabel`. The whole pane is fixed left to right, so nothing of it mirrors in Arabic.
- `App/Editor/Preview/PlayerPicture.swift` holds two types of one screen. `PlayerPicture` is a `UIViewRepresentable` that hands every state to the view. `PlayerPictureView` is a black UIKit view with the identifier `editor.picture` whose layer is the player's layer. It is made once with its player and takes the store, because it reads the state of the moment when the player calls it.
- The item: when `state.project` differs from the project of the last build, `renderPlan(for:)` and `makePlayerItem` build a new item from the store's media folder. Builds are counted and the result of a build that a newer one superseded is dropped. The new item is put into the player together with a seek to the playhead of that moment, so it gets ready on that frame. That first seek has no completion handler, so nothing says when it lands and the player does not count as standing on that playhead. Until the status of the item is ready to play, the player follows nothing. Then the view seeks to the playhead of the state of that moment with a completion handler, and the player counts as standing there only when that seek has finished: it then rests when the state is not playing, and starts when it is. An empty project (`canPlay` false) gets no item and no call of `makePlayerItem`, and the view lets go of the item of the last build. A build that throws leaves the player with no item, which is the black area.
- Following the state: while it is not playing, a playhead other than the one the player was last sent to makes it seek, exact to the frame. One seek is in flight at a time: a playhead that comes meanwhile is held, and when the seek in flight has landed the player is sent to the newest one if it differs. A seek that ends unfinished with no newer playhead waiting is forgotten, so the next state seeks again. When `isPlaying` turns true the player plays and starts to report as soon as it stands on the playhead: at once when a seek with a completion handler has landed there before and no seek is in flight, otherwise when the seek to it has landed. So a start never begins while the first seek of an item is on its way, and no report comes from before it. While it is playing a change of the playhead never makes it seek, so its own reports do not. When `isPlaying` turns false it pauses, stops to report and seeks to the playhead.
- The layer asks for IOSurface buffers (`pixelBufferAttributes`). Without that request the simulator's layer refuses every frame of a clip that fills the canvas unscaled and shows black, while a clip the composition scales is shown. The request names a kind of buffer. What it costs on a device is not measured.
- Reporting: a time observer calls 30 times a second and sends `movePlayhead` with the player's time in ticks. It is removed the moment the view stops the player, and each call first reads `store.state.isPlaying`, so nothing is sent after a `pause`, also when the view has not been handed the paused state yet. When the item has played to its end the view sends `movePlayhead` with the project length and then `pause`, and it does not seek there: the player stands on its last frame.
- Sound plays through the player as it is. The platform's time type is used in this one file, for the player's seek and its reports.
<!-- end slot: m1-7-preview -->

### m1-9b-trim-handles
<!-- slot: m1-9b-trim-handles -->
The trim handles, in `App/Editor/Timeline/TrimHandles.swift`. They decide nothing: how far a clip can be trimmed is `reduce`, and the amount for a drag is `TimelineGeometry.trimAmount(forDragOf:)`.

- `TrimHandle` is one handle, a UIKit view 24 points wide and as high as `strip`. The slot `handles` of `TimelineStripView` calls `TrimHandle.layout(in:below:)` with the strip view and its playhead line on every layout. The first call makes the two handles and adds them to the strip view below the playhead line. Later calls find them among the subviews of the strip view, so nothing piles up.
- With a selected clip the start handle is put with its right edge on the left edge of the clip and the end handle with its left edge on the right edge of the clip, at `strip.frame.minX` plus `TimelineGeometry.x(of:)` of the clip's start. With no selection both are hidden. They never mirror: the frames are set from the left and the handles force left to right.
- The identifiers are `editor.trim.start` and `editor.trim.end`, and the accessibility labels are the keys `trim.start` and `trim.end`.
- A handle has a pan and a tap recognizer of its own and is their delegate: the scrub and the tap of the strip view wait for them to fail, so a drag on a handle is no scrub and a tap on it selects nothing.
- A drag sends `pause` when it starts and keeps the paused state of that moment. While the finger moves it sets `state` of the strip view to `reduce` of the kept state with `trimStart` by the points moved to the right, or `trimEnd` by the points moved to the left, and sends nothing. On release it sends that one action. A cancelled drag sets `state` back to the kept state and sends nothing.
<!-- end slot: m1-9b-trim-handles -->

### m1-9a-split-delete
<!-- slot: m1-9a-split-delete -->
The edit buttons, in the new folder `App/Editor/Tools/`.

- `App/Editor/Tools/ToolsRow.swift`: `ToolsRow`, a SwiftUI row with `state: EditorState` and `send: @MainActor (EditorAction) -> Void`. The slot `tools` of `EditorScreen` builds it from `store.state` and `store.send`. It holds two buttons from leading to trailing, so Arabic mirrors the row: `editor.split` with the key `tools.split`, enabled when `canSplit` is true, sends `split`, and `editor.delete` with the key `tools.delete`, enabled when `canDelete` is true, sends `deleteSelected`. It decides nothing and asks no question.
<!-- end slot: m1-9a-split-delete -->

### m1-10-export
<!-- slot: m1-10-export -->
The export, in `Sources/ReelsmithCore/Export/` and the new folder `App/Editor/Export/`.

- `Sources/ReelsmithCore/Export/ExportState.swift`: `ExportState`, the one value the export button and its panel draw, with the cases `idle`, `exporting(percent:)`, `saved` and `failed(notAllowed:)`. `words` is nil for `idle`, then `Words("export.exporting")`, `Words("export.saved")`, and `Words("export.failed")` or `Words("export.notAllowed")`. `percentText` is the percent while exporting, such as "42%", written with the digits 0 to 9, and nil in every other case. `allWords` lists those four keys. `canStart(_:)` takes the `EditorState` and is true exactly when `canExport` is true and the case is `idle`. `after(_:)` moves between the cases on an `ExportState.Event` (`started`, `progress`, `saved`, `failed(notAllowed:)`, `closed`). A progress value is held between 0 and 1 and never lowers the percent, and an event with no meaning in a case leaves it unchanged, so a progress value that arrives after the end changes nothing.
- `App/Editor/Export/ExportButton.swift`: `ExportButton`, the content of the slot `export` of `EditorScreen`. One button with the identifier `editor.export` and the key `export.button`, enabled when `canStart` is true. It keeps the `ExportState` as its own state, since the store has no place for it. A tap sends `pause`, sends `started`, and runs `exportToPhotos` in a task with the project of that moment, the store's media folder and `options.exportFails`. The Engine reports progress off the main actor, so each value hops to the main actor before it is sent as `progress`. While the state is not `idle` a full screen cover with `ExportPanel` lies over the editor, so nothing behind it answers a touch.
- `App/Editor/Export/ExportPanel.swift`: `ExportPanel` draws the state: its words (`export.words`), the percent (`export.percent`, fixed left to right), the button `export.done` with the key `export.done` on `saved`, and the button `export.close` with the key `export.close` on `failed`. Both buttons send `closed`, which gives `idle` and takes the panel away. The editor state is not touched. While exporting there is no button, so there is no cancel.
- `App/Editor/Export/ExportToPhotos.swift`: `exportToPhotos(project:mediaFolder:fails:progress:)` makes the plan with `renderPlan(for:)`, calls `export(plan:media:mediaFolder:to:progress:)` with the media of the project and the output place `<temporary folder>/<uuid>.mp4`, asks the photo library for the right to add only (`PHPhotoLibrary.requestAuthorization(for: .addOnly)`), and adds the file as a video (`PHAssetCreationRequest`). It returns the event that ends the export: `saved`, `failed(notAllowed: true)` when the right to add is not given, and `failed(notAllowed: false)` for every error of the plan, of the Engine and of the save. The file is removed after the save and after a failure. With `-export-fails` the output place is `<temporary folder>/<uuid>/export.mp4` in a folder that is not there, so the Engine throws `cannotWrite` before any work and reports no progress.
- The words: the keys `export.button`, `export.exporting`, `export.saved`, `export.done`, `export.failed`, `export.notAllowed` and `export.close` in the slot `m1-10-export` of the three word files.
<!-- end slot: m1-10-export -->

### m1-11-guard
<!-- slot: m1-11-guard -->
<!-- end slot: m1-11-guard -->

### m1-12-whole-path
<!-- slot: m1-12-whole-path -->
<!-- end slot: m1-12-whole-path -->

### m1-13-canvas
<!-- slot: m1-13-canvas -->
A project has one of two shapes, and the plan and the Engine follow it.

- `Sources/ReelsmithCore/Model/Canvas.swift`: `Canvas`, an enum with the two cases `landscape` (16:9, 1920 by 1080 pixels) and `portrait` (9:16, 1080 by 1920 pixels), in that order in `allCases`. `width` and `height` are its pixels. `words` gives the word key of a case, `start.landscape` or `start.portrait`, and `allWords` lists the two. `startChoice` is `landscape`, the shape the start screen has chosen before she taps. The text of the two keys is written into the word files by `m1-6b-new-project`.
- The canvas on the project: `Project.canvas`. `Project()` is `portrait` and `Project(canvas:)` takes the other one. `Project` has no size of its own any more, only `framesPerSecond`. An edit never changes the canvas.
- The canvas in the plan: `renderPlan(for:)` fits each upright picture whole inside `canvas.width` by `canvas.height` of the project, centred, and the side that limits the fit takes the canvas value itself. It copies the canvas into `RenderPlan.canvas`, for an empty project too. A plan built with no canvas is `portrait`. The numbers of a `Placement` are pixels of the canvas the plan carries.
- `Seeds/Seed.swift`: the seed `two-clips-wide` (`Seed.twoClipsWide`) is blue then red, 4200 ticks, on the landscape canvas, where blue fills the canvas and red stands in the middle at x 656.25, y 0, 607.5 by 1080. `Seed.canvas` is `landscape` for it and `portrait` for the other three.
- The Engine: `buildComposition` sets the render size from `plan.canvas`, and nothing else in the Engine names a size. So `makePlayerItem` and `export` keep their signatures, and the exported file is 1920 by 1080 or 1080 by 1920.

The tests are `Tests/ReelsmithCoreTests/CanvasTests.swift` and `Tests/ReelsmithEngineTests/CanvasEngineTests.swift`, described in the slot `m1-13-canvas` of `docs/testing.md`.
<!-- end slot: m1-13-canvas -->
