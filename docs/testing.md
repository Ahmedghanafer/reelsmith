# Testing

Each story writes only inside its own slot.

### m1-1-core-contracts
<!-- slot: m1-1-core-contracts -->
<!-- end slot: m1-1-core-contracts -->

### m1-3-edit-actions
<!-- slot: m1-3-edit-actions -->
<!-- end slot: m1-3-edit-actions -->

### m1-2a-engine-target
<!-- slot: m1-2a-engine-target -->
Engine tests live in `Tests/ReelsmithEngineTests` and run with `swift test` on macOS only, first in the compile check. On Linux the target compiles to nothing. A test makes its clips with `writeTestClip` in a folder of its own under the temporary folder. No media file is committed.

- `TestClipMakerTests.swift` holds the five test clips to the table: stored size, H.264, the exact frame count, the exact length of the picture track, the two colours at half the length, the sound track of blue and red with its peak, the 709 colour properties, the stored transform of `turned.mov` and the identity transform of the other four, the write under a temporary name and the kept file.
- When `REELSMITH_CLIP_DIR` is set, `testLeavesBlueAndRedInTheClipFolder` leaves `blue.mov` and `red.mov` in that folder. When it is not set the test is skipped.

The helpers in `Support/MediaReading.swift` read a file back. Each takes the file's URL:

- `pixel(of:at:x:y:)`: the colour of one pixel of the stored picture as an `RGB`, x from the left and y from the top, in the frame shown at a Core `Time`. The turn of the file is not applied.
- `frameCount(of:)`: the number of picture frames, counted without decoding.
- `soundPeak(of:)`: the peak of the first sound track, from 0 to 1 of full scale.
- `storedSize(of:)`: width and height of the picture as stored.
- `tracks(of:)`: one `TrackFacts` per track with `kind` ("vide" or "soun"), `coding` ("avc1" for H.264, "lpcm" for uncompressed sound, and an AAC track reads back as "aac " with a trailing space), `duration`, and for sound `sampleRate`, `channels` and `bitsPerSample`.
- `fileType(of:)`: the major brand the file starts with, "qt  " for a QuickTime movie.
- `colourProperties(of:)`: the primaries, transfer function and matrix the picture track reports, by the platform's names.
- `storedTransform(of:)`: the six numbers a, b, c, d, tx, ty of the picture track.

`UITests/HarnessTests.swift` holds one empty test, so the build for testing has a target. It is built by the compile check and not run there.
<!-- end slot: m1-2a-engine-target -->

### m1-2b-ui-harness
<!-- slot: m1-2b-ui-harness -->
On Linux:

- `LaunchOptionsTests.swift` holds the three launch values: each one read, all three among other arguments, an empty list, an unknown seed name, a missing value, and that no other argument changes anything.
- `WordFilesTests.swift` reads `App/Resources/<en, ar, sv>.lproj/Localizable.strings` from the repository and fails when their key sets differ, when a text is empty, when the placeholders of a key differ between languages, when a key appears twice, or when a file holds anything but comments and lines of a key. It shows each of the first four on word files it writes into a temporary folder. A story that adds a key needs no test of its own for the three files.
- The same file gives every Linux test the function `wordKeys(of language: String) throws -> [String]`, the keys of the repository's word file of `"en"`, `"ar"` or `"sv"`. A story whose Core state gives words holds its keys with it and writes no second reader, as in `XCTAssertTrue(try wordKeys(of: "en").contains(key))` for every key of its `allWords`.

UI tests live in `UITests/`, are built by the compile check and run only in a wave run. The helpers in `UITests/Support/Harness.swift` are methods of `XCTestCase`, in an extension marked `@MainActor`. A test class that uses them is marked `@MainActor` too, as in `@MainActor final class TimelineTests: XCTestCase`:

- `func startApp(seed: String?, language: String = "en", playhead: Int? = nil, exportFails: Bool = false) -> XCUIApplication` starts the app and returns it right after the launch, without waiting for any screen. `seed` is the name of a seed such as `"two-clips"`, or nil for a start with no seed. `language` is `"en"`, `"ar"` or `"sv"` and is passed as `-AppleLanguages (<code>)` and `-AppleLocale <code>`. `playhead` is in ticks, 600 a second.
- `func screenshot(_ name: String)` keeps a picture of the screen under the given name, also when the test passes. The name is `<story key>-<two digits>-<what>`.
- `func mark(_ name: String)` marks the start of a stretch of the recording: a text attachment `<name>.mark.txt` with the clock second of the call, whole seconds since 1970.

