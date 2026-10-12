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
