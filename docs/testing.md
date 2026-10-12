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