A control is found by its identifier, whatever kind of element it is: `app.descendants(matching: .any)["editor.root"]`.

After a seeded start the editor is not there at once. The first seeded start in a fresh simulator writes the seed's clips before the editor opens, and every later start finds them. So every test waits for the root with a long limit before it touches anything, and `HarnessTests` uses 60 seconds: `XCTAssertTrue(app.descendants(matching: .any)["editor.root"].waitForExistence(timeout: 60))`. Until the store is set the content of the slot `start` is on screen. A clip that could not be written is logged by the app with `NSLog` as a line that starts with "seed start:".

`UITests/HarnessTests.swift` starts on `two-clips` and finds `editor.root` and the four regions from top to bottom while they are empty, reads `editor.seedInfo` (it starts with "2 clips, " and names 2 files or more, the media files of the project found in the media folder, which shows the seed start wrote clips inside the simulator), starts with no seed and with an unknown seed name (text is shown, no `editor.root`, no `editor.seedInfo`), and starts once in Swedish with a playhead and the export failure, where `editor.seedInfo` starts with "2 klipp, ", and once in Arabic, where it holds the Arabic line with both numbers. Nothing on the shell shows the playhead or the export failure yet. Screenshots: `m1-2b-ui-harness-01-shell`, `m1-2b-ui-harness-01-shell-ar`, `m1-2b-ui-harness-02-shell-sv`, `m1-2b-ui-harness-02-no-seed`. Mark: `m1-2b-ui-harness-01-launch`.
<!-- end slot: m1-2b-ui-harness -->

### m1-2c-wave-run
<!-- slot: m1-2c-wave-run -->
The UI tests in `UITests/` run only in the wave run (the `macOS build` workflow, see `docs/operations.md`), in one simulator that the run records from before the first test to after the last. The package tests run there too, on macOS, as in the compile check.

- A screenshot kept with the helper `screenshot(_:)` comes back in the artifact `screens` as `<name>.png`.
- A mark set with the helper `mark(_:)` comes back as `<name>.mark.txt` in `screens` and as one line of `recording-index.txt` in the artifact `recording`: the name, a space, and the seconds into `recording.mp4`.
- A failed UI test makes the run red and still brings back the pictures, the recording and the result bundle.
- Before the UI tests the run puts `blue.mov` and `red.mov` into the simulator's photo library and grants the app the right to add to Photos, so no test meets the system's question.
<!-- end slot: m1-2c-wave-run -->

### m1-5-engine
<!-- slot: m1-5-engine -->
Both files run with `swift test` on macOS, on clips from `writeTestClip`. Sizes, frame counts and lengths are exact, a colour matches within 24 of 255 per channel.

- `ExportTests.swift` exports the plan of `three-clips` once for the tests that read it, over an old file at an output place whose name does not end in mp4. The file type is read from that file itself. The other helpers read a copy named `.mp4`, because the platform picks its file reader by the end of the name and cannot open the same bytes under another one. They hold the file type, the one H.264 picture track of 1080 by 1920 with 270 frames in 9 seconds, the one AAC sound track that ends at 7.0 seconds with its peak, the middle colours at 1.0, 5.0 and 8.0 seconds with the black bars around blue, the 709 colour properties with an 8 bit H.264 profile, and the progress values. The time of that export is printed and fails only above 120 seconds. Further tests export a plan built by hand with a trimmed start (180 frames, the colours 2 frames either side of each join, the sound up to 4.0 seconds), `turned` alone (white above blue) and `fast` alone (60 frames in 2 seconds), and hold the three errors with nothing left at the output place. Red and green are also read near the top and the bottom of the canvas. A plan built by hand puts `turned.mov` with no turn as a wide strip (white left, blue right) and red at half size in the middle, and reads points just inside and just outside each rectangle, which holds the scale, the move and that nothing is mirrored. A silent clip between two with sound keeps its stretch silent and the later sound at its own start.
- `CompositionTests.swift` holds the player item of `three-clips`: 9 seconds long, and the frames at 1.0, 5.0 and 8.0 seconds drawn through its video composition are 1080 by 1920 with a blue, red and green middle. Its video composition carries the 709 primaries, transfer function and matrix. For the plan with a trimmed start (`ExportTests.trimmedPlan`) it reads the segments of the composition's picture and sound tracks: source start, target start and length of each in exact ticks.
<!-- end slot: m1-5-engine -->

### m1-6a-media-facts
<!-- slot: m1-6a-media-facts -->
- `Tests/ReelsmithEngineTests/MediaProbeTests.swift` runs with `swift test` on macOS. It writes each of the five test clips with `writeTestClip` and holds that `readMediaInfo` returns exactly the clip's `info`, with the numbers of `turned.mov` (1920 by 1080, one quarter turn, 1200 ticks, no sound) and of `blue.mov` under another id written out. It holds the mapping of the four stored transforms of 0, 1, 2 and 3 quarter turns on the six numbers alone, because no test clip is stored with two or three turns, and the rounding of a length down to a tick on numbers (2999 over 3000 of a second gives 599 ticks), because every test clip is a whole number of ticks long. For those two internal functions the file imports the Engine with `@testable`. A text file named `note.mov` throws `cannotRead`, and a file name that is not in the folder throws `sourceMissing` with the id.
- `Tests/ReelsmithCoreTests/StartStateTests.swift` runs on Linux. It holds the word key of each case of `StartState`, the two keys of `allWords`, the project that `ready` carries, and every move of `after(_:)`: nothing chosen, one or more chosen, facts that give a project, one of two videos read, no facts, facts too short to give a clip, the confirmed failure, and the nine pairs of a case and an event with no meaning in it, which leave the case unchanged. That every key of `allWords` is in the English word file is held by `m1-6b-new-project`, which writes those lines.
<!-- end slot: m1-6a-media-facts -->

### m1-8-timeline
<!-- slot: m1-8-timeline -->
`UITests/TimelineTests.swift` holds the timeline strip on the seed `three-clips` (blue 3 seconds, red 4, green 2). It is built by the compile check and first runs in a wave run. Every test waits 60 seconds for `editor.root` after a start. The strip has no Linux test of its own: its positions and times are `TimelineGeometry`, held by `TimelineGeometryTests.swift`.

- The blocks, started at 2700 ticks so a part of every block is on the screen: `editor.clip.1`, `editor.clip.2` and `editor.clip.3` are in one row inside `editor.timelineRegion`, in track order from left to right, touching, 180, 240 and 120 points wide. The label of a block is the text on it, the position and then the length, so it starts with "1" and ends with "00:03". After a pinch the widths are the same.
- The playhead: `editor.playhead` is in the middle of the region's width and its value is the playhead's `clockText`. With no playhead value it reads "00:00" with the left edge of the first block under it, with `-playhead 3000` it reads "00:05" with the red block under it.
- The scrub: a drag is a press on a point of `editor.timelineRegion` and a move sideways, and only the value of `editor.playhead` is read after it. To the right at the start leaves "00:00", 120 points to the left gives "00:01", "00:02" or "00:03", back to the right gives less, and three long drags to the left stop at "00:09". That `pause` is sent before `movePlayhead` cannot be seen on this screen and is read in the diff.
- The tap, started at 2400 ticks: a tap in the middle of the red block makes `editor.clip.2` read as selected (`isSelected`) and the other two not, a tap on the blue block moves that to `editor.clip.1`, and the playhead still reads "00:04". No block is selected before the first tap.
- The seed `empty`: `editor.playhead` is there, `editor.clip.1` is not, and a drag leaves "00:00".
- Arabic, started at 2700 ticks: the same checks of the blocks as in English, so the order from left to right and the digits 0 to 9 hold, and a drag to the left gives a later time.

Screenshots: `m1-8-timeline-01-strip`, `m1-8-timeline-01-strip-ar`, `m1-8-timeline-02-placed`, `m1-8-timeline-03-selected`, `m1-8-timeline-04-empty`. Marks: `m1-8-timeline-01-scrub`, `m1-8-timeline-02-scrub-ar`. The strip is 540 points long and the screen is narrower, so no picture shows all three blocks whole.

For a later test of the strip: a block is one element, and its frame is expected to be the whole block, also where it is off the screen. That is confirmed by the first full simulator run, and the checks of the frames and the taps rest on it. A tap needs a point on the screen, so a test that taps a block first starts with a `-playhead` that puts the tapped point on the screen. `TimelineTests` starts at 2400 ticks, where the middles of the first two blocks are on the screen, and taps with `block.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()`. The view in `App/Editor/Timeline/TimelineView.swift` and its slot `handles` are described in the slot `m1-8-timeline` of `docs/architecture.md`.
<!-- end slot: m1-8-timeline -->

### m1-6b-new-project
<!-- slot: m1-6b-new-project -->
- `Tests/ReelsmithCoreTests/StartWordsTests.swift` runs on Linux, with `wordKeys(of:)`. It fails when one of the seven keys of the start screen is missing from the English, the Arabic or the Swedish word file, and when a key of `StartState.allWords` or of `Canvas.allWords` is missing from the English file. `FirstOpenedTests.swift` is gone with the code it tested.
- `UITests/StartTests.swift` is built by the compile check and first runs in a wave run. Four tests start with no seed, and the relaunch test starts on `two-clips` first. Each waits 30 seconds for `start.newProject` after a start with no seed. Which shape is chosen is read as `isSelected` of `start.landscape` and `start.portrait`, never from a word.
  - The start screen in English: the title, the two shapes with `start.landscape` selected and on the left, the button enabled, no `editor.root`, and the four English texts as labels.
  - In Arabic: the Arabic label of `start.newProject`, `start.landscape` on the right of `start.portrait`, and labels that still hold "16:9" and "9:16".
  - A tap on `start.portrait` selects it and not `start.landscape`, and a tap on `start.landscape` moves the choice back. The first tap lands near the leading edge of the shape, inside the padding around its words, so a border that takes no tap fails the test. Then the app is ended with `start.portrait` selected, and the next start with no seed reads `start.landscape` as selected and `start.portrait` not, which a product that remembered the choice would fail.
  - The relaunch: a start on `two-clips` until `editor.root` is there, the app ended, then a start with no seed shows the start screen with `start.landscape` selected and no `editor.root`. That only `<documents>/Media/` is emptied is read in the diff, since no screen shows a folder.
  - The one try at the system picker, `testOneTryAtTheSystemPicker`. It cannot fail the run: the whole test stands under `XCTExpectFailure` with `isStrict` off, and it asserts nothing. It taps `start.newProject`, waits 40 seconds for the cells of the picker's grid (the images with the system's identifier `PXGGridLayout-Info` inside a scroll view, which leaves out the picture at the head of the picker), taps the first two, keeps a screenshot, taps the enabled button furthest to the right in a navigation bar, and waits 30 seconds for `editor.root`. The picker's controls have no identifier of ours, so they are found by kind, place and the system's own identifier. The test prints lines that start with "m1-6b-new-project:" into the test log: "picker driven" or "picker not driven:" with the step where it stopped, the labels of the first three cells of the grid, so the order of the videos is known, the lengths on the first two blocks of the editor (blue then red reads 00:03 then 00:04), and "the system asked a question at picking" when a system alert was up.

Screenshots: `m1-6b-new-project-01-start`, `m1-6b-new-project-01-start-ar`, `m1-6b-new-project-04-relaunch`, `m1-6b-new-project-05-portrait`, and only when the picker is driven `m1-6b-new-project-02-picker` (two videos chosen, before the confirm) and `m1-6b-new-project-03-editor`. Mark: `m1-6b-new-project-01-picker`, before the tap on `start.newProject` in the try.

The words "Copying videos" and the state with `start.noneReadable` and `start.ok` are not reached by any launch value and have no UI test. Their keys are held on Linux and the screens are judged at the test install.
<!-- end slot: m1-6b-new-project -->

### m1-7-preview
<!-- slot: m1-7-preview -->
`UITests/PreviewTests.swift` holds the preview on the seeds `two-clips`, `two-clips-wide` and `empty`. It is built by the compile check and first runs in a wave run. Every test waits 60 seconds for `editor.root` after a start. A UI test cannot see the colour of the picture: what the area shows is judged on the screenshots, and the tests read the frame of `editor.picture`, the labels and the enabled states. No element says when a frame is drawn, so a test pauses 2 seconds before it takes a picture of the area. What the label reads and whether the button is enabled is `timeLabel` and `canPlay`, held on Linux by `EditorStateTests.swift`, and what `play`, `pause` and `movePlayhead` do is held by `ReduceTests.swift`.

- The first frame, on `two-clips`: `editor.picture`, `editor.play` and `editor.time` are among the descendants of `editor.previewRegion`. The width of the picture divided by its height lies between 0.55 and 0.58, the picture is inside the region and in the middle of its width, and the button and the label start under it. The label reads "00:00 / 00:07", the button reads "Play" and is enabled.
- Play and pause, on `two-clips`: after a tap the button reads "Pause". After 2 seconds and a second tap it reads "Play", the label reads "00:01", "00:02" or "00:03" before the slash, which equals the value of `editor.playhead`, and a second later it reads the same.
- The end, with `-playhead 3600`: after a tap the test reads the label until it is "00:07 / 00:07", prints the seconds it waited and fails only above 9, three times an expected 3. Then the button reads "Play" and the label equals the playhead. After a tap there the test reads the label until it is "00:01" or later and before "00:07", which only the player's reports give, prints the seconds and fails only above 6, three times an expected 2. After one more tap the label equals the playhead again.
- From blue into red, with `-playhead 1500`, half a second before the join on the 9:16 canvas: after a tap the test reads the label until it is "00:04" or later, prints the seconds and fails only above 9, three times an expected 3. After one more tap the label equals the playhead.
- The scrub, with `-playhead 3000`: the label reads "00:05 / 00:07". Three drags of the strip 320 points to the right from a tenth of the region's width, where no handle lies because nothing is selected, leave `editor.playhead` at "00:00" and the label at "00:00 / 00:07".
- The seed `empty`: the picture area is there, the label reads "00:00 / 00:00" and the button is disabled.
- Arabic, on `two-clips`: the label reads "00:00 / 00:07", the button reads the Arabic line of the word file and is left of the label as in English, and the picture has the same shape in the middle of the region.
- The wide canvas, on `two-clips-wide`, with no playhead value and with `-playhead 3000`: the width of the picture divided by its height lies between 1.74 and 1.81 and the picture is as wide as the region.

On Linux, `Tests/ReelsmithCoreTests/PreviewWordsTests.swift` fails when `preview.play` or `preview.pause` is missing from the English, the Arabic or the Swedish word file.

Screenshots: `m1-7-preview-01-first-frame` (blue whole with a black bar above and below), `m1-7-preview-01-first-frame-ar`, `m1-7-preview-02-placed` (red fills the area), `m1-7-preview-03-after-scrub` (blue with bars again), `m1-7-preview-04-empty` (black), `m1-7-preview-05-wide` (blue fills the wide area), `m1-7-preview-06-wide-bars` (red whole with a black bar left and right). Mark: `m1-7-preview-01-play`, the playback of the play and pause test. The pictures `m1-7-preview-02-placed` and `m1-7-preview-05-wide` are the two where a clip fills the canvas unscaled: both were black in the first simulator run while their tests passed, so they are looked at after every run.

That the item is built again when the project changes, that an old build never replaces a new one, that nothing is reported after a `pause` and that a failed build leaves the area black cannot be seen in these tests and is read in the diff.
<!-- end slot: m1-7-preview -->

### m1-9b-trim-handles
<!-- slot: m1-9b-trim-handles -->
`UITests/TrimTests.swift` holds the two trim handles on the seed `three-clips`. It is built by the compile check and first runs in a wave run. Every test waits 60 seconds for `editor.root` after a start and uses no control of the preview or the tools. How far a clip can be trimmed is `reduce` and `TimelineGeometry`, held on Linux by `EditActionsTests.swift` and `TimelineGeometryTests.swift`, and the UI tests below hold that the handles follow them.

The screen is 402 points wide with the playhead at x 201, and a handle is 24 points wide outside its edge. A drag starts in the middle of a handle with `press(forDuration:thenDragTo:)`, so each test starts with a `-playhead` that puts the tapped point, the handle and the end of the drag on the screen. A block is tapped a quarter of its width from its left edge. The project length is read by three drags of the strip to the left from x 362, where no handle lies in any of these tests, and then the value of `editor.playhead`.

- The handles, at 3000 ticks: before a tap `editor.trim.start` and `editor.trim.end` do not exist. After a tap on the red block the start handle ends where the block starts and the end handle starts where the block ends, and they read "Trim start" and "Trim end". A tap on the start handle, which lies over the end of the blue block, leaves red selected.
- The end handle, at 3000 ticks: a drag of 120 points to the left leaves `editor.clip.2` narrower than 240 points with green against it, red still selected and the playhead still at "00:05", so the drag was no scrub. A drag of the start handle 60 points to the left then changes nothing, which holds that the end was cut and not the start. The project length reads "00:06", "00:07" or "00:08".
- The start handle, at 3000 ticks: a drag of 120 points to the right leaves the block narrower with its left edge where it was, against blue. A drag of the end handle 120 points to the right then changes nothing, which holds that the start was cut and not the end. The length is the same as above.
- The limits, at 2700 ticks: a drag of the end handle of red 300 points to the left leaves the block 6 points wide with both handles outside its edges, and the length reads "00:05". A drag of 300 points to the right then leaves it 240 points wide, and the length reads "00:09". The screen has no room for a drag of 600 points: 300 is 66 points past each limit.
- The first clip, with no playhead value: the start handle of blue lies left of the strip. A drag of 120 points to the right leaves blue narrower with its left edge under the playhead.
- The last clip, at 4200 ticks: the end handle of green lies right of the strip. A drag of 60 points to the left leaves green narrower, and the length reads "00:07" or "00:08".
- Arabic, at 3000 ticks: the start handle is still at the left edge of the red block and the end handle at the right, and they read the Arabic lines of the word file.

That nothing is sent while the finger moves, that one trim is sent on release and that a drag starts with `pause` cannot be seen on this screen and is read in the diff.

On Linux, `Tests/ReelsmithCoreTests/TrimWordsTests.swift` fails when `trim.start` or `trim.end` is missing from the English, the Arabic or the Swedish word file.

Screenshots: `m1-9b-trim-handles-01-handles`, `m1-9b-trim-handles-01-handles-ar`, `m1-9b-trim-handles-02-shortest`. Marks: `m1-9b-trim-handles-01-trim-end`, `m1-9b-trim-handles-02-trim-start`, `m1-9b-trim-handles-03-limits`, `m1-9b-trim-handles-04-first-clip`, `m1-9b-trim-handles-05-last-clip`.
<!-- end slot: m1-9b-trim-handles -->

### m1-9a-split-delete
<!-- slot: m1-9a-split-delete -->
`UITests/ToolsTests.swift` holds the split and the delete button. It is built by the compile check and first runs in a wave run. Every test waits 60 seconds for `editor.root` after a start, taps blocks of the timeline strip and uses no control of the preview or the export. Whether a button is enabled is `canSplit` and `canDelete`, held on Linux by `EditActionsTests.swift`, and the UI tests below hold that the two buttons follow them.

- The row, on `three-clips` with no playhead value: `editor.split` and `editor.delete` are found among the descendants of `editor.toolsRegion`, read "Split" and "Delete", are both disabled, and split is left of delete.
- Split, then delete, on `three-clips` with `-playhead 600`: `editor.split` is enabled and `editor.delete` is not. After a tap on split the strip has `editor.clip.1` to `editor.clip.4`, touching, 60, 120, 240 and 120 points wide, none selected, `editor.playhead` still reads "00:01", and split is disabled, because the playhead is now on a join. A block is named by its position, so the two parts of the blue clip are blocks 1 and 2. A tap in the middle of `editor.clip.1` selects it and enables delete. After a tap on delete the strip has three blocks, 120, 240 and 120 points wide, none selected, and delete is disabled.
- The empty editor, on `two-clips`: twice, a tap in the middle of `editor.clip.1` and a tap on delete. Then no block is left, both buttons are disabled and `editor.seedInfo` starts with "0 clips".
- Arabic, on `three-clips`: the two buttons read the Arabic lines of the word file and split is right of delete.

On Linux, `Tests/ReelsmithCoreTests/ToolsWordsTests.swift` fails when `tools.split` or `tools.delete` is missing from the English, the Arabic or the Swedish word file.

Screenshots: `m1-9a-split-delete-01-tools`, `m1-9a-split-delete-01-tools-ar`, `m1-9a-split-delete-02-after-split`, `m1-9a-split-delete-03-after-delete`, `m1-9a-split-delete-04-empty`. No mark: nothing here moves.
<!-- end slot: m1-9a-split-delete -->

### m1-10-export
<!-- slot: m1-10-export -->
<!-- end slot: m1-10-export -->

### m1-11-guard
<!-- slot: m1-11-guard -->
`Tests/ReelsmithCoreTests/TrackGuardTests.swift` guards the edits as a whole and runs on Linux. It changes no product code and tests no single edit: what each edit does is held by `EditActionsTests.swift`.

- Two tests play 1000 runs of 50 actions each, one from `Seed.threeClips` and one from a project of two media that are 1219 and 2417 ticks long, so not whole frames. The actions come from a random source in the file itself (SplitMix64, whole number arithmetic only) with the start numbers 1 to 1000, so a run is the same on every platform and every time.
- After every action the state must be valid (each clip inside its source, each length whole frames and at least `minimumClip`, the playhead a whole frame inside the project, the selection a clip of the project or none), `renderPlan(for:)` must not throw and must give a plan as long as the project whose segments touch and lie inside their media, and a `split` or `deleteSelected` must change the state exactly when `canSplit` or `canDelete` was true.
- The run from the seed also fails when a kind of action was never sent. The kinds are the cases of the enum `Kind` in the file: every case of `EditorAction`, amounts past each limit, clip ids that are not in the project, and a project that became empty.
- A failure names the start number, the number of the action and what was broken, and prints the actions of that run. To play it again, send those actions to `reduce` one by one from the start state. The tests stop at the first run that fails.
- Two small tests hold that a trim of a clip before the playhead leaves the playhead at its time, and that a `trimEnd` that rounds to nothing still pauses.

Changing a weight, a range or the media list in the file changes every run, so the count of each kind must be looked at again.
<!-- end slot: m1-11-guard -->

### m1-12-whole-path
<!-- slot: m1-12-whole-path -->
<!-- end slot: m1-12-whole-path -->

### m1-13-canvas
<!-- slot: m1-13-canvas -->
- `Tests/ReelsmithCoreTests/CanvasTests.swift` runs on Linux. It holds `Canvas`: the two cases in order, their sizes, `startChoice`, the two word keys and `allWords`. It holds the canvas on the project (`Project()` is portrait, `Project(canvas: .landscape)` is landscape, each empty) and in the plan (`renderPlan(for:)` copies it, for an empty project too, and a plan built with no canvas is portrait). On the landscape canvas it places one clip alone, with every number compared with no tolerance: a picture stored 1920 by 1080, 1280 by 720 or 3840 by 2160 at 0, 0, 1920 by 1080, one stored 1080 by 1920 and the clip `turned` at 656.25, 0, 607.5 by 1080, one stored 1080 by 1080 at 420, 0, 1080 by 1080, and one stored 2532 by 1170 with a width of exactly 1920 at x 0. It holds the seed `two-clips-wide` by its name, also through `LaunchOptions`, with its clips, ids, length, canvas and the two places of its plan, and that the other three seeds are portrait. Last, from that seed, the canvas is still landscape after `addClips`, a `split` at 600 ticks, `trimStart`, `trimEnd` and `deleteSelected` down to the empty project.
- `Tests/ReelsmithEngineTests/CanvasEngineTests.swift` runs with `swift test` on macOS, on clips from `writeTestClip`, in the folder of `ExportTests` and through its `exported`. It exports the plan of `two-clips-wide` once: the file type, one H.264 picture track of 1920 by 1080 with 210 frames in 7 seconds, one AAC sound track, blue at three points across the canvas at 1.0 second, and at 5.0 seconds red at four points with black at (100, 540), (620, 540) and (1820, 540), the bars left and right of an edge near x 656. `turned` alone on the landscape canvas exports to 1920 by 1080 with 60 frames, white at (960, 200), blue at (960, 880) and black at (300, 540). A frame at 1.0 second of the player item of `two-clips-wide`, drawn through its video composition, is 1920 by 1080 with a blue middle. A colour matches within 24 of 255 per channel.
- The portrait canvas is held by the tests on the 9:16 seeds and on plans built with no canvas: `RenderPlanTests.swift`, `ExportTests.swift` and `CompositionTests.swift`.
<!-- end slot: m1-13-canvas -->
